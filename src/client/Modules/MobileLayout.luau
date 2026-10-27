--[[
	Where the lobby's pieces sit on a phone, in one place so they can't drift
	onto each other (tests/mobile_layout_cases checks every phone size):

	  top left      your kaiju's card (KaijuHud), small, two rows: the
	                team's three and the support, AUTO HEAL under them; in
	                a fight too. CATCH under it. Beside it, when it's opened
	                (tap the swing bar by a rock), the pick card
	                (OutpostScene), drawn at CardScale;
	                in a fight, the foe list (FoeBars) is on the right. On a
	                small screen with a keyboard, the CHAT button goes under
	                CATCH's place; opened, the chat is a column down the left
	                that stops above the dock. Phones and tablets use
	                Roblox's own chat instead (ChatFrame).
	  bottom left   the team keys 1 to 4 (KaijuHud), in a row just above
	                the move stick (your left thumb), and the team's
	                HYPERBEAM (KaijuBeamHud) just right of them, a button of
	                its own over the kit switch
	  top middle    the live feed (LobbyFeed), between the pick card's place
	                and the toasts' place (gone on a screen too narrow for it)
	  top right     your level and coins (LobbyUI) in a pill, your health
	                under it, and your teammates' health under that, a row
	                each the same size (PartyUI; hidden in a fight); a toast
	                (UiKit.toast) just left of your coins, as wide as its
	                words (on a phone too narrow for it beside your kaiju's
	                card, under your health and teammates instead); under
	                them, right-aligned, your loot card (MinerLoot), slim,
	                and one row under that (beside them on the left where
	                under them would reach the jump button). All keep clear
	                of the slim tab Roblox puts on a phone's right edge. The
	                live feed steps aside while the loot card is up
	                (claimTop). Nothing else: tasks and the day's challenges
	                open from the dock's TASKS tile, and the lobby's board
	                isn't shown
	  bottom middle the dock (LobbyUI): a row of tiles, PLAY the first (on a
	                phone a green tile; a computer's big PLAY bar), and over
	                them PLAY's old place, HOP OUT's in a mech, the kit
	                switch just left of it

	Rects are { X, Y, W, H } in the ScreenGui's space (below the top bar).

	  MobileLayout.card()                  the pick card (while you mine)
	  MobileLayout.wallet(screen)          level and coins (top right);
	                                       health(screen) just under it
	  MobileLayout.chat(screen, open)      the chat box: CHAT button, or opened
	  MobileLayout.dock(screen, tiles)     the dock, its PLAY and tile size
	  MobileLayout.party(screen, rows?)    the teammates' rows (Party.Max of
	                                       them unless told); setPartyRows(n)
	                                       says how many are up (PartyUI),
	                                       partyRows() reads it, onParty(fn)
	                                       hears when it changes
	  MobileLayout.toast(screen)           a toast's place: left of your
	                                       coins, Toast.W at most, one line
	                                       (Toast.H); Under: on a narrow
	                                       phone, under your health instead
	  MobileLayout.loot(screen)            your loot card: under your health
	                                       and teammates, right-aligned (or
	                                       Beside them, clear of the jump
	                                       button)
	  MobileLayout.jump(screen)            Roblox's jump button (about where)
	  MobileLayout.topGap(screen)          the top's free middle ({ X, W }),
	                                       between your kaiju and the toasts
	  MobileLayout.claimTop(owner, on)     something has the top (a
	                                       loot card); topClaimed(except?)
	                                       says if anything else does, and
	                                       onTop(fn) hears when that changes
	  MobileLayout.kaiju(screen)           your kaiju's card (KaijuHud), two
	                                       rows at the top left, and CATCH;
	                                       kaijuDesk(screen) on a computer
	                                       (three by two), kaijuCells(card)
	                                       its cells; keys(screen) the team
	                                       keys above the move stick, and
	                                       beam(screen) the HYPERBEAM right
	                                       of them
	  MobileLayout.foes(screen, viewY)     the fight's foe list (FoeBars):
	                                       on the right at the top, down to
	                                       just over DODGE
	  MobileLayout.Drive                   a mech's HOP OUT button (VehicleDrive),
	                                       bottom middle on every screen, in
	                                       PLAY's place on a phone (PLAY hides
	                                       while you pilot): its size and how
	                                       far up it sits
	  MobileLayout.ring(height)            the fight's ring of buttons (Combat.client)
	  MobileLayout.onRing(screen, ring, size, radius, degrees)   a button on it
	  MobileLayout.vitals(viewport, ring, clear?)   where the fight's vitals
	                                       go between the stick and the ring
	  MobileLayout.kitSwitch(screen, viewport?)   the pick/kit switch
	                                       (SparKit): just left of PLAY, and
	                                       there still with your kit out
	  MobileLayout.stick(screen)           a mech's drive stick on a touch
	                                       screen (VehicleDrive): bottom left,
	                                       where Roblox's thumbstick sits,
	                                       clear of the dock and the jump
	                                       button; Stick is its size, the
	                                       knob's and its place
]]
local MobileLayout = {}

