--[[
	Parties of up to four. Request actions:
	  "PartyInvite", userId          invite someone in the server
	  "PartyRespond", userId, accept  answer an invite from that player
	  "PartyLeave"                    leave (the next member leads)
	  "PartyKick", userId             leader only
	  "PartyReady", ready             ready check
	  "PartyRally", landmark|nil      leader sets a rally point everyone sees
	The Party remote tells members the state ("State", data) and invitees
	about invites ("Invite", fromId, fromName).

	In a party, a monster's rewards go to every member fighting nearby, not
	just the top damage dealer (see Enemies).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local MAX_SIZE = 4
local INVITE_SECONDS = 60
local RALLY_POINTS = { Wilds = true, Arena = true, Quarry = true, Quartermaster = true, Market = true }

local reply = Shop.reply

type PartyData = { Leader: Player, Members: { Player }, Ready: { [Player]: boolean }, Rally: string? }

local Party = {}

local memberOf: { [Player]: PartyData } = {}
local invites: { [Player]: { [Player]: number } } = {} -- invitee -> inviter -> expiry

local function push(party: PartyData?)
	if not party then
		return
	end
	local members = {}
	for _, member in party.Members do
		local loadout = PlayerData.character(member)
		local class = loadout and Classes.get(loadout.Class)
		table.insert(members, {
			UserId = member.UserId,
			Name = member.DisplayName,
			Class = class and class.Name or "",
			Color = class and class.Color or Color3.new(1, 1, 1),
			Ready = party.Ready[member] == true,
		})
	end
	local state = { Leader = party.Leader.UserId, Members = members, Rally = party.Rally }
	for _, member in party.Members do
		Remotes.Party:FireClient(member, "State", state)
	end
end

local function leave(player: Player)
	local party = memberOf[player]
	if not party then
		return
	end
	memberOf[player] = nil
	local index = table.find(party.Members, player)
	if index then
		table.remove(party.Members, index)
	end
	party.Ready[player] = nil
	Remotes.Party:FireClient(player, "State", nil)
	if #party.Members <= 1 then
		-- A party of one is no party.
		for _, rest in party.Members do
			memberOf[rest] = nil
			Remotes.Party:FireClient(rest, "State", nil)
		end
		return
	end
	if party.Leader == player then
		party.Leader = party.Members[1]
	end
	push(party)
end

function Party.of(player: Player): PartyData?
	return memberOf[player]
end

-- Party members (including `player`) whose characters are within `radius`.
function Party.nearby(player: Player, position: Vector3, radius: number): { Player }
	local party = memberOf[player]
	if not party then
		return { player }
	end
	local list = {}
	for _, member in party.Members do
		local root = member.Character and member.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if member == player or (root and (root.Position - position).Magnitude <= radius) then
			table.insert(list, member)
		end
	end
	return list
end

local function byUserId(userId: any): Player?
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function invite(player: Player, userId: any)
	local target = byUserId(userId)
	if not target or target == player then
		return reply(false, "That player isn't here.")
	end
	local party = memberOf[player]
	if party and party.Leader ~= player then
		return reply(false, "Only the party leader can invite.")
	end
	if party and #party.Members >= MAX_SIZE then
		return reply(false, "Your party is full (4 players).")
	end
	if memberOf[target] then
		return reply(false, target.DisplayName .. " is already in a party.")
	end
	invites[target] = invites[target] or {}
	invites[target][player] = os.clock() + INVITE_SECONDS
	Remotes.Party:FireClient(target, "Invite", player.UserId, player.DisplayName)
	return reply(true, "Invited " .. target.DisplayName .. ".")
end

local function respond(player: Player, fromId: any, accept: any)
	local from = byUserId(fromId)
	local pending = invites[player]
	local expiry = from and pending and pending[from]
	if pending and from then
		pending[from] = nil
	end
	if not from or not expiry or os.clock() > expiry then
		return reply(false, "That invite has expired.")
	end
	if accept ~= true then
		Remotes.Notify:FireClient(from, player.DisplayName .. " declined your party invite.")
		return reply(true, "Invite declined.")
	end
	if memberOf[player] then
		leave(player)
	end
	local party = memberOf[from]
	if not party then
		party = { Leader = from, Members = { from }, Ready = {}, Rally = nil }
		memberOf[from] = party
	end
	if #party.Members >= MAX_SIZE then
		return reply(false, "That party is full.")
	end
	table.insert(party.Members, player)
	memberOf[player] = party
	push(party)
	return reply(true, "Joined " .. party.Leader.DisplayName .. "'s party.")
end

local function kick(player: Player, userId: any)
	local party = memberOf[player]
	local target = byUserId(userId)
	if not party or party.Leader ~= player or not target or memberOf[target] ~= party or target == player then
		return reply(false, "Only the leader can remove party members.")
	end
	leave(target)
	Remotes.Notify:FireClient(target, "You were removed from the party.")
	return reply(true, "Removed " .. target.DisplayName .. ".")
end

local function ready(player: Player, isReady: any)
	local party = memberOf[player]
	if not party then
		return reply(false, "You're not in a party.")
	end
	party.Ready[player] = isReady == true
	push(party)
	return reply(true, if isReady == true then "Ready!" else "Not ready.")
end

local function rally(player: Player, point: any)
	local party = memberOf[player]
	if not party or party.Leader ~= player then
		return reply(false, "Only the party leader sets the rally point.")
	end
	if point ~= nil and not RALLY_POINTS[point] then
		return reply(false, "Unknown place.")
	end
	party.Rally = point
	push(party)
	return reply(true, if point then "Rally point set." else "Rally point cleared.")
end

function Party.start()
	Shop.register("PartyInvite", invite)
	Shop.register("PartyRespond", respond)
	Shop.register("PartyLeave", function(player)
		if not memberOf[player] then
			return reply(false, "You're not in a party.")
		end
		leave(player)
		return reply(true, "You left the party.")
	end)
	Shop.register("PartyKick", kick)
	Shop.register("PartyReady", ready)
	Shop.register("PartyRally", rally)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		invites[player] = nil
	end)
end

return Party
