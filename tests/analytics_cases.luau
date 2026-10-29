-- Analytics (Systems/Analytics): coins added up per reason and sent in
-- batches that match the real balance, custom events, and the Store funnel.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local economy, custom, funnel = {}, {}, {}
Analytics.send.economy = function(player, source, amount, balance, kind, sku)
	table.insert(economy, { Player = player, Source = source, Amount = amount, Balance = balance, Kind = kind, Sku = sku })
end
Analytics.send.custom = function(player, name, value, fields)
	table.insert(custom, { Player = player, Name = name, Value = value, Fields = fields })
end
Analytics.send.funnel = function(player, name, session, step, stepName)
	table.insert(funnel, { Player = player, Funnel = name, Session = session, Step = step, Name = stepName })
end
local balances = {}
Analytics.balanceOf = function(player)
	return balances[player]
end
local clock = 1000
Analytics.now = function()
	return clock
end
local function sent(player)
	local out = {}
	for _, e in economy do
		if e.Player == player then
			table.insert(out, string.format("%s%d:%s/%s=%d", if e.Source then "+" else "-", e.Amount, e.Sku, e.Kind, e.Balance))
		end
	end
	return table.concat(out, ",")
end
local function steps(player)
	local out = {}
	for _, e in funnel do
		if e.Player == player then
			table.insert(out, e.Step .. ":" .. e.Name)
		end
	end
	return table.concat(out, ",")
end
-- A change as PlayerData makes it: the balance first, then the tag.
local function change(player, delta, reason)
	balances[player] += delta
	Analytics.coins(player, delta, reason)
end

-- Every reason uses one of Roblox's transaction types.
local types = { IAP = true, Shop = true, Gameplay = true, ContextualPurchase = true, TimedReward = true, Onboarding = true }
for reason, kind in Analytics.Reasons do
	check(types[kind], reason .. " has an unknown transaction type: " .. tostring(kind))
end
check(Analytics.Reasons.Other, "No reason for untagged changes")

