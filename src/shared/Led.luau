--[[
	The Outpost's LED screens (four round Arena Row, World.OutpostWorld's
	LedScreens; Client.LedScreens lights them): what's on them, as pixels.
	A screen is W x H LEDs; a page is a buffer of them, each off (nil) or one
	colour (0xRRGGBB). Text is Shared.LedFont's 3x5; pictures are Shared.
	LedArt's (the game's art, converted by tools/led_art.py).

	Each screen has a board of its own (Server.Boards publishes what's on
	them) and shows its pages one at a time:

	  Ranked    north, to the pods: this server's ranked 1v1 ladder
	  Live      east: Arena Row now, ring by ring, and who's fighting
	  Miners    south, to the plaza: the most rocks mined
	  Hunters   west: the most Rift bosses beaten

	  Led.W, Led.H, Led.Boards
	  Led.new() -> buffer;  Led.get(buffer, x, y) -> rgb?
	  Led.text(buffer, x, y, text, rgb) -> width;  Led.width(text)
	  Led.center(buffer, y, text, rgb);  Led.art(buffer, art, x, y)
	  Led.fit(text, chars) -> text   capitals the font has, cut to fit
	  Led.pages(board, data) -> { buffer }   a board's pages from its data
]]
local LedFont = require(script.Parent.LedFont)
local LedArt = require(script.Parent.LedArt)

local Led = {}
Led.W, Led.H = 72, 30
Led.Chars = math.floor((Led.W + 1) / LedFont.Advance) -- (18 across)
Led.Line = LedFont.Height + 1
Led.Boards = { "Ranked", "Live", "Miners", "Hunters" }

local function rgb(r: number, g: number, b: number): number
	return r * 65536 + g * 256 + b
end
Led.rgb = rgb
local CYAN, WHITE, GOLD, SILVER, COPPER, DIM, GOOD =
	rgb(110, 220, 255), rgb(235, 242, 249), rgb(255, 202, 91), rgb(200, 206, 216), rgb(217, 138, 78), rgb(110, 122, 150), rgb(90, 220, 150)
Led.Colors = { Cyan = CYAN, White = WHITE, Gold = GOLD, Dim = DIM, Good = GOOD }

function Led.new()
	return { W = Led.W, H = Led.H, P = {} }
end

function Led.set(buffer, x: number, y: number, color: number?)
	if x >= 0 and y >= 0 and x < buffer.W and y < buffer.H then
		buffer.P[y * buffer.W + x + 1] = color
	end
end

function Led.get(buffer, x: number, y: number): number?
	return buffer.P[y * buffer.W + x + 1]
end

-- Capitals the font has (the rest dropped), at most `chars` of them.
function Led.fit(text: any, chars: number?): string
	local out = {}
	for _, code in utf8.codes(tostring(text or "")) do
		local ch = string.upper(utf8.char(code))
		if #ch == 1 and LedFont.glyph(ch) then
			table.insert(out, ch)
		end
	end
	local s = table.concat(out)
	if chars and #s > chars then
		s = string.sub(s, 1, chars)
	end
	return s
end

