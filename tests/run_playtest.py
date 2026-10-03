"""Exercise the playtest safety pieces: the save session lock (SessionLock.luau)
and feedback/error report handling (Feedback.luau)."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
def module(name, path):
    source = re.sub(r'^local \w+ = (require\([^\n]+\)|game:GetService\([^\n]+\))\n', '', read(path), flags=re.M)
    return f'local {name}=(function()\n{source}\nend)()\n'

source = 'local Color3={new=function() return {} end,fromRGB=function() return {} end}\n'
source += 'local Shop={reply=function(ok,message) return {Ok=ok,Message=message} end}\n'
source += module('Config', 'src/shared/Config.luau')
source += module('SessionLock', 'src/server/Systems/SessionLock.luau')
source += module('Feedback', 'src/server/Systems/Feedback.luau')
source += 'do\n' + read('tests/session_lock_cases.luau') + '\nend\n'
source += 'do\n' + read('tests/feedback_cases.luau') + '\nend\n'
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if os.name == 'nt' and luau.exists() else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-playtest-') as directory:
    script = Path(directory) / 'playtest.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
