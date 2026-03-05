"""
BO3 Zombies Accessibility Mod - TTS Audio Generator
Generates all voice line .wav files using Windows SAPI directly via COM.

Usage:
    python generate_tts_audio.py

Requirements:
    - Windows OS (uses Windows SAPI speech engine)
    - Python 3.x
    - pywin32 (install with: pip install pywin32)

Output:
    Creates .wav files in the /sound/accessibility/ folder,
    organized by category subdirectories.
"""

import os
import sys
import time

# ============================================
# CONFIGURATION
# ============================================

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_BASE = os.path.join(SCRIPT_DIR, "..", "sound", "accessibility")

# TTS settings
TTS_RATE = 1            # Speech rate: -10 (slowest) to 10 (fastest). 1 = slightly slow for clarity.
TTS_VOLUME = 100        # Volume: 0 to 100
TTS_VOICE_INDEX = 0     # 0 = default voice

# ============================================
# VOICE LINES DEFINITIONS
# ============================================

voice_lines = {
    "rounds": {
        f"aud_acc_round_{i}": f"Round {i}"
        for i in range(1, 101)
    },

    "points": {
        "aud_acc_points_100": "100 points",
        "aud_acc_points_200": "200 points",
        "aud_acc_points_300": "300 points",
        "aud_acc_points_400": "400 points",
        "aud_acc_points_500": "500 points",
        "aud_acc_points_600": "600 points",
        "aud_acc_points_700": "700 points",
        "aud_acc_points_800": "800 points",
        "aud_acc_points_900": "900 points",
        "aud_acc_points_1000": "1000 points",
        "aud_acc_points_2000": "2000 points",
        "aud_acc_points_3000": "3000 points",
        "aud_acc_points_4000": "4000 points",
        "aud_acc_points_5000": "5000 points",
        "aud_acc_points_6000": "6000 points",
        "aud_acc_points_7000": "7000 points",
        "aud_acc_points_8000": "8000 points",
        "aud_acc_points_9000": "9000 points",
        "aud_acc_points_10000": "10,000 points",
        "aud_acc_points_15000": "15,000 points",
        "aud_acc_points_20000": "20,000 points",
        "aud_acc_points_25000": "25,000 points",
        "aud_acc_points_30000": "30,000 points",
        "aud_acc_points_40000": "40,000 points",
        "aud_acc_points_50000": "50,000 points",
        "aud_acc_points_60000": "60,000 points",
        "aud_acc_points_70000": "70,000 points",
        "aud_acc_points_80000": "80,000 points",
        "aud_acc_points_90000": "90,000 points",
        "aud_acc_points_100000": "100,000 points",
    },

    "health": {
        "aud_acc_health_critical": "Health critical",
        "aud_acc_health_warning": "Health low",
        "aud_acc_health_full": "Health recovered",
        "aud_acc_health_recovered": "Health regenerated",
        "aud_acc_damage_taken": "Hit",
    },

    "ammo": {
        "aud_acc_ammo_empty": "Out of ammo",
        "aud_acc_ammo_reload": "Reload",
        "aud_acc_ammo_critical": "Last clip, ammo critical",
        "aud_acc_ammo_low": "Ammo low",
    },

    "targeting": {
        "aud_acc_target_acquired": "Target acquired",
        "aud_acc_target_lost": "Target lost",
    },

    "proximity": {
        "aud_acc_dir_front": "Front",
        "aud_acc_dir_behind": "Behind",
        "aud_acc_dir_left": "Left",
        "aud_acc_dir_right": "Right",
        "aud_acc_swarm_warning": "Surrounded",
        "aud_acc_all_clear": "Clear",
    },

    "threat": {
        "aud_acc_threat_critical": "Danger close",
        "aud_acc_threat_high": "Danger",
        "aud_acc_threat_medium": "Warning",
        "aud_acc_threat_low": "Zombies nearby",
    },

    "beacons": {
        "aud_acc_beacon_perk_close": "Perk machine, here",
        "aud_acc_beacon_perk_near": "Perk machine, nearby",
        "aud_acc_beacon_perk_far": "Perk machine, ahead",
        "aud_acc_beacon_wallbuy_close": "Wall weapon, here",
        "aud_acc_beacon_wallbuy_near": "Wall weapon, nearby",
        "aud_acc_beacon_box_close": "Mystery box, here",
        "aud_acc_beacon_box_near": "Mystery box, nearby",
        "aud_acc_beacon_box_far": "Mystery box, ahead",
        "aud_acc_beacon_door_close": "Door, here",
        "aud_acc_beacon_door_far": "Door, nearby",
        "aud_acc_beacon_power_close": "Power switch, here",
        "aud_acc_beacon_power_near": "Power switch, nearby",
        "aud_acc_beacon_power_far": "Power switch, ahead",
        "aud_acc_beacon_pap_close": "Pack a Punch, here",
        "aud_acc_beacon_pap_near": "Pack a Punch, nearby",
    },

    "general": {
        "aud_acc_spawned": "Game started",
        "aud_acc_round_start": "New round",
        "aud_acc_points_gained": "Points earned",
        "aud_acc_points_milestone": "Points milestone reached",
        "aud_acc_points_status": "Points update",
    },

    "perks": {
        "aud_acc_perk_juggernog": "Juggernog acquired",
        "aud_acc_perk_speedcola": "Speed Cola acquired",
        "aud_acc_perk_doubletap": "Double Tap acquired",
        "aud_acc_perk_quickrevive": "Quick Revive acquired",
        "aud_acc_perk_staminup": "Stamin-Up acquired",
        "aud_acc_perk_widowswine": "Widows Wine acquired",
        "aud_acc_perk_deadshot": "Deadshot Daiquiri acquired",
        "aud_acc_perk_mulekick": "Mule Kick acquired",
        "aud_acc_perk_electriccherry": "Electric Cherry acquired",
    },

    "powerups": {
        "aud_acc_powerup_nuke": "Nuke activated",
        "aud_acc_powerup_insta": "Insta-Kill activated",
        "aud_acc_powerup_double": "Double Points activated",
        "aud_acc_powerup_maxammo": "Max Ammo",
        "aud_acc_powerup_carpenter": "Carpenter activated",
        "aud_acc_powerup_firesale": "Fire Sale activated",
    },

    "weapons": {
        "aud_acc_weapon_swap": "Weapon switched",
        "aud_acc_weapon_bought": "Weapon purchased",
        "aud_acc_weapon_upgraded": "Weapon upgraded",
    },

    "player_state": {
        "aud_acc_downed": "You are down! Need revive!",
        "aud_acc_revived": "Revived",
        "aud_acc_game_over": "Game over",
        "aud_acc_bleedout": "Bleeding out",
    },
}


