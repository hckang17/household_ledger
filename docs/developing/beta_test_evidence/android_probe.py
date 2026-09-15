"""Isolated Android beta audit. Always targets the dedicated emulator.

python docs/developing/beta_test_evidence/android_probe.py capture <name>
Other commands: tap x y | text ascii | key keycode | swipe x1 y1 x2 y2
Screenshots and semantic UI dumps are saved next to this script.
"""
import pathlib
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parent
SERIAL = "emulator-5554"


def adb(*args):
    return subprocess.check_output(["adb", "-s", SERIAL, *args])


def capture(name):
    time.sleep(0.8)
    (ROOT / f"android_{name}.png").write_bytes(adb("exec-out", "screencap", "-p"))
    adb("shell", "rm", "-f", "/sdcard/ledger-beta-window.xml")
    result = adb("shell", "uiautomator", "dump", "/sdcard/ledger-beta-window.xml")
    if b"dumped to" not in result:
        print("Screenshot saved; UI dump unavailable (animation/idle timeout).")
        return
    xml = adb("shell", "cat", "/sdcard/ledger-beta-window.xml")
    (ROOT / f"android_{name}.xml").write_bytes(xml)
    for node in ET.fromstring(xml).iter("node"):
        a = node.attrib
        label = a.get("text") or a.get("content-desc")
        if label or a.get("clickable") == "true":
            print(a.get("bounds"), a.get("class", "").split(".")[-1], label,
                  "click" if a.get("clickable") == "true" else "")


def steps(*actions):
    for action in actions:
        adb("shell", "input", *map(str, action))
        time.sleep(1)


def tap_label(label):
    """Tap a fresh semantic label after navigation has settled."""
    adb("shell", "rm", "-f", "/sdcard/ledger-beta-window.xml")
    adb("shell", "uiautomator", "dump", "/sdcard/ledger-beta-window.xml")
    root = ET.fromstring(adb("shell", "cat", "/sdcard/ledger-beta-window.xml"))
    for node in root.iter("node"):
        a = node.attrib
        value = a.get("text") or a.get("content-desc") or ""
        if value == label and a.get("clickable") == "true":
            x1, y1, x2, y2 = map(int, re.findall(r"\d+", a["bounds"]))
            steps(("tap", (x1 + x2) // 2, (y1 + y2) // 2))
            return
    raise ValueError(f"Visible clickable label not found: {label}")


if __name__ == "__main__":
    action, *args = sys.argv[1:]
    if action == "capture":
        capture(args[0])
    else:
        cmd = {"key": "keyevent", "text": "text", "tap": "tap", "swipe": "swipe"}[action]
        adb("shell", "input", cmd, *args)
