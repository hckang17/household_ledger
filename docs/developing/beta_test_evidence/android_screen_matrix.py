"""Native core-screen matrix; start on the main shell, with every dialog closed."""
import contextlib
import json
import time
from android_probe import ROOT, adb, capture, steps

configs = [
    ("small", 640, 1136, "1.0"),
    ("phone", 786, 1704, "1.0"),
    ("landscape", 1280, 720, "1.0"),
    ("tablet", 1600, 2560, "1.0"),
    ("largefont", 720, 1280, "1.8"),
]
results = []
with (ROOT / "android_matrix_ui.txt").open("w", encoding="utf-8") as log:
    with contextlib.redirect_stdout(log):
        for name, width, height, font in configs:
            adb("shell", "wm", "size", f"{width}x{height}")
            adb("shell", "wm", "density", "320")
            adb("shell", "settings", "put", "system", "font_scale", font)
            time.sleep(2)
            for tab, slug in [(2, "home"), (3, "expense"), (4, "fixed"), (0, "income"), (1, "analysis")]:
                steps(("tap", round(width * (tab + .5) / 5), height - 128))
                screenshot = f"matrix_{name}_{slug}"
                print("\nSCREEN:", screenshot, flush=True)
                capture(screenshot)
                results.append({"config": name, "physicalSize": [width, height], "density": 320, "logicalSize": [width / 2, height / 2], "fontScale": font, "tab": slug, "screenshot": f"android_{screenshot}.png"})
                log.flush()
adb("shell", "wm", "size", "786x1704")
adb("shell", "settings", "put", "system", "font_scale", "1.0")
time.sleep(2)
steps(("tap", 393, 1576))
(ROOT / "android_matrix.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
(ROOT / "android_runtime_matrix.txt").write_bytes(adb("logcat", "-d", "-s", "flutter"))
