"""
BO3 Zombies Accessibility Mod - Combined TTS Bridge (Gameplay + Menu OCR)

Combines two TTS systems in one process:
1. Log tail: reads ACC_TTS: messages from console_mp.log (in-game announcements)
2. Screen OCR: captures the game window and reads menu text via Windows OCR

The log tail handles gameplay (zombie alerts, prompts, round changes).
The OCR handles menus (main menu, lobby, map selection, GobbleGum, settings).

When gameplay TTS messages are flowing, OCR is suppressed to avoid crosstalk.
When no gameplay messages arrive for a few seconds, OCR resumes for menus.

Usage:
    conda activate bo3
    python menu_ocr_bridge.py -v

Hotkeys:
    Shift+F9 = Toggle menu OCR on/off

Requires:
    pip install cytolk bettercam Pillow numpy keyboard
    pip install winrt-windows-media-ocr winrt-windows-graphics-imaging winrt-windows-storage-streams
    NVDA must be running
"""

import os
import sys
import time
import glob
import threading
import argparse
import ctypes
import numpy as np
from PIL import Image
import keyboard

# --- Configuration ---

BO3_DIR = r"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III"

LOG_PATHS = [
    os.path.join(BO3_DIR, "console_mp.log"),
    os.path.join(BO3_DIR, "mods", "zm_accessibility", "console_mp.log"),
    os.path.join(BO3_DIR, "console_zm.log"),
]

TTS_PREFIX = "ACC_TTS:"
LOG_POLL_INTERVAL = 0.05          # 50ms for low latency log reading
OCR_POLL_INTERVAL = 0.5           # 500ms between OCR checks (~2/sec) — light on GPU
OCR_STABLE_DELAY = 0.15           # Brief wait for screen to stabilize
GAMEPLAY_TIMEOUT = 8.0            # Seconds of silence before switching to OCR mode
DHASH_THRESHOLD = 3               # Hamming distance threshold for "screen changed"
OCR_COOLDOWN = 1.0                # Minimum seconds between OCR speech outputs
DUPLICATE_SUPPRESS_TIME = 10.0    # Don't re-speak identical text within this window
HEADER_CHANGE_THRESHOLD = 12      # dhash distance that signals a new page (not just highlight move)


# --- Foreground Window Check ---

def is_bo3_foreground():
    """Check if BO3 is the active foreground window."""
    try:
        hwnd = ctypes.windll.user32.GetForegroundWindow()
        length = ctypes.windll.user32.GetWindowTextLengthW(hwnd)
        if length == 0:
            return False
        buf = ctypes.create_unicode_buffer(length + 1)
        ctypes.windll.user32.GetWindowTextW(hwnd, buf, length + 1)
        title = buf.value.lower()
        return "call of duty" in title or "black ops" in title
    except Exception:
        return True  # If check fails, assume yes to avoid blocking


# --- Perceptual Hash for Change Detection ---

def dhash(pil_image, hash_size=8):
    """Compute difference hash of a PIL image. Fast (~0.5ms)."""
    resized = pil_image.convert("L").resize((hash_size + 1, hash_size), Image.LANCZOS)
    pixels = np.array(resized)
    diff = pixels[:, 1:] > pixels[:, :-1]
    return diff.flatten()


def hamming_distance(hash1, hash2):
    """Count differing bits between two hashes."""
    return np.sum(hash1 != hash2)


# --- Highlight Detection ---

