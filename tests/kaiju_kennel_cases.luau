-- lune run tests/kaiju_kennel_cases.luau <repo>
-- The Kaiju Kennel (Shared.KaijuKennel, Client.KennelLife, Server
-- OutpostWorld): today's residents and the Kaiju of the Day come from the
-- rarest batch, change with the day, and never overlap; each resident
-- walks only in its own wedge of the pen, inside the fence, smoothly (no
-- jumps from one moment to the next), and stops to sniff, look, rest,
-- sleep or roar; every client works out the same. The hologram is off,
-- the pen is built on its stage, Wren keeps it, and CreatureAnimation
-- walks its kaiju.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
-- (Lune has no Random: a small seeded one with the same methods)
local Random = {
	new = function(seed)
		local state = (seed or 1) % 2147483647
		local r = {}
		function r:NextNumber(a, b)
			state = (state * 16807) % 2147483647
			local x = state / 2147483647
			return if a then a + (b - a) * x else x
		end
		function r:NextInteger(a, b)
			return a + math.floor(self:NextNumber() * (b - a + 1))
		end
		return r
	end,
}
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local loaded = {}
local env
local function shared(name)
	if loaded[name] == nil then
		local source = fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau")
		loaded[name] = luau.load(source, { debugName = name, environment = env })()
	end
	return loaded[name]
end
env = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Enum = roblox.Enum,
	UDim2 = roblox.UDim2,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	game = { GetService = function() return setmetatable({}, { __index = function() return {} end }) end },
	script = { Parent = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}) },
	require = function(name)
		return shared(name)
	end,
}, { __index = _G })

local Kaiju = shared("Kaiju")
local Kennel = shared("KaijuKennel")
local Vector3 = roblox.Vector3

