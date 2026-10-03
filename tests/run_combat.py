"""Exercise real action rules and CombatServer with deterministic Roblox service mocks."""
from pathlib import Path
import re, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding='utf-8')
def module(name,path):
    source=re.sub(r'^local \w+ = require\([^\n]+\)\n','',read(path),flags=re.M)
    return f'local {name}=(function()\n{source}\nend)()\n'
source=read('tests/roblox_primitives.luau')+read('tests/combat_services.luau')
for name,path in [('EquipmentBalance', 'src/shared/EquipmentBalance.luau'), ('ExpeditionEconomy', 'src/shared/ExpeditionEconomy.luau'), ('CrowdControl', 'src/shared/CrowdControl.luau'), ('StatusEffects', 'src/shared/StatusEffects.luau'), ('GemConfig', 'src/shared/GemConfig.luau'), ('ArmorFamilies', 'src/shared/ArmorFamilies.luau'), ('Actions', 'src/shared/CombatActions.luau'), ('GemRoller', 'src/shared/GemRoller.luau'), ('Tech', 'src/shared/CombatTechnology.luau'), ('Tree', 'src/shared/AugmentTree.luau'), ('Season', 'src/shared/Season.luau'), ('ExpandedTraits', 'src/shared/ExpandedItemTraits.luau'), ('Slots', 'src/shared/EquipmentSlots.luau'), ('Crafting', 'src/shared/Crafting.luau'), ('GearRolls', 'src/shared/GearRolls.luau'), ('Classes', 'src/shared/Classes.luau'), ('Combat', 'src/shared/Combat.luau'), ('DuelistBrain', 'src/shared/DuelistBrain.luau'), ('RivalPose', 'src/shared/RivalPose.luau'), ('Matchup', 'src/shared/Matchup.luau'), ('CombatLogUI', 'src/client/Modules/CombatLogUI.luau'), ('HealthRegen', 'src/server/Systems/HealthRegen.luau')]: source+=module(name,path)
source+=read('tests/combat_players.luau')
source+=module('DamageLog','src/server/Systems/DamageLog.luau')
source+=module('CombatServer','src/server/Systems/CombatServer.luau')
source+=module('ArenaSessions','src/server/Systems/ArenaSessions.luau')
source+=module('AugmentSystem','src/server/Systems/Augments.luau')
source+=module('Progress','src/server/Systems/Progress.luau')
source+=read('tests/combat_cases.luau')
source+='\ndo\n'+read('tests/technology_cases.luau')+'\nend\n'
source+='\ndo\n'+read('tests/augment_cases.luau')+'\nend\n'
source+='\ndo\n'+read('tests/duelist_cases.luau')+'\nend\n'
with tempfile.TemporaryDirectory(prefix='gemsoul-combat-') as directory:
    script=Path(directory)/'combat.luau'; script.write_text(source,encoding='utf-8')
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'),str(script)],check=True)
