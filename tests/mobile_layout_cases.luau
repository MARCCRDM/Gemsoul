-- lune run tests/mobile_layout_cases.luau <repo>
-- The lobby's pieces on a phone never overlap (MobileLayout): your kaiju's
-- card (one row, top left) and the pick card under it, your level and coins,
-- your health and your teammates' rows under it (as many as are up), the
-- CHAT button (small screens with a keyboard), the opened chat, the dock
-- (PLAY and its tiles, TASKS among them), a toast and your loot card, CATCH,
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
	local function inside(r)
		return r.X >= 0 and r.Y >= 0 and r.X + r.W <= screen.X and r.Y + r.H <= screen.Y
	end
	local card, dock, wallet = MobileLayout.card(), MobileLayout.dock(screen, TILES), MobileLayout.wallet(screen)
	local closed, open = MobileLayout.chat(screen, false), MobileLayout.chat(screen, true)
	local hp = MobileLayout.health(screen)
	local jump = MobileLayout.jump(screen)
	local stick = MobileLayout.stick(screen)
	local drive = MobileLayout.Drive
	local hop = { X = (screen.X - drive.W) / 2, Y = screen.Y - drive.Bottom - drive.H, W = drive.W, H = drive.H }
	-- Your kaiju's card: one row at the top left (the pick card's old
	-- place), the pick card under it only while you mine.
	local k = MobileLayout.kaiju(screen, false)
	local kWhole = { X = k.X, Y = k.Y, W = k.W, H = k.H + k.Notch / 2 }
	check(k.X == 12 and k.Y == 12, label .. ": your kaiju's card isn't at the top left")
	check(#k.Rows == 1, label .. ": your kaiju's card isn't one row")
	check(card.X == k.X and card.Y >= kWhole.Y + kWhole.H, label .. ": the pick card isn't under your kaiju's card")
	check(not MobileLayout.overlaps(kWhole, wallet) and not MobileLayout.overlaps(kWhole, hp), label .. ": your kaiju's card reaches your coins or health")
	for _, rows in { 0, 1, MobileLayout.Party.Max } do
		-- (As many teammates' rows as are up: PartyUI says, each the size of
		-- your health bar, stacked under it.)
		MobileLayout.setPartyRows(rows)
		local what = label .. " (" .. rows .. " teammates)"
		local party = MobileLayout.party(screen, rows)
		local loot, toast, gap = MobileLayout.loot(screen), MobileLayout.toast(screen), MobileLayout.topGap(screen)
		local ki = MobileLayout.kaiju(screen, false)
		local tame = { X = ki.TameX, Y = ki.TameY, W = ki.TameW, H = ki.TameH }
		for name, r in { card = card, wallet = wallet, dock = dock, chat = closed, open = open, loot = loot, toast = toast, health = hp, kaiju = kWhole, CATCH = tame } do
			check(inside(r), what .. ": the " .. name .. " runs off the screen")
		end
		if rows > 0 then
			check(inside(party), what .. ": the teammates' rows run off the screen")
			check(party.X == hp.X and party.W == hp.W and party.Row == hp.H and party.Y >= hp.Y + hp.H,
				what .. ": the teammates' rows aren't under your health, its size")
			check(math.abs(party.H - (rows * hp.H + (rows - 1) * party.Gap)) < 1e-6, what .. ": the teammates' rows aren't one each")
		end
		-- A toast: left of your coins, right of your kaiju's card (or, too
		-- narrow there, under your health and teammates).
		check(toast.H <= 30 and toast.W <= 260, what .. ": a toast's place is too big")
		if toast.Under then
			check(toast.X + toast.W == wallet.X + wallet.W and toast.Y >= hp.Y + hp.H, what .. ": the toast isn't under your health")
			check(s[1] < 736, what .. ": the toast left the top on a phone with room for it")
		else
			check(toast.Y == wallet.Y and toast.X + toast.W <= wallet.X - 4, what .. ": the toast isn't on the top row, left of your coins")
			check(toast.X >= kWhole.X + kWhole.W + 4, what .. ": the toast runs over your kaiju's card")
		end
		check(gap.X >= kWhole.X + kWhole.W and gap.X + gap.W <= (if toast.Under then wallet.X else toast.X), what .. ": the top's gap isn't between your kaiju and the toasts")
		-- The loot card: under your health and teammates, right-aligned; or
		-- beside them, clear of the jump button.
		if loot.Beside then
			check(loot.Y == hp.Y and loot.X + loot.W <= hp.X - 4, what .. ": the loot card isn't beside your health")
		else
			check(loot.X + loot.W == hp.X + hp.W and loot.Y >= hp.Y + hp.H, what .. ": the loot card isn't under your health")
		end
		local row = { X = loot.X, Y = if loot.RowsBelow then loot.Y + loot.H + MobileLayout.Loot.Gap else loot.Y, W = loot.W, H = MobileLayout.Loot.Row }
		for name, r in { toast = toast, ["loot card"] = loot, ["loot row"] = row } do
			check(r.X + r.W <= screen.X - 24, what .. ": the " .. name .. " runs under Roblox's tab on the right")
			local others = { ["pick card"] = card, coins = wallet, health = hp, dock = dock, ["kaiju card"] = kWhole, jump = jump }
			if rows > 0 then
				others["teammates' rows"] = party
			end
			for other, o in others do
				check(not MobileLayout.overlaps(r, o), what .. ": the " .. name .. " overlaps the " .. other)
			end
		end
		if not toast.Under then
			check(not MobileLayout.overlaps(loot, toast), what .. ": the loot card overlaps the toast")
		end
		check(loot.H == MobileLayout.Loot.H and loot.W == MobileLayout.Loot.W, what .. ": the loot card isn't slim")
		-- Your kaiju's card and CATCH, clear of all of it.
		local near = { ["pick card"] = card, coins = wallet, health = hp, dock = dock, jump = jump, thumbstick = stick,
			["loot card"] = loot, ["CHAT button"] = closed, ["HOP OUT"] = hop }
		if rows > 0 then
			near["teammates' rows"] = party
		end
		if not toast.Under then
			near.toast = toast
		end
		for name, r in near do
			check(not MobileLayout.overlaps(kWhole, r), what .. ": your kaiju's card overlaps the " .. name)
			if name ~= "pick card" then
				check(not MobileLayout.overlaps(tame, r), what .. ": CATCH overlaps the " .. name)
			end
		end
		check(not MobileLayout.overlaps(kWhole, tame), what .. ": CATCH overlaps your kaiju's card")
		check(tame.W >= 140, what .. ": CATCH is too narrow")
		-- The pick card (while you mine) and the teammates' rows, clear of the rest.
		for name, r in { coins = wallet, dock = dock, ["loot card"] = loot, thumbstick = stick, ["CHAT button"] = closed } do
			check(not MobileLayout.overlaps(card, r), what .. ": the pick card overlaps the " .. name)
		end
		if rows > 0 then
			for name, r in { dock = dock, ["HOP OUT"] = hop, thumbstick = stick, jump = jump, ["open chat"] = open, wallet = wallet } do
				check(not MobileLayout.overlaps(party, r), what .. ": the teammates' rows overlap the " .. name)
			end
		end
	end
	MobileLayout.setPartyRows(0)
	local party = MobileLayout.party(screen)
	local loot, toast = MobileLayout.loot(screen), MobileLayout.toast(screen)
	check(wallet.Y <= 12 and wallet.X + wallet.W >= screen.X - 40, label .. ": your level and coins aren't at the top right")
	check(MobileLayout.tasks == nil and MobileLayout.board == nil, "A TASKS button or board strip is back on a phone")
	check(
		dock.PlayWidth <= dock.W and dock.PlayHeight + dock.Gap + dock.TileHeight <= dock.H,
		label .. ": PLAY doesn't fit the dock"
	)
	-- In a mech: HOP OUT in PLAY's place (PLAY hides), above the tiles.
	check(
		math.abs(hop.Y - dock.Y) < 1e-6 and drive.H == dock.PlayHeight and drive.W <= dock.W,
		label .. ": HOP OUT isn't in PLAY's place"
	)
	-- And on a touch screen, its drive stick at the bottom left (where
	-- Roblox's thumbstick sits), clear of everything else on the HUD.
	check(stick.X >= 0 and stick.Y + stick.H <= screen.Y, label .. ": the drive stick is off the screen")
	check(stick.Y >= screen.Y * 0.4, label .. ": the drive stick isn't down at the bottom")
	for name, other in { dock = dock, ["HOP OUT"] = hop, coins = wallet, ["pick card"] = card, ["teammates' rows"] = party } do
		check(not MobileLayout.overlaps(stick, other), label .. ": the drive stick overlaps the " .. name)
	end
	check(MobileLayout.Stick.Knob < MobileLayout.Stick.Size, label .. ": the stick's knob is bigger than the stick")
	for name, r in { coins = wallet, ["pick card"] = card, dock = dock, ["CHAT button"] = closed } do
		check(not MobileLayout.overlaps(hp, r), label .. ": the health bar overlaps the " .. name)
	end
	check(not MobileLayout.overlaps(wallet, closed), label .. ": the CHAT button overlaps the coins")
	check(not MobileLayout.overlaps(wallet, dock), label .. ": the coins overlap the dock")
	check(not MobileLayout.overlaps(card, closed), label .. ": the CHAT button overlaps the pick card")
	check(not MobileLayout.overlaps(closed, dock), label .. ": the CHAT button overlaps the dock")
	check(not MobileLayout.overlaps(open, dock), label .. ": the open chat covers PLAY or the tiles")
	check(not MobileLayout.overlaps(dock, jump), label .. ": the dock runs under the jump button")
	-- Every tile fits the dock, with room for its name.
	check(dock.TileWidth * TILES + dock.Gap * (TILES - 1) <= dock.W, label .. ": the tiles spill off the dock")
	check(dock.TileWidth >= 44 and dock.TileHeight >= 44, label .. ": tiles too small to tap")
	check(open.H >= 120 and open.W >= 240, label .. ": the open chat is too small to read")
	-- Your kaiju's card: one row (the team's three, the support a little
	-- apart, AUTO HEAL, the team keys 1 to 4), the HYPERBEAM its outline,
	-- its pill on the bottom edge. Every cell big enough to tap, inside the
	-- card and clear of the others. While you hunt it's under your health
	-- on the right (your teammates' rows hide then), CATCH left of it.
	for _, hunting in { false, true } do
		local kc = MobileLayout.kaiju(screen, hunting)
		local tame = { X = kc.TameX, Y = kc.TameY, W = kc.TameW, H = kc.TameH }
		local what = label .. (if hunting then " (hunting)" else "")
		check(inside(kc) and inside(tame), what .. ": the kaiju card or CATCH runs off the screen")
		check(kc.H >= 50 and kc.H <= 72, what .. ": the kaiju card is squashed or too tall: " .. kc.H)
		local cells = MobileLayout.kaijuCells(kc)
		check(cells.Row == true, what .. ": the kaiju card's cells aren't in a row")
		local all = { cells.Fighters[1], cells.Fighters[2], cells.Fighters[3], cells.Support, cells.Auto, cells.Teams }
		for i, cell in all do
			check(cell.X >= 0 and cell.Y >= 0 and cell.X + cell.W <= kc.W and cell.Y + cell.H <= kc.H, what .. ": a cell spills out of the card: " .. i)
			check(cell.W >= 40 and cell.H >= 40, what .. ": a cell too small to tap: " .. i)
			check(cell.Y == all[1].Y and cell.H == all[1].H, what .. ": the cells aren't one row: " .. i)
			for j = i + 1, #all do
				check(not MobileLayout.overlaps(cell, all[j]), what .. ": two of the card's cells overlap: " .. i .. ", " .. j)
				check(all[j].X > cell.X, what .. ": the cells aren't in order: " .. i .. ", " .. j)
			end
		end
		-- (the team keys: four chips in a row, each wide enough to tap)
		check((cells.Teams.W - kc.Gap * 3) / 4 >= 20, what .. ": the team keys are too narrow to tap")
		-- The HYPERBEAM's pill: across the middle of the card's bottom edge,
		-- big enough to tap, over none of the cells, its lower half on the screen.
		local beam = cells.Beam
		check(beam.W >= kc.W * 0.7 and beam.H >= 20, what .. ": the HYPERBEAM's pill is too small to tap")
		check(math.abs(beam.Y + beam.H / 2 - kc.H) <= 1, what .. ": the HYPERBEAM's pill isn't on the card's bottom edge")
		check(math.abs(beam.X + beam.W / 2 - kc.W / 2) <= 1, what .. ": the HYPERBEAM's pill isn't centred")
		for i, cell in all do
			check(not MobileLayout.overlaps(cell, beam), what .. ": the HYPERBEAM's pill covers a cell: " .. i)
		end
		check(inside({ X = kc.X + beam.X, Y = kc.Y + beam.Y, W = beam.W, H = beam.H }), what .. ": the HYPERBEAM's pill runs off the screen")
		if hunting then
			local whole = { X = kc.X, Y = kc.Y, W = kc.W, H = kc.H + kc.Notch / 2 }
			check(kc.X + kc.W == hp.X + hp.W and kc.Y >= hp.Y + hp.H, what .. ": the kaiju card isn't under your health")
			for name, r in { coins = wallet, health = hp, dock = dock, jump = jump, thumbstick = stick } do
				check(not MobileLayout.overlaps(whole, r), what .. ": the kaiju card overlaps the " .. name)
				check(not MobileLayout.overlaps(tame, r), what .. ": CATCH overlaps the " .. name)
			end
			check(not MobileLayout.overlaps(whole, tame), what .. ": CATCH overlaps the kaiju card")
		end
	end
	-- (The computer's card keeps three by two: the kaiju two by two, AUTO
	-- HEAL over the team keys.)
	local desk = MobileLayout.kaijuDesk(Vector2.new(1366, 710))
	local dc = MobileLayout.kaijuCells(desk)
	check(not dc.Row and dc.Teams.X == dc.Auto.X and dc.Teams.Y > dc.Auto.Y and dc.Fighters[3].Y > dc.Fighters[1].Y,
		"The computer's kaiju card isn't three by two")
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
		local others = {
			jump = jump,
			PLAY = playRect,
			tiles = tiles,
			["thumbstick"] = stick,
			toast = toast,
			["loot card"] = loot,
			["teammates' rows"] = MobileLayout.party(screen),
			["pick card"] = card,
			coins = wallet,
			health = hp,
			["kaiju card"] = kWhole,
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
		.. " mobile layout checks (your kaiju's card in one row at the top left with its HYPERBEAM pill on the edge, the pick card under it, coins, chat, dock with TASKS, teammates' rows under your health and its size, the toast beside your kaiju or under your health, the loot card under or beside them clear of the jump button, CATCH, the kit switch by PLAY and clear of the fight's ring and vitals, at 7 screen sizes with 0 to 3 teammates)"
)
