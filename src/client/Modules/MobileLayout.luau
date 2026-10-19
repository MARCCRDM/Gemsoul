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
	  top middle    your loot card (MinerLoot), slim, between the pick card
	                and the TASKS button, clear of the board's strip; the
	                live feed (LobbyFeed) steps aside while it's up
	                (claimTop): the middle of the screen stays the game's
	  top right     the TASKS button (TrainingRewards), the board's one slim
	                strip (LobbyBoard) close under it, and teammates' health
	                (PartyUI), hidden in a fight
	  bottom middle the dock (LobbyUI): PLAY, and a row of tiles under it

	Rects are { X, Y, W, H } in the ScreenGui's space (below the top bar).

	  MobileLayout.card()                  the pick card
	  MobileLayout.wallet()                level and coins
	  MobileLayout.chat(screen, open)      the chat box: CHAT button, or opened
	  MobileLayout.dock(screen, tiles)     the dock, its PLAY and tile size
	  MobileLayout.party(screen)           the teammates' cards
	  MobileLayout.tasks(screen)           the TASKS button
	  MobileLayout.board(screen)           the board's strip, under TASKS
	  MobileLayout.loot(screen)            your loot card: top middle, as
	                                       wide as fits (Loot.W at most)
	  MobileLayout.claimTop(owner, on)     something has the top middle (a
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
	                                       far up it sits, so the loot card
	                                       (MinerLoot) goes above it
]]
local MobileLayout = {}

MobileLayout.CardScale = 0.7
MobileLayout.Margin = 12
MobileLayout.Drive = { W = 160, H = 38, Bottom = 62 }
MobileLayout.Tasks = { W = 112, H = 34 }
MobileLayout.Board = { W = 236, H = 38 }
MobileLayout.Loot = { W = 250, MinW = 170, H = 56, ShortH = 44, Top = 8 }

function MobileLayout.card()
	return { X = 12, Y = 12, W = 300 * MobileLayout.CardScale, H = 100 * MobileLayout.CardScale }
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

function MobileLayout.tasks(screen: Vector2)
	local t = MobileLayout.Tasks
	return { X = screen.X - 16 - t.W, Y = 12, W = t.W, H = t.H }
end

function MobileLayout.board(screen: Vector2)
	local tasks, b = MobileLayout.tasks(screen), MobileLayout.Board
	return { X = screen.X - 16 - b.W, Y = tasks.Y + tasks.H + 6, W = b.W, H = b.H }
end

-- Between the pick card and TASKS, and clear of the board's strip under
-- it. On a small phone, where that leaves it too narrow, it's shorter
-- instead (Loot.ShortH: done above the strip) and as wide as up to TASKS.
function MobileLayout.loot(screen: Vector2)
	local l = MobileLayout.Loot
	local card, tasks, board = MobileLayout.card(), MobileLayout.tasks(screen), MobileLayout.board(screen)
	local left = card.X + card.W + 8
	local right, height = tasks.X - 8, l.H
	if l.Top + height > board.Y then
		local clear = math.min(right, board.X - 8)
		if clear - left >= l.W or l.Top + l.ShortH > board.Y then
			right = clear
		else
			height = l.ShortH
		end
	end
	local width = math.clamp(right - left, l.MinW, l.W)
	return { X = math.floor(left + (right - left - width) / 2), Y = l.Top, W = width, H = height }
end

-- Who has the top middle (pure: no Roblox objects, so it's tested on its own).
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
