--[[
	Robbed while you're down (Shared.Frontier.Rob). Knocked out out past the
	core (FrontierServer) or in the Rift (RiftServer), you stay down while
	the critters rob you: the ones near come for you (KaijuWilds.rob), and
	if fewer are near than there's to take, the caller brings more through
	tears round you (its Spawn, handing each this robbery: KaijuWilds.spawnBug's
	Robbery). Each grabs one thing (the caller's Steal: one of this trip's
	gems), holds it up and runs for a tear with it, as a gem raid's
	snatcher does; bonked or knocked out first, it drops it back (the
	caller's Recover). Once it's over (Frontier.robOver), you're back at
	base (the caller's Done) and told what they took: "Robbed", report, to
	your client (the CombatFx remote; Client.RobReport draws it).

	On the Player while it lasts: Robbed (the server time it's over by) and
	SparDown (down till then: SparServer leaves you down, and the caller's
	Done gets you up).

	  Robbery.start(player, opts) -> robbery   (the one on them already, if any)
	      opts: Where ("Outpost" | "Rift"), Steal(player) -> gem?,
	            Takeable (how many there are to take), Max?,
	            Recover(player, gem, at)?, Away(from, at) -> Vector3?,
	            Spawn(count, robbery)?, Done(player, report)
	  Robbery.of(player) -> robbery?
	  Robbery.summary(gem) -> what a report shows of it
	  Robbery.report(robbery) -> { Where, Items = { { Id, Name, Tier,
	      Element, Size, Clarity, Cut, Back? } }, Empty }   (Back: dropped
	      back to you before it was over)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Frontier = require(ReplicatedStorage.Shared.Frontier)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local KaijuWilds = require(script.Parent.KaijuWilds)
local Remotes = require(script.Parent.Remotes)

local Robbery = {}

local robberies: { [Player]: any } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- What the report shows of a gem (all a client needs to draw it).
function Robbery.summary(gem)
	return {
		Id = tostring(gem.Id),
		Name = GemConfig.displayName(gem),
		Tier = gem.Tier,
		Element = gem.Element,
		Size = tonumber(gem.Size),
		Clarity = tonumber(gem.Clarity),
		Cut = tonumber(gem.Cut),
	}
end

function Robbery.report(robbery)
	local items = {}
	for _, item in robbery.Items do
		local entry = table.clone(item)
		entry.Back = robbery.Back[item.Id] or nil
		table.insert(items, entry)
	end
	return { Where = robbery.Where, Items = items, Empty = #items == 0 }
end

function Robbery.of(player: Player)
	return robberies[player]
end

-- It's over: the robbers are critters again, and you're home, told.
local function finish(robbery)
	local player = robbery.Player
	if robberies[player] ~= robbery then
		return
	end
	robberies[player] = nil
	robbery.Over = true
	KaijuWilds.unrob(robbery)
	if not player.Parent then
		return
	end
	player:SetAttribute("Robbed", nil)
	local report = Robbery.report(robbery)
	robbery.Done(player, report)
	Remotes.CombatFx:FireClient(player, "Robbed", report)
end

local function step()
	local now = os.clock()
	for player, robbery in robberies do
		if not player.Parent then
			robberies[player] = nil
			robbery.Over = true
			KaijuWilds.unrob(robbery)
		elseif Frontier.robOver(robbery, now) then
			finish(robbery)
		end
	end
end

local stepping = false
function Robbery.start(player: Player, opts)
	if robberies[player] then
		return robberies[player]
	end
	if not stepping then
		stepping = true
		local timer = 0
		RunService.Heartbeat:Connect(function(dt)
			timer += dt
			if timer >= 0.2 then
				timer = 0
				step()
			end
		end)
	end
	local rules = Frontier.Rob
	local robbery = {
		Player = player,
		Where = opts.Where or "Outpost",
		-- (No more than there's to take, and one at least: a robber that
		-- comes and finds nothing, and it's over.)
		Max = math.max(1, math.min(opts.Max or rules.Max, opts.Takeable or rules.Max)),
		Taken = 0,
		Items = {},
		Back = {},
		EndAt = os.clock() + rules.Hold,
		Away = opts.Away,
		Done = opts.Done,
	}
	-- (A robber's grab: one more of what's to take, till it's all gone.)
	robbery.Steal = function(who: Player)
		if robbery.Over or robbery.Empty or robbery.Taken >= robbery.Max then
			return nil
		end
		local gem = opts.Steal(who)
		robbery.LastAt = os.clock()
		if not gem then
			robbery.Empty = true
			return nil
		end
		robbery.Taken += 1
		table.insert(robbery.Items, Robbery.summary(gem))
		return gem
	end
	robbery.Recover = function(who: Player?, gem, at: Vector3)
		robbery.Back[tostring(gem.Id)] = true
		if opts.Recover then
			opts.Recover(who, gem, at)
		end
	end
	-- (Away with it: the report tells them, not a word for each.)
	robbery.Lost = function(_who: Player?, _gem) end
	robberies[player] = robbery
	local by = serverNow() + rules.Hold
	player:SetAttribute("Robbed", by)
	player:SetAttribute("SparDown", by + 1)
	local came = KaijuWilds.rob(player, robbery, rules.Near)
	local more = Frontier.robCrew(opts.Takeable or robbery.Max, came)
	if more > 0 and opts.Spawn then
		task.spawn(opts.Spawn, more, robbery)
	end
	return robbery
end

-- For tests.
Robbery._step, Robbery._robberies, Robbery._finish = step, robberies, finish

return Robbery