# ============================================
# SAPI COM CONSTANTS
# ============================================

# SpFileStream.Open modes
SSFMCreateForWrite = 3

# SpeechStreamFileMode
# SpAudioFormat format types - BO3 requires 48kHz 16-bit
# SAPI doesn't have a native 48kHz enum, so we'll use 44kHz 16-bit mono
# and resample to 48kHz after, OR use 22kHz and resample.
# Actually SAPI format enum 34 = 44kHz 16bit mono, 38 = 48kHz 16bit mono
SAFT48kHz16BitMono = 38


# ============================================
# TTS GENERATION USING SAPI COM DIRECTLY
# ============================================

def generate_all():
    """Generate all TTS audio files using Windows SAPI COM interface directly."""
    import win32com.client

    total_files = sum(len(lines) for lines in voice_lines.values())
    generated = 0
    errors = 0

    print(f"\nInitializing Windows SAPI...")

    # Create SAPI voice object
    voice = win32com.client.Dispatch("SAPI.SpVoice")
    voice.Rate = TTS_RATE
    voice.Volume = TTS_VOLUME

    # List available voices
    available_voices = voice.GetVoices()
    print(f"\nAvailable voices:")
    for i in range(available_voices.Count):
        print(f"  [{i}] {available_voices.Item(i).GetDescription()}")

    if TTS_VOICE_INDEX < available_voices.Count:
        voice.Voice = available_voices.Item(TTS_VOICE_INDEX)
        print(f"\nUsing voice: {available_voices.Item(TTS_VOICE_INDEX).GetDescription()}")

    print(f"\nGenerating {total_files} voice line files...\n")

    for category, lines in voice_lines.items():
        # Create category subdirectory
        category_dir = os.path.join(OUTPUT_BASE, category)
        os.makedirs(category_dir, exist_ok=True)

        print(f"--- {category.upper()} ({len(lines)} files) ---")

        for alias, text in lines.items():
            filename = f"{alias}.wav"
            filepath = os.path.join(category_dir, filename)
            # Ensure we use a full Windows-style path
            filepath = os.path.abspath(filepath)

            try:
                # Create a file stream for output
                stream = win32com.client.Dispatch("SAPI.SpFileStream")

                # Set audio format to 22kHz 16-bit mono
                audio_format = win32com.client.Dispatch("SAPI.SpAudioFormat")
                audio_format.Type = SAFT48kHz16BitMono
                stream.Format = audio_format

                # Open file for writing
                stream.Open(filepath, SSFMCreateForWrite)

                # Redirect voice output to the file stream
                voice.AudioOutputStream = stream

                # Speak the text (synchronous)
                voice.Speak(text, 0)

                # Close the stream
                stream.Close()

                if os.path.exists(filepath):
                    size = os.path.getsize(filepath)
                    print(f"  [OK] {filename} ({size:,} bytes) - \"{text}\"")
                    generated += 1
                else:
                    print(f"  [FAIL] {filename} - File not created")
                    errors += 1

            except Exception as e:
                print(f"  [ERROR] {filename} - {str(e)}")
                errors += 1

    print(f"\n{'='*50}")
    print(f"Generation complete!")
    print(f"  Generated: {generated}/{total_files}")
    print(f"  Errors: {errors}")
    print(f"  Output directory: {OUTPUT_BASE}")
    print(f"{'='*50}")

    return generated, errors