function Led.width(text: string): number
	return math.max(0, #text * LedFont.Advance - 1)
end

function Led.text(buffer, x: number, y: number, text: string, color: number): number
	text = Led.fit(text)
	for i = 1, #text do
		local rows = LedFont.glyph(string.sub(text, i, i))
		if rows then
			for dy, row in rows do
				for dx = 1, #row do
					if string.sub(row, dx, dx) == "#" then
						Led.set(buffer, x + (i - 1) * LedFont.Advance + dx - 1, y + dy - 1, color)
					end
				end
			end
		end
	end
	return Led.width(text)
end

function Led.center(buffer, y: number, text: string, color: number)
	text = Led.fit(text, Led.Chars)
	Led.text(buffer, math.floor((buffer.W - Led.width(text)) / 2), y, text, color)
end

-- Right-aligned to `right` (the last column it may light).
local function rightText(buffer, right: number, y: number, text: string, color: number)
	text = Led.fit(text)
	Led.text(buffer, right - Led.width(text) + 1, y, text, color)
end

local DIGITS = "0123456789abcde"
function Led.art(buffer, art, x: number, y: number)
	if type(art) ~= "table" then
		return
	end
	for dy, row in art.Rows do
		for dx = 1, #row do
			local index = string.find(DIGITS, string.sub(row, dx, dx), 1, true)
			local c = index and art.Palette[index]
			if c then
				Led.set(buffer, x + dx - 1, y + dy - 1, rgb(c[1], c[2], c[3]))
			end
		end
	end
end

-- A title page: the picture on the left, the words right of it.
local function titlePage(art, lines: { { string } })
	local b = Led.new()
	local pic = LedArt[art]
	local w = if pic then pic.W else 0
	if pic then
		Led.art(b, pic, 1, math.floor((Led.H - pic.H) / 2))
	end
	local left = w + 4
	local chars = math.floor((Led.W - left + 1) / LedFont.Advance)
	local top = math.floor((Led.H - #lines * Led.Line + 1) / 2)
	for i, line in lines do
		local text = Led.fit(line[1], chars)
		local x = left + math.floor((Led.W - left - Led.width(text)) / 2)
		Led.text(b, x, top + (i - 1) * Led.Line, text, line[2])
	end
	return b
end

-- The place's colour: gold, silver and copper for the top three.
local function placeColor(place: number): number
	return if place == 1 then GOLD elseif place == 2 then SILVER elseif place == 3 then COPPER else WHITE
end

-- A ladder page: its heading, then up to four rows "1 NAME ... 1234".
local function ladderPage(heading: string, rows, from: number)
	local b = Led.new()
	Led.center(b, 0, heading, CYAN)
	for i = 0, 3 do
		local row = rows[from + i]
		if not row then
			break
		end
		local place = from + i
		local y = Led.Line + 1 + i * Led.Line
		local value = Led.fit(row.Value, 5)
		local nameChars = Led.Chars - 3 - #value
		Led.text(b, 0, y, tostring(place), placeColor(place))
		Led.text(b, (if place >= 10 then 3 else 2) * LedFont.Advance, y, Led.fit(row.Name, nameChars), placeColor(place))
		rightText(b, Led.W - 1, y, value, GOLD)
	end
	return b
end

local function ladder(art: string, title: { { string } }, heading: string, rows, empty: { { string } })
	local pages = { titlePage(art, title) }
	if #rows == 0 then
		table.insert(pages, titlePage(nil, empty))
		return pages
	end
	for from = 1, math.min(#rows, 12), 4 do
		table.insert(pages, ladderPage(heading, rows, from))
	end
	return pages
end

-- Arena Row now: a page of the rings, then one for each fight on.
local SHORT = { IntroRing = "INTRO", GrandArena = "GRAND", DuelRingWest = "WEST", DuelRingEast = "EAST" }
local function live(data)
	local rings = (type(data) == "table" and data.Rings) or {}
	local b = Led.new()
	Led.center(b, 0, "ARENA ROW", CYAN)
	local fights = {}
	for i, ring in rings do
		if i > 4 then
			break
		end
		local y = Led.Line + 1 + (i - 1) * Led.Line
		Led.text(b, 0, y, SHORT[ring.Name] or Led.fit(ring.Name, 5), WHITE)
		local busy = type(ring.Fighters) == "table" and #ring.Fighters > 0
		rightText(b, Led.W - 1, y, if busy then "FIGHT ON" else "OPEN", if busy then GOOD else DIM)
		if busy then
			table.insert(fights, ring)
		end
	end
	local pages = { b }
	for _, ring in fights do
		local f = Led.new()
		Led.center(f, 0, (SHORT[ring.Name] or "") .. " RING", CYAN)
		Led.center(f, Led.Line + 2, ring.Fighters[1] or "", WHITE)
		Led.center(f, 2 * Led.Line + 2, if ring.Fighters[2] then "VS" else "", GOLD)
		Led.center(f, 3 * Led.Line + 2, ring.Fighters[2] or "PRACTICE", WHITE)
		table.insert(pages, f)
	end
	if #fights == 0 then
		table.insert(pages, titlePage("Shield", { { "DUEL", GOLD }, { "PLAY >", WHITE }, { "1V1", WHITE } }))
	end
	return pages
end

function Led.pages(board: string, data: any): { any }
	local rows = (type(data) == "table" and type(data.Rows) == "table" and data.Rows) or {}
	if board == "Ranked" then
		return ladder("Shield", { { "RANKED", GOLD }, { "1V1", WHITE }, { "LADDER", WHITE } }, "RANKED 1V1", rows, { { "NO RANKED", WHITE }, { "FIGHTS YET", WHITE } })
	elseif board == "Miners" then
		local gems = { "FireGem", "FrostGem", "ShockGem", "PoisonGem" }
		local art = gems[((type(data) == "table" and tonumber(data.Turn)) or 0) % #gems + 1]
		return ladder(art, { { "TOP", GOLD }, { "MINERS", WHITE }, { "ROCKS", DIM } }, "ROCKS MINED", rows, { { "GO MINE", WHITE }, { "A ROCK!", WHITE } })
	elseif board == "Hunters" then
		return ladder("Chest", { { "BOSS", GOLD }, { "HUNTERS", WHITE }, { "THE RIFT", DIM } }, "BOSSES BEATEN", rows, { { "BEAT A", WHITE }, { "RIFT BOSS", WHITE } })
	elseif board == "Live" then
		return live(data)
	end
	return { Led.new() }
end

return Led
