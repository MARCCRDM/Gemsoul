"""The bounty board on the Shelter's hall floor (Shared.Bounties.Board, Client.BountyBoard): its two faces, its turns, where it stands (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_bounty_board needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/bounty_board_cases.luau'), str(ROOT)], check=True)
