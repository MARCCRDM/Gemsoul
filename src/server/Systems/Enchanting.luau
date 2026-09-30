--[[
	Socketing gems into gear, at Vey's Arcanum (or anywhere during the intro).
	  "SocketGem", gemId, slot     slot is "Weapon" (default) or "Armor"
	  "UnsocketGem", slot          the gem goes back to the pouch
	A weapon gem adds its element to your hits; an armor gem wards you
	against it. See GemConfig.enchantment for the numbers.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Tags = require(ReplicatedStorage.Shared.Tags)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local VEY_RANGE = 30 -- studs from Vey the Arcanist

local reply = Shop.reply

local Enchanting = {}

local function nearVey(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, vendor in CollectionService:GetTagged(Tags.Vendor) do
		local torso = vendor:FindFirstChild("Torso")
		if vendor:IsA("Model") and torso and torso:GetAttribute("VendorId") == "Enchanting" then
			if (vendor:GetPivot().Position - root.Position).Magnitude <= VEY_RANGE then
				return true
			end
		end
	end
	return false
end

-- New players socket their first gem in the intro; after that it's Vey's job.
local function canEnchant(player: Player): boolean
	local intro = PlayerData.intro(player)
	return not (intro and intro.Done) or nearVey(player)
end

local function socketGem(player: Player, gemId: any, slot: any)
	slot = slot or "Weapon"
	if typeof(gemId) ~= "string" or (slot ~= "Weapon" and slot ~= "Armor") then
		return reply(false, "Pick a gem and a socket.")
	end
	if not canEnchant(player) then
		return reply(false, "Visit Vey at the Arcanum (east road) to change enchantments.")
	end
	local gem = PlayerData.socketGem(player, gemId, slot)
	if not gem then
		return reply(false, "Only cut gems can be socketed. Rough stones need cutting first.")
	end
	local name, effect = GemConfig.enchantment(gem, slot)
	return reply(true, string.format("%s: %s", name, effect), { Gem = gem })
end

local function unsocketGem(player: Player, slot: any)
	if slot ~= "Weapon" and slot ~= "Armor" then
		return reply(false, "Pick a socket.")
	end
	if not canEnchant(player) then
		return reply(false, "Visit Vey at the Arcanum (east road) to change enchantments.")
	end
	local gem = PlayerData.unsocketGem(player, slot)
	if not gem then
		return reply(false, "Nothing to remove, or your pouch is full.")
	end
	return reply(true, GemConfig.shade(gem).Name .. " is back in your pouch.", { Gem = gem })
end

function Enchanting.start()
	Shop.register("SocketGem", socketGem)
	Shop.register("UnsocketGem", unsocketGem)
end

return Enchanting