-- Who's there -------------------------------------------------------------------------------
local specials = {}
for day = 20000, 20060 do
	local special = Kennel.special(day)
	check(Kaiju.batch(special.Species) == 1, "The Kaiju of the Day isn't of the rarest batch: " .. special.Species)
	check(table.find(Kaiju.Elements, special.Element) ~= nil, "The Kaiju of the Day has no element")
	specials[special.Species] = (specials[special.Species] or 0) + 1
	local residents = Kennel.residents(day)
	check(#residents == Kennel.Count, "Not a full pen on day " .. day)
	local seen = {}
	for _, r in residents do
		check(Kaiju.batch(r.Species) == 1, r.Species .. " in the pen isn't of the rarest batch")
		check(r.Species ~= special.Species, "The Kaiju of the Day is in the pen as well")
		check(not seen[r.Species], r.Species .. " is in the pen twice")
		seen[r.Species] = true
		check(table.find(Kaiju.Elements, r.Element) ~= nil, r.Species .. " has no element")
	end
end
local kinds = 0
for _, n in specials do
	kinds += 1
	check(n <= 3, "One kind is the Kaiju of the Day too often in two months")
end
check(kinds >= 25, "The Kaiju of the Day doesn't go through the batch")
local a, b = Kennel.residents(20000), Kennel.residents(20001)
local same = 0
for _, r in a do
	for _, s in b do
		if r.Species == s.Species then
			same += 1
		end
	end
end
check(same < Kennel.Count, "The pen doesn't change from one day to the next")
check(Kennel.day(86400 * 20000 + 5) == 20000 and Kennel.day(86400 * 20001 - 1) == 20000, "Days don't turn at midnight")

-- Where they go -----------------------------------------------------------------------------
local pen = Kennel.Pen
local count = Kennel.Count
local moods, walked = {}, 0
for i = 1, count do
	local wedge = math.pi * 2 / count
	local last = nil
	for step = 0, 3000 do
		local now = 1.7e9 + step * 0.1
		local s = Kennel.state(i, count, now)
		local off = (s.Position - pen.Middle) * Vector3.new(1, 0, 1)
		check(off.Magnitude <= pen.Outer + 0.01, "A kaiju walked out past the pen's edge")
		check(off.Magnitude < pen.Fence - 2, "A kaiju is up against the fence")
		check(math.abs(s.Position.Y - pen.Middle.Y) < 1e-6, "A kaiju isn't on the pen's floor")
		local angle = math.atan2(off.Z, off.X) % (math.pi * 2)
		local lo, hi = (i - 1) * wedge, i * wedge
		check(angle >= lo - 0.02 and angle <= hi + 0.02, "A kaiju left its own wedge of the pen")
		if s.Speed > 0 then
			walked += 1
			check(s.Speed >= Kennel.Speed - 1e-6, "Walking slower than a kaiju walks")
		else
			moods[s.Mood or "Stand"] = true
		end
		if last then
			local moved = (s.Position - last.Position).Magnitude
			check(moved <= math.max(last.Speed, s.Speed, Kennel.Speed) * 0.1 + 0.05, "A kaiju jumped from one place to another")
			local turn = math.abs((s.Yaw - last.Yaw + math.pi) % (math.pi * 2) - math.pi)
			check(turn <= math.pi * 0.1 / Kennel.Turn + 0.05 or moved < 0.01 and s.Speed == 0, "A kaiju spun round at once")
		end
		last = s
		-- (Every client works it out the same.)
		local again = Kennel.state(i, count, now)
		check(again.Position == s.Position and again.Yaw == s.Yaw and again.Mood == s.Mood, "Two clients would see it differently")
	end
end
check(walked > 2000, "The kennel's kaiju hardly walk")
for _, mood in { "Sniff", "Look", "Rest", "Sleep", "Roar" } do
	check(moods[mood], "A kennel kaiju never does " .. mood)
end
-- No two residents ever closer than a kaiju's width.
for step = 0, 2000 do
	local now = 1.8e9 + step * 0.25
	local spots = {}
	for i = 1, count do
		spots[i] = Kennel.state(i, count, now).Position
	end
	for i = 1, count do
		for j = i + 1, count do
			check((spots[i] - spots[j]).Magnitude > 1.5, "Two kennel kaiju walked into each other")
		end
	end
end

-- The world and the client ------------------------------------------------------------------
local world = fs.readFile(ROOT .. "/src/server/World/OutpostWorld.luau")
check(world:find('"KennelBed"', 1, true) ~= nil, "The kennel's bed isn't on the stage")
check(world:find('"ProjectorLens"', 1, true) == nil, "The hologram's lens is still on the stage")
-- (The pen itself is each player's own: the Shelter's server parts are at their budget.)
check(world:find("KennelSign", 1, true) == nil and world:find("KennelRock", 1, true) == nil, "The pen is built by the server again")
check(world:find('Id = "KaijuKeeper"', 1, true) ~= nil, "No keeper by the kennel")
local vendors = fs.readFile(ROOT .. "/src/shared/Vendors.luau")
check(vendors:find("Vendors.KaijuKeeper", 1, true) ~= nil and vendors:find('Action = "KennelToday"', 1, true) ~= nil, "Wren can't say who's in the pen")
local dialogue = fs.readFile(ROOT .. "/src/client/Dialogue.client.luau")
check(dialogue:find("function actions.KennelToday", 1, true) ~= nil and dialogue:find("function actions.KaijuMarket", 1, true) ~= nil, "Wren's options do nothing")
local life = fs.readFile(ROOT .. "/src/client/Modules/ShelterLife.luau")
check(life:find("ShelterLife.Hologram = false", 1, true) ~= nil, "The hologram is still on")
local anim = fs.readFile(ROOT .. "/src/client/CreatureAnimation.client.luau")
check(anim:find('"KaijuKennel"', 1, true) ~= nil and anim:find('"PacedSpeed"', 1, true) ~= nil, "CreatureAnimation doesn't walk the kennel's kaiju")
local scene = fs.readFile(ROOT .. "/src/client/Modules/OutpostScene.luau")
check(scene:find("KennelLife.mount(shelterFrame)", 1, true) ~= nil and scene:find("KennelLife.step(dt)", 1, true) ~= nil, "The kennel's kaiju aren't drawn")
local client = fs.readFile(ROOT .. "/src/client/Modules/KennelLife.luau")
check(client:find("CanQuery", 1, true) ~= nil and client:find("root.Anchored = true", 1, true) ~= nil, "Kennel kaiju can be clicked or fall")
check(client:find('"KENNEL"', 1, true) ~= nil and client:find("buildPen", 1, true) ~= nil, "The client doesn't build the pen and its KENNEL arch")
check(client:find('"DAILY KAIJU SALE"', 1, true) ~= nil and client:find("Kennel.special(day)", 1, true) ~= nil, "No Daily Kaiju Sale display")
check(client:find("KennelSale.open()", 1, true) ~= nil and client:find("ProximityPrompt", 1, true) ~= nil, "The display's prompt doesn't open the sale")
check(client:find("pen.Parent = parent", 1, true) ~= nil, "The pen isn't shown and hidden with its kaiju")
-- (the fence is solid to you: built on your screen, for your own character)
check(client:find("Vector3.new(0.45, 3.2, 0.45), STEEL, Enum.Material.Metal, true)", 1, true) ~= nil, "The fence posts aren't solid")
local sale = fs.readFile(ROOT .. "/src/client/Modules/KennelSale.luau")
check(sale:find("PromptProductPurchase", 1, true) ~= nil and sale:find("Gilt.frame", 1, true) ~= nil, "The sale window doesn't buy, or isn't in the gilt look")
check(sale:find("Kaiju.dailyBought(profile, day)", 1, true) ~= nil and sale:find("profile[rare.Once]", 1, true) ~= nil, "The sale window offers what's yours already")
check(dialogue:find("function actions.KennelSale", 1, true) ~= nil and vendors:find('Action = "KennelSale"', 1, true) ~= nil, "Wren doesn't open the sale")

-- The sales' rules (Shared.Kaiju.Sale) --------------------------------------------------------
local rareKinds = Kaiju.rareKinds()
check(#rareKinds >= 20, "Too few kinds for a rare roll")
for _, id in rareKinds do
	check(Kaiju.batch(id) == 1 and not Kaiju.isSupport(id), "A rare roll can deal " .. id)
end
local rng = Random.new(9)
local dealt = {}
for _ = 1, 600 do
	local pick = Kaiju.rarePick(rng)
	check(table.find(rareKinds, pick.Species) ~= nil and table.find(Kaiju.Elements, pick.Element) ~= nil, "A rare pick out of the batch")
	dealt[pick.Species] = true
end
local dealtKinds = 0
for _ in dealt do
	dealtKinds += 1
end
check(dealtKinds == #rareKinds, "A rare roll never deals some kinds")
check(Kaiju.Sale.Daily.TraitFloor > Kaiju.Sale.Rare.TraitFloor and Kaiju.Sale.Rare.TraitFloor > 0, "The sales' trait floors")
check(Kaiju.dailyBought({ KaijuDailyDay = 5 }, 5) and not Kaiju.dailyBought({ KaijuDailyDay = 4 }, 5) and not Kaiju.dailyBought({}, 5), "dailyBought")
-- Rare rolls owed: only after the starter roll, and counted as boss rolls (they play there).
local fresh = { Kaiju = { List = {}, Next = 1 }, KaijuRareRolls = 1 }
check(Kaiju.rareRollsOwed(fresh) == 0, "A rare roll before the starter roll")
local done = { Kaiju = { List = {}, Next = 1 }, KaijuRolled = Kaiju.RollVersion, KaijuRareRolls = 1, KaijuBossRolls = 1 }
check(Kaiju.rollsOwed(done) == 0, "(the starter roll should be taken)")
check(Kaiju.rareRollsOwed(done) == 1 and Kaiju.bossRollsOwed(done) == 2, "A rare roll isn't owed, or isn't played on the roll screen")
-- The starter support: Skyjelly, any element.
check(Kaiju.StarterSupport.Species == "Skyjelly" and Kaiju.StarterSupport.Element == nil, "The starter support's element is fixed")
local elements = {}
for _ = 1, 200 do
	elements[Kaiju.supportElement(rng)] = true
end
for _, element in Kaiju.Elements do
	check(elements[element], "The starter support never comes " .. element)
end
-- Every support kind goes in the support slot, and swaps with another.
local roster = { List = {}, Next = 1 }
local supports = {}
for _, id in Kaiju.Order do
	if Kaiju.isSupport(id) then
		local soul = Kaiju.rollSoul(rng, "Frost", { Id = "s" .. id, Time = 1, Species = id })
		table.insert(supports, Kaiju.add(roster, id, soul, 1, true))
	end
end
check(#supports >= 2, "Only one support kind")
for _, record in supports do
	check(Kaiju.setSupport(roster, record.Id) and Kaiju.supportId(roster) == record.Id, record.Species .. " can't go in the support slot")
end
-- The Store's two (200 R$ each, the day counted as KaijuKennel counts it).
local Store = shared("Store")
check(Store.robuxPrice("KaijuDaily") == 200 and Store.robuxPrice("KaijuRareRoll") == 200, "The Kennel's sales aren't R$ 200")
check(Store.RobuxProducts.KaijuDaily ~= nil and Store.RobuxProducts.KaijuRareRoll ~= nil, "No product slots for the Kennel's sales")
check(Store.contents("KaijuDaily").KaijuSale == "Daily" and Store.contents("KaijuRareRoll").KaijuSale == "Rare", "What the sales give")
local now = 86400 * 20000 + 3600
check(Store.canBuy("KaijuDaily", {}, now), "Today's kaiju can't be bought")
check(not Store.canBuy("KaijuDaily", { KaijuDailyDay = Kennel.day(now) }, now), "Today's kaiju bought twice")
check(Store.canBuy("KaijuDaily", { KaijuDailyDay = Kennel.day(now) - 1 }, now), "Yesterday's purchase blocks today's")
check(Store.canBuy("KaijuRareRoll", {}, now) and not Store.canBuy("KaijuRareRoll", { KaijuRareRollBought = true }, now), "The Starter Rare Roll isn't once only")
check(Kaiju.Sale.Daily.Product == "KaijuDaily" and Kaiju.Sale.Rare.Product == "KaijuRareRoll", "The sales' product keys")
local storeServer = fs.readFile(ROOT .. "/src/server/Systems/StoreServer.luau")
check(storeServer:find("StoreServer.kaijuSale(player, reward.KaijuSale)", 1, true) ~= nil, "A Kennel receipt isn't granted")
check(fs.readFile(ROOT .. "/src/server/Main.server.luau"):find("StoreServer.kaijuSale = KaijuServer.saleGrant", 1, true) ~= nil, "The Kennel's grant isn't wired")
-- The Store sells them too: a Kaiju tab, and the Featured front page leads
-- with the two sales above the bundles. The lobby's button says STORE.
check(Store.Tabs[1] == "Featured" and table.find(Store.Tabs, "Kaiju") ~= nil, "The Store has no Featured front page or Kaiju tab")
check(table.find(Store.Tabs, "Bundles") == nil, "The bundles have a tab of their own as well as the front page")
local shopUi = fs.readFile(ROOT .. "/src/client/Modules/ShopUI.luau")
check(shopUi:find("KaijuDeals.strip(list, 10)", 1, true) ~= nil, "Featured doesn't lead with the kaiju deals")
check(shopUi:find("Featured = drawBundles", 1, true) ~= nil, "The bundles aren't on the front page")
check(
	shopUi:find("KaijuDeals.daily(list", 1, true) ~= nil
		and shopUi:find("KaijuDeals.rare(row", 1, true) ~= nil
		and shopUi:find("KaijuDeals.premium(row", 1, true) ~= nil,
	"The Kaiju page misses a sale"
)
-- (the starter roll first, then the premium trio, on both pages)
check(
	shopUi:find("KaijuDeals.rare(row, cw, cardH, 1)\n\t\tKaijuDeals.premium(row, cw, cardH, 2)", 1, true) ~= nil,
	"The Starter Rare Roll doesn't come before the premium trio"
)
check(shopUi:find("revive(list", 1, true) == nil, "The team revive is still on the Store's page")
check(shopUi:find("which == \"Bundles\"", 1, true) ~= nil, "Old links to the Bundles tab go nowhere")
check(fs.readFile(ROOT .. "/src/client/Modules/LobbyUI.luau"):find('tile("STORE"', 1, true) ~= nil, "The lobby's Store button isn't STORE")

print(string.format("PASS: %d Kaiju Kennel checks (residents and the Kaiju of the Day by day, wedges, no collisions, smooth walks, moods, the pen, Wren, the Daily Kaiju Sale and the Starter Rare Roll, in the Kennel and the Store, any support in the slot)", checks))
