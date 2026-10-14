"""Exercise the production camera-shake callbacks with a deterministic camera."""
from pathlib import Path
import subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'src/client/Modules/CombatFx.luau').read_text()
shake = source.split('-- Camera shake ')[1].split('-- How close is this spot')[0]
shake = shake[shake.index('local shakeUntil'):]
fixture = (ROOT / 'tests/hit_shake_cases.luau').read_text()
prefix, cases = fixture.split('-- SHAKE HERE')
with tempfile.TemporaryDirectory(prefix='gemsoul-hit-shake-') as directory:
    script = Path(directory) / 'shake.luau'
    script.write_text(prefix + shake + cases)
    subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(script)], check=True)
