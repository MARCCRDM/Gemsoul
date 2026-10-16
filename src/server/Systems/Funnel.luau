--[[
	The onboarding funnel: how far new players get through their first
	session (Creator Dashboard > Analytics > Funnels > Onboarding). Each step
	is logged once per account, in this order:

	   1 Joined        a new account's profile loaded
	   2 Style         picked a fighting style (the picker says so)
	   3 Element       picked an element: the starter kit is rolled
	   4 Kit           the kit is on, after the reveal
	   5 First fight   the first fight is over (won, lost or left)
	   6 Lobby         arrived in the Outpost lobby after it
	   7 First rock    broke a rock
	   8 First gem     a rock dropped a gem
	   9 Socketed      put a gem in a gear socket
	  10 Surge ready   put a gem in Q, E or R
	  11 Second duel   played another duel after the first fight

	Only accounts that join as new players are counted: profile.Funnel is
	made on their first load, and holds the steps already logged, so a
	rejoin never logs one twice. Players from before it are left out.

	  Funnel.reach(player, name)   logs that step if it's new -> true if logged
	  Funnel.start()
]]
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local Funnel = {}

Funnel.Steps = {
	"Joined",
	"Style",
	"Element",
	"Kit",
	"First fight",
	"Lobby",
	"First rock",
	"First gem",
	"Socketed",
	"Surge ready",
	"Second duel",
}
local stepOf: { [string]: number } = {}
for i, name in Funnel.Steps do
	stepOf[name] = i
end
-- Steps the client may report: only what happens in its own menus.
Funnel.FromClient = { Style = true }
-- Tasks events (PlayerData.training) that are funnel steps.
Funnel.FromTraining = { Mine = "First rock", MineGem = "First gem", Enchant = "Socketed", EquipSurge = "Surge ready" }

-- Sends one step to Roblox (tests swap it out).
function Funnel.log(player: Player, step: number, name: string)
	AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
end

local function logged(player: Player): { [string]: boolean }?
	local profile = PlayerData.get(player) :: any
	return profile and profile.Funnel
end

function Funnel.reach(player: Player, name: string): boolean
	local step = stepOf[name]
	local done = logged(player)
	if not step or not done or done[name] then
		return false
	end
	-- The lobby counts once the first fight is behind them.
	if name == "Lobby" and not done["First fight"] then
		return false
	end
	done[name] = true
	local ok, problem = pcall(Funnel.log, player, step, name)
	if not ok then
		warn("[Funnel] couldn't log " .. name .. ": " .. tostring(problem))
	end
	return true
end

-- A profile loaded: a new account starts the funnel.
function Funnel.joined(player: Player)
	local profile = PlayerData.get(player) :: any
	if not profile then
		return
	end
	if profile.Funnel == nil and profile.Intro and not profile.Intro.Done then
		profile.Funnel = {}
	end
	Funnel.reach(player, "Joined")
	Funnel.watch(player)
end

-- The steps that show on the player: the first fight ending, the lobby,
-- and duels played.
function Funnel.watch(player: Player)
	if not logged(player) then
		return
	end
	local fighting = player:GetAttribute("FirstFight") == true
	player:GetAttributeChangedSignal("FirstFight"):Connect(function()
		if player:GetAttribute("FirstFight") then
			fighting = true
		elseif fighting then
			fighting = false
			Funnel.reach(player, "First fight")
			if player:GetAttribute("Outpost") then
				Funnel.reach(player, "Lobby")
			end
		end
	end)
	player:GetAttributeChangedSignal("Outpost"):Connect(function()
		if player:GetAttribute("Outpost") then
			Funnel.reach(player, "Lobby")
		end
	end)
	player:GetAttributeChangedSignal("DuelsPlayed"):Connect(function()
		local played = player:GetAttribute("DuelsPlayed")
		local done = logged(player)
		if type(played) == "number" and played >= 2 and done and done["First fight"] then
			Funnel.reach(player, "Second duel")
		end
	end)
end

function Funnel.start()
	PlayerData.Loaded:Connect(Funnel.joined)
	PlayerData.Trained:Connect(function(player, event)
		local name = Funnel.FromTraining[event]
		if name then
			Funnel.reach(player, name)
		end
	end)
	Remotes.Funnel.OnServerEvent:Connect(function(player, name)
		if type(name) == "string" and Funnel.FromClient[name] then
			Funnel.reach(player, name)
		end
	end)
	-- Anyone already here (a module loaded late).
	for _, player in Players:GetPlayers() do
		if PlayerData.get(player) then
			task.spawn(Funnel.joined, player)
		end
	end
end

return Funnel
