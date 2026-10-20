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
	  MobileLayout.kaiju(chat)             your kaiju's card (KaijuHud), under
	                                       the coins (beside the CHAT button,
	                                       if there is one), TAME beside it
	  MobileLayout.Drive                   a mech's HOP OUT button (VehicleDrive),
	                                       bottom middle on every screen, in
	                                       PLAY's place on a phone (PLAY hides
	                                       while you pilot): its size and how
	                                       far up it sits
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
MobileLayout.Loot = { W = 196, H = 56, Row = 24, Gap = 6 }

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
	local wallet = MobileLayout.wallet()
	if not open then
		return { X = 12, Y = wallet.Y + wallet.H + 8, W = 76, H = 44 }
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
	return { X = toast.X + toast.W - l.W, Y = toast.Y + toast.H + l.Gap, W = l.W, H = l.H }
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

function MobileLayout.kaiju(chat: boolean?)
	local wallet = MobileLayout.wallet()
	local x, y = 12, wallet.Y + wallet.H + 8
	if chat then
		-- (Beside the CHAT button: under it, a short screen runs into the dock.)
		local button = MobileLayout.chat(Vector2.zero, false)
		x, y = button.X + button.W + 8, button.Y
	end
	return { X = x, Y = y, W = 236, H = 50, TameX = x + 236 + 8, TameW = 86 }
end

function MobileLayout.overlaps(a, b): boolean
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

return MobileLayout
