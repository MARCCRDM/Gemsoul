from pathlib import Path
R=Path(__file__).resolve().parents[1]
def edit(p,a,b):
 s=(R/p).read_text(encoding='utf-8'); assert a in s,(p,a); (R/p).write_text(s.replace(a,b),encoding='utf-8')
edit('src/shared/ExpandedItemTraits.luau','function Traits.pick(catalog, rng)','function Traits.pick(catalog, rng, weights)\n\tweights = weights or Traits.Weights')
edit('src/shared/ExpandedItemTraits.luau','in Traits.Weights do','in weights do')
edit('src/shared/ExpandedItemTraits.luau','if group then\n\t\t\tpick -= weight','if group and weight > 0 then\n\t\t\tpick -= weight')
p=R/'src/server/Systems/MineWall.luau'; s=p.read_text(); s=s.replace('local Classes = require(ReplicatedStorage.Shared.Classes)','local Classes = require(ReplicatedStorage.Shared.Classes)\nlocal ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)\nlocal ExpandedTraits = require(ReplicatedStorage.Shared.ExpandedItemTraits)'); start=s.index('\tlocal choices = {}',s.index('local function recoverGear')); end=s.index('\nend',start)
s=s[:start]+'''\tlocal rng = Gems.random()
\tlocal kind = Slots.Kinds[rng:NextInteger(1, #Slots.Kinds)]
\tlocal weights = ArmorFamilies.DepthWeights[math.clamp(math.ceil(depth / 2), 1, 5)]
\tlocal gear = if kind == "Weapons" then ExpandedTraits.pick(ExpandedTraits.Catalog.Weapons, rng, weights)
\t\telse ArmorFamilies.pick(ArmorFamilies.Catalog[kind], rng, depth)
\tif not gear then return nil end
\tlocal quality = profile.Owned[kind][gear.Id] or 0
\tif quality >= maxQuality then
\t\tPlayerData.addCoins(player, gear.RarityTier * 5)
\t\treturn gear.Name .. " (salvaged)"
\tend
\tPlayerData.setGearQuality(player, kind, gear.Id, rng:NextInteger(quality + 1, maxQuality))
\tPlayerData.milestone(player, "Recovered")
\treturn gear.Name'''+s[end:]; p.write_text(s)
edit('src/shared/Classes.luau','Classes.Order = { "Warrior" }','Classes.Order = { "Warrior" }\ntable.insert(Classes.ById.Warrior.Abilities, { Id = "WarriorDodge", Name = "Dodge Roll", Description = "Roll backward. A full Skirmisher set grants 10% damage for 3 seconds afterward.", Kind = "Dash", Distance = 12, Backward = true, Dodge = true, Cost = 0, Cooldown = 5 })')
edit('src/server/Systems/CombatServer.luau','\tShieldUntil: number,','\tShieldUntil: number,\n\tDodgeUntil: number,')
edit('src/server/Systems/CombatServer.luau','\t\t\tShieldUntil = 0,','\t\t\tShieldUntil = 0,\n\t\t\tDodgeUntil = 0,')
edit('src/server/Systems/CombatServer.luau','local damage = base * Combat.powerMult(rating(k, "Power")) * buffTotal(st, "DamageMult")','local damage = base * Combat.powerMult(rating(k, "Power")) * buffTotal(st, "DamageMult")\n\tif os.clock() < st.DodgeUntil then damage *= 1 + (k.Effects.DamageAfterDodge or 0) end')
edit('src/server/Systems/CombatServer.luau','humanoid.MaxHealth * ability.Heal)','humanoid.MaxHealth * ability.Heal * (1 + (k.Effects.HealingReceived or 0)))')
edit('src/server/Systems/CombatServer.luau','elseif kind == "Dash" then','elseif kind == "Dash" then\n\t\tif ability.Dodge then st.DodgeUntil = os.clock() + 3 end')
edit('src/server/Systems/Enemies.luau','local Combat = require(ReplicatedStorage.Shared.Combat)','local Combat = require(ReplicatedStorage.Shared.Combat)\nlocal Classes = require(ReplicatedStorage.Shared.Classes)')
edit('src/server/Systems/Enemies.luau','\tDamage: { [Player]: number },','\tDamage: { [Player]: number },\n\tThreat: { [Player]: number },')
edit('src/server/Systems/Enemies.luau','\t\tDamage = {},','\t\tDamage = {},\n\t\tThreat = {},')
edit('src/server/Systems/Enemies.luau','enemy.Damage[source] = (enemy.Damage[source] or 0) + amount','enemy.Damage[source] = (enemy.Damage[source] or 0) + amount\n\t\tlocal loadout = PlayerData.character(source)\n\t\tlocal bonus = if loadout then Classes.effects(loadout).ThreatGeneration or 0 else 0\n\t\tenemy.Threat[source] = (enemy.Threat[source] or 0) + amount * (1 + bonus)')
edit('src/server/Systems/Enemies.luau','table.clear(enemy.Damage)','table.clear(enemy.Damage)\n\t\t\t\ttable.clear(enemy.Threat)')
edit('src/server/Systems/Enemies.luau','local best, bestRoot, bestDistance = nil, nil, enemy.Kind.Aggro','local best, bestRoot, bestDistance = nil, nil, enemy.Kind.Aggro\n\tlocal bestThreat = -1')
edit('src/server/Systems/Enemies.luau','local reach = if now - enemy.LastHit < 6 then bestDistance * 1.6 else bestDistance','local reach = enemy.Kind.Aggro * (if now - enemy.LastHit < 6 then 1.6 else 1)\n\t\t\tlocal threat = enemy.Threat[player] or 0')
edit('src/server/Systems/Enemies.luau','if distance < reach and (root.Position - enemy.Home).Magnitude < LEASH then','if distance < reach and (root.Position - enemy.Home).Magnitude < LEASH and (threat > bestThreat or (threat == bestThreat and distance < bestDistance)) then\n\t\t\t\tbestThreat = threat')
edit('src/server/Systems/ArmorKits.luau','local ArmorKits = {}','local ArmorFamilies = require(game:GetService("ReplicatedStorage").Shared.ArmorFamilies)\nlocal ArmorKits = {}')
edit('src/server/Systems/ArmorKits.luau','HelmetDesign = if itemId then tonumber(string.match(itemId, "^MatrixHelmets(%d+)$")) else nil,','HelmetDesign = if itemId and ArmorFamilies.ById[itemId] then ArmorFamilies.ById[itemId].HelmetDesign elseif itemId then tonumber(string.match(itemId, "^MatrixHelmets(%d+)$")) else nil,')
edit('src/server/Systems/ArmorKits.luau','else -- Metron: interlocking neural lattice','elseif design == 10 then -- Metron: interlocking neural lattice')
edit('src/server/Systems/ArmorKits.luau','\n\t\t\tend\n\n\t\t\tif family == 1 then','''
\t\t\telseif design >= 11 then
\t\t\t\t-- Vanguard: progressively reinforced face plates and a distinct crown per tier.
\t\t\t\tlocal tier = design - 10
\t\t\t\tblock(head, 0, -y * 0.25, -z * 0.62, x * (0.48 + tier * 0.035), y * 0.22, 0.13, metal)
\t\t\t\tfor i = 1, tier do
\t\t\t\t\tlocal offset = (i - (tier + 1) / 2) * x * 0.14
\t\t\t\t\tblock(head, offset, y * (0.52 + tier * 0.015), 0, x * 0.085, y * (0.10 + tier * 0.025), z * 0.74, if tier >= 4 then ornament else edge)
\t\t\t\tend
\t\t\t\tfor _, side in sides() do
\t\t\t\t\tblock(head, side * x * 0.48, -y * 0.06, -z * 0.42, x * 0.17, y * (0.25 + tier * 0.03), z * 0.32, metal)
\t\t\t\t\tif tier >= 3 then lit(head, side * x * 0.5, y * 0.10, -z * 0.6, x * 0.07, y * 0.08, 0.03) end
\t\t\t\tend
\t\t\tend

\t\t\tif family == 1 then''')
edit('src/client/Modules/CharacterUI.luau','string.format("+%d %s", entry[2], entry[1])','if entry[1] == "Critical" or entry[1] == "Cooldown" then string.format("+%g%% %s", entry[2] * 100, entry[1]) else string.format("+%g %s", entry[2], entry[1])')
edit('src/client/Modules/CharacterUI.luau','\tsignatureLine(gear)\nend','''\tif gear.ArmorFamily then
\t\tlocal state = Classes.setState(profile.Character).Active[gear.ArmorFamily]
\t\ttext(tipBody, string.format("%s · %d/6 equipped · %d-piece bonus active", gear.ArmorFamily, state.Count, state.Tier), 12, P.Teal)
\t\tif roll and roll.Budget then text(tipBody, string.format("%d stat points · %d modifiers", roll.Budget, #(roll.Modifiers or {})), 12, P.Dim) end
\tend
\tsignatureLine(gear)
end''')
for name in ['run_equipment.py','run_expedition.py']:
 p=R/'tests'/name; s=p.read_text(); needle='source += module("ExpandedTraits", "src/shared/ExpandedItemTraits.luau")'; assert needle in s; p.write_text(s.replace(needle,'source += module("ArmorFamilies", "src/shared/ArmorFamilies.luau")\n'+needle))
