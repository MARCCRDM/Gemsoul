--[[
	A new player's first session as a journey (Creator Dashboard > Analytics >
	Journeys: the paths players take, drawn as a Sankey). Unlike a funnel's
	fixed order, a journey records each place a player reaches, in whatever
	order they reach it: the intro rounds won and lost, HUNT BOUNTY or more
	rounds, the first dungeon, the lobby's intro, and where they left.

	One journey a new player, for the session they joined as new in (their
	first visit: Server.Funnel starts it at "Joined"); one session id for it.
	Each node is logged once a session. Dev and test accounts are left out
	(Analytics.excluded, set by Server.DevAccounts).

	  Journey.Name                    the journey's name on the dashboard
	  Journey.start(player)           a new account joined: its journey begins
	  Journey.reach(player, node)     they reached `node` (ignored when not on it)
	  Journey.left(player)            they left the game: the last node
	  Journey.active(player) -> bool
	  Journey.listen()                once (Main): the last node as they leave

	AnalyticsService:LogJourneyEvent(player, journeyName, nodeName,
	journeySessionId?, customFields?): names can't be empty or hold a comma,
	a quote or a newline, and a node can't start with "__".
]]
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Journey = {}

Journey.Name = "First session"
Journey.MaxNodes = 60 -- a session's nodes, at most (the event budget)

type Run = { Id: string, Seen: { [string]: boolean }, Count: number, Last: string?, Started: number }
local runs: { [Player]: Run } = {}

-- Sends one node to Roblox (tests swap it out).
function Journey.log(player: Player, node: string, session: string, fields: { [string]: any }?)
	AnalyticsService:LogJourneyEvent(player, Journey.Name, node, session, fields)
end

-- Accounts left out of the numbers (Server.DevAccounts sets it).
Journey.excluded = function(_player: Player): boolean
	return false
end

-- A node's name as Roblox takes it: no commas, quotes or newlines, not
-- starting with "__", not empty, kept short.
function Journey.clean(node: any): string?
	if type(node) ~= "string" then
		return nil
	end
	local name = node:gsub("[,\"'\r\n]", " "):gsub("^_+", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	name = string.sub(name, 1, 50)
	return if name ~= "" then name else nil
end

function Journey.active(player: Player): boolean
	return runs[player] ~= nil
end

function Journey.start(player: Player)
	if runs[player] then
		return
	end
	local ok, id = pcall(function()
		return HttpService:GenerateGUID(false)
	end)
	runs[player] = {
		Id = if ok and type(id) == "string" then id else string.format("%d-%d", player.UserId, os.time()),
		Seen = {},
		Count = 0,
		Started = os.clock(),
	}
	Journey.reach(player, "Joined")
end

function Journey.reach(player: Player, node: any): boolean
	local run = runs[player]
	local name = Journey.clean(node)
	if not run or not name or run.Seen[name] or run.Count >= Journey.MaxNodes then
		return false
	end
	run.Seen[name], run.Count, run.Last = true, run.Count + 1, name
	if Journey.excluded(player) then
		return true -- (a dev account: reached, not counted)
	end
	local ok, problem = pcall(Journey.log, player, name, run.Id, nil)
	if not ok then
		warn("[Journey] couldn't log " .. name .. ": " .. tostring(problem))
	end
	return true
end

-- Leaving: the journey's last node, with where they were and how long in.
function Journey.left(player: Player)
	local run = runs[player]
	if not run then
		return
	end
	local last = run.Last or "Joined"
	runs[player] = nil
	if Journey.excluded(player) then
		return
	end
	local minutes = math.floor((os.clock() - run.Started) / 60)
	local length = if minutes < 2 then "under 2 min" elseif minutes < 5 then "2-5 min" elseif minutes < 10 then "5-10 min" else "10+ min"
	local ok, problem = pcall(function()
		Journey.log(player, "Left the game", run.Id, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = last,
			[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = length,
		})
	end)
	if not ok then
		warn("[Journey] couldn't log the leaving: " .. tostring(problem))
	end
end

local listening = false
function Journey.listen()
	if listening then
		return
	end
	listening = true
	Players.PlayerRemoving:Connect(Journey.left)
end

return Journey
