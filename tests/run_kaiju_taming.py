"""Drive KaijuTaming: the ready glow, the cast's beam and motes, the tamer's bar and its results."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
source = read('tests/roblox_primitives.luau').split('local built = 0')[0]
source += read('tests/kaiju_taming_services.luau')
for name, path in [('ExpeditionEconomy', 'src/shared/ExpeditionEconomy.luau'), ('GemConfig', 'src/shared/GemConfig.luau'),
                   ('GemTraits', 'src/shared/GemTraits.luau'), ('GemRoller', 'src/shared/GemRoller.luau'),
                   ('ArmorSignatures', 'src/shared/ArmorSignatures.luau'), ('ElementMatchup', 'src/shared/ElementMatchup.luau'),
                   ('KaijuRoster', 'src/shared/KaijuRoster.luau'), ('KaijuRoles', 'src/shared/KaijuRoles.luau'),
                   ('Kaiju', 'src/shared/Kaiju.luau'),
                   ('Taming', 'src/client/Modules/KaijuTaming.luau')]:
    code = re.sub(r'^local \w+ = (require\([^\n]+\)|game:GetService\([^\n]+\))\n', '', read(path), flags=re.M)
    source += f'\nlocal {name} = (function()\n{code}\nend)()\n'
source += read('tests/kaiju_taming_cases.luau')
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if luau.exists() and os.access(luau, os.X_OK) else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-kaiju-taming-') as directory:
    script = Path(directory) / 'kaiju_taming.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
