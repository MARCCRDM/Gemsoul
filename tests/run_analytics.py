"""Run the real Analytics (Systems/Analytics.luau) against stand-in players, balances and services."""
from pathlib import Path
import os, re, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
source = read('tests/analytics_services.luau')
source += 'local Analytics=(function()\n' + re.sub(r'^local \w+ = (require\([^\n]+\)|game:GetService\([^\n]+\))\n', '', read('src/server/Systems/Analytics.luau'), flags=re.M) + '\nend)()\n'
source += read('tests/analytics_cases.luau')
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if luau.exists() and os.access(luau, os.X_OK) else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-analytics-') as directory:
    script = Path(directory) / 'analytics.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
