"""Run the miner's loot card stack (MinerLoot's LootStack) through its cases."""
from pathlib import Path
import os, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT / path).read_text(encoding='utf-8')
source = 'local LootStack=(function()\n' + read('src/client/Modules/LootStack.luau') + '\nend)()\n'
source += read('tests/loot_stack_cases.luau')
luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if luau.exists() and os.access(luau, os.X_OK) else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-loot-stack-') as directory:
    script = Path(directory) / 'loot_stack.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
