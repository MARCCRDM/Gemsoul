-- lune run tests/mobile_layout_cases.luau <repo>
-- The lobby's pieces on a phone never overlap (MobileLayout): the pick card,
-- your level and coins, the CHAT button (small screens with a keyboard), the
-- opened chat, the dock (PLAY and its tiles, TASKS among them), the
-- teammates' cards, a toast and your loot card under it at the top right,
-- and a mech's HOP OUT and drive stick, at every common phone size; the
-- dock's tiles all fit.
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
	{ 667, 375 - 36, 375 },
	{ 736, 414 - 36, 414 },
	{ 812, 375 - 58, 375 },
	{ 844, 390 - 58, 390 },
	{ 896, 414 - 58, 414 },
	{ 932, 430 - 58, 430 },
	{ 1024, 768 - 36, 768 },
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
	local loot, toast = MobileLayout.loot(screen), MobileLayout.toast(screen)
	for name, r in
		{
			card = card,
			wallet = wallet,
			dock = dock,
			party = party,
			chat = closed,
			open = open,
			loot = loot,
			toast = toast,
		}
	do
		check(inside(r), label .. ": the " .. name .. " runs off the screen")
	end
	-- A toast at the top right, and the loot card (with its row) under it,
	-- right-aligned with it: clear of everything round them, of Roblox's
	-- slim tab on the right edge (about 24 points), and of each other.
	local row = { X = loot.X, Y = if loot.RowsBelow then loot.Y + loot.H + MobileLayout.Loot.Gap else loot.Y, W = loot.W, H = MobileLayout.Loot.Row }
	check(toast.H <= 30 and toast.W <= 260, label .. ": a toast's place is too big")
	check(loot.Y >= toast.Y + toast.H, label .. ": the loot card isn't under the toast")
	check(loot.X + loot.W == toast.X + toast.W, label .. ": the loot card isn't right-aligned with the toast")
	check(loot.W < toast.W, label .. ": the loot card is wider than a toast")
	for name, r in { toast = toast, ["loot card"] = loot, ["loot row"] = row } do
		check(r.X + r.W <= screen.X - 24, label .. ": the " .. name .. " runs under Roblox's tab on the right")
		for other, o in
			{
				["pick card"] = card,
				coins = wallet,
				dock = dock,
				["teammates' cards"] = party,
			}
		do
			check(not MobileLayout.overlaps(r, o), label .. ": the " .. name .. " overlaps the " .. other)
		end
	end
	check(not MobileLayout.overlaps(loot, toast), label .. ": the loot card overlaps the toast")
	check(loot.H == MobileLayout.Loot.H, label .. ": the loot card isn't slim")
	check(loot.W == MobileLayout.Loot.W, label .. ": the loot card isn't its own width")
	check(MobileLayout.tasks == nil and MobileLayout.board == nil, "A TASKS button or board strip is back on a phone")
	-- (on the right edge, its row and all, well above the middle of the screen)
	check(row.Y + row.H <= screen.Y * 0.42, label .. ": the loot card reaches the middle of the screen")
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
	-- Your health under the coins, clear of everything else.
	local health = MobileLayout.health()
	check(inside(health), label .. ": the health bar runs off the screen")
	for name, r in { coins = wallet, ["pick card"] = card, dock = dock, ["CHAT button"] = closed, ["teammates' cards"] = party } do
		check(not MobileLayout.overlaps(health, r), label .. ": the health bar overlaps the " .. name)
	end
	for _, hunting in { false, true } do
		check(not MobileLayout.overlaps(health, MobileLayout.kaiju(screen, hunting)), label .. ": the kaiju card covers the health bar")
	end
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
	-- Your kaiju's card (one card, three by three: the team's three, the
	-- support with AUTO HEAL and CALL BACK, the HYPERBEAM along the bottom)
	-- and CATCH: right of your coins, or up at the top right while you hunt.
	-- On the screen, every cell big enough to tap and inside the card, clear
	-- of everything round it. (Out hunting you aren't mining: no loot card,
	-- and a toast may pass over it.)
	for _, hunting in { false, true } do
		local k = MobileLayout.kaiju(screen, hunting)
		local tame = { X = k.TameX, Y = k.TameY, W = k.TameW, H = k.TameH }
		local what = label .. (if hunting then " (hunting)" else "")
		check(inside(k) and inside(tame), what .. ": the kaiju card or CATCH runs off the screen")
		check(k.H >= 100, what .. ": the kaiju card is squashed: " .. k.H)
		local cells = MobileLayout.kaijuCells(k)
		local all = { cells.Fighters[1], cells.Fighters[2], cells.Fighters[3], cells.Support, cells.Auto, cells.Call, cells.Beam }
		for i, cell in all do
			check(cell.X >= 0 and cell.Y >= 0 and cell.X + cell.W <= k.W and cell.Y + cell.H <= k.H, what .. ": a cell spills out of the card: " .. i)
			check(cell.W >= 50 and cell.H >= 28, what .. ": a cell too small to tap: " .. i)
			for j = i + 1, #all do
				check(not MobileLayout.overlaps(cell, all[j]), what .. ": two of the card's cells overlap: " .. i .. ", " .. j)
			end
		end
		check(cells.Beam.W > cells.Auto.W * 2.5, what .. ": the HYPERBEAM isn't the width of the card")
		-- The kaiju two by two on the left (two rows of the same height), the
		-- buttons stacked on the right, the HYPERBEAM under them all.
		local f = cells.Fighters
		check(f[1].Y == f[2].Y and f[3].Y == cells.Support.Y and f[3].Y > f[1].Y, what .. ": the kaiju aren't in two rows")
		check(f[1].X == f[3].X and f[2].X == cells.Support.X and f[2].X > f[1].X, what .. ": the kaiju aren't in two columns")
		check(f[1].H == f[3].H, what .. ": the kaiju rows aren't the same height")
		check(cells.Auto.X > f[2].X and cells.Call.X == cells.Auto.X and cells.Auto.Y == f[1].Y and cells.Call.Y == f[3].Y,
			what .. ": AUTO HEAL and CALL BACK aren't stacked beside the kaiju")
		check(cells.Beam.Y > f[3].Y + f[3].H, what .. ": the HYPERBEAM isn't under the kaiju")
		local near = {
			["pick card"] = card,
			coins = wallet,
			health = health,
			dock = dock,
			["teammates' cards"] = party,
			jump = jump,
			["CHAT button"] = closed,
			thumbstick = MobileLayout.stick(screen),
		}
		if not hunting then
			near["loot card"], near.toast = loot, toast
		end
		for name, r in near do
			check(not MobileLayout.overlaps(k, r), what .. ": the kaiju card overlaps the " .. name)
		end
		check(not MobileLayout.overlaps(k, tame), what .. ": CATCH overlaps the kaiju card")
		for name, r in { dock = dock, jump = jump, coins = wallet, ["pick card"] = card, thumbstick = MobileLayout.stick(screen) } do
			check(not MobileLayout.overlaps(tame, r), what .. ": CATCH overlaps the " .. name)
		end
	end
	-- The kit switch (pick or combat kit): just left of PLAY and level with
	-- it, big enough to tap, on the screen, clear of PLAY, the tiles under
	-- it, Roblox's thumbstick, the fight's ring (ATTACK, the surges, GUARD,
	-- DODGE) and of everything there when you mine (the jump button, the top
	-- right, the cards on the left), with or without the CHAT button. With
	-- your kit out it stays put, and the fight's vitals (and the moves over
	-- them) keep right of it, clear of the ring.
	local ring = MobileLayout.ring(s[3])
	local buttons = {
		ATTACK = MobileLayout.onRing(screen, ring, ring.Attack, 0, 0),
		GUARD = MobileLayout.onRing(screen, ring, ring.Guard, ring.Outer, MobileLayout.Ring.Guard),
		DODGE = MobileLayout.onRing(screen, ring, ring.Dodge, ring.Outer, MobileLayout.Ring.Dodge),
	}
	for i, degrees in MobileLayout.Ring.Surges do
		buttons["surge " .. i] = MobileLayout.onRing(screen, ring, ring.Surge, ring.Inner, degrees)
	end
	for name, r in buttons do
		check(inside(r), label .. ": the fight's " .. name .. " runs off the screen")
	end
	local switch = MobileLayout.kitSwitch(screen)
	local playRect = { X = (screen.X - dock.PlayWidth) / 2, Y = dock.Y, W = dock.PlayWidth, H = dock.PlayHeight }
	local tiles = { X = dock.X, Y = dock.Y + dock.PlayHeight + dock.Gap, W = dock.W, H = dock.TileHeight }
	check(inside(switch), label .. ": the kit switch runs off the screen")
	check(switch.W >= 44 and switch.H >= 44, label .. ": the kit switch is too small to tap")
	check(switch.W >= MobileLayout.KitSwitch.Icon, label .. ": the kit switch has no room for its word (FIGHT, MINE)")
	check(
		switch.X + switch.W <= playRect.X and playRect.X - (switch.X + switch.W) <= 12,
		label .. ": the kit switch isn't just left of PLAY"
	)
	check(
		math.abs((switch.Y + switch.H / 2) - (playRect.Y + playRect.H / 2)) <= 1,
		label .. ": the kit switch isn't level with PLAY"
	)
	-- (The fight's vitals, the moves over them (three at most) and the ring,
	-- on the camera's viewport: the screen with Roblox's top bar.)
	local view = Vector2.new(s[1], s[3])
	local armed = MobileLayout.kitSwitch(screen, view)
	check(
		armed.X == switch.X and armed.Y == switch.Y and armed.H == switch.H and armed.W <= switch.W,
		label .. ": the kit switch moves with the kit out"
	)
	check(armed.W >= 44, label .. ": the kit switch is too small to tap with the kit out")
	local vitals = MobileLayout.vitals(view, ring, armed)
	local Mv, mvGap = math.floor(46 * ring.K), math.floor(12 * ring.K)
	local moves = 3 * Mv + 2 * mvGap
	local guard = MobileLayout.onRing(view, ring, ring.Guard, ring.Outer, MobileLayout.Ring.Guard)
	check(vitals.X >= armed.X + armed.W + 8 - 1e-6, label .. ": the fight's vitals run under the kit switch")
	check(vitals.Centre - moves / 2 >= armed.X + armed.W, label .. ": the fight's moves run under the kit switch")
	check(vitals.X + vitals.W <= guard.X, label .. ": the fight's vitals run under GUARD")
	check(
		vitals.W >= MobileLayout.KitSwitch.Room,
		label .. ": the fight's vitals are too narrow (their words overlap) with the kit switch up"
	)
	-- (Without it, as they were.)
	local plain = MobileLayout.vitals(view, ring)
	check(
		plain.W >= 240 and plain.X >= s[1] * 0.2 - 1e-6,
		label .. ": the fight's vitals changed without the kit switch"
	)
	for _, chat in { false, true } do
		local what = label .. (if chat then " (with CHAT)" else "")
		local k = MobileLayout.kaiju(screen, false)
		local others = {
			jump = jump,
			PLAY = playRect,
			tiles = tiles,
			["thumbstick"] = MobileLayout.stick(screen),
			toast = toast,
			["loot card"] = loot,
			["teammates' cards"] = party,
			["pick card"] = card,
			coins = wallet,
			health = MobileLayout.health(),
			["kaiju card"] = k,
			CATCH = { X = k.TameX, Y = k.TameY, W = k.TameW, H = k.TameH },
		}
		if chat then
			others.CHAT = closed
		end
		for name, r in buttons do
			others[name] = r
		end
		for name, r in others do
			check(not MobileLayout.overlaps(switch, r), what .. ": the kit switch overlaps the " .. name)
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
		.. " mobile layout checks (pick card, coins, chat, dock with TASKS, teammates, kaiju, loot card, clear top right, the kit switch by PLAY and clear of the fight's ring and vitals, the kaiju card three by three (its kaiju two by two) with its HYPERBEAM, at 7 screen sizes)"
)
