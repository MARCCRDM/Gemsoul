"""Run the translation rules (Shared.Lang) and check the Spanish table (Shared.LangEs)."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
def module(name, path):
    source = re.sub(r'^local \w+ = (require\([^\n]+\)|game:GetService\([^\n]+\))\n', '', read(path), flags=re.M)
    return f'local {name}=(function()\n{source}\nend)()\n'
source = module('Lang', 'src/shared/Lang.luau')
source += module('LangEs', 'src/shared/LangEs.luau')
source += module('KaijuRosterMore', 'src/shared/KaijuRosterMore.luau')
source += module('KaijuRoster', 'src/shared/KaijuRoster.luau')
source += module('Training', 'src/shared/TrainingRewards.luau')
source += module('GameGuide', 'src/shared/GameGuide.luau')
source += read('tests/lang_cases.luau')
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if luau.exists() and os.access(luau, os.X_OK) else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-lang-') as directory:
    script = Path(directory) / 'lang.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