def find_highlight_strip(frame, verbose=False):
    """Find the highlighted/selected menu item in a BO3 menu screenshot.

    BO3 menus use a solid, vivid orange/amber highlight bar behind the
    selected item. Background elements (fire, glow) are much less saturated.
    We require very high saturation to match ONLY the UI highlight bar.

    Returns a cropped PIL Image of just the highlighted row, or None.
    """
    h, w = frame.size[1], frame.size[0]

    # Skip top 10% (avoids BO3 logo, decorative orange elements, and
    # window title bar) and bottom 4% (taskbar)
    y_start = int(h * 0.10)
    y_end = int(h * 0.96)

    # Only analyze the left portion where menus live
    menu_region = frame.crop((0, y_start, int(w * 0.5), y_end))
    mw, mh = menu_region.size

    # Convert to HSV for color-based detection
    hsv = np.array(menu_region.convert("HSV"))
    hue, sat, val = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]

    # Detect the solid orange highlight bar — VERY high saturation to
    # exclude warm-toned background effects (campfire glow, explosions)
    # PIL HSV: hue 0-255 (red=0, orange~15-38, yellow~43)
    orange = (hue >= 8) & (hue <= 42) & (sat >= 150) & (val >= 100)

    # Count orange pixels per row
    row_scores = orange.sum(axis=1).astype(float)

    # The real highlight bar spans a significant width — require at least
    # 8% of the menu region width to be solid orange
    min_orange = mw * 0.08
    if row_scores.max() < min_orange:
        if verbose:
            print(f"  [OCR] No highlight bar (max={row_scores.max():.0f}, need={min_orange:.0f})")
        return None

    # Find all rows that have meaningful orange (above half the peak)
    peak_score = row_scores.max()
    qualifying = row_scores >= (peak_score * 0.5)

    # Find contiguous runs of qualifying rows
    best_start = best_end = -1
    best_len = 0
    run_start = -1

    for i in range(mh):
        if qualifying[i]:
            if run_start == -1:
                run_start = i
        else:
            if run_start != -1:
                run_len = i - run_start
                if run_len > best_len:
                    best_len = run_len
                    best_start = run_start
                    best_end = i
                run_start = -1
    # Handle run that extends to the end
    if run_start != -1:
        run_len = mh - run_start
        if run_len > best_len:
            best_len = run_len
            best_start = run_start
            best_end = mh

    # Minimum bar height — filters false positives from small UI elements
    # (GobbleGum icon borders ~18px, decorative accents)
    if best_len < 20:
        if verbose and best_len > 0:
            print(f"  [OCR] Orange band too thin ({best_len}px)")
        return None

    # Maximum bar height — single menu items have bars of 20-52px at 1080p;
    # larger means merged items or campfire glow contamination
    if best_len > 55:
        if verbose:
            print(f"  [OCR] Bar too large ({best_len}px, max=55)")
        return None

    # Density check: real highlight bars have consistent solid orange;
    # icon borders and background effects are spotty
    band_scores = row_scores[best_start:best_end]
    dense_rows = int((band_scores >= min_orange).sum())
    density = dense_rows / best_len if best_len > 0 else 0
    if density < 0.5:
        if verbose:
            print(f"  [OCR] Low orange density ({density:.0%})")
        return None

    # Center the crop on the row with the strongest orange signal.
    # This targets the core of the highlighted item even during scroll
    # animations where the bar may briefly span multiple items.
    peak_row = best_start + int(np.argmax(row_scores[best_start:best_end]))

    # Fixed crop height proportional to screen resolution (~70px at 1080p).
    # BO3 uses all-caps text that fits within the orange bar itself, so we
    # only need a small window — tight enough for one item without bleeding
    # into adjacent menu items (~45px apart center-to-center).
    half_crop = int(h * 0.032)
    top = max(y_start, y_start + peak_row - half_crop)
    bottom = min(h, y_start + peak_row + half_crop)
    band_height = bottom - top

    if verbose:
        print(f"  [OCR] Highlight: rows {top}-{bottom} ({band_height}px, bar={best_len}px)")

    # Crop left 40% — menu text is on the far left; keeping the crop
    # tight avoids background imagery that OCR misreads as noise.
    # Start at x=15 to skip left-edge decorative elements that cause
    # noise chars like "t BONUS" instead of "BONUS".
    return frame.crop((15, top, int(w * 0.4), bottom))


