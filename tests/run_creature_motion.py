"""Execute the actual creature and combat pose math using the bundled Luau VM."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = ''
for name, path in [('RivalPose', 'src/shared/RivalPose.luau'), ('Motion', 'src/shared/CreatureMotion.luau')]:
    source += f'local {name}=(function()\n{(ROOT/path).read_text(encoding="utf-8")}\nend)()\n'
source += (ROOT/'tests/creature_motion_cases.luau').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='creature-motion-') as directory:
    bundle = Path(directory)/'cases.luau'
    bundle.write_text(source, encoding='utf-8')
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'), str(bundle)], check=True)
