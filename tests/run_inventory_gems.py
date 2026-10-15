"""Exercise the actual vault and inventory drag handlers with UI/input doubles."""
from pathlib import Path
import re, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding='utf-8')
def module(name, path):
    code = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', read(path), flags=re.M)
    return f'local {name}=(function()\n{code}\nend)()\n'
inventory = read('src/client/Modules/InventoryV2.luau')
fixture = read('tests/inventory_gems_cases.luau')
source = read('tests/roblox_primitives.luau') + module('Slots', 'src/shared/EquipmentSlots.luau')
source += module('GemInventory', 'src/shared/GemInventory.luau')
source += fixture.replace('-- VAULT MODULE', module('GemVault', 'src/client/Modules/GemVault.luau'))
source = source.replace('-- SOCKET RULES', inventory[inventory.index('local function acceptsSlot'):inventory.index('local function sameItem')])
source = source.replace('-- DRAG HANDLERS', inventory[inventory.index('local function pointOf'):inventory.index('-- Draw --------')])
source = source.replace('-- ROW BUILD', inventory[inventory.index('local function buildRow'):inventory.index('local function buildRight')])
source = source.replace('-- ROW DRAW', inventory[inventory.index('function InventoryV2.paintRow'):inventory.index('-- The nudge under the list')])
with tempfile.TemporaryDirectory(prefix='gemsoul-inventory-gems-') as directory:
    path = Path(directory)/'inventory.luau'
    path.write_text(source, encoding='utf-8')
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'),str(path)], check=True)
