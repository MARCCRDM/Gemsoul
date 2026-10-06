"""Exercise the real insertion lifecycle without a Roblox renderer."""
from pathlib import Path
import re, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
def module(name, path):
    source = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', (ROOT/path).read_text(), flags=re.M)
    return f"local {name}=(function()\n{source}\nend)()\n"
source = (ROOT/'tests/insertion_lifecycle.luau').read_text()
prefix, cases = source.split('-- MODULES HERE')
source = prefix + module('Motion','src/shared/InsertionMotion.luau') + module('Drop','src/server/Systems/ArenaDrop.luau') + cases
with tempfile.TemporaryDirectory(prefix='gemsoul-insertion-') as directory:
    script = Path(directory)/'lifecycle.luau'
    script.write_text(source)
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'),str(script)], check=True)
