"""Prototype role, compatibility, rarity and painted-icon regressions."""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
def module(name, path):
    text = (ROOT / path).read_text(encoding="utf-8")
    text = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', text, flags=re.M)
    text = re.sub(r'^local ReplicatedStorage = .*\n', '', text, flags=re.M)
    return f'local {name} = (function()\n{text}\nend)()\n'

source = (ROOT / 'tests/roblox_primitives.luau').read_text(encoding='utf-8')
for name, path in [
    ('GemRoller', 'src/shared/GemRoller.luau'),
    ('Tech', 'src/shared/CombatTechnology.luau'),
    ('Atlas', 'src/client/Modules/AbilityIconAtlas.luau'),
    ('Icons', 'src/client/Modules/SurgeIcons.luau'),
    ('ElementCombos', 'src/shared/ElementCombos.luau'),
]:
    source += module(name, path)
source += (ROOT / 'tests/surge_prototype_cases.luau').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='gemsoul-surge-prototype-') as directory:
    script = Path(directory) / 'prototype.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(script)], check=True)
