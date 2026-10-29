--[[
	What players do, for the Creator Dashboard (Analytics: Economy, Custom
	events, Funnels). Everything here is fire-and-forget: a send that fails
	warns once and never throws into the game.

	Coins (Economy). Every change carries a reason, and the reasons are
	added up per player and sent once a minute (and when they leave), so a
	busy server stays inside Roblox's event budget. A change nobody tagged
	is still counted, as "Other", so the dashboard's totals match the real
	balances.
	  Analytics.coins(player, delta, reason)   a change already made (+ in, - out)
	  Analytics.track(player, balance)         start counting (profile loaded)
	  Analytics.flush(player?)                 send what's added up now

	Events (Custom), one per thing that happened:
	  Analytics.event(player, name, value?, a?, b?, c?)   a, b, c: the custom fields

	The Store funnel (Funnels, a recurring one: one session per visit):
	  1 Opened store   2 Viewed an item   3 Saw a price prompt   4 Bought
	The client reports 1 and 2 (Remotes.Funnel "StoreOpened" / "StoreViewed");
	the server sees 3 (MarketplaceService.PromptProductPurchaseFinished) and
	4 (a granted receipt: Analytics.purchased).
]]
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Analytics = {}

Analytics.Currency = "Coins"
Analytics.FlushEvery = 60 -- seconds between economy sends
Analytics.StoreVisit = 15 * 60 -- a Store session lasts this long after it opens

-- Each reason's transaction type (an Enum.AnalyticsEconomyTransactionType name).
Analytics.Reasons = {
	-- Earned in play
	Duel = "Gameplay", -- a 1v1 / 2v2 result
	QueueBonus = "Gameplay", -- stepping in to fill a queue
	Rival = "Gameplay", -- beating the sparring rival
	Raid = "Gameplay", -- a party raid wave
	Streak = "Gameplay", -- an Arena win streak milestone
	Dungeon = "Gameplay",
	Rift = "Gameplay",
	Enemy = "Gameplay",
	Critters = "Gameplay", -- critters your kaiju beat
	Secret = "Gameplay", -- an Outpost easter egg
	MineWall = "Gameplay", -- coins dug out of the Moon Mine wall
	KaijuBet = "Gameplay", -- a kaiju battle stake, paid or won
	GemSale = "Shop", -- gems sold for coins
	-- Timed and first-time rewards
	DailyLogin = "TimedReward",
	DailyChallenge = "TimedReward",
	Tasks = "Onboarding",
	Tutorial = "Onboarding",
	Code = "Onboarding", -- a redeemed code
	Season = "Gameplay", -- a Season Path level's reward
	-- Spent
	Store = "Shop", -- something bought with coins in the Store (and its refunds)
	MineEntry = "Shop", -- a Moon Mine wall past the free ones
	RiftRestore = "ContextualPurchase",
	-- Robux
	CoinPack = "IAP",
	Bundle = "IAP", -- coins in a Robux bundle (or for a cosmetic you already had)
	-- Between players (the Market board: buys, sales, refunds, commissions)
	Market = "Shop",
	-- Old saves' materials, turned into coins
	Legacy = "Gameplay",
	-- Untagged changes
	Other = "Gameplay",
}

-- (For tests: the clock a Store visit goes by.)
Analytics.now = function(): number
	return os.clock()
end

-- The game's own balance, read when a change wasn't tagged (PlayerData sets it).
Analytics.balanceOf = function(_player: Player): number?
	return nil
end

-- What's added up but not sent, and the balance everything sent so far adds up to.
local pending: { [Player]: { [string]: number } } = {}
local known: { [Player]: number } = {}
local store: { [Player]: { Id: string, At: number, Step: number } } = {}
local warned: { [string]: boolean } = {}

local function warnOnce(what: string, problem: any)
	if not warned[what] then
		warned[what] = true
		warn("[Analytics] " .. what .. ": " .. tostring(problem))
	end
end

-- The three custom field slots, by their enum names.
local function fields(a: any?, b: any?, c: any?): { [string]: any }?
	if a == nil and b == nil and c == nil then
		return nil
	end
	local keys = { "CustomField01", "CustomField02", "CustomField03" }
	local ok, names = pcall(function()
		return {
			Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
			Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
			Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
		}
	end)
	if ok then
		keys = names
	end
	local out = {}
	for i, v in { a, b, c } do
		if v ~= nil then
			out[keys[i]] = tostring(v)
		end
	end
	return out
end

-- The calls to Roblox (tests swap them out).
Analytics.send = {
	economy = function(player: Player, source: boolean, amount: number, balance: number, kind: string, sku: string)
		AnalyticsService:LogEconomyEvent(
			player,
			if source then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			Analytics.Currency,
			amount,
			balance,
			kind,
			sku
		)
	end,
	custom = function(player: Player, name: string, value: number, custom: { [string]: any }?)
		AnalyticsService:LogCustomEvent(player, name, value, custom)
	end,
	funnel = function(player: Player, funnel: string, session: string, step: number, name: string)
		AnalyticsService:LogFunnelStepEvent(player, funnel, session, step, name)
	end,
}

