-- lune run tests/mobile_layout_cases.luau <repo>
-- The lobby's pieces on a phone never overlap (MobileLayout): the pick card,
-- the CHAT button, the opened chat, the dock (PLAY and its tiles) and the
-- teammates' cards, at every common phone size; the dock's tiles all fit.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector2 = roblox.Vector2
local ROOT = process.args[1] or "."
local MobileLayout = luau.load(fs.readFile(ROOT .. "/src/client/Modules/MobileLayout.luau"), {
	debugName = "MobileLayout",
	environment = setmetatable({ Vector2 = Vector2 }, { __index = _G }),
})()
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
-- Landscape phones (points), less Roblox's top bar (about 58 on a notched
-- phone, 36 otherwise), and a small tablet.
local SCREENS = {
	{ 667, 375 - 36 },
	{ 736, 414 - 36 },
	{ 812, 375 - 58 },
	{ 844, 390 - 58 },
	{ 896, 414 - 58 },
	{ 932, 430 - 58 },
	{ 1024, 768 - 36 },
}
local TILES = 5
for _, s in SCREENS do
	local screen = Vector2.new(s[1], s[2])
	local label = s[1] .. "x" .. s[2]
	local card, dock, party = MobileLayout.card(), MobileLayout.dock(screen, TILES), MobileLayout.party(screen)
	local closed, open = MobileLayout.chat(screen, false), MobileLayout.chat(screen, true)
	local function inside(r)
		return r.X >= 0 and r.Y >= 0 and r.X + r.W <= screen.X and r.Y + r.H <= screen.Y
	end
	for name, r in { card = card, dock = dock, party = party, chat = closed, open = open } do
		check(inside(r), label .. ": the " .. name .. " runs off the screen")
	end
	check(not MobileLayout.overlaps(card, closed), label .. ": the CHAT button overlaps the pick card")
	check(not MobileLayout.overlaps(closed, dock), label .. ": the CHAT button overlaps the dock")
	check(not MobileLayout.overlaps(open, dock), label .. ": the open chat covers PLAY or the tiles")
	check(not MobileLayout.overlaps(open, party), label .. ": the open chat covers the teammates' cards")
	check(not MobileLayout.overlaps(card, party), label .. ": the pick card overlaps the teammates' cards")
	check(not MobileLayout.overlaps(dock, party), label .. ": the dock overlaps the teammates' cards")
	-- Roblox's jump button: about 70 points square, its centre ~95 from the right, ~90 from the bottom.
	local jump = { X = screen.X - 130, Y = screen.Y - 125, W = 70, H = 70 }
	check(not MobileLayout.overlaps(dock, jump), label .. ": the dock runs under the jump button")
	-- Every tile fits the dock, with room for its name.
	check(dock.TileWidth * TILES + dock.Gap * (TILES - 1) <= dock.W, label .. ": the tiles spill off the dock")
	check(dock.TileWidth >= 44, label .. ": tiles too narrow to tap")
	check(open.H >= 120 and open.W >= 240, label .. ": the open chat is too small to read")
end
print("PASS: " .. checks .. " mobile layout checks (pick card, chat, dock, teammates, at 7 screen sizes)")