def generate_manifest():
    """Create a manifest file listing all aliases and their audio files."""
    manifest_path = os.path.join(OUTPUT_BASE, "sound_alias_manifest.txt")

    with open(manifest_path, "w") as f:
        f.write("# BO3 Zombies Accessibility Mod - Sound Alias Manifest\n")
        f.write("# Format: alias_name | category | spoken_text | file_path\n")
        f.write("#" + "=" * 80 + "\n\n")

        for category, lines in voice_lines.items():
            f.write(f"# --- {category.upper()} ---\n")
            for alias, text in lines.items():
                rel_path = f"sound/accessibility/{category}/{alias}.wav"
                f.write(f"{alias} | {category} | {text} | {rel_path}\n")
            f.write("\n")

    print(f"\nManifest written to: {manifest_path}")


# ============================================
# MAIN
# ============================================

if __name__ == "__main__":
    print("=" * 50)
    print("BO3 Zombies Accessibility - TTS Audio Generator")
    print("=" * 50)

    if sys.platform != "win32":
        print("ERROR: This script requires Windows (SAPI TTS)")
        sys.exit(1)

    # Create output directory
    os.makedirs(OUTPUT_BASE, exist_ok=True)

    # Generate all audio files
    try:
        generated, errors = generate_all()
    except Exception as e:
        print(f"ERROR: {e}")
        print("Make sure pywin32 is installed: pip install pywin32")
        sys.exit(1)

    # Generate manifest
    generate_manifest()

    if errors > 0:
        print(f"\nWARNING: {errors} files had errors. Check output above.")
    else:
        print("\nAll files generated successfully!")

    print("\nNext steps:")
    print("1. Review the generated .wav files in your sound/accessibility/ folder")
    print("2. Import them into BO3 Asset Property Editor (APE) as sound aliases")
    print("3. Each file's name matches the sound alias used in the GSC scripts")
