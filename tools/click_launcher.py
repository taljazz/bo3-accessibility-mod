"""
Use keyboard to toggle TreeView checkboxes.
Click to select item, then press Space to toggle checkbox.
"""
import subprocess, sys
subprocess.check_call([sys.executable, "-m", "pip", "install", "pywinauto", "pyautogui", "-q"],
                      stderr=subprocess.DEVNULL)

import time
import pyautogui
from pywinauto import Application
from pywinauto.keyboard import send_keys

pyautogui.FAILSAFE = False

print("Connecting to launcher...")

# Dismiss any dialogs
try:
    app = Application(backend="uia").connect(title="No Tasks", timeout=2)
    dlg = app.window(title="No Tasks")
    dlg.child_window(title="OK", control_type="Button").click_input()
    print("Dismissed dialog")
    time.sleep(0.5)
except:
    pass

app = Application(backend="uia").connect(title="Black Ops III Mod Tools Launcher", timeout=5)
dlg = app.window(title="Black Ops III Mod Tools Launcher")
dlg.set_focus()
dlg.maximize()
time.sleep(1)
print("Connected and maximized!")

# Get the TreeView and click on it to give it focus
tree = dlg.TreeView
tree.click_input()
time.sleep(0.3)

# Now use keyboard navigation:
# The tree items order is:
# Maps (header)
#   mp_combine
#   zm_giant
# Mods (header)
#   zm_accessibility
#     core_mod
#     zm_mod

# Press Down arrow to navigate through items, Space to toggle checkboxes
# First, go to the top
send_keys("{HOME}")
time.sleep(0.2)

# Navigate down to core_mod (should be 5th item from top: Maps, mp_combine, zm_giant, Mods, zm_accessibility, core_mod)
# But headers might not be selectable, so let's try
for i in range(10):
    send_keys("{DOWN}")
    time.sleep(0.1)
    # Take quick screenshot to track

# Let's try a more targeted approach - click on the text "core_mod" then press Space
print("Clicking on core_mod text...")
pyautogui.click(92, 208)  # Click on "core_mod" text to select the row
time.sleep(0.3)

snap1 = r"C:\Coding Projects\bo3 mod\launcher_select1.png"
pyautogui.screenshot(snap1)

# Now press Space to toggle the checkbox
print("Pressing Space to toggle core_mod...")
send_keys(" ")
time.sleep(0.5)

snap2 = r"C:\Coding Projects\bo3 mod\launcher_space1.png"
pyautogui.screenshot(snap2)

# Now click on zm_mod text
print("Clicking on zm_mod text...")
pyautogui.click(88, 228)
time.sleep(0.3)

# Press Space to toggle
print("Pressing Space to toggle zm_mod...")
send_keys(" ")
time.sleep(0.5)

snap3 = r"C:\Coding Projects\bo3 mod\launcher_space2.png"
pyautogui.screenshot(snap3)

print(f"Screenshots: {snap1}, {snap2}, {snap3}")

# Check Link state
try:
    link_cb = dlg.child_window(title="Link", control_type="CheckBox")
    print(f"Link state: {link_cb.get_toggle_state()}")
except:
    pass