def extract_page_header(frame):
    """Crop the page title region from the top of the screen.

    BO3 page headers (MAPS, ZOMBIES, MODS, DR. MONTY'S FACTORY, etc.)
    are large bold text in the top-left area.
    """
    h, w = frame.size[1], frame.size[0]
    # Headers live in the top ~12%, left ~55%
    return frame.crop((0, int(h * 0.01), int(w * 0.55), int(h * 0.12)))


def extract_bottom_bar(frame):
    """Crop the bottom action bar (A Select, B Back, etc.)."""
    h, w = frame.size[1], frame.size[0]
    return frame.crop((0, int(h * 0.93), w, h))


def extract_center_text(frame):
    """Crop the main content region for non-standard menu screens.

    Covers everything between the header and the bottom bar:
    labels, counters, descriptions, banners, prompts.
    (e.g. LIQUID DIVINIUM 002, Y Purchase, 3 VATS BEST CHANCE AT RARE)
    """
    h, w = frame.size[1], frame.size[0]
    return frame.crop((int(w * 0.02), int(h * 0.12), int(w * 0.7), int(h * 0.9)))


def preprocess_for_ocr(pil_image):
    """Extract bright text from BO3 menu screenshots for clean OCR.

    BO3 menus use white/bright text on orange highlight bars or dark
    backgrounds. We isolate the text by thresholding on the minimum RGB
    channel — white text has all channels high, while orange bars (high R,
    low B) and dark backgrounds both fall below the threshold.
    """
    arr = np.array(pil_image)

    # White/bright text: all RGB channels above threshold → min channel high.
    # Orange bar (R~230, G~150, B~50): min=50 → excluded.
    # Dark background (R~20, G~20, B~20): min=20 → excluded.
    min_channel = arr.min(axis=2)
    binary = np.where(min_channel > 130, 255, 0).astype(np.uint8)

    img = Image.fromarray(binary)

    # Upscale very small crops — OCR needs minimum text size
    if img.height < 50:
        scale = min(2.5, max(2.0, 50.0 / img.height))
        img = img.resize(
            (int(img.width * scale), int(img.height * scale)),
            Image.LANCZOS,
        )

    return img.convert("RGB")


# --- OCR Engine ---

class OCREngine:
    """Windows OCR via WinRT API directly (avoids screen-ocr's dxcam conflict).

    Optimizations:
    - Reuses a single asyncio event loop (no create/destroy per call)
    - Downscales large images to reduce processing time
    """

    MAX_OCR_WIDTH = 960  # Half of 1080p width — plenty for text recognition

    def __init__(self):
        self._engine = None
        self._loop = None
        self._DataWriter = None
        self._SoftwareBitmap = None
        self._BitmapPixelFormat = None

    def initialize(self):
        try:
            from winrt.windows.media.ocr import OcrEngine
            from winrt.windows.storage.streams import DataWriter
            from winrt.windows.graphics.imaging import SoftwareBitmap, BitmapPixelFormat

            self._engine = OcrEngine.try_create_from_user_profile_languages()
            if self._engine is None:
                print("WARNING: OCR engine unavailable. Install a language pack in Windows Settings.")
                return False

            # Cache imports and create reusable event loop
            self._DataWriter = DataWriter
            self._SoftwareBitmap = SoftwareBitmap
            self._BitmapPixelFormat = BitmapPixelFormat

            import asyncio
            self._loop = asyncio.new_event_loop()

            return True
        except ImportError:
            print("WARNING: WinRT OCR packages not installed. Menu OCR disabled.")
            print("  Install with: pip install winrt-windows-media-ocr winrt-windows-graphics-imaging winrt-windows-storage-streams")
            return False
        except Exception as e:
            print(f"WARNING: OCR init failed: {e}")
            return False

    def read_image(self, pil_image):
        """Run OCR on a PIL Image, return extracted text."""
        if self._engine is None:
            return ""
        try:
            # Downscale large images for faster OCR
            img = pil_image
            if img.width > self.MAX_OCR_WIDTH:
                ratio = self.MAX_OCR_WIDTH / img.width
                img = img.resize(
                    (self.MAX_OCR_WIDTH, int(img.height * ratio)),
                    Image.BILINEAR,
                )

            img = img.convert("RGBA") if img.mode != "RGBA" else img

            writer = self._DataWriter()
            writer.write_bytes(img.tobytes())
            bitmap = self._SoftwareBitmap.create_copy_from_buffer(
                writer.detach_buffer(),
                self._BitmapPixelFormat.RGBA8,
                img.width,
                img.height,
            )

            result = self._loop.run_until_complete(
                self._engine.recognize_async(bitmap)
            )
            return result.text.strip()
        except Exception as e:
            if not hasattr(self, '_ocr_error_shown'):
                print(f"  [OCR] read_image error: {e}")
                self._ocr_error_shown = True
            return ""


