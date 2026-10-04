local cases = 0
local function check(value, message) assert(value, message); cases += 1 end
local class = Classes.get("Warrior")
local function profile(weaponIndex)
 local p = {Coins = 100, Marks = 0, Materials = {}, Gems = {}, Character = {Class = "Warrior", ItemGems = {}, GearRolls = {}}, Owned = {}}
 for _, slot in Slots.Order do
  local kind = Slots.Definitions[slot].Kind
  local id = class[kind][if slot == "Weapon" then weaponIndex else 1].Id
  p.Character[slot] = id
  p.Character[slot .. "Quality"] = 1
  p.Owned[kind] = {[id] = 1}
 end
 Slots.initialize(p)
 GearRolls.ensure(p, Random.new())
 return p
end
-- New discoveries from every source are ready, graded and still use the diamond shape.
local total = 0
for _, source in {"MiningNode", "VipMiningNode", "FirstStone", "PvEDrop", "MiningStore"} do
 for i = 1, 2000 do
  local gem = GemGenerator.generate(rng, source, {Id = source .. i, Time = 1})
  check(gem.Cut ~= nil and gem.Cut >= 1 and gem.Cut <= 10 and gem.CutMethod == "Natural", "Discovery is not enchant-ready")
  if source == "MiningNode" then total += Crafting.marketPrice(gem) end
 end
end
print("SIMULATION: baseline mined gem average exchange price " .. math.floor(total / 2000) .. " coins")
-- Saved rough gems, off-slot enchants and copies upgrade once; valid cuts stay intact.
local legacy = profile(1)
legacy.Marks = 100
legacy.Materials = {Iron = 2, Shards = 3}
legacy.Gems = {{Id = "rough"}, {Id = "known", Cut = 9, CutMethod = "Manual"}}
legacy.Character.HelmetGem = {Id = "known"}
legacy.Character.ItemGems.Helmet.reserve = {Id = "bank"}
Economy.migrate(legacy, rng)
check(legacy.Coins == 284 and legacy.Marks == 0 and next(legacy.Materials) == nil, "Legacy currency conversion incorrect")
check(legacy.Character.HelmetGem.Cut == 9 and legacy.Gems[2].Cut == 9, "Migration changed an existing grade")
check(legacy.Gems[1].Cut and legacy.Character.ItemGems.Helmet.reserve.Cut, "Migration missed inventory or saved enchantment")
local grade, coins = legacy.Gems[1].Cut, legacy.Coins
Economy.migrate(legacy, rng)
check(grade == legacy.Gems[1].Cut and coins == legacy.Coins, "Migration rerolled or refunded twice")
-- Pure exchange: rolls, quality and bound gems transfer together; replay is rejected.
local a, b = profile(2), profile(3)
local leftId, rightId = a.Character.Weapon, b.Character.Weapon
local bound = {Id = "attached", Element = "Fire", Tier = "Rare", Cut = 8, Size = 7, Clarity = 7}
a.Character.WeaponGem = bound
a.Character.ItemGems.Weapon[leftId] = bound
local left, right = Logic.item(a, "Weapon", leftId), Logic.item(b, "Weapon", rightId)
check(Logic.exchange(a, b, left, right), "Valid trade failed")
check(a.Character.Weapon == rightId and b.Character.WeaponGem.Id == "attached", "Trade lost equipped item or gem")
check(b.Character.GearRolls.Weapons[leftId].Rarity == left.Roll.Rarity, "Trade rerolled rarity")
check(not Logic.exchange(a, b, left, right), "Trade replay duplicated gear")
a, b = profile(2), profile(3)
left, right = Logic.item(a, "Weapon", a.Character.Weapon), Logic.item(b, "Weapon", b.Character.Weapon)
a.Character.GearRolls.Weapons[left.Id].Stats.Health = 99
check(not Logic.exchange(a, b, left, right), "Changed stats accepted without a new offer")
a, b = profile(2), profile(3)
a.Owned.Weapons[b.Character.Weapon] = 1
left, right = Logic.item(a, "Weapon", a.Character.Weapon), Logic.item(b, "Weapon", b.Character.Weapon)
check(not Logic.exchange(a, b, left, right), "Trade overwrote an owned model")
-- Real server handlers: no trade without both confirmations; stale revisions are invalid.
local pa = {UserId = 11, DisplayName = "A", Parent = true, GetAttribute = function() return nil end}
local pb = {UserId = 12, DisplayName = "B", Parent = true, GetAttribute = function() return nil end}
registry[11], registry[12] = pa, pb
profiles[pa], profiles[pb] = profile(2), profile(3)
Trading.start()
Forge.start()
check(not handlers.TradeOffer(pa, 0/0, "Weapon", profiles[pa].Character.Weapon).Ok, "Invalid target accepted")
check(not handlers.TradeOffer(pa, pa.UserId, "Weapon", profiles[pa].Character.Weapon).Ok, "Self trade accepted")
local offer = handlers.TradeOffer(pa, pb.UserId, "Weapon", profiles[pa].Character.Weapon)
check(offer.Ok, "Offer failed")
local id = offer.Trade.Id
check(not handlers.TradeCounter(pa, id, profiles[pa].Character.Weapon).Ok, "Initiator countered their own offer")
local counter = handlers.TradeCounter(pb, id, profiles[pb].Character.Weapon)
check(counter.Ok, "Counteroffer failed")
check(not handlers.TradeConfirm(pa, id, 1).Ok, "Stale offer confirmation accepted")
check(handlers.TradeConfirm(pa, id, counter.Trade.Revision).Ok and profiles[pa].Character.Weapon == leftId, "One confirmation exchanged items")
counter = handlers.TradeCounter(pb, id, profiles[pb].Character.Weapon)
check(not handlers.TradeState(pa).Trade.OwnConfirmed, "Counter change retained old consent")
check(not handlers.TradeConfirm(pa, id, counter.Trade.Revision - 1).Ok, "Old counter revision accepted")
check(handlers.TradeConfirm(pa, id, counter.Trade.Revision).Ok, "Fresh confirmation failed")
check(handlers.TradeConfirm(pb, id, counter.Trade.Revision).Ok, "Mutual confirmation failed")
check(profiles[pa].Character.Weapon == rightId and profiles[pb].Character.Weapon == leftId, "Handler did not swap equipment")
check(handlers.TradeState(pa).Trade == nil and handlers.TradeState(pb).Trade == nil, "Completed session stayed live")
-- Disconnect clears both sides.
offer = handlers.TradeOffer(pa, pb.UserId, "Weapon", profiles[pa].Character.Weapon)
check(offer.Ok, "Second offer failed")
removal(pb)
check(handlers.TradeState(pa).Trade == nil, "Disconnect left a stale trade")
-- Retired actions have no registered handler, even when explicitly called by an old client.
for _, action in {"Craft", "BuyMaterial", "SalvageGems", "StartCut", "FinishCut", "AutoCut", "BuyRoughStone"} do
 check(handlers[action] == nil, "Retired handler is registered: " .. action)
 local player = {}
 profiles[player] = profile(1)
 check(not RequestRouter.handle(player, action).Ok, "Retired router request succeeded")
