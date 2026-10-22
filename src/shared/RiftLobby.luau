--[[
	A Rift Gate's lobby (Client.RiftClient draws it): your party's four
	places, the miners in the Outpost and your Roblox friends online, and
	what you can do about each of them. Pure, for the client and tests.

	  RiftLobby.Near                      studs from the gate: "at the gate"
	  RiftLobby.lobby(view) -> lobby      who's where, and the invites
]]
local RiftRun = require(script.Parent.RiftRun)

local RiftLobby = {}

-- Within this of the gate, a miner's "at the gate".
RiftLobby.Near = 30

-- Who's round the gate, as its lobby shows them. `view`:
--   Me       your UserId, MeName your name
--   Party    your party (the server's Party state: { Leader, Members:
--            { { UserId, Name, Ready } } }), or nil when you're on your own
--   Players  everyone else in the server: { { UserId, Name, Level, Outpost,
--            Party ("Mine", "Other" or nil: whose party they're in), InRift,
--            Near (at this gate) } }
--   Friends  your Roblox friends online (Player:GetFriendsOnline), or nil
--            before the first answer
--   Invited  { [userId] = true }: asked a moment ago
--   PlaceId  this game's
-- Returns { Slots (RiftRun.Party of them, you first, then the leader: a
-- member { UserId, Name, Leader, Ready, You, Where }, or false: open), Lead
-- (you lead, or you're on your own), Size (your party, you too), Ready (the
-- others who are ready), Trip (one of them's in the Rift: you'd join them),
-- Outpost and Friends ({ row }), Known (your friends have been fetched) }. A row is { UserId,
-- Name, Level, Where, Friend, Invite }: Invite is "Party" (you can ask them
-- into your party), "Game" (a friend who isn't here: Roblox's invite),
-- "Invited", "Busy" (in a party or in the Rift already) or nil (only your
-- leader invites, or your party's full).
function RiftLobby.lobby(view)
	local me, party = view.Me, view.Party
	-- (On your own you're your party, ready to go: no leader to show.)
	local members = if party then party.Members else { { UserId = me, Name = view.MeName, Ready = true } }
	local lead = party == nil or party.Leader == me
	local size = #members
	local byId = {}
	for _, other in view.Players or {} do
		byId[other.UserId] = other
	end
	local friendIds = {}
	for _, friend in view.Friends or {} do
		friendIds[friend.VisitorId] = true
	end
	local function whereOf(other): string
		if other.InRift then
			return "In the Rift"
		elseif other.Near then
			return "At the gate"
		elseif other.Outpost then
			return "In the Outpost"
		end
		return "Not in the Outpost"
	end
	local function invite(userId: number, here): string?
		if (view.Invited or {})[userId] then
			return "Invited"
		elseif here and (here.Party ~= nil or here.InRift) then
			return "Busy"
		elseif not here then
			return "Game"
		elseif not lead or size >= RiftRun.Party then
			return nil
		end
		return "Party"
	end

	-- Your party: you, the leader, the rest; then the open places.
	local ordered = {}
	for _, member in members do
		table.insert(ordered, member)
	end
	local function rank(member): number
		return if member.UserId == me then 0 elseif party and member.UserId == party.Leader then 1 else 2
	end
	table.sort(ordered, function(a, b)
		local ra, rb = rank(a), rank(b)
		return if ra ~= rb then ra < rb else tostring(a.Name) < tostring(b.Name)
	end)
	local slots, ready = {}, 0
	for i = 1, RiftRun.Party do
		local member = ordered[i]
		if member then
			local here = byId[member.UserId]
			local you = member.UserId == me
			slots[i] = {
				UserId = member.UserId,
				Name = member.Name,
				Leader = party ~= nil and member.UserId == party.Leader,
				Ready = member.Ready == true,
				You = you,
				Where = if you then "At the gate" elseif here then whereOf(here) else "Away",
			}
			if not you and member.Ready then
				ready += 1
			end
		else
			slots[i] = false
		end
	end
	local inParty = {}
	for _, member in members do
		inParty[member.UserId] = true
	end

	-- The Outpost: who's at this gate first, your friends next, then by name.
	local outpost = {}
	for _, other in view.Players or {} do
		if other.Outpost and not inParty[other.UserId] then
			table.insert(outpost, {
				UserId = other.UserId,
				Name = other.Name,
				Level = other.Level,
				Where = whereOf(other),
				Friend = friendIds[other.UserId] == true,
				Invite = invite(other.UserId, other),
				Near = other.Near == true,
			})
		end
	end
	table.sort(outpost, function(a, b)
		if a.Near ~= b.Near then
			return a.Near
		elseif a.Friend ~= b.Friend then
			return a.Friend
		end
		return a.Name < b.Name
	end)

	-- Your friends online: here first, then in this game elsewhere, then the rest.
	local friends = {}
	for _, friend in view.Friends or {} do
		local id = friend.VisitorId
		if type(id) == "number" and not inParty[id] then
			local here = byId[id]
			local name = friend.DisplayName or friend.UserName or "?"
			local sameGame = friend.PlaceId ~= nil and friend.PlaceId == view.PlaceId
			table.insert(friends, {
				UserId = id,
				Name = if here then here.Name else name,
				Level = here and here.Level,
				Where = if here then whereOf(here) elseif sameGame then "Playing, another server" else "Online",
				Friend = true,
				Invite = invite(id, here),
				Order = if here then 0 elseif sameGame then 1 else 2,
			})
		end
	end
	table.sort(friends, function(a, b)
		return if a.Order ~= b.Order then a.Order < b.Order else a.Name < b.Name
	end)

	-- One of your party in the Rift already: going in, you join their trip.
	local trip = false
	for _, member in members do
		local here = byId[member.UserId]
		trip = trip or (here ~= nil and here.InRift == true)
	end

	return {
		Slots = slots,
		Lead = lead,
		Size = size,
		Ready = ready,
		Trip = trip,
		Outpost = outpost,
		Friends = friends,
		Known = view.Friends ~= nil,
	}
end

return RiftLobby
