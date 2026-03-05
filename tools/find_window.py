"""List all visible windows."""
import subprocess, sys
subprocess.check_call([sys.executable, "-m", "pip", "install", "pygetwindow", "-q"],
                      stderr=subprocess.DEVNULL)
import pygetwindow as gw

all_windows = gw.getAllTitles()
print("All visible windows:")
for title in all_windows:
    if title.strip():
        print(f"  '{title}'")
