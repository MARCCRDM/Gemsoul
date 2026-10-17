"""Run PROBE-7's window layout (ProbeLayout) and the picks it sells through their cases."""
from pathlib import Path
import os, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
# (Shared.Outpost colours its picks and places the quarry; plain Luau has no Color3 or CFrame.)
source = 'local Color3={fromRGB=function(r,g,b) return {r,g,b} end}\nlocal CFrame={new=function(...) return {...} end}\n'
source += 'local Rules=(function()\n' + read('src/shared/Outpost.luau') + '\nend)()\n'
source += 'local Layout=(function()\n' + read('src/client/Modules/ProbeLayout.luau') + '\nend)()\n'
source += read('tests/probe_layout_cases.luau')
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if luau.exists() and os.access(luau, os.X_OK) else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-probe-layout-') as directory:
    script = Path(directory) / 'probe_layout.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