# --- Screen Capture ---

class ScreenCapture:
    """Screen capture using BetterCam (maintained DXcam fork).

    Uses on-demand grab() instead of continuous capture to minimize
    GPU overhead. grab() returns None when the screen hasn't changed
    (DXGI only delivers new frames on change) — we cache the last
    valid frame so OCR can still work on static screens.
    """

    def __init__(self):
        self._camera = None
        self._last_frame = None  # Cache for static screen re-reads

    def initialize(self):
        try:
            import bettercam
            import atexit
            self._camera = bettercam.create(output_color="RGB")
            atexit.register(self.release)
            return True
        except ImportError:
            print("WARNING: bettercam not installed. Menu OCR disabled.")
            print("  Install with: pip install bettercam")
            return False
        except Exception as e:
            print(f"WARNING: Screen capture init failed: {e}")
            return False

    def release(self):
        """Explicitly release the camera to avoid cleanup errors."""
        if self._camera is not None:
            try:
                self._camera.release()
            except Exception:
                pass
            self._camera = None

    def grab(self):
        """Capture screen. Returns (PIL Image, changed: bool).

        Uses DXGI grab() which only returns a frame when the screen updated.
        Returns cached frame when screen is static (changed=False).
        """
        if self._camera is None:
            return None, False
        try:
            frame = self._camera.grab()
            if frame is not None:
                self._last_frame = Image.fromarray(frame)
                return self._last_frame, True
            # Screen hasn't changed — return cached frame
            if self._last_frame is not None:
                return self._last_frame, False
            return None, False
        except Exception:
            return None, False


# --- Log File Utilities ---

def find_log_file():
    """Find the console_mp.log file."""
    for path in LOG_PATHS:
        if os.path.exists(path):
            return path
    pattern = os.path.join(BO3_DIR, "console*.log")
    matches = glob.glob(pattern)
    if matches:
        matches.sort(key=os.path.getmtime, reverse=True)
        return matches[0]
    return None


# --- Combined Bridge ---