MobileLayout.CardScale = 0.66
MobileLayout.Margin = 12
MobileLayout.Drive = { W = 160, H = 38, Bottom = 62 }
MobileLayout.Stick = { Size = 112, Knob = 46, Left = 20, Bottom = 16 }
-- (Right: from the screen's right edge, clear of Roblox's tab there. A
-- toast: left of your coins, no wider than W, and not there at all with
-- less than Min beside your kaiju's card.)
MobileLayout.Wallet = { W = 150, H = 30, Top = 8, Right = 30 }
MobileLayout.Toast = { W = 240, H = 28, Top = 8, Min = 170 }
MobileLayout.Loot = { W = 232, H = 72, Row = 24, Gap = 6 }

-- (Your kaiju's card at the top left: its size, the same on every phone.
-- Two rows: the team's three and the support, Tile square, the support
-- Split apart; AUTO HEAL under them, AutoH tall, the card's width. The
-- HYPERBEAM isn't on it: beam(screen). Back: how see-through the card's
-- own back is, the tiles' solid on it.)
MobileLayout.Kaiju = { Tile = 36, Pad = 4, Gap = 3, Split = 6, AutoH = 20, Back = 0.55 }
local function kaijuSize(): (number, number)
	local k = MobileLayout.Kaiju
	local w = k.Pad * 2 + k.Tile * 4 + k.Gap * 2 + k.Split
	return w, k.Pad * 2 + k.Tile + k.Gap + k.AutoH
end
-- (Where the card ends.)
local function kaijuBottom(): number
	local _, h = kaijuSize()
	return 12 + h
end
-- CATCH on a phone: under your kaiju's card, as wide.
MobileLayout.Tame = { H = 38 }

-- The pick card (only while you mine): beside your kaiju's card at the
-- top, at CardScale (H: as tall as it opens).
function MobileLayout.card()
	local kw = kaijuSize()
	return { X = 12 + kw + 8, Y = 12, W = 300 * MobileLayout.CardScale, H = 100 * MobileLayout.CardScale }
end
-- (The top left's right edge: your kaiju's card and the pick card's place.)
local function topLeftRight(): number
	local pick = MobileLayout.card()
	return pick.X + pick.W
end

function MobileLayout.stick(screen: Vector2)
	local stick = MobileLayout.Stick
	return { X = stick.Left, Y = screen.Y - stick.Bottom - stick.Size, W = stick.Size, H = stick.Size }
end

-- Your level and coins: the top right (as the user's phone layout has it),
-- clear of Roblox's tab on the right edge.
function MobileLayout.wallet(screen: Vector2)
	local w = MobileLayout.Wallet
	return { X = screen.X - w.Right - w.W, Y = w.Top, W = w.W, H = w.H }
end

function MobileLayout.dock(screen: Vector2, tiles: number)
	-- Clear of Roblox's jump button at the bottom right (and as wide on the
	-- left); no wider than it needs, so the ground in front of you shows.
	local width = math.min(392, math.max(240, screen.X - 280))
	local gap, tileHeight, playHeight = 6, 44, 38
	local height = playHeight + 6 + tileHeight
	return {
		X = (screen.X - width) / 2,
		Y = screen.Y - MobileLayout.Margin - height,
		W = width,
		H = height,
		Gap = gap,
		TileWidth = math.floor((width - gap * math.max(0, tiles - 1)) / math.max(1, tiles)),
		TileHeight = tileHeight,
		PlayWidth = math.min(184, width),
		PlayHeight = playHeight,
	}
end

function MobileLayout.chat(screen: Vector2, open: boolean)
	if not open then
		-- (Under CATCH's place, under your kaiju's card.)
		return { X = 12, Y = kaijuBottom() + 6 + MobileLayout.Tame.H + 6, W = 76, H = 44 }
	end
	local dock = MobileLayout.dock(screen, 5)
	local width = math.floor(math.clamp(screen.X * 0.38, 240, 340))
	-- Down the left, stopping above the dock (or beside it, if the screen's
	-- too short for that).
	local bottom = dock.Y - 10
	if width + 12 + 8 <= dock.X then
		bottom = screen.Y - MobileLayout.Margin
	end
	return { X = 12, Y = 12, W = width, H = math.max(120, bottom - 12) }
end

-- Your teammates' health: a row each, as big as your health bar, stacked
-- under it (Party.Max at most). `rows`: how many (all there can be unless
-- told); how many are up now: partyRows(), set by PartyUI.
MobileLayout.Party = { Max = 3, Gap = 4 }
local partyUp = 0
local partyListeners: { () -> () } = {}
function MobileLayout.setPartyRows(n: number)
	n = math.clamp(n, 0, MobileLayout.Party.Max)
	if n == partyUp then
		return
	end
	partyUp = n
	for _, listener in partyListeners do
		local ok, err = pcall(listener)
		if not ok then
			warn("MobileLayout.onParty: " .. tostring(err))
		end
	end
end
function MobileLayout.partyRows(): number
	return partyUp
end
function MobileLayout.onParty(listener: () -> ())
	table.insert(partyListeners, listener)
end
function MobileLayout.party(screen: Vector2, rows: number?)
	local spec, health = MobileLayout.Party, MobileLayout.health(screen)
	local n = math.clamp(rows or spec.Max, 0, spec.Max)
	return {
		X = health.X,
		Y = health.Y + health.H + spec.Gap,
		W = health.W,
		H = math.max(0, n * health.H + (n - 1) * spec.Gap),
		Row = health.H,
		Gap = spec.Gap,
	}
end

-- (The bottom of your health and your teammates' rows, as many as are up.)
local function columnBottom(screen: Vector2): number
	local health = MobileLayout.health(screen)
	if partyUp > 0 then
		local party = MobileLayout.party(screen, partyUp)
		return party.Y + party.H
	end
	return health.Y + health.H
end

-- Roblox's jump button on a touch screen: about 70 points square, its
-- centre ~95 from the right and ~90 from the bottom.
function MobileLayout.jump(screen: Vector2)
	return { X = screen.X - 130, Y = screen.Y - 125, W = 70, H = 70 }
end

-- Left of your coins, right of the pick card's place (beside your kaiju's
-- card); on a phone with less than Toast.Min between them, under your
-- health and teammates instead, right-aligned with them (Under).
function MobileLayout.toast(screen: Vector2)
	local t, wallet = MobileLayout.Toast, MobileLayout.wallet(screen)
	local left, right = topLeftRight() + 8, wallet.X - 8
	if right - left >= t.Min then
		local w = math.min(t.W, right - left)
		return { X = right - w, Y = t.Top, W = w, H = t.H, Under = false }
	end
	-- (as wide as it can be, clear of the pick card's place)
	local w = math.min(t.W, wallet.X + wallet.W - (topLeftRight() + 8))
	return { X = wallet.X + wallet.W - w, Y = columnBottom(screen) + 6, W = w, H = t.H, Under = true }
end

-- The top's free middle: from the pick card's place to the toasts' place
-- (to your coins where the toasts go under your health). { X, W }; W may
-- be small, or none.
function MobileLayout.topGap(screen: Vector2)
	local toast = MobileLayout.toast(screen)
	local left = topLeftRight() + 8
	local right = (if toast.Under then MobileLayout.wallet(screen).X else toast.X) - 8
	return { X = left, W = math.max(0, right - left) }
end

-- Under your health and teammates, right-aligned with them; where that
-- would reach the jump button, beside them on the left (Beside), if the
-- top left (your kaiju's card, the pick card) leaves room there.
function MobileLayout.loot(screen: Vector2)
	local l, health = MobileLayout.Loot, MobileLayout.health(screen)
	local x, y = health.X + health.W - l.W, columnBottom(screen) + l.Gap
	local beside = y + l.H > MobileLayout.jump(screen).Y and health.X - 8 - l.W >= topLeftRight() + 8
	if beside then
		x, y = health.X - 8 - l.W, health.Y
	end
	return { X = x, Y = y, W = l.W, H = l.H, Beside = beside,
		RowsBelow = y + l.H + l.Gap + l.Row <= screen.Y * 0.42 }
end

-- Who has the top (pure: no Roblox objects, so it's tested on its own).
local claims: { [string]: boolean } = {}
local listeners: { () -> () } = {}
function MobileLayout.claimTop(owner: string, on: boolean)
	if (claims[owner] == true) == on then
		return
	end
	claims[owner] = if on then true else nil
	for _, listener in listeners do
		local ok, err = pcall(listener)
		if not ok then
			warn("MobileLayout.onTop: " .. tostring(err))
		end
	end
end
function MobileLayout.topClaimed(except: string?): boolean
	for owner in claims do
		if owner ~= except then
			return true
		end
	end
	return false
end
function MobileLayout.onTop(listener: () -> ())
	table.insert(listeners, listener)
end

-- Your health, just under your level and coins (LobbyUI), as wide.
function MobileLayout.health(screen: Vector2)
	local wallet = MobileLayout.wallet(screen)
	return { X = wallet.X, Y = wallet.Y + wallet.H + 4, W = wallet.W, H = 20 }
end

-- Your kaiju's card on a phone (KaijuHud), small, at the top left, in a
-- fight too: two rows, the team's three and the support a little apart,
-- AUTO HEAL under them. The team keys and the HYPERBEAM aren't on it:
-- keys(screen), above the move stick, and beam(screen), right of them.
-- TameX, TameY, TameW, TameH: where CATCH goes on a touch screen, under it.
-- (`_hunting`: the same place either way now.)
function MobileLayout.kaiju(_screen: Vector2, _hunting: boolean?)
	local spec = MobileLayout.Kaiju
	local w, h = kaijuSize()
	return {
		X = 12,
		Y = 12,
		W = w,
		H = h,
		Pad = spec.Pad,
		Gap = spec.Gap,
		Split = spec.Split,
		Rows = { spec.Tile, spec.AutoH },
		Grid = true,
		TameX = 12,
		TameY = kaijuBottom() + 6,
		TameW = w,
		TameH = MobileLayout.Tame.H,
	}
end

-- The team keys 1 to 4 on a phone (KaijuHud): their own row, Size square,
-- just above the move stick, under your left thumb.
MobileLayout.Keys = { Size = 34, Gap = 5, Above = 8, Count = 4 }
function MobileLayout.keys(screen: Vector2)
	local k, stick = MobileLayout.Keys, MobileLayout.stick(screen)
	return {
		X = stick.X,
		Y = stick.Y - k.Above - k.Size,
		W = k.Size * k.Count + k.Gap * (k.Count - 1),
		H = k.Size,
		Size = k.Size,
		Gap = k.Gap,
	}
end

-- The team's HYPERBEAM on a phone (KaijuBeamHud): a button of its own, W
-- by H, just right of the team keys and level with their bottom (your
-- left thumb's row, over the kit switch). Its meter is its own rim (Rim
-- out round it), SAVE a strip along its bottom inside it.
MobileLayout.Beam = { W = 60, H = 52, Gap = 12, Rim = 3 }
function MobileLayout.beam(screen: Vector2)
	local b, keys = MobileLayout.Beam, MobileLayout.keys(screen)
	return { X = keys.X + keys.W + b.Gap, Y = keys.Y + keys.H - b.H, W = b.W, H = b.H, Rim = b.Rim }
end

-- The fight's foe list on a phone (FoeBars): on the right, at the top
-- (your coins and health hide in a fight), right-aligned with their
-- column, W wide, down to Bottom: just over DODGE, the fight's ring's top
-- (`viewY`: the camera's height, which sizes the ring), and over a toast's
-- place where the toasts come down there.
MobileLayout.Foes = { W = 150 }
function MobileLayout.foes(screen: Vector2, viewY: number?)
	local wallet, ring = MobileLayout.wallet(screen), MobileLayout.ring(viewY or screen.Y)
	local dodge = MobileLayout.onRing(screen, ring, ring.Dodge, ring.Outer, MobileLayout.Ring.Dodge)
	local toast = MobileLayout.toast(screen)
	local bottom = dodge.Y - 6
	if toast.Under then
		bottom = math.min(bottom, toast.Y - 6)
	end
	local w = MobileLayout.Foes.W
	return { X = wallet.X + wallet.W - w, Y = wallet.Y, W = w, Bottom = bottom }
end

-- The same card on a computer: bottom left, a fixed size, the pill's
-- lower half clear above the screen's edge (ChatFeed keeps its bottom
-- clear above it).
MobileLayout.KaijuDesk = { W = 276, Pad = 6, Gap = 6, Rows = { 58, 58 }, Notch = 24 }
-- The card's strip under its rows: the pill's upper half and a little air.
function MobileLayout.under(notch: number): number
	return math.floor(notch / 2) + 3
end
function MobileLayout.kaijuDesk(screen: Vector2)
	local spec = MobileLayout.KaijuDesk
	local h = spec.Pad + spec.Gap + spec.Rows[1] + spec.Rows[2] + MobileLayout.under(spec.Notch)
	return {
		X = 24,
		Y = screen.Y - 24 - spec.Notch / 2 - h,
		W = spec.W,
		H = h,
		Pad = spec.Pad,
		Gap = spec.Gap,
		Rows = table.clone(spec.Rows),
		Notch = spec.Notch,
	}
end

-- The card's cells, inside it (`card`: kaiju's or kaijuDesk's). A
-- computer's: the kaiju two by two on the left (Fighters 1 and 2 on top,
-- Fighter 3 and Support under them), Auto (AUTO HEAL) over Teams (the team
-- keys) on the right, and Beam, the HYPERBEAM's pill, across the middle of
-- the card's bottom edge (half below it). A phone's (Grid): the team's
-- three in a row and the support a little apart, Auto across the card
-- under them, no Teams or Beam (they're keys(screen) and beam(screen)).
function MobileLayout.kaijuCells(card)
	local pad, gap, rows = card.Pad, card.Gap, card.Rows
	if card.Grid then
		local t, split = rows[1], card.Split or gap
		local x = pad
		local fighters = {}
		for i = 1, 3 do
			fighters[i] = { X = x, Y = pad, W = t, H = t }
			x += t + (if i < 3 then gap else split)
		end
		local support = { X = x, Y = pad, W = t, H = t }
		local auto = { X = pad, Y = pad + t + gap, W = card.W - pad * 2, H = rows[2] }
		return { Fighters = fighters, Support = support, Auto = auto, Grid = true }
	end
	local notch = card.Notch or 22
	local beamW = math.floor(card.W * 0.78)
	local beam = { X = math.floor((card.W - beamW) / 2), Y = card.H - math.floor(notch / 2), W = beamW, H = notch }
	local cell = math.floor((card.W - pad * 2 - gap * 2) / 3)
	local function at(column: number, y: number, h: number)
		return { X = pad + (column - 1) * (cell + gap), Y = y, W = cell, H = h }
	end
	local y2 = pad + rows[1] + gap
	return {
		Fighters = { at(1, pad, rows[1]), at(2, pad, rows[1]), at(1, y2, rows[2]) },
		Support = at(2, y2, rows[2]),
		Auto = at(3, pad, rows[1]),
		Teams = at(3, y2, rows[2]),
		Beam = beam,
		Grid = false,
	}
end

-- The fight's ring of buttons on a touch screen (Client.Combat): ATTACK in
-- the bottom-right corner, the three surges round it (at Ring.Surges
-- degrees), GUARD and DODGE on an outer arc (Ring.Guard, Ring.Dodge); sized
-- to the screen's height (`height`: the camera's viewport's). Cx, Cy: its
-- centre, from the bottom-right corner.
MobileLayout.Ring = { Surges = { 180, 135, 90 }, Guard = 184, Dodge = 100 }
function MobileLayout.ring(height: number)
	local k = math.clamp(height / 380, 0.8, 1.3)
	local A, S, M, G = math.floor(86 * k), math.floor(58 * k), math.floor(50 * k), math.floor(56 * k)
	local margin = math.floor(12 * k)
	local inner = A / 2 + S / 2 + 8 * k
	return {
		K = k,
		Attack = A,
		Surge = S,
		Dodge = M,
		Guard = G,
		Margin = margin,
		Cx = margin + A / 2,
		Cy = margin + A / 2,
		Inner = inner,
		Outer = inner + S / 2 + G / 2 + 8 * k,
	}
end

-- A button `size` across at `degrees` and `radius` round the ring's centre,
-- as a rect on `screen` (as Client.Combat places it).
function MobileLayout.onRing(screen: Vector2, ring, size: number, radius: number, degrees: number)
	local a = math.rad(degrees)
	local x = screen.X - ring.Cx + math.floor(radius * math.cos(a))
	local y = screen.Y - ring.Cy - math.floor(radius * math.sin(a))
	return { X = x - size / 2, Y = y - size / 2, W = size, H = size }
end

-- How far right the fight's vitals may reach on a touch screen: short of
-- the ring, with some room to spare.
local function vitalsRight(viewport: Vector2, ring): number
	local reserve = math.floor(math.clamp(viewport.X * 0.035, 16, 44))
	return viewport.X - (ring.Cx + reserve + ring.Outer + ring.Guard / 2 + 14 * ring.K)
end

-- The kit switch (Client.SparKit: your pick or your combat kit): just to
-- the left of PLAY, level with it and a touch taller (H, big enough to
-- tap), a pill with its icon and word. Where the room between PLAY and the
-- thumbstick's corner is short, it's narrower, down to round with just its
-- icon (Icon: narrower than this, no word). It stays put with your kit out
-- (PLAY's gone then; `viewport`: the camera's, the fight's ring and vitals
-- up), the vitals keeping to its right (MobileLayout.vitals); if that would
-- leave them under Room wide, it's round, from the same left edge.
MobileLayout.KitSwitch = { W = 100, H = 44, Gap = 8, Icon = 80, Room = 200 }
function MobileLayout.kitSwitch(screen: Vector2, viewport: Vector2?)
	local spec = MobileLayout.KitSwitch
	local dock = MobileLayout.dock(screen, 1)
	local playLeft = math.floor((screen.X - dock.PlayWidth) / 2)
	local stick = MobileLayout.stick(screen)
	local room = playLeft - spec.Gap - (stick.X + stick.W + spec.Gap)
	local w = math.clamp(room, spec.H, spec.W)
	local rect = {
		X = playLeft - spec.Gap - w,
		Y = dock.Y + math.floor((dock.PlayHeight - spec.H) / 2),
		W = w,
		H = spec.H,
	}
	if viewport then
		local right = vitalsRight(viewport, MobileLayout.ring(viewport.Y))
		if right - (rect.X + rect.W + 8) < spec.Room then
			rect.W = spec.H
		end
	end
	return rect
end

-- The fight's vitals on a touch screen (Client.Combat): between the move
-- stick's side (the left fifth) and the ring (with the room they had
-- before the ring moved to the edge, so they keep their layout), and right
-- of `clear` too when given (a rect: the kit switch, up in the lobby with
-- your kit out). 240 to 420 wide; narrower (down to 160) only to keep
-- clear of it. X, W, and Centre (its middle).
function MobileLayout.vitals(viewport: Vector2, ring, clear)
	local left = viewport.X * 0.2
	if clear then
		left = math.max(left, clear.X + clear.W + 8)
	end
	local right = vitalsRight(viewport, ring)
	local room = right - left
	local least = if clear then math.clamp(room, 160, 240) else 240
	local width = math.clamp(room, least, 420)
	local centre = math.max(left + width / 2, math.min(right - width / 2, viewport.X / 2))
	return { X = centre - width / 2, W = width, Centre = centre }
end

function MobileLayout.overlaps(a, b): boolean
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

return MobileLayout
