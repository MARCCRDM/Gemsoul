--[[
	Handles the Request remote: everything players ask shopkeepers to do.
	  "BuyRoughStone"            Mining Store: coins for a random rough stone
	  "AutoCut", gemId, tier     Laser cutter: coins for a guaranteed cut grade
	  "StartCut", gemId          Begin the hand-cutting minigame
	  "FinishCut", times         Submit strike times; the server grades the cut
	Every request is checked on the server: ownership, coins, and that the
	gem is still rough.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemGenerator = require(script.Parent.GemGenerator)
local Gems = require(script.Parent.Gems)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Remotes = require(script.Parent.Remotes)

type Session = { GemId: string, Started: number, Centers: { number }, Zone: number, Sweep: number }

local Shop = {}

local sessions: { [Player]: Session } = {}
local lastRequest: { [Player]: number } = {}

local function reply(ok: boolean, message: string, extra: { [string]: any }?): { [string]: any }
	local result = extra or {}
	result.Ok = ok
	result.Message = message
	return result
end

local function roughGem(player: Player, gemId: any): GemConfig.Gem?
	if typeof(gemId) ~= "string" then
		return nil
	end
	local gem = PlayerData.findGem(player, gemId)
	if gem and gem.Cut == nil then
		return gem
	end
	return nil
end

local handlers = {}

function handlers.GetProfile(player: Player)
	return reply(true, "", { Profile = PlayerData.snapshot(player) })
end

function handlers.BuyRoughStone(player: Player)
	local profile = PlayerData.get(player)
	if profile and #profile.Gems >= Config.MaxGems then
		return reply(false, "Your gem pouch is full.")
	end
	if not PlayerData.spendCoins(player, Config.RoughStonePrice) then
		return reply(false, string.format("You need %d coins for a rough stone.", Config.RoughStonePrice))
	end
	local gem = Gems.award(player, "MiningStore")
	if not gem then
		PlayerData.addCoins(player, Config.RoughStonePrice)
		return reply(false, "Your gem pouch is full.")
	end
	return reply(true, "Here's your stone: " .. GemConfig.displayName(gem) .. ".", { Gem = gem })
end

function handlers.AutoCut(player: Player, gemId: any, tier: any)
	local gem = roughGem(player, gemId)
	if not gem then
		return reply(false, "That stone can't be cut (it's missing or already cut).")
	end
	local laser = nil
	for _, option in GemConfig.AutoCut do
		if option.Tier == tier then
			laser = option
		end
	end
	if not laser then
		return reply(false, "Unknown laser cutter.")
	end
	if not PlayerData.spendCoins(player, laser.Price) then
		return reply(false, string.format("The %s costs %d coins.", laser.Name, laser.Price))
	end
	gem.Cut = GemGenerator.autoCutGrade(Gems.random(), laser.Tier)
	gem.CutMethod = "AutoCut"
	PlayerData.gemChanged(player)
	PlayerData.milestone(player, "Cut")
	Progress.addXP(player, "CutByLaser")
	return reply(
		true,
		string.format("%s cut to grade %d. Now worth ~%d coins.", laser.Name, gem.Cut, GemConfig.value(gem)),
		{ Gem = gem }
	)
end

function handlers.StartCut(player: Player, gemId: any)
	local gem = roughGem(player, gemId)
	if not gem then
		return reply(false, "That stone can't be cut (it's missing or already cut).")
	end
	local zone, sweep = GemConfig.cuttingDifficulty(gem.Size)
	local centers = {}
	local rng = Gems.random()
	for i = 1, GemConfig.Cutting.Strikes do
		centers[i] = rng:NextNumber(zone / 2 + 0.05, 1 - zone / 2 - 0.05)
	end
	sessions[player] = { GemId = gem.Id, Started = os.clock(), Centers = centers, Zone = zone, Sweep = sweep }
	return reply(true, "Cutting started.", { Centers = centers, Zone = zone, Sweep = sweep })
end

function handlers.FinishCut(player: Player, times: any)
	local session = sessions[player]
	sessions[player] = nil
	if not session then
		return reply(false, "No cut in progress.")
	end
	local elapsed = os.clock() - session.Started
	if elapsed > GemConfig.Cutting.SessionTimeout then
		return reply(false, "Too slow: the stone cooled. Try again.")
	end
	local gem = roughGem(player, session.GemId)
	if not gem or typeof(times) ~= "table" then
		return reply(false, "That stone can't be cut.")
	end
	-- Strike times must be in order and can't be later than now.
	local clean, previous = {}, 0
	for i = 1, #session.Centers do
		local t = times[i]
		if typeof(t) ~= "number" or t ~= t or t < previous or t > elapsed + 0.5 then
			t = -1
		else
			previous = t
		end
		clean[i] = t
	end
	local accuracies = GemGenerator.strikeAccuracy(clean, session.Centers, session.Zone, session.Sweep)
	gem.Cut = GemGenerator.manualCutGrade(accuracies)
	gem.CutMethod = "Manual"
	PlayerData.gemChanged(player)
	PlayerData.milestone(player, "Cut")
	Progress.addXP(player, "CutByHand")
	local verdict = if gem.Cut >= 10
		then "Flawless! Gem Mint!"
		elseif gem.Cut >= 9 then "Masterful cut!"
		else "Cut complete."
	return reply(
		true,
		string.format("%s Grade %d. Now worth ~%d coins.", verdict, gem.Cut, GemConfig.value(gem)),
		{ Gem = gem, Accuracies = accuracies }
	)
end

-- Lets other systems add request actions (e.g. the intro's).
function Shop.register(action: string, handler: (Player, ...any) -> { [string]: any })
	handlers[action] = handler
end

Shop.reply = reply

-- Entry point for every client request (also called directly by tests).
function Shop.handle(player: Player, action: any, ...): { [string]: any }
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.2 then
		return reply(false, "Slow down!")
	end
	lastRequest[player] = now
	local handler = typeof(action) == "string" and handlers[action]
	if not handler or not PlayerData.get(player) then
		return reply(false, "Unknown request.")
	end
	return handler(player, ...)
end

function Shop.start()
	Remotes.Request.OnServerInvoke = Shop.handle
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		lastRequest[player] = nil
	end)
end

return Shop
