-- lune run tests/mobile_layout_cases.luau <repo>
-- The lobby's pieces on a phone never overlap (MobileLayout): the pick card,
-- your level and coins, the CHAT button (small screens with a keyboard), the
-- opened chat, the dock (PLAY and its tiles, TASKS among them), the
-- teammates' cards, your loot card at the top middle, and a mech's HOP OUT
-- and drive stick, at every common phone size; the dock's tiles all fit.
-- Nothing else is up at the top right (no TASKS button, no board strip).
-- And who has the top middle (claimTop).
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
local TILES = 7 -- INVENTORY, TASKS, MARKET, STORE, RANKS, SOCIAL, INVITE
for _, s in SCREENS do
	local screen = Vector2.new(s[1], s[2])
	local label = s[1] .. "x" .. s[2]
	local card, dock, party = MobileLayout.card(), MobileLayout.dock(screen, TILES), MobileLayout.party(screen)
	local closed, open = MobileLayout.chat(screen, false), MobileLayout.chat(screen, true)
	local wallet = MobileLayout.wallet()
	local function inside(r)
		return r.X >= 0 and r.Y >= 0 and r.X + r.W <= screen.X and r.Y + r.H <= screen.Y
	end
	local loot = MobileLayout.loot(screen)
	for name, r in
		{
			card = card,
			wallet = wallet,
			dock = dock,
			party = party,
			chat = closed,
			open = open,
			loot = loot,
		}
	do
		check(inside(r), label .. ": the " .. name .. " runs off the screen")
	end
	-- The loot card at the top middle: clear of everything round it, never
	-- too narrow to read, and well above the middle of the screen.
	for name, r in
		{
			["pick card"] = card,
			coins = wallet,
			dock = dock,
			["teammates' cards"] = party,
		}
	do
		check(not MobileLayout.overlaps(loot, r), label .. ": the loot card overlaps the " .. name)
	end
	check(loot.W >= MobileLayout.Loot.MinW, label .. ": the loot card is too narrow")
	check(loot.H == MobileLayout.Loot.H, label .. ": the loot card isn't slim")
	check(loot.W == MobileLayout.Loot.W, label .. ": the loot card isn't full width with the corner clear")
	check(MobileLayout.tasks == nil and MobileLayout.board == nil, "A TASKS button or board strip is back on a phone")
	check(loot.Y + loot.H <= screen.Y * 0.3, label .. ": the loot card reaches the middle of the screen")
	check(
		dock.PlayWidth <= dock.W and dock.PlayHeight + dock.Gap + dock.TileHeight <= dock.H,
		label .. ": PLAY doesn't fit the dock"
	)
	-- In a mech: HOP OUT in PLAY's place (PLAY hides), above the tiles.
	local drive = MobileLayout.Drive
	local hop = { X = (screen.X - drive.W) / 2, Y = screen.Y - drive.Bottom - drive.H, W = drive.W, H = drive.H }
	check(
		math.abs(hop.Y - dock.Y) < 1e-6 and drive.H == dock.PlayHeight and drive.W <= dock.W,
		label .. ": HOP OUT isn't in PLAY's place"
	)
	check(not MobileLayout.overlaps(hop, party), label .. ": HOP OUT overlaps the teammates' cards")
	-- And on a touch screen, its drive stick at the bottom left (where
	-- Roblox's thumbstick sits), clear of everything else on the HUD.
	local stick = MobileLayout.stick(screen)
	check(stick.X >= 0 and stick.Y + stick.H <= screen.Y, label .. ": the drive stick is off the screen")
	check(stick.Y >= screen.Y * 0.4, label .. ": the drive stick isn't down at the bottom")
	for name, other in { dock = dock, ["HOP OUT"] = hop, coins = wallet, ["pick card"] = card, ["teammates' cards"] = party } do
		check(not MobileLayout.overlaps(stick, other), label .. ": the drive stick overlaps the " .. name)
	end
	check(MobileLayout.Stick.Knob < MobileLayout.Stick.Size, label .. ": the stick's knob is bigger than the stick")
	check(not MobileLayout.overlaps(card, wallet), label .. ": the coins overlap the pick card")
	check(not MobileLayout.overlaps(wallet, closed), label .. ": the CHAT button overlaps the coins")
	check(not MobileLayout.overlaps(wallet, dock), label .. ": the coins overlap the dock")
	check(not MobileLayout.overlaps(wallet, party), label .. ": the coins overlap the teammates' cards")
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
	check(dock.TileWidth >= 44 and dock.TileHeight >= 44, label .. ": tiles too small to tap")
	check(open.H >= 120 and open.W >= 240, label .. ": the open chat is too small to read")
	-- Your kaiju's card and TAME, with and without the CHAT button above.
	for _, chat in { false, true } do
		local k = MobileLayout.kaiju(chat)
		local tame = { X = k.TameX, Y = k.Y, W = k.TameW, H = k.H }
		local what = label .. (if chat then " (with CHAT)" else "")
		check(inside(k) and inside(tame), what .. ": the kaiju card runs off the screen")
		for name, r in
			{
				["pick card"] = card,
				coins = wallet,
				dock = dock,
				["teammates' cards"] = party,
				jump = jump,
				["loot card"] = MobileLayout.loot(screen),
			}
		do
			check(not MobileLayout.overlaps(k, r), what .. ": the kaiju card overlaps the " .. name)
			check(not MobileLayout.overlaps(tame, r), what .. ": TAME overlaps the " .. name)
		end
		if chat then
			check(not MobileLayout.overlaps(k, closed), what .. ": the kaiju card overlaps the CHAT button")
		end
	end
end
-- The top middle: claimed and given back, each owner on its own; a listener
-- hears each change (and not a repeat).
local heard = 0
MobileLayout.onTop(function()
	heard += 1
end)
check(not MobileLayout.topClaimed(), "The top middle starts claimed")
MobileLayout.claimTop("MinerLoot", true)
MobileLayout.claimTop("MinerLoot", true)
check(MobileLayout.topClaimed() and heard == 1, "A claim wasn't heard once")
check(not MobileLayout.topClaimed("MinerLoot"), "An owner's own claim counted against it")
MobileLayout.claimTop("Other", true)
MobileLayout.claimTop("MinerLoot", false)
check(
	MobileLayout.topClaimed() and MobileLayout.topClaimed("MinerLoot"),
	"One owner giving it back freed another's claim"
)
MobileLayout.claimTop("Other", false)
check(not MobileLayout.topClaimed() and heard == 4, "The top middle wasn't given back")
print(
	"PASS: "
		.. checks
		.. " mobile layout checks (pick card, coins, chat, dock with TASKS, teammates, kaiju, loot card, clear top right, at 7 screen sizes)"
)
