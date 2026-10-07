"""Exercise real action rules and CombatServer with deterministic Roblox service mocks."""
from pathlib import Path
import re, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding='utf-8')
def module(name,path):
    source=re.sub(r'^local \w+ = require\([^\n]+\)\n','',read(path),flags=re.M)
    return f'local {name}=(function()\n{source}\nend)()\n'
source=read('tests/roblox_primitives.luau')+read('tests/combat_services.luau')
for name,path in [('EquipmentBalance', 'src/shared/EquipmentBalance.luau'), ('ExpeditionEconomy', 'src/shared/ExpeditionEconomy.luau'), ('CrowdControl', 'src/shared/CrowdControl.luau'), ('StatusEffects', 'src/shared/StatusEffects.luau'), ('ElementCombos', 'src/shared/ElementCombos.luau'), ('ElementMatchup', 'src/shared/ElementMatchup.luau'), ('Matchmaking', 'src/shared/Matchmaking.luau'), ('PvPRules', 'src/shared/PvPRules.luau'), ('GemConfig', 'src/shared/GemConfig.luau'), ('ArmorFamilies', 'src/shared/ArmorFamilies.luau'), ('Actions', 'src/shared/CombatActions.luau'), ('GemRoller', 'src/shared/GemRoller.luau'), ('Tech', 'src/shared/CombatTechnology.luau'), ('Tree', 'src/shared/AugmentTree.luau'), ('Season', 'src/shared/Season.luau'), ('WeaponForge', 'src/shared/WeaponForge.luau'), ('ExpandedTraits', 'src/shared/ExpandedItemTraits.luau'), ('Slots', 'src/shared/EquipmentSlots.luau'), ('Crafting', 'src/shared/Crafting.luau'), ('GearRolls', 'src/shared/GearRolls.luau'), ('Classes', 'src/shared/Classes.luau'), ('Combat', 'src/shared/Combat.luau'), ('DuelistBrain', 'src/shared/DuelistBrain.luau'), ('CombatTutorial', 'src/shared/CombatTutorial.luau'), ('RivalPose', 'src/shared/RivalPose.luau'), ('Matchup', 'src/shared/Matchup.luau'), ('CombatLogUI', 'src/client/Modules/CombatLogUI.luau'), ('HealthRegen', 'src/server/Systems/HealthRegen.luau'), ('CombatEvents', 'src/server/Systems/CombatEvents.luau')]: source+=module(name,path)
# These suites check the archived (pre-prototype) surges; the live
# prototype has its own suite (run_surge_prototype.py).
source+='\nGemRoller.LivePrototype = GemRoller.Prototype\nGemRoller.Prototype, Tech.Prototype = false, false\n'
source+=module('DungeonLoadout','src/shared/DungeonLoadout.luau')
source+=read('tests/dungeon_loadout_cases.luau')
source+=read('tests/combat_players.luau')
source+=module('DamageLog','src/server/Systems/DamageLog.luau')
source+=module('CombatServer','src/server/Systems/CombatServer.luau')
source+=module('Motion','src/shared/InsertionMotion.luau')
source+=module('ArenaDrop','src/server/Systems/ArenaDrop.luau')
source+=module('ArenaSessions','src/server/Systems/ArenaSessions.luau')
source+=module('AugmentSystem','src/server/Systems/Augments.luau')
source+=module('Progress','src/server/Systems/Progress.luau')
source+=read('tests/combat_cases.luau')
source+='\ndo\n'+read('tests/arena_drop_cases.luau')+'\nend\n'
source+='\ndo\n'+read('tests/restored_surge_live_cases.luau')+'\nend\n'
# Preserve the archived scaling contract as an explicit compatibility test.
# The restored live model is exercised above and by run_restored_surges.py.
source+='\nTech.RaritySurges=false; GemRoller.RaritySurges=false\n'
source+='\ndo\n'+read('tests/technology_cases.luau')+'\nend\n'
source+='\ndo\n'+read('tests/augment_cases.luau')+'\nend\n'
source+='\nTech.RaritySurges=true; GemRoller.RaritySurges=true\n'
source+='\ndo\n'+read('tests/duelist_cases.luau')+'\nend\n'
source+=read('tests/combat_tutorial_cases.luau')
source+='\ndo\n'+read('tests/weapon_perk_cases.luau')+'\nend\n'
with tempfile.TemporaryDirectory(prefix='gemsoul-combat-') as directory:
    script=Path(directory)/'combat.luau'; script.write_text(source,encoding='utf-8')
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'),str(script)],check=True)
