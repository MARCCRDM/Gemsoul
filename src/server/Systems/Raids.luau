--[[
	Party Raids (PvE): a party of at least three (Shared.Matchmaking.Raid.Min)
	fights a raid boss together in the Arena. Request actions:

	  "PartyRaid"   the party's leader starts one: every member is brought
	                to the Arena floor in a "Raid" session (RaidId set), and
	                a boss steps in (Duelist.startRaid)

	Leaving is the Arena's usual Leave button (ArenaLeave). The boss itself,
	its waves, targets and rewards live in the Duelist.
]]
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)
local CombatServer = require(script.Parent.CombatServer)
local Duelist = require(script.Parent.Duelist)
local Party = require(script.Parent.Party)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local Raids = {}

Raids.Delay = 2.5 -- seconds between arriving and the boss stepping in

-- Why this member can't come right now, or nil.
function Raids.busy(player: Player): string?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local name = player.DisplayName
	if not humanoid or humanoid.Health <= 0 or not PlayerData.get(player) then
		return name .. " isn't ready yet."
	end
	if player:GetAttribute("Expedition") then
		return name .. " is on an expedition."
	end
	if player:GetAttribute("MatchId") or player:GetAttribute("DuelQueue") then
		return name .. " is in a duel or the duel queue."
	end
	if player:GetAttribute("CombatSession") then
		return name .. " is already in the Arena. Leave it first."
	end
	return nil
end

local function start(player: Player)
	local party = Party.of(player)
	if party and party.Leader ~= player then
		return reply(false, "Only your party's leader can start a raid.")
	end
	local ok, why = Matchmaking.raidCheck(party and party.Members, player, Raids.busy)
	if not ok then
		return reply(false, why or "Can't start a raid right now.")
	end
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local center = landmarks and landmarks:GetAttribute("ArenaFloor")
	if typeof(center) ~= "Vector3" then
		return reply(false, "The Arena isn't ready yet.")
	end
	local members = table.clone((party :: any).Members)
	local id = "R" .. string.sub(HttpService:GenerateGUID(false), 1, 8)
	-- In a ring on the floor, facing in.
	for index, member in members do
		local angle = (index - 1) / #members * math.pi * 2
		local spot = center + Vector3.new(math.cos(angle) * 9, 4, math.sin(angle) * 9)
		local character = member.Character
		pcall(function()
			member:RequestStreamAroundAsync(spot)
		end)
		if character then
			character:PivotTo(CFrame.lookAt(spot, center + Vector3.new(0, 4, 0)))
			local protection = Instance.new("ForceField")
			protection.Parent = character
			Debris:AddItem(protection, 3)
		end
		member:SetAttribute("PvPEnabled", false)
		CombatServer.reset(member)
		member:SetAttribute("RaidId", id)
		member:SetAttribute("CombatSession", "Raid")
		if member ~= player then
			Remotes.Notify:FireClient(member, player.DisplayName .. " started a Party Raid! Get ready…")
		end
	end
	task.delay(Raids.Delay, function()
		local here = {}
		for _, member in members do
			if member.Parent and member:GetAttribute("RaidId") == id then
				table.insert(here, member)
			end
		end
		if here[1] then
			Duelist.startRaid(here, id)
		end
	end)
	return reply(true, string.format("Party Raid! %d raiders vs a raid boss. Stick together.", #members))
end

function Raids.start()
	Shop.register("PartyRaid", start)
end

return Raids
