--[[
	Where the lobby's pieces sit on a phone, in one place so they can't drift
	onto each other (tests/mobile_layout_cases checks every phone size):

	  top left      the pick card (OutpostScene), drawn at CardScale, and
	                the CHAT button under it; opened, the chat is a column
	                down the left that stops above the dock (and the card
	                steps aside while it's open)
	  bottom middle the dock (LobbyUI): PLAY, and a row of tiles under it
	  top right     teammates' health (PartyUI), hidden in a fight

	Rects are { X, Y, W, H } in the ScreenGui's space (below the top bar).

	  MobileLayout.card()                  the pick card
	  MobileLayout.chat(screen, open)      the chat box: CHAT button, or opened
	  MobileLayout.dock(screen, tiles)     the dock, its PLAY and tile size
	  MobileLayout.party(screen)           the teammates' cards
]]
local MobileLayout = {}

MobileLayout.CardScale = 0.7
MobileLayout.Margin = 12

function MobileLayout.card()
	return { X = 12, Y = 12, W = 300 * MobileLayout.CardScale, H = 100 * MobileLayout.CardScale }
end

function MobileLayout.dock(screen: Vector2, tiles: number)
	-- Clear of Roblox's jump button at the bottom right (and as wide on the left).
	local width = math.min(420, math.max(240, screen.X - 280))
	local gap, tileHeight, playHeight = 6, 34, 44
	local height = playHeight + 8 + tileHeight
	return {
		X = (screen.X - width) / 2,
		Y = screen.Y - MobileLayout.Margin - height,
		W = width,
		H = height,
		Gap = gap,
		TileWidth = math.floor((width - gap * math.max(0, tiles - 1)) / math.max(1, tiles)),
		TileHeight = tileHeight,
	}
end

function MobileLayout.chat(screen: Vector2, open: boolean)
	local card = MobileLayout.card()
	if not open then
		return { X = 12, Y = card.Y + card.H + 10, W = 76, H = 44 }
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

function MobileLayout.overlaps(a, b): boolean
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

return MobileLayout
