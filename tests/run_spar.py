"""Friendly sparring in the lobby: Shared.Spar's rules, and SparServer with the real CombatServer."""
from pathlib import Path
import re, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding='utf-8')
def module(name,path):
    source=re.sub(r'^local \w+ = require\([^\n]+\)\n','',read(path),flags=re.M)
    return f'local {name}=(function()\n{source}\nend)()\n'
source=read('tests/roblox_primitives.luau')+read('tests/combat_services.luau')
for name,path in [('EquipmentBalance', 'src/shared/EquipmentBalance.luau'), ('ExpeditionEconomy', 'src/shared/ExpeditionEconomy.luau'), ('CrowdControl', 'src/shared/CrowdControl.luau'), ('StatusEffects', 'src/shared/StatusEffects.luau'), ('ElementCombos', 'src/shared/ElementCombos.luau'), ('Matchmaking', 'src/shared/Matchmaking.luau'), ('PvPRules', 'src/shared/PvPRules.luau'), ('GemConfig', 'src/shared/GemConfig.luau'), ('ArmorSignatures', 'src/shared/ArmorSignatures.luau'), ('ElementMatchup', 'src/shared/ElementMatchup.luau'), ('ArmorFamilies', 'src/shared/ArmorFamilies.luau'), ('Actions', 'src/shared/CombatActions.luau'), ('GemTraits', 'src/shared/GemTraits.luau'), ('GemRoller', 'src/shared/GemRoller.luau'), ('Tech', 'src/shared/CombatTechnology.luau'), ('Tree', 'src/shared/AugmentTree.luau'), ('Season', 'src/shared/Season.luau'), ('WeaponForge', 'src/shared/WeaponForge.luau'), ('ExpandedTraits', 'src/shared/ExpandedItemTraits.luau'), ('Slots', 'src/shared/EquipmentSlots.luau'), ('Crafting', 'src/shared/Crafting.luau'), ('GearRolls', 'src/shared/GearRolls.luau'), ('Classes', 'src/shared/Classes.luau'), ('Combat', 'src/shared/Combat.luau'), ('RivalPose', 'src/shared/RivalPose.luau'), ('Spar', 'src/shared/Spar.luau'), ('FightSpacing', 'src/shared/FightSpacing.luau'), ('CombatEvents', 'src/server/Systems/CombatEvents.luau')]: source+=module(name,path)
# GearRolls' SuitTraits goes inside it: the chunk is at Luau's 200-local limit.
source=source.replace('local GearRolls=(function()\n','local GearRolls=(function()\n'+module('SuitTraits','src/shared/SuitTraits.luau'),1)
source+='\nGemTraits.Enabled = false\n'
source+=read('tests/combat_players.luau')
source+=module('DamageLog','src/server/Systems/DamageLog.luau')
source+=module('TriadServer','src/server/Systems/TriadServer.luau')
source+=module('CombatServer','src/server/Systems/CombatServer.luau')
source+=module('SparServer','src/server/Systems/SparServer.luau')
source+='\ndo\n'+read('tests/spar_cases.luau')+'\nend\n'
with tempfile.TemporaryDirectory(prefix='gemsoul-spar-') as directory:
    script=Path(directory)/'spar.luau'; script.write_text(source,encoding='utf-8')
    subprocess.run([str(ROOT/'.tools/luau/luau.exe'),str(script)],check=True)
