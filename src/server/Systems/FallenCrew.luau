--[[
	The fallen crews' bodies: real miners. A dead miner by a dungeon room's
	wall or in a Rift cave is the body every player wears (FighterRig), in
	the gear every player wears (Equipment), rolled at random: a helmet,
	chest, gloves, boots and shield from the armor families players wear
	today (Shared.ArmorFamilies: Prospector, Skirmisher, Juggernaut, any
	rarity, commons likelier), a sword (Traits.rollable: the standard swords
	and their variants, as the rolls hand out; no axes, hammers, lances or
	pistols), a gem in a piece or two, and for some a suit, a weapon skin, a
	visor or a helmet skin (and for some nothing at all), so no two of them
	lie alike. Server.World.FallenMiners lays them out in their death poses
	(FallenMiners.dresser), the sword dropped on the floor by its hand.

	  FallenCrew.wearable(kind, gear) -> may a fallen miner wear it?
	  FallenCrew.roll(rng) -> loadout, cosmetics, skin
	  FallenCrew.body(rng, parent) -> Model?   a dressed rig, standing at the
	                                           origin, under `parent`
	  FallenCrew.start()                       hands FallenMiners its bodies
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Traits = require(ReplicatedStorage.Shared.ExpandedItemTraits)
local Equipment = require(script.Parent.Equipment)
local FighterRig = require(script.Parent.FighterRig)
local FallenMiners = require(script.Parent.Parent.World.FallenMiners)

local FallenCrew = {}

-- How often a dead miner wears each kind of cosmetic (independent rolls:
-- about one in six wears nothing at all).
FallenCrew.Odds = { Suit = 0.45, Skin = 0.35, Visor = 0.4, Helmet = 0.25 }
-- How many pieces carry a gem: none, one or two.
FallenCrew.GemOdds = { 0.3, 0.45, 0.25 }
FallenCrew.GemTiers = { "Common", "Common", "Uncommon", "Uncommon", "Rare" }
-- How likely each rarity tier of gear is on one (1 to 5): crews that got
-- this far carried better than the commons a fresh roll hands out.
FallenCrew.Weights = { 35, 30, 20, 10, 5 }
FallenCrew.Elements = { "Fire", "Frost", "Shock", "Poison" }

-- What a fallen miner may wear: armor and shields of the families players
-- wear today (Shared.ArmorFamilies), and of the weapons only the swords
-- (Traits.rollable). Anything else in the catalogue is from before.
function FallenCrew.wearable(kind: string, gear): boolean
	if gear == nil then
		return false
	end
	if gear.StartPool == false then
		return false -- (retired: kept for saves, never handed out)
	end
	if kind == "Weapons" then
		return Traits.rollable(gear)
	end
	return Traits.obtainable(gear) and gear.ArmorFamily ~= nil
end

-- One of a kind of gear, commons likelier than legendaries
-- (FallenCrew.Weights by rarity tier), of what a fallen miner may wear
-- (FallenCrew.wearable; failing that, anything that can be handed out at all).
local function pickGear(kind: string, list, rng)
	local wearable = {}
	for _, gear in list do
		if FallenCrew.wearable(kind, gear) then
			table.insert(wearable, gear)
		end
	end
	if #wearable == 0 then
		for _, gear in list do
			if Traits.obtainable(gear) then
				table.insert(wearable, gear)
			end
		end
	end
	local groups = {}
	for _, gear in wearable do
		local tier = gear.RarityTier or 1
		groups[tier] = groups[tier] or {}
		table.insert(groups[tier], gear)
	end
	local total = 0
	for tier, weight in FallenCrew.Weights do
		if groups[tier] then
			total += weight
		end
	end
	if total == 0 then
		return list[1]
	end
	local pick = rng:NextNumber(0, total)
	for tier, weight in FallenCrew.Weights do
		local group = groups[tier]
		if group then
			pick -= weight
			if pick <= 0 then
				return group[rng:NextInteger(1, #group)]
			end
		end
	end
	return list[1]
end

local function one(ids: { string }, rng): string
	return ids[rng:NextInteger(1, #ids)]
end

local byKind: { [string]: { string } } = {}
local function kindIds(kind: string): { string }
	if not byKind[kind] then
		byKind[kind] = Cosmetics.ofKind(kind)
	end
	return byKind[kind]
end

-- A random kit, as a player might have worn it, and what it wore for looks.
function FallenCrew.roll(rng: Random)
	local class = Classes.get("Warrior")
	assert(class, "No Warrior class")
	local c = { Class = "Warrior", GearRolls = {}, ItemGems = {} }
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		local gear = pickGear(kind, class[kind] or {}, rng)
		if gear then
			c[slot] = gear.Id
			c[slot .. "Quality"] = 1
			c.GearRolls[kind] = c.GearRolls[kind] or {}
			c.GearRolls[kind][gear.Id] = GearRolls.roll(rng, gear.RarityTier or 1, gear)
		end
	end
	-- A gem in a piece or two.
	local gems = 0
	local draw = rng:NextNumber()
	for n, odds in FallenCrew.GemOdds do
		draw -= odds
		if draw <= 0 then
			gems = n - 1
			break
		end
	end
	local slots = table.clone(Slots.Order)
	for _ = 1, gems do
		local slot = table.remove(slots, rng:NextInteger(1, #slots))
		if slot and c[slot] then
			c[slot .. "Gem"] = {
				Id = "fallen-" .. slot,
				Element = one(FallenCrew.Elements, rng),
				Tier = one(FallenCrew.GemTiers, rng),
				Size = rng:NextInteger(3, 9),
				Clarity = rng:NextInteger(3, 9),
				Cut = rng:NextInteger(3, 9),
			}
		end
	end
	-- What it wore for looks: some of these, or none.
	local cosmetics = { Owned = {} }
	for kind, odds in FallenCrew.Odds do
		local ids = kindIds(kind)
		if #ids > 0 and rng:NextNumber() < odds then
			local id = one(ids, rng)
			cosmetics[kind] = id
			cosmetics.Owned[id] = true
		end
	end
	local skin = Color3.fromHSV(0.06 + rng:NextNumber() * 0.05, 0.25 + rng:NextNumber() * 0.35, 0.45 + rng:NextNumber() * 0.5)
	return c, cosmetics, skin
end

-- A dressed body, standing at the origin under `parent` (the gear welds to
-- it there; whoever lays it down moves it).
function FallenCrew.body(rng: Random, parent: Instance?): Model?
	local loadout, cosmetics, skin = FallenCrew.roll(rng)
	local rig = FighterRig.build(skin)
	rig.Name = "Body"
	-- Anchored from the start: it's built inside a live world, and an
	-- unanchored body would drop (and drag its gear with it) before it's
	-- laid down.
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	-- (its weapon in its fist, as a fighter holds it)
	rig:SetAttribute("FistGrip", true)
	if parent then
		rig.Parent = parent
	end
	local folder = Equipment.dressModel(rig, loadout, rng:NextInteger(1, 1000000), cosmetics)
	if not folder then
		rig:Destroy()
		return nil
	end
	rig:SetAttribute("Kit", string.format("%s / %s / %s", tostring(loadout.Armor), tostring(loadout.Helmet), tostring(loadout.Weapon)))
	rig:SetAttribute(
		"Look",
		string.format(
			"%s / %s / %s / %s",
			tostring(cosmetics.Suit),
			tostring(cosmetics.Skin),
			tostring(cosmetics.Visor),
			tostring(cosmetics.Helmet)
		)
	)
	return rig
end

function FallenCrew.start()
	FallenMiners.dresser = FallenCrew.body
end

return FallenCrew
