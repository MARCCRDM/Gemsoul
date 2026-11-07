-- The Outpost's LED screens: the font, the art (tools/led_art.py's) and each
-- board's animated scenes and cartoons (Shared.Led).
-- Run by tests/run_led.py (needs lune).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local mods = {}
local function shared(name)
	if mods[name] then
		return mods[name]
	end
	local env = setmetatable({ script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) } }, { __index = _G })
	env.require = function(m)
		return shared(m)
	end
	mods[name] = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { debugName = name, environment = env })()
	return mods[name]
end
local LedFont, LedArt, Led = shared("LedFont"), shared("LedArt"), shared("Led")

-- The font: every letter and digit, five rows of three, and nothing it can't draw kept.
for _, ch in string.split("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .:-#!/>", "") do
	local rows = LedFont.glyph(ch)
	check(rows and #rows == LedFont.Height, "No glyph for " .. ch)
	for _, row in rows do
		check(#row == LedFont.Width and not string.find(row, "[^#.]"), "A bad row in " .. ch)
	end
end
check(LedFont.glyph("a") == LedFont.glyph("A"), "Small letters aren't drawn as capitals")
check(Led.fit("Dev_volver★", 30) == "DEV_VOLVER", "Fitting kept a glyph it can't draw")
check(Led.fit("Gemcutter_09", 5) == "GEMCU", "Fitting didn't cut to length")

-- The art: each picture's rows as wide as it says, every LED a palette colour or off.
local pictures = 0
for name, art in LedArt do
	pictures += 1
	check(art.W > 0 and art.H > 0 and #art.Rows == art.H and art.W <= Led.W and art.H <= Led.H, name .. " doesn't fit a screen")
	local lit = 0
	for _, row in art.Rows do
		check(#row == art.W, name .. " has a row of the wrong width")
		for i = 1, #row do
			local c = string.sub(row, i, i)
			if c ~= "." then
				local index = string.find("0123456789abcde", c, 1, true)
				check(index and art.Palette[index], name .. " lights a colour it hasn't got")
				lit += 1
			end
		end
	end
	check(lit > art.W * art.H * 0.25, name .. " is mostly dark")
end
check(pictures >= 4, "Too few pictures for the screens")

-- Text lands where it's put, inside the screen, in its colour.
local b = Led.new()
local w = Led.text(b, 0, 0, "HI", 0xFF0000)
check(w == 7 and Led.get(b, 0, 0) == 0xFF0000 and Led.get(b, 3, 0) == nil and Led.get(b, 4, 0) == 0xFF0000, "Text isn't drawn where it should be")
Led.text(b, Led.W - 2, Led.H - 2, "WWW", 1) -- (off the edge: clipped, no error)
check(Led.get(b, Led.W - 2, Led.H - 1) ~= nil, "Text at the edge wasn't drawn")

-- The scenes: every board's, every frame of them on the screen, never blank
-- for long, and moving (they're animations, not pages).
local info = Led.catalog(function(name)
	return ({ Razorback = "Ranged", Bulwark = "Warrior", Skyjelly = "Warden" })[name]
end, function(id)
	return ({
		Drago = { Name = "Bombardiro Drago", Element = "Fire", Weakness = "Frost", Threat = 1 },
		SahurTrio = { Name = "Tung Tung Tung Sahur", Element = "Fire", Weakness = "Frost", Threat = 3 },
	})[id]
end, { "SahurTrio", "Drago" })
check(#info.Kaiju == 3 and info.Kaiju[1].Art and LedArt[info.Kaiju[1].Art], "The kaiju shown aren't the ones with pictures and data")
check(#info.Bosses == 2 and info.Bosses[1].Name == "Tung Tung Tung Sahur", "The bosses aren't in the order given")
local function lit(frame)
	local n = 0
	for i in frame.P do
		check(i >= 1 and i <= Led.W * Led.H, "A frame lights an LED off the screen")
		n += 1
	end
	return n
end
for _, board in Led.Boards do
	local scenes = Led.scenes(board, info)
	check(#scenes >= 3, board .. " has too few scenes")
	local moving = 0
	for k, scene in scenes do
		check(scene.Duration >= 3 and scene.Duration <= (if scene.Toon then 16.5 else 15), board .. " scene " .. k .. " is too short or long")
		local last = nil
		for step = 0, 9 do
			local frame = scene.Draw(scene.Duration * step / 10)
			check(lit(frame) > 15, board .. " scene " .. k .. " goes blank")
			local key = table.concat((function()
				local t = {}
				for i = 1, Led.W * Led.H, 7 do
					t[#t + 1] = tostring(frame.P[i] or 0)
				end
				return t
			end)(), ",")
			if last and key ~= last then
				moving += 1
			end
			last = key
		end
	end
	check(moving >= #scenes, board .. "'s scenes hardly move")
end
-- The boards that show them: a scene for each kaiju and each boss.
check(#Led.scenes("Bounties", info) == 3 + #info.Bosses, "The Bounty Board doesn't show each boss")
check(#Led.scenes("Kaiju", info) == 4 + #info.Kaiju, "The kaiju board doesn't show each kaiju")
-- SAGA TOONS: every episode has its cast's art, plays on a screen, and every
-- screen has one; each ends on a tip (TIP lit, top left of the words).
local shown = {}
for _, board in Led.Boards do
	local has = false
	for _, scene in Led.scenes(board, info) do
		if scene.Toon then
			has = true
			shown[scene.Toon] = true
		end
	end
	check(has or board == "Rift" or board == "Kaiju" or board == "Outpost", board .. " shows no cartoon")
end
for _, name in Led.Toons do
	local ep = Led.toon(name)
	check(ep and ep.Toon == name, "No art for the cartoon " .. name)
	check(shown[name], "The cartoon " .. name .. " isn't on a screen")
	local last = ep.Draw(ep.Duration - 0.05)
	check(Led.get(last, 26, 1) == Led.Colors.Gold, name .. " doesn't end on a tip")
end
check(Led.toon("Nope") == nil, "A cartoon that isn't there")
-- Every element named, in its own colour.
for _, element in { "Fire", "Frost", "Shock", "Poison" } do
	check(Led.ElementNames[element] and Led.ElementColors[element], "No name or colour for " .. element)
end
-- Nothing to show yet: still a scene, no error.
for _, board in Led.Boards do
	check(#Led.scenes(board, nil) >= 1, board .. " broke with no data")
end

-- The basics (a new miner's video, Client.BasicsScreen): each line's
-- scene on screen all the way through, the topic named big on its first
-- phrase and something else showing once the next one starts; a phone's
-- and a keyboard's.
for _, touch in { false, true } do
	for _, name in Led.BasicsOrder do
		local cues = { 0.15, 2, 4, 6 }
		local sc = Led.basics(name, cues, 8, touch)
		check(sc.Duration == 8, name .. "'s scene isn't the line's length")
		local first = sc.Draw(1)
		local second = sc.Draw(3)
		local same = 0
		for i = 1, Led.W * Led.H do
			if first.P[i] == second.P[i] then
				same += 1
			end
		end
		check(same < Led.W * Led.H, name .. " shows the same thing on its next phrase")
		for step = 0, 79 do
			check(lit(sc.Draw(step / 10)) > 15, name .. " goes blank")
		end
	end
end

print("PASS: " .. checks .. " LED screen checks (the font, the art, text where it's put, every board's scenes on screen and moving, the kaiju and bosses shown, the cartoons on the screens, the basics' video)")
