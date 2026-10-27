--[[
	COUNTER between the rounds of a Ranked 1v1 (Shared.CounterGear): what
	hurt a fighter in the round, the armor-only answer from what they own,
	and wearing it when the next round is revealed (Systems/Duels' pivot
	window). The plan is rebuilt here when it's worn: a client never says
	which gems or pieces to move.

	  CounterServer.threat(player, foes) -> CounterGear threat: the damage
	                                  the player took this round by element
	                                  (CombatServer), else the first foe's gear
	  CounterServer.offer(player, threat) -> the plan (CounterGear.plan)
	  CounterServer.wear(player, threat) -> { Element, Pieces, Gems }
	  CounterServer.newRound(player)  forget what they took (a round starts)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CounterGear = require(ReplicatedStorage.Shared.CounterGear)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local CombatServer = require(script.Parent.CombatServer)
local PlayerData = require(script.Parent.PlayerData)

local CounterServer = {}

function CounterServer.threat(player: Player, foes: { Player })
	local foe = foes and foes[1]
	return CounterGear.threat(CombatServer.takenByElement(player), foe and PlayerData.character(foe))
end

function CounterServer.offer(player: Player, threat)
	return CounterGear.plan(PlayerData.get(player), threat)
end

function CounterServer.wear(player: Player, threat)
	local plan = CounterGear.plan(PlayerData.get(player), threat)
	local pieces, gems = 0, 0
	for _, step in plan.Gear do
		if PlayerData.equipGear(player, Slots.Definitions[step.Slot].Kind, step.Id) then
			pieces += 1
		end
	end
	for _, step in plan.Gems do
		if PlayerData.socketGem(player, step.Gem, step.Slot) then
			gems += 1
		end
	end
	return { Element = plan.Element, Pieces = pieces, Gems = gems }
end

function CounterServer.newRound(player: Player)
	CombatServer.clearTaken(player)
end

return CounterServer