class AccessibilityBridge:
    """Combined gameplay TTS + menu OCR bridge."""

    def __init__(self, verbose=False, log_path=None, ocr_enabled=True):
        self.verbose = verbose
        self.log_path = log_path
        self.ocr_enabled = ocr_enabled

        # Speech state
        self._tolk = None
        self._speech_lock = threading.Lock()

        # Mode tracking
        self.last_gameplay_tts_time = 0
        self.in_gameplay = False

        # OCR state
        self.ocr_engine = OCREngine()
        self.screen_capture = ScreenCapture()
        self.last_ocr_hash = None
        self.last_ocr_text = ""
        self.last_ocr_speak_time = 0
        self.last_spoken_texts = {}  # text -> timestamp, for dedup
        self.last_page_header = ""   # track current page title for change detection

        # OCR toggle (Shift+F9)
        self.ocr_active = True

        # Threads
        self._stop_event = threading.Event()

    def toggle_ocr(self):
        """Toggle OCR on/off via hotkey."""
        self.ocr_active = not self.ocr_active
        state = "on" if self.ocr_active else "off"
        if self.verbose:
            print(f"  [OCR] Toggled {state}")
        self.speak(f"Menu reading {state}", interrupt=True)

    def speak(self, text, interrupt=True):
        """Thread-safe speech via NVDA."""
        if not text:
            return
        with self._speech_lock:
            try:
                from cytolk import tolk
                tolk.speak(text, interrupt=interrupt)
            except Exception as e:
                if self.verbose:
                    print(f"  [!] Speech error: {e}")

    def start(self):
        """Start the bridge."""
        print("=" * 55)
        print("  BO3 Accessibility - Combined TTS Bridge")
        print("=" * 55)
        print()

        # Initialize screen capture and OCR BEFORE cytolk, because
        # bettercam (DXGI Desktop Duplication) needs COM in MTA mode,
        # and cytolk's tolk() context sets COM to STA which can't be changed after.
        ocr_ready = False
        if self.ocr_enabled:
            cap_ok = self.screen_capture.initialize()
            ocr_ok = self.ocr_engine.initialize()
            ocr_ready = cap_ok and ocr_ok
            if ocr_ready:
                print("[OCR] Menu screen reader: READY")
            else:
                print("[OCR] Menu screen reader: DISABLED (init failed)")
        else:
            print("[OCR] Menu screen reader: DISABLED (--no-ocr flag)")

        from cytolk import tolk as tolk_mod

        with tolk_mod.tolk():
            self._tolk = tolk_mod

            tolk_mod.speak("Accessibility bridge connected", interrupt=True)

            # Register global hotkey: Shift+F9 toggles OCR
            if ocr_ready:
                keyboard.add_hotkey("shift+f9", self.toggle_ocr, suppress=False)
                print("[KEY] Shift+F9 = Toggle menu OCR on/off")

            print()

            # Start log tail thread
            log_thread = threading.Thread(
                target=self._log_tail_loop, daemon=True, name="log-tail"
            )
            log_thread.start()

            # Start OCR thread if available
            if ocr_ready:
                ocr_thread = threading.Thread(
                    target=self._ocr_loop, daemon=True, name="ocr-reader"
                )
                ocr_thread.start()

            # Main thread: wait for Ctrl+C
            try:
                print("Bridge running. Press Ctrl+C to stop.")
                print()
                while not self._stop_event.is_set():
                    time.sleep(0.5)
            except KeyboardInterrupt:
                print("\nStopping bridge...")
                self._stop_event.set()
                keyboard.unhook_all()
                tolk_mod.speak("Bridge disconnected", interrupt=True)
                time.sleep(0.5)

    # ==========================================
    # LOG TAIL (gameplay TTS)
    # ==========================================

    def _log_tail_loop(self):
        """Tail console_mp.log for ACC_TTS: messages."""
        log_path = self.log_path
        if log_path is None:
            log_path = find_log_file()
        if log_path is None:
            log_path = LOG_PATHS[0]

        print(f"[LOG] Watching: {log_path}")

        # Wait for file to appear
        while not os.path.exists(log_path) and not self._stop_event.is_set():
            alt = find_log_file()
            if alt is not None:
                log_path = alt
                break
            time.sleep(2.0)

        if self._stop_event.is_set():
            return

        print(f"[LOG] Log file found. Listening for ACC_TTS: messages...")

        f = open(log_path, "r", encoding="utf-8", errors="replace")
        f.seek(0, 2)  # Seek to end

        while not self._stop_event.is_set():
            line = f.readline()

            if line:
                line = line.strip()
                if TTS_PREFIX in line:
                    idx = line.index(TTS_PREFIX)
                    message = line[idx + len(TTS_PREFIX):].strip()

                    if message:
                        if self.verbose:
                            print(f"  [GAME] {message}")

                        self.last_gameplay_tts_time = time.time()
                        self.in_gameplay = True
                        self.speak(message, interrupt=True)
            else:
                time.sleep(LOG_POLL_INTERVAL)

                # Handle file rotation
                try:
                    current_pos = f.tell()
                    file_size = os.path.getsize(log_path)
                    if file_size < current_pos:
                        if self.verbose:
                            print("  [LOG] File rotated, reopening")
                        f.close()
                        f = open(log_path, "r", encoding="utf-8", errors="replace")
                except OSError:
                    f.close()
                    while not self._stop_event.is_set():
                        alt = find_log_file()
                        if alt is not None:
                            log_path = alt
                            break
                        time.sleep(2.0)
                    if self._stop_event.is_set():
                        return
                    f = open(log_path, "r", encoding="utf-8", errors="replace")
                    f.seek(0, 2)

        f.close()

    # ==========================================
    # OCR LOOP (menu reading)
    # ==========================================

    def _ocr_loop(self):
        """Periodically capture screen and OCR for menu text.

        Optimized for minimal GPU impact:
        - On-demand grab() (no continuous capture thread)
        - DXGI change detection: skip OCR when screen is static
        - Max 2 OCR calls per cycle (header only on page change + 1 content)
        - Downscaled images for faster OCR processing
        - Long sleep intervals between checks
        """
        print("[OCR] Screen reader active. Will read menus when not in gameplay.")
        time.sleep(1.0)

        while not self._stop_event.is_set():
            time.sleep(OCR_POLL_INTERVAL)

            # ── Gate checks (no GPU work) ──
            if not self.ocr_active:
                continue

            if not is_bo3_foreground():
                time.sleep(1.0)
                continue

            if self.in_gameplay:
                elapsed = time.time() - self.last_gameplay_tts_time
                if elapsed < GAMEPLAY_TIMEOUT:
                    time.sleep(1.0)
                    continue
                else:
                    self.in_gameplay = False
                    self.last_ocr_hash = None
                    if self.verbose:
                        print("  [OCR] Switched to menu mode")

            # ── Grab frame (lightweight — DXGI returns None if unchanged) ──
            frame, changed = self.screen_capture.grab()
            if frame is None:
                continue

            if not changed:
                # Screen is static — no need to re-OCR
                continue

            # ── Screen changed — verify with dhash on menu region ──
            fw, fh = frame.size
            menu_crop = frame.crop((0, 0, int(fw * 0.55), fh))
            current_hash = dhash(menu_crop)
            dist = 99  # Force first read

            if self.last_ocr_hash is not None:
                dist = hamming_distance(current_hash, self.last_ocr_hash)
                if dist <= DHASH_THRESHOLD:
                    continue

            if self.verbose:
                print(f"  [OCR] Screen changed (dist={dist})")

            # Brief stabilization wait, then re-grab
            time.sleep(OCR_STABLE_DELAY)
            fresh, _ = self.screen_capture.grab()
            if fresh is not None:
                frame = fresh
                fw, fh = frame.size
                menu_crop = frame.crop((0, 0, int(fw * 0.55), fh))
                current_hash = dhash(menu_crop)

            self.last_ocr_hash = current_hash

            # ── OCR: max 2 calls per cycle ──
            now = time.time()
            speech_parts = []

            # Step 1: Page header — only on big screen changes (new page)
            if dist >= HEADER_CHANGE_THRESHOLD:
                header_crop = extract_page_header(frame)
                header_text = self._clean_ocr_text(
                    self.ocr_engine.read_image(preprocess_for_ocr(header_crop))
                )
                if header_text and header_text != self.last_page_header:
                    self.last_page_header = header_text
                    speech_parts.append(header_text)
                    if self.verbose:
                        print(f"  [OCR] Header: {header_text}")

            # Step 2: Highlight bar OR fallback (ONE call, not both)
            highlight = find_highlight_strip(frame, verbose=self.verbose)

            if highlight is not None:
                hl_text = self._clean_ocr_text(
                    self.ocr_engine.read_image(preprocess_for_ocr(highlight))
                )
                if hl_text:
                    speech_parts.append(hl_text)
                    if self.verbose:
                        print(f"  [OCR] Highlight: {hl_text}")
            elif dist >= HEADER_CHANGE_THRESHOLD:
                # Fallback only on significant screen changes, not every frame
                if self.verbose:
                    print("  [OCR] Fallback read")
                fallback_crop = extract_center_text(frame)
                fallback_text = self._clean_ocr_text(
                    self.ocr_engine.read_image(preprocess_for_ocr(fallback_crop)),
                    max_lines=5,
                )
                if fallback_text:
                    speech_parts.append(fallback_text)

            # ── Assemble and speak ──
            if not speech_parts:
                continue

            full_speech = ". ".join(speech_parts)

            # Dedup
            if full_speech in self.last_spoken_texts:
                if now - self.last_spoken_texts[full_speech] < DUPLICATE_SUPPRESS_TIME:
                    if self.verbose:
                        print(f"  [OCR] Suppressed duplicate")
                    continue

            # Rate limit
            if now - self.last_ocr_speak_time < OCR_COOLDOWN:
                continue

            if self.verbose:
                display = full_speech[:100] + "..." if len(full_speech) > 100 else full_speech
                print(f"  [OCR] Speaking: {display}")

            self.speak(full_speech, interrupt=True)
            self.last_ocr_text = full_speech
            self.last_ocr_speak_time = now
            self.last_spoken_texts[full_speech] = now

            # Clean old dedup entries
            self.last_spoken_texts = {
                t: ts for t, ts in self.last_spoken_texts.items()
                if now - ts < DUPLICATE_SUPPRESS_TIME * 2
            }

    def _clean_ocr_text(self, raw_text, max_lines=0):
        """Clean and filter OCR output for TTS.

        Args:
            raw_text: Raw OCR output string.
            max_lines: Maximum meaningful lines to keep (0 = unlimited).
        """
        if not raw_text:
            return ""

        lines = raw_text.split("\n")
        meaningful = []

        for line in lines:
            line = line.strip()

            # Strip leading/trailing noise characters from OCR misreads
            # (background edges read as quotes, periods, commas, dashes)
            line = line.strip(".,;:!?\"'`-_/\\|@#$%^&*()[]{}~<> ")

            # Skip very short fragments (OCR noise from icons/artifacts)
            if len(line) < 3:
                continue

            # Skip lines that are just numbers or special chars
            stripped = line.replace(" ", "").replace(".", "").replace(",", "")
            if not any(c.isalpha() for c in stripped):
                continue

            # Skip lines that look like timestamps (clock from taskbar)
            if any(ts in line for ts in ["AM ", "PM ", "/202"]):
                continue

            # Skip window title bar / non-menu content that OCR misreads
            lower = line.lower()
            if any(skip in lower for skip in [
                "call of duty", "taljazz", "ship -", "- ship",
                "black ops"
            ]):
                continue

            meaningful.append(line)

            # Cap line count for fallback reads (avoids reading entire lobby)
            if max_lines > 0 and len(meaningful) >= max_lines:
                break

        if not meaningful:
            return ""

        # Join into a single string, limit length for TTS
        result = ". ".join(meaningful)

        # Cap at reasonable TTS length
        if len(result) > 500:
            result = result[:500]

        return result


# --- Entry Point ---

def main():
    parser = argparse.ArgumentParser(
        description="BO3 Accessibility - Combined TTS Bridge (Gameplay + Menu OCR)"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Print messages to console as they are spoken"
    )
    parser.add_argument(
        "-l", "--log-path",
        type=str,
        default=None,
        help="Override the log file path"
    )
    parser.add_argument(
        "--no-ocr",
        action="store_true",
        help="Disable menu OCR (gameplay TTS only, same as old bridge)"
    )
    args = parser.parse_args()

    bridge = AccessibilityBridge(
        verbose=args.verbose,
        log_path=args.log_path,
        ocr_enabled=not args.no_ocr,
    )
    bridge.start()


if __name__ == "__main__":
    main()
