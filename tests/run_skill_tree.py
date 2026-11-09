"""The skill tree: its trees, rules, what each key fires and the server's requests (needs lune)."""
from pathlib import Path
import shutil, subprocess
ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if not lune:
    raise SystemExit('run_skill_tree needs lune (https://github.com/lune-org/lune) on PATH')
subprocess.run([lune, 'run', str(ROOT / 'tests/skill_tree_cases.luau'), str(ROOT)], check=True)