end
for _, bundle in Store.Bundles do
 check(not bundle.Contents.Materials and not bundle.Contents.Marks and not bundle.Contents.Stones and not bundle.Contents.CutGems and not bundle.Contents.Crates, "Paid bundle includes obsolete supplies or random power")
end
for level = 1, Season.MaxLevel do
 local reward = Season.reward(level)
 check(not reward.Materials and not reward.Marks, "Season awards obsolete currency")
end
check(not Store.RobuxProducts.GeodeCrate and not Store.RobuxProducts.MasterworkCrate, "Random caches can be purchased with Robux")
-- Mine recovery awards every category, gives coins for ore and improves quality at depth.
local miner = { DisplayName = "Miner" }
profiles[miner] = profile(1)
local foundKinds = {}
local previousCounts = {}
for _, kind in Slots.Kinds do previousCounts[kind] = 1 end
for _ = 1, 1000 do
 local loot = grant(miner, {Depth = 40}, {Kind = "Ore", Ore = "Iron"})
 check(loot.Kind == "Coins" and loot.Count > 0 and next(profiles[miner].Materials) == nil, "Ore produced unusable crafting materials")
 for _, kind in Slots.Kinds do
  for _, q in profiles[miner].Owned[kind] do if q > 1 then foundKinds[kind] = true end end
 end
end
for _, kind in Slots.Kinds do check(foundKinds[kind], "No equipment recovery for " .. kind) end
-- Gear found in the mine is stamped with its finder (Forge weapons included).
local stamped, forgeFound = 0, false
for kind, rolls in profiles[miner].Character.GearRolls do
 for id, roll in rolls do
  if profiles[miner].Owned[kind][id] and profiles[miner].Owned[kind][id] > 1 then
   if roll.FoundBy then stamped += 1 end
  end
  if string.find(id, "^Forge") then forgeFound = true end
 end
end
check(stamped > 10, "Mined gear wasn't stamped with its finder")
check(forgeFound, "The mine never gave a Forge weapon")
local mined = grant(miner, {Depth = 1, Tutorial = true}, {Kind = "Gem"})
check(mined.Gem and mined.Gem.Cut, "Tutorial mining awarded a rough gem")
print("PASS: " .. cases .. " expedition checks (10,000 gem rolls, migration, loot, trade consent and retired actions)")