-- Coins added up per reason, sent once with the balance they end on.
local a = makePlayer(1, "A")
balances[a] = 100
Analytics.track(a, 100)
change(a, 50, "Duel")
change(a, 30, "Duel")
change(a, -40, "Store")
check(#economy == 0, "Coins were sent before a flush")
Analytics.flush(a)
check(sent(a) == "+80:Duel/Gameplay=140,-40:Store/Shop=140", "Batched coins wrong: " .. sent(a))
Analytics.flush(a)
check(#economy == 2, "A flush with nothing new sent again")

-- A change nobody tagged still counts, as Other, whenever it's noticed.
economy = {}
balances[a] += 20 -- (straight onto the profile)
change(a, 10, "Rift")
balances[a] += 5
Analytics.flush(a)
check(sent(a) == "+25:Other/Gameplay=175,+10:Rift/Gameplay=175", "Untagged coins wrong: " .. sent(a))

-- Spent and given back: nothing to send. Unknown reasons are Other.
economy = {}
change(a, -500, "Store")
change(a, 500, "Store")
change(a, 7, "Made up")
change(a, 3, nil)
Analytics.coins(a, 0, "Duel")
Analytics.coins(a, 0 / 0, "Duel")
Analytics.coins(a, "12" :: any, "Duel")
Analytics.flush(a)
check(sent(a) == "+10:Other/Gameplay=185", "Refund or bad input sent: " .. sent(a))

-- The sent totals always add up to the real balance.
economy = {}
local b = makePlayer(2, "B")
balances[b] = 0
Analytics.track(b, 0)
-- (A small seeded generator: the test runtime has no Random.)
local seed = 7
local function roll(lo, hi)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return lo + seed % (hi - lo + 1)
end
local reasons = { "Duel", "Store", "Market", "DailyLogin", "Tasks", "CoinPack" }
for _ = 1, 200 do
	local delta = roll(-50, 80)
	if roll(1, 10) <= 2 then
		balances[b] += delta -- untagged
	else
		change(b, delta, reasons[roll(1, #reasons)])
	end
	if roll(1, 10) == 1 then
		Analytics.flush(b)
	end
end
Analytics.flush(b)
local total = 0
for _, e in economy do
	total += if e.Source then e.Amount else -e.Amount
	check(e.Amount > 0, "A zero or negative amount was sent")
end
check(total == balances[b], string.format("Sent coins add up to %d, balance is %d", total, balances[b]))

-- Without a balance to read, the counted one carries on.
economy = {}
local c = makePlayer(3, "C")
Analytics.track(c, 10)
Analytics.coins(c, 5, "Rival")
Analytics.flush(c)
check(sent(c) == "+5:Rival/Gameplay=15", "No-balance path wrong: " .. sent(c))

-- Leaving sends what's left and forgets them.
economy = {}
change(a, 40, "Enemy")
Analytics.forget(a)
check(sent(a) == "+40:Enemy/Gameplay=225", "Leaving didn't flush: " .. sent(a))
Analytics.flush()
check(#economy == 1, "A player who left was sent again")

-- A send that fails warns once and never throws.
local works = Analytics.send.economy
Analytics.send.economy = function()
	error("rate limited")
end
local d = makePlayer(4, "D")
balances[d] = 0
Analytics.track(d, 0)
change(d, 5, "Duel")
Analytics.flush(d)
change(d, 5, "Duel")
Analytics.flush(d)
check(#warnings == 1 and string.find(warnings[1], "rate limited", 1, true), "Failing sends didn't warn once")
Analytics.send.economy = works

-- Custom events: the value and up to three fields, as strings.
Analytics.event(a, "KaijuCaught", 2, "Razorback", "Fire")
Analytics.event(a, "PlayerLevel", 12)
Analytics.event(a, "Hyperbeam", nil, 3, nil, "Boss")
check(custom[1].Name == "KaijuCaught" and custom[1].Value == 2, "Event name or value wrong")
check(custom[1].Fields.CustomField01 == "Razorback" and custom[1].Fields.CustomField02 == "Fire" and custom[1].Fields.CustomField03 == nil, "Event fields wrong")
check(custom[2].Fields == nil, "An event without fields sent empty ones")
check(custom[3].Value == 1 and custom[3].Fields.CustomField01 == "3" and custom[3].Fields.CustomField03 == "Boss", "Default value or gaps wrong")

-- The Store funnel: open, look, see a price, buy; one session a visit.
local remote = { OnServerEvent = signal() }
Analytics.start(remote, function(id)
	return if id == 77 then "Coins10k" else nil
end)
check(#loops == 1 and #closers == 1, "start didn't set up the flush loop and shutdown")
local e = makePlayer(5, "E")
remote.OnServerEvent:Fire(e, "StoreViewed")
check(steps(e) == "", "A view without the Store open counted")
remote.OnServerEvent:Fire(e, "StoreOpened")
remote.OnServerEvent:Fire(e, "StoreViewed")
remote.OnServerEvent:Fire(e, "StoreViewed")
remote.OnServerEvent:Fire(e, { "StoreViewed" })
remote.OnServerEvent:Fire(e, 4)
MarketplaceService.PromptProductPurchaseFinished:Fire(5, 77, false)
check(steps(e) == "1:Opened store,2:Viewed an item,3:Saw a price prompt", "Funnel steps wrong: " .. steps(e))
local prompt = custom[#custom]
check(prompt.Name == "PurchasePrompt" and prompt.Fields.CustomField01 == "Coins10k" and prompt.Fields.CustomField02 == "Closed", "Prompt event wrong")
MarketplaceService.PromptProductPurchaseFinished:Fire(5, 77, true)
Analytics.purchased(e, "Coins10k")
check(steps(e) == "1:Opened store,2:Viewed an item,3:Saw a price prompt,4:Bought", "Bought step wrong: " .. steps(e))
check(custom[#custom].Name == "Purchase" and custom[#custom].Fields.CustomField01 == "Coins10k", "Purchase event wrong")
local session = funnel[1].Session
for _, step in funnel do
	check(step.Funnel == "Store" and step.Session == session, "Steps of one visit split across sessions")
end
-- Closed and opened again straight away: the same visit.
clock += 10
remote.OnServerEvent:Fire(e, "StoreOpened")
check(#funnel == 4, "Reopening at once started a new visit")
-- Later: a new visit with its own session.
clock += 60
remote.OnServerEvent:Fire(e, "StoreOpened")
check(#funnel == 5 and funnel[5].Step == 1 and funnel[5].Session ~= session, "A later visit didn't get a new session")
-- A purchase long after the visit: its event, but no funnel step.
clock += Analytics.StoreVisit + 1
local before = #funnel
Analytics.purchased(e, "Coins10k")
check(#funnel == before and custom[#custom].Name == "Purchase", "A stale visit took a purchase")
-- Bought without a prompt seen here (another server's receipt): 3 and 4.
local f = makePlayer(6, "F")
remote.OnServerEvent:Fire(f, "StoreOpened")
Analytics.purchased(f, "Bundle")
check(steps(f) == "1:Opened store,3:Saw a price prompt,4:Bought", "Receipt-only purchase wrong: " .. steps(f))
-- A prompt from someone not in this server, or an unknown product: no error.
MarketplaceService.PromptProductPurchaseFinished:Fire(999, 77, true)
MarketplaceService.PromptProductPurchaseFinished:Fire(6, 12345, false)
check(custom[#custom].Fields.CustomField01 == "12345", "An unknown product's id wasn't kept")

-- Leaving the server and shutting down flush.
economy = {}
balances[f] = 50
Analytics.track(f, 50)
change(f, 25, "Dungeon")
Players.PlayerRemoving:Fire(f)
check(sent(f) == "+25:Dungeon/Gameplay=75", "Leaving the server didn't flush: " .. sent(f))
local g = makePlayer(7, "G")
balances[g] = 0
Analytics.track(g, 0)
change(g, 9, "Critters")
closers[1]()
check(sent(g) == "+9:Critters/Gameplay=9", "Shutdown didn't flush: " .. sent(g))

print(string.format("analytics: %d checks passed", checks))
