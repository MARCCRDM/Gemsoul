--[[
	Where the lobby's pieces sit on a phone, in one place so they can't drift
	onto each other (tests/mobile_layout_cases checks every phone size):

	  top left      the pick card (OutpostScene), drawn at CardScale, and
	                your level and coins (LobbyUI) in a pill under it. On a
	                small screen with a keyboard, the CHAT button goes under
	                that; opened, the chat is a column down the left that
	                stops above the dock (and the card steps aside while it's
	                open). Phones and tablets use Roblox's own chat instead
	                (ChatFrame).
	  top middle    the live feed (LobbyFeed), between the pick card and
	                the toasts' place
	  top right     a toast (UiKit.toast), one line here, as wide as its
	                words; under it, right-aligned with it, your loot card
	                (MinerLoot), slim, and one row under that (a toast that
	                wraps to more lines pushes it down while it's up). Both
	                keep clear of the slim tab Roblox puts on a phone's
	                right edge. The live feed steps aside while the loot
	                card is up (claimTop). Under them, teammates' health
	                (PartyUI), hidden in a fight. Nothing else: tasks and
	                the day's challenges open from the dock's TASKS tile,
	                and the lobby's board isn't shown
	  bottom middle the dock (LobbyUI): PLAY, and a row of tiles under it

	Rects are { X, Y, W, H } in the ScreenGui's space (below the top bar).

	  MobileLayout.card()                  the pick card
	  MobileLayout.wallet()                level and coins
	  MobileLayout.chat(screen, open)      the chat box: CHAT button, or opened
	  MobileLayout.dock(screen, tiles)     the dock, its PLAY and tile size
	  MobileLayout.party(screen)           the teammates' cards
	  MobileLayout.toast(screen)           a toast's place: top right, Toast.W
	                                       at most, one line (Toast.H)
	  MobileLayout.loot(screen)            your loot card: under the toast,
	                                       right-aligned with it
	  MobileLayout.claimTop(owner, on)     something has the top (a
	                                       loot card); topClaimed(except?)
	                                       says if anything else does, and
	                                       onTop(fn) hears when that changes
	  MobileLayout.kaiju(screen, hunting)  your kaiju's card (KaijuHud), three
	                                       by three, right of your coins (top
	                                       right while you hunt), and CATCH;
	                                       kaijuDesk(screen) on a computer,
	                                       kaijuCells(card) its cells
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

MobileLayout.CardScale = 0.7
MobileLayout.Margin = 12
MobileLayout.Drive = { W = 160, H = 38, Bottom = 62 }
MobileLayout.Stick = { Size = 112, Knob = 46, Left = 20, Bottom = 16 }
-- (Right: from the screen's right edge, clear of Roblox's tab there.)
MobileLayout.Toast = { W = 240, H = 28, Top = 8, Right = 30 }
MobileLayout.Loot = { W = 232, H = 72, Row = 24, Gap = 6 }

function MobileLayout.card()
	return { X = 12, Y = 12, W = 300 * MobileLayout.CardScale, H = 100 * MobileLayout.CardScale }
end

function MobileLayout.stick(screen: Vector2)
	local stick = MobileLayout.Stick
	return { X = stick.Left, Y = screen.Y - stick.Bottom - stick.Size, W = stick.Size, H = stick.Size }
end

function MobileLayout.wallet()
	local card = MobileLayout.card()
	return { X = 12, Y = card.Y + card.H + 8, W = 150, H = 30 }
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
	local health = MobileLayout.health()
	if not open then
		return { X = 12, Y = health.Y + health.H + 6, W = 76, H = 44 }
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

function MobileLayout.party(screen: Vector2)
	return { X = screen.X - 16 - 220, Y = 132, W = 220, H = 40 }
end

function MobileLayout.toast(screen: Vector2)
	local t = MobileLayout.Toast
	return { X = screen.X - t.Right - t.W, Y = t.Top, W = t.W, H = t.H }
end

-- Under the toast's place, right-aligned with it.
function MobileLayout.loot(screen: Vector2)
	local l, toast = MobileLayout.Loot, MobileLayout.toast(screen)
	local y = toast.Y + toast.H + l.Gap
	return { X = toast.X + toast.W - l.W, Y = y, W = l.W, H = l.H,
		RowsBelow = y + l.H + l.Gap + l.Row <= math.min(screen.Y * 0.42, MobileLayout.party(screen).Y - 6) }
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
function MobileLayout.health()
	local wallet = MobileLayout.wallet()
	return { X = wallet.X, Y = wallet.Y + wallet.H + 4, W = wallet.W, H = 20 }
end

-- Your kaiju's card (KaijuHud): one card, three across and three down: the
-- team's three on top, then the support beside AUTO HEAL and CALL BACK, and
-- the team's HYPERBEAM (KaijuBeamHud) along the bottom. On a phone it sits
-- right of your coins and health, as tall as there's room for above the
-- dock (down to Max); while you hunt, up at the top right (the fight's foe
-- list has the top left then), clear of the teammates' cards. TameX, TameY,
-- TameW, TameH: where CATCH goes on a touch screen (the top right; left of
-- the card while you hunt).
MobileLayout.Kaiju = { W = 172, Pad = 4, Gap = 3, Max = 124, Split = { 0.36, 0.36 } }
function MobileLayout.kaiju(screen: Vector2, hunting: boolean?)
	local spec = MobileLayout.Kaiju
	local x, y, room
	if hunting then
		x, y = screen.X - 12 - spec.W, 12
		room = MobileLayout.party(screen).Y - 6 - y
	else
		local wallet = MobileLayout.wallet()
		x, y = wallet.X + wallet.W + 8, wallet.Y
		room = MobileLayout.dock(screen, 5).Y - 6 - y
	end
	local h = math.min(spec.Max, room)
	local inner = h - spec.Pad * 2 - spec.Gap * 2
	local r1 = math.floor(inner * spec.Split[1])
	local r2 = math.floor(inner * spec.Split[2])
	local tameW = math.min(210, screen.X - 24)
	return {
		X = x,
		Y = y,
		W = spec.W,
		H = h,
		Pad = spec.Pad,
		Gap = spec.Gap,
		Rows = { r1, r2, inner - r1 - r2 },
		TameX = if hunting then x - 8 - tameW else screen.X - 12 - tameW,
		TameY = if hunting then 12 else 52,
		TameW = tameW,
		TameH = 90,
	}
end

-- The same card on a computer: bottom left, a fixed size (ChatFeed keeps
-- its bottom clear above it).
MobileLayout.KaijuDesk = { W = 276, Pad = 6, Gap = 6, Rows = { 58, 58, 46 } }
function MobileLayout.kaijuDesk(screen: Vector2)
	local spec = MobileLayout.KaijuDesk
	local h = spec.Pad * 2 + spec.Gap * 2 + spec.Rows[1] + spec.Rows[2] + spec.Rows[3]
	return {
		X = 24,
		Y = screen.Y - 24 - h,
		W = spec.W,
		H = h,
		Pad = spec.Pad,
		Gap = spec.Gap,
		Rows = table.clone(spec.Rows),
	}
end

-- The card's cells, inside it (`card`: kaiju's or kaijuDesk's): the kaiju
-- two by two on the left (Fighters 1 and 2 on top, Fighter 3 and Support
-- under them), Auto (AUTO HEAL) over Call (CALL BACK) on the right, and
-- Beam the width of the bottom row.
function MobileLayout.kaijuCells(card)
	local pad, gap, rows = card.Pad, card.Gap, card.Rows
	local cell = math.floor((card.W - pad * 2 - gap * 2) / 3)
	local function at(column: number, y: number, h: number)
		return { X = pad + (column - 1) * (cell + gap), Y = y, W = cell, H = h }
	end
	local y2 = pad + rows[1] + gap
	local y3 = y2 + rows[2] + gap
	return {
		Fighters = { at(1, pad, rows[1]), at(2, pad, rows[1]), at(1, y2, rows[2]) },
		Support = at(2, y2, rows[2]),
		Auto = at(3, pad, rows[1]),
		Call = at(3, y2, rows[2]),
		Beam = { X = pad, Y = y3, W = card.W - pad * 2, H = rows[3] },
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
