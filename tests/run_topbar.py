"""Roblox's own buttons at the top of the screen stay clear (UiKit.topbar / clearTopbar).

1. tests/topbar_cases.luau: the layout rules, on phones, a tablet and a desktop,
   before and after Roblox has drawn its buttons, with the DEV button's room kept.
2. Every screen that draws over the top bar's strip (IgnoreGuiInset = true, or
   ScreenInsets None) either lays itself out with UiKit's top bar helpers or is
   listed below with why nothing of it sits under Roblox's buttons.
"""
from pathlib import Path
import os, re, shutil, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]

# Screens that cover the whole screen on purpose and put nothing in the strip.
COVERS = {
    "src/first/LoadingScreen.luau": "the loading cover: art and a progress bar, centred, no buttons",
    "src/client/Splash.client.luau": "the title screen: centred art, the prompt low down; any tap continues",
    "src/client/ArenaDrop.client.luau": "the drop pod's flash and streaks, no buttons",
    "src/client/Combat.client.luau": "damage numbers over the fight (the combat HUD itself sits below the strip)",
    "src/client/Modules/SparKit.luau": "a hit flash and the centred DOWNED banner, no buttons",
    "src/client/Modules/RiftClient.luau": "the crossing into the Rift: a dark fade, the centred title and solo warning, no buttons (its gate card, strip and down window keep the inset)",
    "src/client/Modules/KaijuPitClient.luau": "the stairs to the Kaiju Arena: a dark fade and the centred title, no buttons (the pad card keeps the inset)",
}
HELPERS = ("UiKit.clearTopbar", "UiKit.topbar", "UiKit.onTopbar", "UiKit.reserveTopbar")
OVER_STRIP = re.compile(r"IgnoreGuiInset\s*=\s*true|ScreenInsets\s*=\s*Enum\.ScreenInsets\.None")


def guard():
    problems, checked = [], 0
    for path in sorted(list((ROOT / "src/client").rglob("*.luau")) + list((ROOT / "src/first").rglob("*.luau"))):
        rel = path.relative_to(ROOT).as_posix()
        source = path.read_text(encoding="utf-8")
        if not OVER_STRIP.search(source):
            continue
        checked += 1
        if rel in COVERS:
            continue
        if not any(helper in source for helper in HELPERS):
            problems.append(rel)
    for rel in COVERS:
        if not (ROOT / rel).exists():
            problems.append(rel + " (listed as a cover but gone: drop it from COVERS)")
    if problems:
        sys.exit(
            "These screens draw over Roblox's top bar without keeping clear of its buttons "
            "(use UiKit.clearTopbar / UiKit.topbar, or list them in COVERS with why):\n  " + "\n  ".join(problems)
        )
    print(f"PASS: {checked} screens drawn over the top bar's strip keep clear of Roblox's buttons or are covers")


luau = ROOT / ".tools/luau/luau.exe"
lune = shutil.which("lune")
if lune:
    subprocess.run([lune, "run", str(ROOT / "tests/topbar_cases.luau"), str(ROOT)], check=True)
elif os.name == "nt" and luau.exists():
    print("(lune not found: skipping topbar_cases.luau)")
guard()