local function call(what: string, fn, ...)
	local ok, problem = pcall(fn, ...)
	if not ok then
		warnOnce(what, problem)
	end
	return ok
end

local function add(player: Player, reason: string, delta: number)
	if delta == 0 then
		return
	end
	local bucket = pending[player]
	if not bucket then
		bucket = {}
		pending[player] = bucket
	end
	bucket[reason] = (bucket[reason] or 0) + delta
end

function Analytics.track(player: Player, balance: number)
	known[player] = balance
end

-- A change of `delta` coins already made, for `reason`. The balance after
-- it is read from the game; anything between the last counted balance and
-- this change is counted as "Other".
function Analytics.coins(player: Player, delta: number, reason: string?)
	if type(delta) ~= "number" or delta ~= delta or delta == 0 then
		return
	end
	local balance = Analytics.balanceOf(player)
	local before = known[player]
	if balance and before then
		add(player, "Other", balance - delta - before)
	end
	add(player, if reason and Analytics.Reasons[reason] then reason else "Other", delta)
	if balance then
		known[player] = balance
	elseif before then
		known[player] = before + delta
	end
end

-- Sends what's added up (one event per reason and direction).
function Analytics.flush(player: Player?)
	local list = if player then { player } else {}
	if not player then
		for p in pending do
			table.insert(list, p)
		end
		for p in known do
			if not pending[p] then
				table.insert(list, p)
			end
		end
	end
	for _, p in list do
		-- Changes since the last tagged one, nobody's tagged: Other.
		local balance = Analytics.balanceOf(p)
		if balance and known[p] then
			add(p, "Other", balance - known[p])
			known[p] = balance
		end
		local bucket = pending[p]
		pending[p] = nil
		if bucket then
			local ending = balance or known[p] or 0
			local reasons = {}
			for reason in bucket do
				table.insert(reasons, reason)
			end
			table.sort(reasons)
			for _, reason in reasons do
				local amount = bucket[reason]
				if amount ~= 0 then
					call("economy", Analytics.send.economy, p, amount > 0, math.abs(amount), ending, Analytics.Reasons[reason] or "Gameplay", reason)
				end
			end
		end
	end
end

function Analytics.event(player: Player, name: string, value: number?, a: any?, b: any?, c: any?)
	call("event " .. name, Analytics.send.custom, player, name, value or 1, fields(a, b, c))
end

-- The Store funnel ------------------------------------------------------------------------------
Analytics.StoreSteps = { "Opened store", "Viewed an item", "Saw a price prompt", "Bought" }

local function storeStep(player: Player, step: number)
	local visit = store[player]
	if not visit or Analytics.now() - visit.At > Analytics.StoreVisit or visit.Step >= step then
		return false
	end
	visit.Step = step
	call("store funnel", Analytics.send.funnel, player, "Store", visit.Id, step, Analytics.StoreSteps[step])
	return true
end

-- A step the client reports from the Store window.
function Analytics.fromClient(player: Player, name: any)
	if name == "StoreOpened" then
		local visit = store[player]
		-- (Closed and opened again straight away: the same visit.)
		if visit and Analytics.now() - visit.At < 30 then
			return
		end
		store[player] = { Id = HttpService:GenerateGUID(false), At = Analytics.now(), Step = 0 }
		storeStep(player, 1)
	elseif name == "StoreViewed" then
		storeStep(player, 2)
	end
end

-- A price prompt closed (bought or not), from anywhere in the game.
function Analytics.prompted(player: Player, key: string?, bought: boolean)
	Analytics.event(player, "PurchasePrompt", 1, key or "Unknown", if bought then "Bought" else "Closed")
	storeStep(player, 3)
end

-- A Robux purchase granted.
function Analytics.purchased(player: Player, key: string)
	Analytics.event(player, "Purchase", 1, key)
	storeStep(player, 3)
	storeStep(player, 4)
end

function Analytics.forget(player: Player)
	Analytics.flush(player)
	pending[player] = nil
	known[player] = nil
	store[player] = nil
end

function Analytics.start(remote: RemoteEvent?, productKey: ((number) -> string?)?)
	if remote then
		remote.OnServerEvent:Connect(Analytics.fromClient)
	end
	local ok, MarketplaceService = pcall(game.GetService, game, "MarketplaceService")
	if ok and MarketplaceService then
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, bought)
			local player = Players:GetPlayerByUserId(userId)
			if player then
				Analytics.prompted(player, productKey and productKey(productId) or tostring(productId), bought == true)
			end
		end)
	end
	Players.PlayerRemoving:Connect(Analytics.forget)
	task.spawn(function()
		while true do
			task.wait(Analytics.FlushEvery)
			Analytics.flush()
		end
	end)
	game:BindToClose(function()
		Analytics.flush()
	end)
end

return Analytics
