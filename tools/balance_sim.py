"""Simulated duels for ability balance (see tools/balance_sim.luau).

Usage: python tools/balance_sim.py [fights per pairing, default 16]
Stitches the production combat modules together with the test doubles
(tests/roblox_primitives.luau, tests/combat_services.luau,
tests/combat_players.luau) and runs it with Luau (.tools/luau) or lune.
"""
from pathlib import Path
import os, re, shutil, subprocess, sys, tempfile

ROOT = Path(__file__).resolve().parents[1]
MODULES = [
    ('EquipmentBalance', 'src/shared/EquipmentBalance.luau'), ('ExpeditionEconomy', 'src/shared/ExpeditionEconomy.luau'),
    ('CrowdControl', 'src/shared/CrowdControl.luau'), ('StatusEffects', 'src/shared/StatusEffects.luau'),
    ('ElementCombos', 'src/shared/ElementCombos.luau'), ('Matchmaking', 'src/shared/Matchmaking.luau'), ('GemConfig', 'src/shared/GemConfig.luau'),
    ('ArmorFamilies', 'src/shared/ArmorFamilies.luau'), ('Actions', 'src/shared/CombatActions.luau'),
    ('GemRoller', 'src/shared/GemRoller.luau'), ('Tech', 'src/shared/CombatTechnology.luau'),
    ('Tree', 'src/shared/AugmentTree.luau'), ('Season', 'src/shared/Season.luau'),
    ('WeaponForge', 'src/shared/WeaponForge.luau'), ('ExpandedTraits', 'src/shared/ExpandedItemTraits.luau'), ('Slots', 'src/shared/EquipmentSlots.luau'),
    ('Crafting', 'src/shared/Crafting.luau'), ('GearRolls', 'src/shared/GearRolls.luau'),
    ('Classes', 'src/shared/Classes.luau'), ('Combat', 'src/shared/Combat.luau'),
    ('DuelistBrain', 'src/shared/DuelistBrain.luau'), ('RivalPose', 'src/shared/RivalPose.luau'),
    ('Matchup', 'src/shared/Matchup.luau'), ('CombatLogUI', 'src/client/Modules/CombatLogUI.luau'),
    ('HealthRegen', 'src/server/Systems/HealthRegen.luau'),
]

def read(path): return (ROOT / path).read_text(encoding='utf-8')
def module(name, path):
    source = re.sub(r'^local \w+ = require\([^\n]+\)\n', '', read(path), flags=re.M)
    return f'local {name}=(function()\n{source}\nend)()\n'

fights = sys.argv[1] if len(sys.argv) > 1 else '16'
source = read('tests/roblox_primitives.luau') + read('tests/combat_services.luau')
for name, path in MODULES:
    source += module(name, path)
source += read('tests/combat_players.luau')
for name, path in [('DamageLog', 'src/server/Systems/DamageLog.luau'), ('CombatServer', 'src/server/Systems/CombatServer.luau'),
                   ('ArenaSessions', 'src/server/Systems/ArenaSessions.luau'), ('AugmentSystem', 'src/server/Systems/Augments.luau'),
                   ('Progress', 'src/server/Systems/Progress.luau')]:
    source += module(name, path)
probe = sys.argv[2] if len(sys.argv) > 2 else None
source += f'\nlocal SIM_FIGHTS = {int(fights)}\nlocal SIM_PROBE = {repr(probe) if probe else "nil"}\ndo\n' + read('tools/balance_sim.luau') + '\nend\n'

luau = ROOT / '.tools/luau/luau.exe'
command = [str(luau)] if os.name == 'nt' and luau.exists() else ([shutil.which('lune'), 'run'] if shutil.which('lune') else ['luau'])
with tempfile.TemporaryDirectory(prefix='gemsoul-balance-') as directory:
    script = Path(directory) / 'balance.luau'
    script.write_text(source, encoding='utf-8')
    subprocess.run(command + [str(script)], check=True)
