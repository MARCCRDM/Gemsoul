-- lune run tests/kaiju_roll_cases.luau <repo>
-- The kaiju starter roll's screen (Modules/KaijuRoll), driven frame by frame
-- on a clock of its own: made like the intro's gem roll, a card for each
-- kaiju with a reel in its window. Kaiju of every kind and element run down
-- past it (never the same one twice in sight, each on a rarity's glow),
-- named under it as they go, and it stops on yours: the first, then the next,
-- then the last. Each lands, drops onto its spot and lets its E move out,
-- and the card fills in (name, stats, what it's like, its moves). Then
-- START, which claims them (on its own too, after a while). A click lands
-- them all at once. A phone's cards are shorter.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local Instance, Vector2, Vector3, CFrame = roblox.Instance, roblox.Vector2, roblox.Vector3, roblox.CFrame
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- A clock of our own: os.clock, task.delay and each frame.
local now = 0
local delayed = {}
local fakeTask = {
	delay = function(seconds, fn, ...)
		table.insert(delayed, { At = now + (seconds or 0), Fn = fn, Args = { ... } })
	end,
	spawn = function(fn, ...)
		fn(...)
	end,
	defer = function(fn, ...)
		fn(...)
	end,
}
local frames = {}
local renderStepped = {
	Connect = function(_, fn)
		table.insert(frames, fn)
		return {
			Disconnect = function()
				local at = table.find(frames, fn)
				if at then
					table.remove(frames, at)
				end
			end,
		}
	end,
}
local tweens = {}
local function lerp(a, b, p)
	if type(a) == "number" then
		return a + (b - a) * p
	elseif typeof(a) == "UDim2" then
		return roblox.UDim2.new(
			lerp(a.X.Scale, b.X.Scale, p),
			lerp(a.X.Offset, b.X.Offset, p),
			lerp(a.Y.Scale, b.Y.Scale, p),
			lerp(a.Y.Offset, b.Y.Offset, p)
		)
	elseif typeof(a) == "Color3" then
		return a:Lerp(b, p)
	end
	return if p >= 1 then b else a
end
local function step(seconds)
	local stop = now + seconds
	while now < stop - 1e-9 do
		now = math.min(stop, now + 1 / 30)
		for tween in table.clone(tweens) do
			local p = math.clamp((now - tween.Start) / math.max(tween.Time, 1e-6), 0, 1)
			for key, goal in tween.Goal do
				tween.Object[key] = lerp(tween.From[key], goal, p)
			end
			if p >= 1 then
				tweens[tween] = nil
			end
		end
		while true do
			local due
			for i, entry in delayed do
				if entry.At <= now and (not due or entry.At < delayed[due].At) then
					due = i
				end
			end
			if not due then
				break
			end
			local entry = table.remove(delayed, due)
			entry.Fn(table.unpack(entry.Args))
		end
		for _, fn in table.clone(frames) do
			fn(1 / 30)
		end
	end
end

-- Roblox's events and the model methods Lune's instances lack.
local handlers, nextId = {}, 0
local function idOf(instance)
	local id = instance:GetAttribute("_test")
	if not id then
		nextId += 1
		id = nextId
		instance:SetAttribute("_test", id)
	end
	return id
end
local function signalFor(instance, name)
	local key = idOf(instance) .. ":" .. name
	handlers[key] = handlers[key] or {}
	local list = handlers[key]
	return {
		Connect = function(_, fn)
			table.insert(list, fn)
			return { Disconnect = function() end }
		end,
	}
end
local function fire(instance, name, ...)
	for _, fn in handlers[idOf(instance) .. ":" .. name] or {} do
		fn(...)
	end
end
roblox.implementProperty("GuiButton", "Activated", function(instance)
	return signalFor(instance, "Activated")
end)
roblox.implementProperty("Instance", "Destroying", function(instance)
	return signalFor(instance, "Destroying")
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(instance, prop)
	return signalFor(instance, "Changed:" .. prop)
end)
local SCREEN = Vector2.new(1366, 710)
-- (Lune hands back a new value for the same instance each time, so a model's
-- pivot is kept by its id.)
local pivots = {}
roblox.implementMethod("Model", "GetPivot", function(model)
	return pivots[idOf(model)] or CFrame.new()
end)
roblox.implementMethod("Model", "PivotTo", function(model, cf)
	pivots[idOf(model)] = cf
end)
roblox.implementMethod("Model", "GetBoundingBox", function(model)
	local low, high
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local at, half = part.CFrame.Position, part.Size / 2
			local a, b = at - half, at + half
			low = if low then Vector3.new(math.min(low.X, a.X), math.min(low.Y, a.Y), math.min(low.Z, a.Z)) else a
			high = if high then Vector3.new(math.max(high.X, b.X), math.max(high.Y, b.Y), math.max(high.Z, b.Z)) else b
		end
	end
	low, high = low or Vector3.zero, high or Vector3.one
	return CFrame.new((low + high) / 2), high - low
end)

-- The game's shared rules, as they are.
local loaded = {}
local sharedEnv
local function shared(name)
	if loaded[name] == nil then
		loaded[name] = luau.load(
			fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"),
			{ debugName = name, environment = sharedEnv }
		)()
	end
	return loaded[name]
end
local names = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
local function newRandom(seed)
	local state = seed or 1
	local r = {}
	local function next01()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	function r:NextNumber(a, b)
		a, b = a or 0, b or 1
		return a + (b - a) * next01()
	end
	function r:NextInteger(a, b)
		return math.min(b, a + math.floor(next01() * (b - a + 1)))
	end
	return r
end
local Random = { new = newRandom }
sharedEnv = setmetatable({
	Instance = Instance,
	Color3 = roblox.Color3,
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = CFrame,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Random = Random,
	script = { Parent = names },
	require = function(name)
		return shared(name)
	end,
}, { __index = _G })
local Kaiju = shared("Kaiju")
local GemConfig = shared("GemConfig")

-- The client modules round the screen, as stand-ins.
local root = Instance.new("Folder")
local toasts, sounds, requests = {}, {}, {}
local IronUi = {
	new = function(class, props, parent)
		local object = Instance.new(class)
		for key, value in props or {} do
			object[key] = value
		end
		object.Parent = parent
		return object
	end,
}
local UiKit = {
	gui = function(name)
		local gui = Instance.new("ScreenGui")
		gui.Name = name
		gui.Parent = root
		return gui
	end,
	round = function() end,
	list = function(parent, gap)
		local layout = Instance.new("UIListLayout")
		layout.Padding = roblox.UDim.new(0, gap or 0)
		layout.Parent = parent
		return layout
	end,
	toast = function(message)
		table.insert(toasts, message)
	end,
}
local LotterySound = {
	play = function(name)
		table.insert(sounds, name)
	end,
	reveal = function(rank)
		table.insert(sounds, "Reveal" .. rank)
	end,
}
local claimOk = true
local rolls = {}
local GemClient = {
	request = function(action)
		table.insert(requests, action)
		if action == "KaijuRoll" then
			return { Ok = true, Rolls = rolls }
		elseif action == "KaijuRollClaim" then
			return if claimOk then { Ok = true } else { Ok = false, Message = "Try again." }
		end
		return { Ok = false }
	end,
}
local stubs = {
	IronUi = IronUi,
	UiKit = UiKit,
	LotterySound = LotterySound,
	GemClient = GemClient,
	SurgeIcons = {
		apply = function()
			return false
		end,
		dim = function() end,
	},
	ElementCardFX = {
		create = function()
			return {}
		end,
		update = function() end,
	},
}
local camera = { ViewportSize = Vector2.new(1366, 768) }
local services = {
	ReplicatedStorage = { Shared = names },
	RunService = { RenderStepped = renderStepped },
	TweenService = {
		Create = function(_, object, info, goal)
			local tween = { Object = object, Goal = goal, Time = info.Time, From = {} }
			function tween:Play()
				tween.Start = now
				for key in goal do
					tween.From[key] = object[key]
				end
				tweens[tween] = true
			end
			function tween:Cancel()
				tweens[tween] = nil
			end
			return tween
		end,
	},
}
local function loadRoll()
	local env = setmetatable({
		game = {
			GetService = function(_, name)
				return services[name]
			end,
		},
		workspace = { CurrentCamera = camera },
		script = { Parent = names },
		require = function(name)
			return stubs[name] or shared(name)
		end,
		task = fakeTask,
		os = {
			clock = function()
				return now
			end,
			time = os.time,
		},
		Instance = Instance,
		Color3 = roblox.Color3,
		Vector3 = Vector3,
		Vector2 = Vector2,
		CFrame = CFrame,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		TweenInfo = {
			new = function(time)
				return { Time = time or 1 }
			end,
		},
		Random = Random,
		-- (Lune's instances have no AbsoluteSize: the screen's, read here.)
		__absSize = function()
			return SCREEN
		end,
	}, { __index = _G })
	local source = fs.readFile(ROOT .. "/src/client/Modules/KaijuRoll.luau")
	source = string.gsub(source, "([%w_]+)%.AbsoluteSize", "__absSize(%1)")
	return luau.load(source, { debugName = "KaijuRoll", environment = env })()
end

-- Three kaiju, as the server rolls them.
local rng = newRandom(11)
local function soulFor(species, element, tier)
	local soul = Kaiju.rollSoul(rng, element, { Id = "soul-" .. species, Species = species })
	soul.Tier = tier
	return soul
end
rolls = {
	{ Species = "Razorback", Element = "Fire", Soul = soulFor("Razorback", "Fire", "Rare") },
	{ Species = "Carapace", Element = "Frost", Soul = soulFor("Carapace", "Frost", "Common") },
	{ Species = "Bulwark", Element = "Shock", Soul = soulFor("Bulwark", "Shock", "Legendary") },
}

local function find(parent, name)
	local found = {}
	for _, d in parent:GetDescendants() do
		if d.Name == name then
			table.insert(found, d)
		end
	end
	return found
end
-- The words on show under `parent` (not those hidden).
local function texts(parent)
	local found = {}
	for _, d in parent:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
			local shown, at = true, d
			while at and at ~= parent do
				if at:IsA("GuiObject") and not at.Visible then
					shown = false
				end
				at = at.Parent
			end
			if shown then
				table.insert(found, d.Text)
			end
		end
	end
	return table.concat(found, "\n")
end
local function cardsOf(gui)
	local cards = find(gui, "KaijuRollCard")
	table.sort(cards, function(a, b)
		return a.Position.X.Offset < b.Position.X.Offset
	end)
	return cards
end
local function landed(card)
	return #find(card, "MoveBadge") == 1 and find(card, "MoveBadge")[1].Visible
end
local function views(card)
	local list = {}
	for _, d in card:GetDescendants() do
		if d:IsA("ViewportFrame") and d.Name == "KaijuView" then
			table.insert(list, d)
		end
	end
	return list
end

-- The roll, left to play out -------------------------------------------------------------------------
local KaijuRoll = loadRoll()
local after = 0
KaijuRoll.play(function()
	after += 1
end)
local gui = root:FindFirstChild("KaijuRoll")
check(gui ~= nil and KaijuRoll.showing(), "The roll didn't come up")
local cards = cardsOf(gui)
check(#cards == 3, "Not a card for each kaiju: " .. #cards)
-- Each card: a reel in a window, cell 2 its kaiju, the cells round it never
-- the same kaiju twice in a row, each on a rarity's glow.
for i, card in cards do
	local window = find(card, "ReelWindow")[1]
	check(window and window.ClipsDescendants, "Card " .. i .. " has no window")
	local cells = find(card, "ReelCell")
	check(#cells >= 15, "Card " .. i .. "'s reel is short: " .. #cells)
	check(#find(card, "RarityGlow") >= #cells * 2, "Card " .. i .. "'s reel has kaiju without a rarity's glow")
	-- (Built once, before the spin: its own and three others.)
	check(#views(card) == 0 or #views(card) <= 3, "Card " .. i .. " shows more than the three kaiju in sight")
end
check(texts(gui):find("ROLLING YOUR KAIJU", 1, true), "Not the gem roll's headline")
check(not texts(gui):upper():find("MEET", 1, true), "Still says meet your team")

-- Spinning: the one passing is named under the window, in its rarity's
-- colour, and the three in sight are three different kaiju.
step(0.9)
check(not landed(cards[1]) and not landed(cards[2]) and not landed(cards[3]), "A kaiju landed before its reel stopped")
local seenNames = {}
for i, card in cards do
	local inSight = views(card)
	check(#inSight >= 1 and #inSight <= 3, "Card " .. i .. " shows " .. #inSight .. " kaiju in its window")
	local kinds = {}
	for _, view in inSight do
		local key = view:GetAttribute("Kaiju")
		check(key and not kinds[key], "Card " .. i .. " shows the same kaiju twice in sight")
		kinds[key] = true
	end
	local caption = texts(card)
	for tier, label in GemConfig.TierLabels do
		if caption:find(string.upper(label), 1, true) then
			seenNames[i] = tier
		end
	end
	check(seenNames[i] ~= nil, "Card " .. i .. " doesn't name the rarity going past")
end

-- They stop in turn: the first, then the next, then the last.
local landedAt, liftAtOpen = {}, nil
for _ = 1, 150 do
	step(1 / 30)
	for i, card in cards do
		if not landedAt[i] and landed(card) then
			landedAt[i] = now
		end
	end
	if not liftAtOpen and #views(cards[3]) == 1 and not texts(cards[3]):find("ROLLING", 1, true) then
		local model = views(cards[3])[1]:FindFirstChildOfClass("Model")
		liftAtOpen = model and model:GetPivot().Position.Y
	end
end
check(landedAt[1] and landedAt[2] and landedAt[3], "Not every kaiju landed")
check(landedAt[1] < landedAt[2] and landedAt[2] < landedAt[3], "They didn't stop in turn")
for i, card in cards do
	local entry = rolls[i]
	local shown = views(card)
	check(#shown == 1, "Card " .. i .. " still shows the reel's other kaiju")
	check(
		shown[1]:GetAttribute("Kaiju") == entry.Species .. "/" .. entry.Element,
		"Card " .. i .. " stopped on the wrong kaiju"
	)
	local words = texts(card)
	check(words:find(string.upper(Kaiju.title(entry)), 1, true), "Card " .. i .. " doesn't name its kaiju")
	check(
		words:find(string.upper(GemConfig.TierLabels[entry.Soul.Tier] or entry.Soul.Tier), 1, true)
			and words:find("GEMSOUL", 1, true),
		"Card " .. i .. " doesn't say its Gemsoul's rarity"
	)
	check(words:find(" HP ", 1, true) and words:find(" DMG ", 1, true), "Card " .. i .. " has no stats")
	check(words:find(Kaiju.species(entry.Species).Blurb, 1, true), "Card " .. i .. " doesn't say what it's like")
	local moves = find(card, "Moves")[1]
	check(moves and moves.Visible, "Card " .. i .. " has no moves")
	local mText = texts(moves)
	check(
		mText:find("READY", 1, true)
			and mText:find("LV " .. Kaiju.MoveLevels.Q, 1, true)
			and mText:find("LV " .. Kaiju.MoveLevels.R, 1, true),
		"Card " .. i .. "'s moves don't say E now, Q and R later"
	)
end
check(table.find(sounds, "Reveal5") ~= nil, "The Legendary landed without its fanfare")

-- Yours drops onto its spot as it lands, then stands there.
local mine = views(cards[3])[1]:FindFirstChildOfClass("Model")
step(2)
local settled = mine:GetPivot().Position.Y
check(liftAtOpen and liftAtOpen > settled + 0.3, "The kaiju didn't drop onto its spot")
step(0.5)
check(math.abs(mine:GetPivot().Position.Y - settled) < 0.2, "The kaiju didn't settle on its spot")

-- START, and only START.
local go = find(gui, "Start")[1]
check(go and go.Visible and go.Text == "START   ›", "The button doesn't just say START: " .. tostring(go and go.Text))
check(texts(gui):find("YOUR KAIJU ARE LOCKED IN", 1, true), "The headline didn't lock in")
check(not texts(gui):upper():find("MEET", 1, true), "Still says meet your team")
-- A failed claim says so and keeps the screen.
claimOk = false
fire(go, "Activated")
check(gui.Parent ~= nil and #toasts == 1 and go.Text == "START   ›", "A failed claim wasn't put right")
claimOk = true
fire(go, "Activated")
check(after == 1 and not KaijuRoll.showing(), "START didn't claim them and go on")
check(requests[#requests] == "KaijuRollClaim", "START didn't claim the roll")

-- A click mid-spin lands them all at once ------------------------------------------------------------
table.clear(frames)
table.clear(delayed)
table.clear(tweens)
local KaijuRoll2 = loadRoll()
KaijuRoll2.play(function() end)
gui = root:FindFirstChild("KaijuRoll")
cards = cardsOf(gui)
step(0.7)
fire(gui:FindFirstChild("Shade"), "Activated")
step(0.05)
for i, card in cards do
	check(landed(card) and #views(card) == 1, "Card " .. i .. " didn't land at the click")
end
check(find(gui, "Start")[1].Visible, "No START after the click")
local deskHeight = cards[1].Size.Y.Offset
-- Left alone, it starts on its own.
local claimsBefore = #requests
step(21)
check(#requests == claimsBefore + 1 and not KaijuRoll2.showing(), "It didn't start on its own")

-- A phone: shorter cards, without what each kaiju is like ----------------------------------------------
table.clear(frames)
table.clear(delayed)
table.clear(tweens)
camera.ViewportSize = Vector2.new(844, 390)
local KaijuRoll3 = loadRoll()
KaijuRoll3.play(function() end)
gui = root:FindFirstChild("KaijuRoll")
cards = cardsOf(gui)
step(6)
check(cards[1].Size.Y.Offset < deskHeight, "A phone's cards aren't shorter")
check(find(cards[1], "ReelWindow")[1].Size.Y.Offset < 176, "A phone's window isn't shorter")
check(
	not texts(cards[1]):find(Kaiju.species(rolls[1].Species).Blurb, 1, true),
	"A phone's card still says what it's like"
)
check(landed(cards[1]) and landed(cards[3]), "A phone's kaiju didn't land")

print(
	string.format(
		"PASS: %d kaiju roll checks (the gem roll's reel, in turn, the cards, START, a click, a phone)",
		checks
	)
)
