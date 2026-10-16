"""Run the daily challenge rules (Shared.DailyChallenges) through their cases."""
from pathlib import Path
import os, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
source = 'local Daily=(function()\n' + read('src/shared/DailyChallenges.luau') + '\nend)()\n'
source += read('tests/daily_challenges_cases.luau')
# The server's own glue (PlayerData.training and its progress push), with
# stand-ins for the rest of PlayerData.
data = read('src/server/Systems/PlayerData.luau')
glue = data[data.index('-- Daily challenge progress goes to the lobby'):data.index('function PlayerData.milestone')]
source += 'do\n' + read('tests/daily_challenges_server.luau').replace('--[[GLUE]]', glue) + '\nend\n'
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if luau.exists() and os.access(luau, os.X_OK) else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-daily-') as directory:
    script = Path(directory) / 'daily.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
