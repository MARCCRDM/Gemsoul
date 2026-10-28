-- lune run tests/mobile_layout_cases.luau <repo>
-- The lobby's pieces on a phone never overlap (MobileLayout): your kaiju's
-- card (small, two rows, top left), CATCH under it, the pick card beside
-- it, the team keys above the move stick, the fight's foe list at the top
-- right, your level and coins,
-- your health and your teammates' rows under it (as many as are up), the
-- CHAT button (small screens with a keyboard), the opened chat, the dock
-- (its tiles, PLAY and TASKS among them, and PLAY's old place over them), a toast and your loot card, CATCH,
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
local TILES = 7 -- PLAY, INVENTORY, STORE, TASKS, MARKET, SOCIAL, INVITE (no RANKS on a phone)
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
	-- Your kaiju's card: small, two rows, at the top left; the pick card
	-- beside it only while you mine.
	local k = MobileLayout.kaiju(screen, false)
	local kWhole = { X = k.X, Y = k.Y, W = k.W, H = k.H }
	check(k.X == 12 and k.Y == 12, label .. ": your kaiju's card isn't at the top left")
	check(k.Grid and #k.Rows == 2, label .. ": your kaiju's card isn't two rows")
	check(k.W <= 200 and kWhole.H <= 100, label .. ": your kaiju's card isn't small: " .. k.W .. " by " .. kWhole.H)
	check(card.Y == k.Y and card.X >= kWhole.X + kWhole.W + 4, label .. ": the pick card isn't beside your kaiju's card")
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
			check(s[1] < 812, what .. ": the toast left the top on a phone with room for it")
		else
			check(toast.Y == wallet.Y and toast.X + toast.W <= wallet.X - 4, what .. ": the toast isn't on the top row, left of your coins")
			check(toast.X >= card.X + card.W + 4, what .. ": the toast runs over your kaiju's card or the pick card's place")
		end
		check(gap.X >= card.X + card.W and gap.X + gap.W <= (if toast.Under then wallet.X else toast.X), what .. ": the top's gap isn't between the pick card's place and the toasts")
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
			check(not MobileLayout.overlaps(tame, r), what .. ": CATCH overlaps the " .. name)
		end
		check(not MobileLayout.overlaps(kWhole, tame), what .. ": CATCH overlaps your kaiju's card")
		check(tame.X == kWhole.X and tame.Y >= kWhole.Y + kWhole.H, what .. ": CATCH isn't under your kaiju's card")
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
	-- Your kaiju's card: small, two rows (the team's three and the support a
	-- little apart, AUTO HEAL across the card under them), no team keys or
	-- HYPERBEAM on it; at the top left in a fight too. Every cell big enough
	-- to tap, inside the card and clear of the others.
	for _, hunting in { false, true } do
		local kc = MobileLayout.kaiju(screen, hunting)
		local tame = { X = kc.TameX, Y = kc.TameY, W = kc.TameW, H = kc.TameH }
		local what = label .. (if hunting then " (hunting)" else "")
		check(kc.X == 12 and kc.Y == 12, what .. ": the kaiju card isn't at the top left")
		check(inside(kc) and inside(tame), what .. ": the kaiju card or CATCH runs off the screen")
		check(kc.H >= 64 and kc.H <= 90, what .. ": the kaiju card is squashed or too tall: " .. kc.H)
		local cells = MobileLayout.kaijuCells(kc)
		check(cells.Grid == true and cells.Teams == nil and cells.Beam == nil,
			what .. ": the kaiju card isn't the phone's grid, or still has the team keys or the HYPERBEAM")
		local top = { cells.Fighters[1], cells.Fighters[2], cells.Fighters[3], cells.Support }
		local all = { top[1], top[2], top[3], top[4], cells.Auto }
		for i, cell in all do
			check(cell.X >= 0 and cell.Y >= 0 and cell.X + cell.W <= kc.W and cell.Y + cell.H <= kc.H, what .. ": a cell spills out of the card: " .. i)
			for j = i + 1, #all do
				check(not MobileLayout.overlaps(cell, all[j]), what .. ": two of the card's cells overlap: " .. i .. ", " .. j)
			end
		end
		for i, cell in top do
			check(cell.W >= 36 and cell.H >= 36, what .. ": a kaiju too small to tap: " .. i)
			check(cell.Y == top[1].Y and cell.H == top[1].H, what .. ": the kaiju aren't one row: " .. i)
			check(i == 1 or cell.X > top[i - 1].X + top[i - 1].W, what .. ": the kaiju aren't in order: " .. i)
		end
		check(cells.Support.X - (top[3].X + top[3].W) > cells.Fighters[2].X - (top[1].X + top[1].W), what .. ": the support isn't a little apart")
		check(cells.Auto.Y >= top[1].Y + top[1].H and cells.Auto.W >= kc.W - 2 * kc.Pad and cells.Auto.H >= 18,
			what .. ": AUTO HEAL isn't a row across the card under the kaiju")
	end
	-- The team keys: off the card, two by two just above the move stick
	-- (under your left thumb), each big enough to tap (full size wherever
	-- there's room: the phones from 844 by 390 up), clear of everything
	-- else there is (with your pick out, and with your kit out: the fight's
	-- ring). (The CHAT button only comes with a keyboard, the keys only on
	-- touch: never both.)
	local keys = MobileLayout.keys(screen)
	check(inside(keys), label .. ": the team keys run off the screen")
	check(
		keys.Size >= 30 and keys.Across == 2 and keys.W == 2 * keys.Size + keys.Gap and keys.H == keys.W,
		label .. ": the team keys are too small to tap, or not two by two"
	)
	check(s[2] < 330 or keys.Size == MobileLayout.Keys.Size, label .. ": the team keys are smaller than they need be: " .. keys.Size)
	check(keys.X == stick.X and keys.Y + keys.H <= stick.Y and stick.Y - (keys.Y + keys.H) <= 12,
		label .. ": the team keys aren't just above the move stick")
	check(keys.Y >= k.TameY + k.TameH + 2, label .. ": the team keys are jammed against CATCH")
	local fightRing = MobileLayout.ring(s[3])
	local keyClear = {
		["kaiju card"] = kWhole,
		CATCH = { X = k.TameX, Y = k.TameY, W = k.TameW, H = k.TameH },
		["pick card"] = card,
		coins = wallet,
		health = hp,
		dock = dock,
		jump = jump,
		["kit switch"] = MobileLayout.kitSwitch(screen),
		["HOP OUT"] = hop,
		ATTACK = MobileLayout.onRing(screen, fightRing, fightRing.Attack, 0, 0),
		GUARD = MobileLayout.onRing(screen, fightRing, fightRing.Guard, fightRing.Outer, MobileLayout.Ring.Guard),
		DODGE = MobileLayout.onRing(screen, fightRing, fightRing.Dodge, fightRing.Outer, MobileLayout.Ring.Dodge),
	}
	for name, r in keyClear do
		check(not MobileLayout.overlaps(keys, r), label .. ": the team keys overlap the " .. name)
	end
	-- The HYPERBEAM: a button of its own just right of the team keys, its
	-- rim level with their top and bottom, bigger than a key; the two of
	-- them a block of their own (no wider than the old row of keys alone);
	-- clear of the same (its rim too), of the keys and the move stick, and
	-- of the fight's vitals and the moves over them (three at most) with
	-- your kit out.
	local beam = MobileLayout.beam(screen)
	local rimmed = { X = beam.X - beam.Rim, Y = beam.Y - beam.Rim, W = beam.W + 2 * beam.Rim, H = beam.H + 2 * beam.Rim }
	check(inside(rimmed), label .. ": the HYPERBEAM runs off the screen")
	check(beam.W >= 52 and beam.H >= 48 and beam.H > keys.Size, label .. ": the HYPERBEAM is too small to tap")
	check(
		rimmed.X >= keys.X + keys.W + 6 and rimmed.X - (keys.X + keys.W) <= 12
			and rimmed.Y == keys.Y and rimmed.Y + rimmed.H == keys.Y + keys.H,
		label .. ": the HYPERBEAM isn't just right of the team keys, as tall as they are"
	)
	check(rimmed.X + rimmed.W - keys.X <= 4 * 34 + 3 * 5, label .. ": the team keys and the HYPERBEAM take up too much room: " .. (rimmed.X + rimmed.W - keys.X))
	local beamClear = table.clone(keyClear)
	beamClear["team keys"] = keys
	beamClear["move stick"] = stick
	do
		-- (The fight's vitals and the moves over them, on the camera's
		-- viewport: bottom-anchored, so the same bottom edge as the screen.)
		local view = Vector2.new(s[1], s[3])
		local inset = s[3] - s[2]
		local armed = MobileLayout.kitSwitch(screen, view)
		local vitals = MobileLayout.vitals(view, fightRing, armed)
		local height = if vitals.W < 400 then 64 else 34
		local bottom = s[3] - (fightRing.Margin + height) - inset
		beamClear.vitals = { X = vitals.X, Y = bottom, W = vitals.W, H = height }
		local Mv, mvGap = math.floor(46 * fightRing.K), math.floor(12 * fightRing.K)
		local moves = 3 * Mv + 2 * mvGap
		beamClear.moves = { X = vitals.Centre - moves / 2, Y = bottom - 10 * fightRing.K - Mv, W = moves, H = Mv }
		beamClear["kit switch (kit out)"] = armed
	end
	for name, r in beamClear do
		check(not MobileLayout.overlaps(rimmed, r), label .. ": the HYPERBEAM overlaps the " .. name)
	end
	-- The fight's foe list: on the right at the top (your coins and health
	-- hide in a fight), right-aligned with their column, clear of Roblox's
	-- tab; two rows or more over DODGE (one where the toasts come down under
	-- your health and it stops over their place), and the rows it shows
	-- clear of the fight's ring, your kaiju's card, CATCH, the team keys and
	-- the kit switch.
	local foes = MobileLayout.foes(screen, s[3])
	local fit = math.floor((foes.Bottom - foes.Y + 4) / 38)
	local shown = { X = foes.X, Y = foes.Y, W = foes.W, H = math.max(1, fit) * 38 - 4 }
	check(foes.X + foes.W == wallet.X + wallet.W and foes.Y == wallet.Y, label .. ": the foe list isn't at the top right")
	check(foes.X + foes.W <= screen.X - 24 and foes.W >= 140, label .. ": the foe list runs under Roblox's tab, or is too narrow")
	check(fit >= (if toast.Under then 1 else 2), label .. ": the foe list has room for only " .. fit .. " rows")
	local foeClear = {
		["kaiju card"] = kWhole,
		CATCH = keyClear.CATCH,
		["team keys"] = keys,
		HYPERBEAM = beam,
		["kit switch"] = keyClear["kit switch"],
		ATTACK = keyClear.ATTACK,
		GUARD = keyClear.GUARD,
		DODGE = keyClear.DODGE,
		toast = toast,
	}
	for i, degrees in MobileLayout.Ring.Surges do
		foeClear["surge " .. i] = MobileLayout.onRing(screen, fightRing, fightRing.Surge, fightRing.Inner, degrees)
	end
	for name, r in foeClear do
		check(not MobileLayout.overlaps(shown, r), label .. ": the foe list overlaps the " .. name)
	end
	-- (The computer's card keeps three by two: the kaiju two by two, AUTO
	-- HEAL over the team keys.)
	local desk = MobileLayout.kaijuDesk(Vector2.new(1366, 710))
	local dc = MobileLayout.kaijuCells(desk)
	check(not dc.Grid and dc.Teams.X == dc.Auto.X and dc.Teams.Y > dc.Auto.Y and dc.Fighters[3].Y > dc.Fighters[1].Y,
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
			["team keys"] = MobileLayout.keys(screen),
			HYPERBEAM = MobileLayout.beam(screen),
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

-- The Store on a phone (MobileLayout.store): the whole screen at every phone
-- size (drawn 844 wide, as tall as the screen's shape leaves, scaled to fill
-- it); the coins and the close button in Roblox's strip, at its right end,
-- clear of its buttons and of DEV; the eight categories down the rail, every
-- tab a thumb's height, all of them in it; the page beside the rail, inside
-- the screen; and a catalog page with at least two columns of looks beside a
-- product page that keeps its width.
for _, s in {
	{ 667, 375, 36 },
	{ 736, 414, 36 },
	{ 812, 375, 58 },
	{ 844, 390, 58 },
	{ 847, 391, 58 },
	{ 896, 414, 58 },
	{ 932, 430, 58 },
	{ 568, 320, 36 },
	{ 960, 411, 58 },
	{ 1000, 400, 58 },
} do
	local screen = Vector2.new(s[1], s[2])
	local label = "Store " .. s[1] .. "x" .. s[2]
	local right = screen.X - 70 -- (DEV)
	local store = MobileLayout.store(screen, s[3], right)
	check(math.abs(store.W * store.Scale - screen.X) <= 1.5, label .. ": doesn't fill the screen's width")
	check(math.abs(store.H * store.Scale - screen.Y) <= 1.5, label .. ": doesn't fill the screen's height")
	check(store.W >= MobileLayout.Store.Width and store.H >= MobileLayout.Store.MinH, label .. ": drawn too small")
	check(store.Scale >= 0.6, label .. ": scaled down to " .. store.Scale)
	local close, rail, page = store.Close, store.Rail, store.Page
	check(close.Y >= 0 and close.Y + close.H <= store.Strip, label .. ": the close button isn't in the strip")
	check(close.W >= 32, label .. ": the close button is small: " .. close.W)
	check((close.X + close.W) * store.Scale <= right, label .. ": the close button is under DEV")
	check(store.Wallet.Right <= close.X - 6, label .. ": the coins run into the close button")
	check(rail.Y >= store.Strip, label .. ": the rail starts under Roblox's buttons")
	-- (eight categories now, Featured and Kaiju first: a thumb's height still)
	check(store.TabH >= 34, label .. ": the tabs are short: " .. store.TabH)
	local tabs = MobileLayout.Store.Tabs
	check(tabs * store.TabH + (tabs - 1) * MobileLayout.Store.TabGap <= rail.H, label .. ": the tabs don't fit the rail")
	check(page.X >= rail.X + rail.W and page.Y == rail.Y, label .. ": the page isn't beside the rail")
	check(page.X + page.W <= store.W and page.Y + page.H <= store.H, label .. ": the page runs off the screen")
	check(page.H >= 290, label .. ": the page is short: " .. page.H)
	local grid = MobileLayout.storeGrid(page.W)
	check(grid.Cols >= 2 and grid.CardW >= MobileLayout.StoreGrid.CardMin, label .. ": the grid is cramped")
	check(grid.GridW + 12 <= grid.ProductX, label .. ": the grid runs into the product page")
	check(grid.ProductX + grid.ProductW == page.W, label .. ": the product page isn't at the page's right")
	check(grid.ProductW >= MobileLayout.StoreGrid.ProductMin, label .. ": the product page is narrow")
end
-- A strip too thin for the close button gets one of our own.
local thin = MobileLayout.store(Vector2.new(844, 390), 0, 844)
check(thin.Strip >= thin.Close.H + 8 and thin.Close.Y >= 0, "No strip, and the close button had no room")
print(
	"PASS: "
		.. checks
		.. " mobile layout checks (your kaiju's card small, two rows, at the top left, CATCH under it, the pick card beside it, the team keys above the move stick and the HYPERBEAM right of them, the foe list at the top right over the fight's ring, coins, chat, dock with TASKS, teammates' rows under your health and its size, the toast beside the pick card's place or under your health, the loot card under or beside them clear of the jump button, the kit switch by PLAY and clear of the fight's ring and vitals, at 7 screen sizes with 0 to 3 teammates; the Store filling the screen at 10 phone sizes, its rail and page beside it)"
)
