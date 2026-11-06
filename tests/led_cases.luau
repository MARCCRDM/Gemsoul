-- The Outpost's LED screens: the font, the art (tools/led_art.py's) and each
-- board's pages (Shared.Led), and the boards' data (Server.Boards).
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

-- Every page fits: nothing lit outside the screen, and each page says something.
local function lit(page)
	local n = 0
	for i in page.P do
		check(i >= 1 and i <= Led.W * Led.H, "A page lights an LED off the screen")
		n += 1
	end
	return n
end
local rows = {}
for i = 1, 14 do
	table.insert(rows, { Name = "Miner" .. i, Value = 2000 - i * 37 })
end
local samples = {
	Ranked = { Rows = rows },
	Miners = { Turn = 3, Rows = rows },
	Hunters = { Rows = {} },
	Live = { Rings = { { Name = "IntroRing", Fighters = { "Rookie" } }, { Name = "DuelRingWest", Fighters = {} }, { Name = "DuelRingEast", Fighters = {} }, { Name = "GrandArena", Fighters = { "Ana", "Ben" } } } },
}
for _, board in Led.Boards do
	local pages = Led.pages(board, samples[board])
	check(#pages >= 2, board .. " has nothing to show one at a time")
	for _, page in pages do
		check(lit(page) > 20, board .. " has a blank page")
	end
end
-- A ladder: a title, then four to a page, twelve at most.
check(#Led.pages("Ranked", samples.Ranked) == 1 + 3, "The ranked ladder isn't four to a page, twelve at most")
check(#Led.pages("Hunters", samples.Hunters) == 2, "An empty ladder doesn't say how to get on it")
-- Live: the rings' page, then one for each fight on.
check(#Led.pages("Live", samples.Live) == 3, "Live doesn't show each fight on")
check(#Led.pages("Live", { Rings = { {Name="IntroRing",Fighters={}}, {Name="DuelRingWest",Fighters={}}, {Name="DuelRingEast",Fighters={}}, {Name="DuelRingNorthWest",Fighters={}}, {Name="DuelRingNorthEast",Fighters={}}, {Name="GrandArena",Fighters={}} } }) == 3, "Six rings aren't four to a page")
check(#Led.pages("Live", { Rings = {} }) == 2, "Live with nothing on doesn't invite a duel")
-- No data yet (the server hasn't sent any): still pages, no error.
for _, board in Led.Boards do
	check(#Led.pages(board, nil) >= 1, board .. " broke with no data")
end

print("PASS: " .. checks .. " LED screen checks (the font, the art, text where it's put, every board's pages, no data yet)")
