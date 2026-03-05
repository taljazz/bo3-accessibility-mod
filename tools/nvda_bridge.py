"""
BO3 Zombies Accessibility Mod - NVDA TTS Bridge

Tails the BO3 console_mp.log file and speaks ACC_TTS: prefixed messages
through NVDA via the cytolk library.

Usage:
    conda activate bo3
    python nvda_bridge.py -v

The mod uses IPrintLn() to write TTS messages to the console log, since
logPrint() output does NOT appear in console_mp.log in BO3. IPrintLn lines
appear in the log as: [msg]ACC_TTS:Round 5
This daemon matches the ACC_TTS: substring within each line.

Requires:
    pip install cytolk
    NVDA must be running
"""

import os
import sys
import time
import glob
import argparse

# --- Configuration ---

# BO3 game directory
BO3_DIR = r"C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III"

# Possible log file locations (checked in order, most likely first)
LOG_PATHS = [
    os.path.join(BO3_DIR, "console_mp.log"),
    os.path.join(BO3_DIR, "mods", "zm_accessibility", "console_mp.log"),
    # Zombies sometimes uses console_zm.log
    os.path.join(BO3_DIR, "console_zm.log"),
]

# TTS prefix to look for in log lines
TTS_PREFIX = "ACC_TTS:"

# Poll interval in seconds (50ms for low latency)
POLL_INTERVAL = 0.05

# Messages that should interrupt current speech (high priority)
INTERRUPT_KEYWORDS = [
    "Health critical",
    "Out of ammo",
    "Surrounded",
    "Reload",
    "Ammo critical",
    "Nuke",
]


def find_log_file():
    """Find the console_mp.log file, checking multiple possible locations."""
    for path in LOG_PATHS:
        if os.path.exists(path):
            return path

    # Also check for any console*.log in the BO3 directory
    pattern = os.path.join(BO3_DIR, "console*.log")
    matches = glob.glob(pattern)
    if matches:
        # Return the most recently modified one
        matches.sort(key=os.path.getmtime, reverse=True)
        return matches[0]

    return None


def should_interrupt(message):
    """Check if this message should interrupt current speech."""
    msg_lower = message.lower()
    for keyword in INTERRUPT_KEYWORDS:
        if keyword.lower() in msg_lower:
            return True
    return False


def tail_and_speak(log_path, verbose=False):
    """
    Tail the log file and speak ACC_TTS: messages through NVDA.

    Seeks to end of file on start (ignores old history).
    Polls for new lines and speaks them via cytolk.
    Handles file rotation (game restart overwrites the log).
    """
    try:
        from cytolk import tolk
    except ImportError:
        print("ERROR: cytolk not installed. Run: pip install cytolk")
        print("Make sure NVDA is running before starting this bridge.")
        sys.exit(1)

    with tolk.tolk():
        print("NVDA TTS Bridge started")
        print(f"Watching: {log_path}")
        print(f"Poll interval: {POLL_INTERVAL * 1000:.0f}ms")
        print()
        print("The mod sets logfile dvar automatically.")
        print("Start BO3, load a zombies map with the zm_accessibility mod.")
        print("Press Ctrl+C to stop.")
        print()

        # Test that NVDA is reachable
        tolk.speak("Accessibility bridge connected", interrupt=True)

        # Wait for the log file to appear if it doesn't exist yet
        print("Waiting for log file..." if not os.path.exists(log_path) else "Log file found.")
        while not os.path.exists(log_path):
            # Keep checking alternate paths in case it appears elsewhere
            alt = find_log_file()
            if alt is not None:
                log_path = alt
                print(f"Found log at: {log_path}")
                break
            time.sleep(2.0)

        # Open file and seek to end (ignore old content)
        f = open(log_path, "r", encoding="utf-8", errors="replace")
        f.seek(0, 2)
        last_inode = os.stat(log_path).st_ino if hasattr(os.stat(log_path), 'st_ino') else None

        if verbose:
            print(f"Seeked to end of file (position {f.tell()})")
            print("Listening for ACC_TTS: messages...")

        try:
            while True:
                line = f.readline()

                if line:
                    line = line.strip()

                    # Check for our TTS prefix
                    if TTS_PREFIX in line:
                        idx = line.index(TTS_PREFIX)
                        message = line[idx + len(TTS_PREFIX):].strip()

                        if message:
                            if verbose:
                                print(f"  [>] {message}")

                            tolk.speak(message, interrupt=True)
                else:
                    time.sleep(POLL_INTERVAL)

                    # Handle file rotation / truncation / recreation
                    try:
                        current_pos = f.tell()
                        file_size = os.path.getsize(log_path)

                        if file_size < current_pos:
                            # File was truncated (game restarted) — reopen from start
                            if verbose:
                                print("Log file rotated, reopening from start")
                            f.close()
                            f = open(log_path, "r", encoding="utf-8", errors="replace")
                    except OSError:
                        # File deleted — try to find it again
                        if verbose:
                            print("Log file disappeared, searching...")
                        f.close()
                        while True:
                            alt = find_log_file()
                            if alt is not None:
                                log_path = alt
                                break
                            time.sleep(2.0)
                        f = open(log_path, "r", encoding="utf-8", errors="replace")
                        f.seek(0, 2)

        except KeyboardInterrupt:
            print("\nStopping NVDA TTS Bridge...")
            tolk.speak("Bridge disconnected", interrupt=True)
            time.sleep(0.5)
        finally:
            f.close()


def main():
    parser = argparse.ArgumentParser(
        description="BO3 Zombies Accessibility Mod - NVDA TTS Bridge"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Print all TTS messages to console as they are spoken"
    )
    parser.add_argument(
        "-l", "--log-path",
        type=str,
        default=None,
        help="Override the log file path (default: auto-detect)"
    )
    args = parser.parse_args()

    log_path = args.log_path
    if log_path is None:
        log_path = find_log_file()

    if log_path is None:
        print("console_mp.log not found yet.")
        print(f"Searched: {', '.join(LOG_PATHS)}")
        print("Will wait for BO3 to create the log file...")
        print()
        log_path = LOG_PATHS[0]

    tail_and_speak(log_path, verbose=args.verbose)


if __name__ == "__main__":
    main()
