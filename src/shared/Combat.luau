--[[
	Combat rules shared by the server (which runs every hit) and the client
	(HUD, cooldowns, where you can fight).

	Where: fighting is off inside the town walls, except in the Arena
	(training dummies). Outside the south gate are the Crystal Wilds, where
	crystal monsters roam and drop stones and coins.

	Numbers:
	  damage = base x (Power / 60) x buffs, x1.6 on a crit or combo finisher
	  crit chance = min(75%, 5% + min(2.5%, Speed / 4000) + equipment bonus)
	  damage taken = hit x 60 / (60 + Defense) x armor/weapon/buff multipliers
	Resources (per class) fill and drain as below; rig maneuvers spend them.

	RigManeuver kinds (numbers live on each rigManeuver in Classes):
	  Cone  hit enemies in front: Damage, Range, Arc
	  Nova  hit enemies around you (or the aimed spot with AtTarget): Radius
	  Dash  move Distance (Backward, Teleport), then hit around you if Damage
	  Bolt  a projectile at the aimed spot: Range, Pierce, Splash, Chain
	  Buff  on yourself: Duration, DamageMult, TakenMult, RateMult, Heal, Shield
	  Zone  a lasting area at the aimed spot: Radius, Duration, Tick damage
	Shared extras: Stun, Slow + SlowTime, Taunt, Burn, Poison, Gain, Cost.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentBalance = require(script.Parent.EquipmentBalance)
local Combat = {}

Combat.TownRadius = 192 -- the walls and moat; no fighting inside (but the Arena)
Combat.CritMult = 1.6
Combat.FinisherMult = 1.6
Combat.InCombatSeconds = 5 -- Rage and Resolve start fading after this long

export type Resource = { Max: number, Start: number, Regen: number, OnHit: number, OnHurt: number }

-- Regen is per second; negative means it fades while out of combat.
Combat.Resources = {
	Stamina = { Max = 100, Start = 100, Regen = 12, OnHit = 0, OnHurt = 0 },
	Charge = { Max = 100, Start = 100, Regen = 7, OnHit = 0, OnHurt = 0 },
} :: { [string]: Resource }
Combat.ResourceColors = {
	Health = Color3.fromRGB(198, 62, 73),
	Stamina = Color3.fromRGB(65, 195, 112),
	Charge = Color3.fromRGB(70, 130, 255),
}

function Combat.powerMult(power: number): number
	return math.max(0.3, power / 60)
end

function Combat.defenseMult(defense: number): number
	return 60 / (60 + math.max(0, defense))
end

function Combat.critChance(speed: number, bonus: number?): number
	return EquipmentBalance.criticalChance(speed, bonus)
end

-- Landmarks the world builder publishes (see Builder.landmark).
local function landmark(name: string): any
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	return landmarks and landmarks:GetAttribute(name)
end

function Combat.inArena(position: Vector3): boolean
	local center, radius = landmark("ArenaFloor"), landmark("ArenaRadius")
	if typeof(center) ~= "Vector3" or typeof(radius) ~= "number" then
		return false
	end
	local offset = position - center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius + 2 and math.abs(offset.Y) < 30
end

-- Can a fight happen at this spot?
function Combat.canFight(position: Vector3): boolean
	return Vector3.new(position.X, 0, position.Z).Magnitude > Combat.TownRadius or Combat.inArena(position)
end

-- Can this player change their build (surges, augments, loadouts) now? Never
-- in a fight, a match or an expedition; yes in town and in the Outpost (the
-- lobby, a safe space far outside the town walls); not out in the field.
function Combat.canChangeBuild(player: Player): boolean
	if player:GetAttribute("CombatSession") or player:GetAttribute("Expedition") or player:GetAttribute("MatchId") then
		return false
	end
	if player:GetAttribute("Outpost") == true then
		return true
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return not root or not Combat.canFight((root :: BasePart).Position)
end

return Combat
