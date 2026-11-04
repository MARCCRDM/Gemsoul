"""The main menu on the title screen (Client Modules/MainMenu, Shared.MainMenuContent): banners, pages, FEEDBACK, PLAY, a phone."""
from pathlib import Path
import shutil, subprocess

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which("lune")
if not lune:
    raise SystemExit("lune is needed for the main menu test")
subprocess.run([lune, "run", str(ROOT / "tests/main_menu_cases.luau"), str(ROOT)], check=True)
