"""Exercise the real armory drag handlers with deterministic input/UI doubles.
Rendering and Roblox event delivery still need a Studio smoke test.
"""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ui = (ROOT / "src/client/Modules/CharacterUI.luau").read_text(encoding="utf-8")
handlers = ui[ui.index("-- Gem dragging"):ui.index("-- Stones are 3D models")]
harness = (ROOT / "tests/gem_drag_cases.luau").read_text(encoding="utf-8")
source = harness.replace("-- INSERT_REAL_DRAG_HANDLERS", handlers)
with tempfile.TemporaryDirectory(prefix="gemsoul-drag-") as directory:
    script = Path(directory) / "drag.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
