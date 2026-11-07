--[[
	The Outpost's LED screens (four giants in the sky round the settlement,
	World.OutpostWorld's LedScreens; Client.LedScreens lights them): guides
	and tips, animated, as pixels. A screen is W x H LEDs; a frame is a
	buffer of them, each off (nil) or one colour (0xRRGGBB). Text is
	Shared.LedFont's 3x5 (twice the size for titles); pictures are Shared.
	LedArt's (the game's art and its kaiju and bosses, converted by
	tools/led_art.py).

	Each screen plays its board's scenes one after another, each a few
	seconds of animation:

	  Guide      north, to the pods: welcome, mining for gems, enchanting
	             your armor, the HYPERBEAM, your pod, Arena Row
	  Elements   east: each element, its own animation (Thermal's embers,
	             Cryo's snow, Ion's lightning, Corrosive's bubbles)
	  Bounties   south, to the plaza: the Rift's bosses, WANTED, what
	             they are and what they're weak to
	  Kaiju      west: the kaiju, one by one, and what each one does

	  Led.W, Led.H, Led.Boards, Led.ElementNames
	  Led.new() -> buffer;  Led.get(buffer, x, y) -> rgb?
	  Led.text(buffer, x, y, text, rgb, scale?) -> width;  Led.width(text, scale?)
	  Led.center(buffer, y, text, rgb, scale?);  Led.art(buffer, art, x, y, tint?, k?)
	  Led.fit(text, chars) -> text   capitals the font has, cut to fit
	  Led.scenes(board, info) -> { { Duration, Draw = (t) -> buffer } }
	      info: { Kaiju = { { Art, Name, Role } }, Bosses = { { Art, Name,
	      Element, Weakness, Threat } } } (Client.LedScreens, from the
	      game's own data)
]]
local LedFont = require(script.Parent.LedFont)
local LedArt = require(script.Parent.LedArt)

local Led = {}
Led.W, Led.H = 72, 30
Led.Chars = math.floor((Led.W + 1) / LedFont.Advance) -- (18 across)
Led.Line = LedFont.Height + 1
Led.Boards = { "Guide", "Elements", "Bounties", "Kaiju" }
Led.ElementNames = { Fire = "THERMAL", Frost = "CRYO", Shock = "ION", Poison = "CORROSIVE" }

local function rgb(r: number, g: number, b: number): number
	r, g, b = math.clamp(math.floor(r + 0.5), 0, 255), math.clamp(math.floor(g + 0.5), 0, 255), math.clamp(math.floor(b + 0.5), 0, 255)
	return r * 65536 + g * 256 + b
end
local function split(c: number): (number, number, number)
	return c // 65536 % 256, c // 256 % 256, c % 256
end
-- `a` toward `b`, `k` of the way.
local function mix(a: number, b: number, k: number): number
	local r1, g1, b1 = split(a)
	local r2, g2, b2 = split(b)
	return rgb(r1 + (r2 - r1) * k, g1 + (g2 - g1) * k, b1 + (b2 - b1) * k)
end
local function scale(c: number, k: number): number
	local r, g, b = split(c)
	return rgb(r * k, g * k, b * k)
end
Led.rgb, Led.mix = rgb, mix

local CYAN, WHITE, GOLD, DIM, GOOD, RED =
	rgb(110, 220, 255), rgb(235, 242, 249), rgb(255, 202, 91), rgb(110, 122, 150), rgb(90, 220, 150), rgb(255, 70, 60)
Led.Colors = { Cyan = CYAN, White = WHITE, Gold = GOLD, Dim = DIM, Good = GOOD, Red = RED }
local ELEMENT = { Fire = rgb(255, 92, 60), Frost = rgb(90, 170, 255), Shock = rgb(255, 214, 50), Poison = rgb(90, 225, 100) }
Led.ElementColors = ELEMENT
local ELEMENTS = { "Fire", "Frost", "Shock", "Poison" }
local GEM = { Fire = "FireGem", Frost = "FrostGem", Shock = "ShockGem", Poison = "PoisonGem" }
local SMALL = { Fire = "SmallFire", Frost = "SmallFrost", Shock = "SmallShock", Poison = "SmallPoison" }

-- A steady pseudo-random 0..1 for `n` (the same every time: frames repeat).
local function hash(n: number): number
	local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

function Led.new()
	return { W = Led.W, H = Led.H, P = {} }
end

function Led.set(buffer, x: number, y: number, color: number?)
	x, y = math.floor(x), math.floor(y)
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

function Led.width(text: string, size: number?): number
	size = size or 1
	return math.max(0, (#text * LedFont.Advance - 1) * size)
end

function Led.text(buffer, x: number, y: number, text: string, color: number, size: number?): number
	size = size or 1
	text = Led.fit(text)
	for i = 1, #text do
		local rows = LedFont.glyph(string.sub(text, i, i))
		if rows then
			for dy, row in rows do
				for dx = 1, #row do
					if string.sub(row, dx, dx) == "#" then
						local px = x + ((i - 1) * LedFont.Advance + dx - 1) * size
						local py = y + (dy - 1) * size
						for sx = 0, size - 1 do
							for sy = 0, size - 1 do
								Led.set(buffer, px + sx, py + sy, color)
							end
						end
					end
				end
			end
		end
	end
	return Led.width(text, size)
end

function Led.center(buffer, y: number, text: string, color: number, size: number?)
	size = size or 1
	text = Led.fit(text, math.floor((Led.W + size) / (LedFont.Advance * size)))
	Led.text(buffer, math.floor((buffer.W - Led.width(text, size)) / 2), y, text, color, size)
end

-- Centred in the columns [left, right].
local function centerIn(buffer, left: number, right: number, y: number, text: string, color: number)
	text = Led.fit(text, math.floor((right - left + 2) / LedFont.Advance))
	Led.text(buffer, left + math.floor((right - left + 1 - Led.width(text)) / 2), y, text, color)
end

local DIGITS = "0123456789abcde"
-- A picture at (x, y): `tint` (with `k`, 0..1) pulls its colours toward one.
function Led.art(buffer, art, x: number, y: number, tint: number?, k: number?)
	if type(art) == "string" then
		art = LedArt[art]
	end
	if type(art) ~= "table" then
		return
	end
	local colors = {}
	for i, c in art.Palette do
		local own = rgb(c[1], c[2], c[3])
		colors[i] = if tint and k then mix(own, tint, k) else own
	end
	for dy, row in art.Rows do
		for dx = 1, #row do
			local index = string.find(DIGITS, string.sub(row, dx, dx), 1, true)
			if index and colors[index] then
				Led.set(buffer, x + dx - 1, y + dy - 1, colors[index])
			end
		end
	end
end

local function artSize(name: string): (number, number)
	local art = LedArt[name]
	return if art then art.W else 0, if art then art.H else 0
end

-- Wraps `text` into lines of at most `chars`, by words.
local function wrap(text: string, chars: number): { string }
	local lines, line = {}, ""
	for word in string.gmatch(Led.fit(text), "[^ ]+") do
		if line == "" then
			line = word
		elseif #line + 1 + #word <= chars then
			line ..= " " .. word
		else
			table.insert(lines, line)
			line = word
		end
	end
	if line ~= "" then
		table.insert(lines, line)
	end
	return lines
end

-- Sparkles: `count` of them, each blinking at its own spot, in `color`.
local function sparkles(b, t: number, count: number, color: number, seed: number?)
	seed = seed or 0
	for i = 1, count do
		local period = 0.8 + hash(i + seed) * 1.4
		local phase = (t / period + hash(i * 7 + seed)) % 1
		local cycle = math.floor(t / period + hash(i * 7 + seed))
		if phase < 0.35 then
			local x = math.floor(hash(i * 3 + cycle * 31 + seed) * Led.W)
			local y = math.floor(hash(i * 5 + cycle * 17 + seed) * Led.H)
			if not Led.get(b, x, y) then
				local k = 1 - math.abs(phase / 0.35 * 2 - 1)
				Led.set(b, x, y, scale(color, 0.35 + 0.65 * k))
			end
		end
	end
end

-- A bright band sweeping across whatever's lit.
local function shimmer(b, t: number, speed: number?)
	local pos = (t * (speed or 40)) % (Led.W + Led.H + 30) - 15
	for y = 0, Led.H - 1 do
		for x = 0, Led.W - 1 do
			local c = Led.get(b, x, y)
			if c then
				local d = math.abs((x + y) - pos)
				if d < 4 then
					Led.set(b, x, y, mix(c, WHITE, (1 - d / 4) * 0.8))
				end
			end
		end
	end
end

-- A ring of `color` round (cx, cy), `r` across.
local function ring(b, cx: number, cy: number, r: number, color: number)
	local steps = math.max(12, math.floor(r * 7))
	for i = 0, steps - 1 do
		local a = i / steps * math.pi * 2
		Led.set(b, cx + math.cos(a) * r, cy + math.sin(a) * r * 0.9, color)
	end
end

-- Each element's weather, over the whole screen at time `t`.
local WEATHER = {}
function WEATHER.Fire(b, t: number)
	for i = 1, 26 do
		local speed = 6 + hash(i) * 8
		local x = math.floor(hash(i * 2) * Led.W + math.sin(t * 2 + i) * 1.5)
		local life = (t * speed / Led.H + hash(i * 3)) % 1
		local y = Led.H - 1 - life * Led.H
		local c = if life < 0.4 then rgb(255, 230, 120) elseif life < 0.75 then rgb(255, 140, 50) else rgb(200, 50, 30)
		if not Led.get(b, x, y) then
			Led.set(b, x, y, scale(c, 1 - life * 0.6))
		end
	end
end
function WEATHER.Frost(b, t: number)
	for i = 1, 30 do
		local speed = 3 + hash(i) * 4
		local x = math.floor(hash(i * 2) * Led.W + math.sin(t * 1.3 + i * 2) * 2)
		local y = ((t * speed + hash(i * 3) * Led.H) % (Led.H + 2)) - 1
		if not Led.get(b, x, y) then
			Led.set(b, x, y, if i % 3 == 0 then WHITE else rgb(160, 210, 255))
		end
	end
end
function WEATHER.Shock(b, t: number)
	-- a bolt down the screen a few times a second, never twice the same
	local strike = math.floor(t * 3)
	local flash = (t * 3) % 1
	if flash < 0.45 then
		local x = math.floor(hash(strike) * (Led.W - 10)) + 5
		for y = 0, Led.H - 1 do
			x += math.floor(hash(strike * 13 + y) * 3) - 1
			if not Led.get(b, x, y) then
				Led.set(b, x, y, if flash < 0.15 then WHITE else ELEMENT.Shock)
			end
		end
	end
	sparkles(b, t, 14, ELEMENT.Shock, 5)
end
function WEATHER.Poison(b, t: number)
	for i = 1, 16 do
		local speed = 3 + hash(i) * 4
		local x = math.floor(hash(i * 2) * Led.W + math.sin(t * 3 + i) * 1.2)
		local life = (t * speed / Led.H + hash(i * 3)) % 1
		local y = Led.H - 1 - life * Led.H
		local big = hash(i * 5) > 0.6
		local c = scale(ELEMENT.Poison, 1 - life * 0.5)
		for _, d in if big then { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } else { { 0, 0 } } do
			if not Led.get(b, x + d[1], y + d[2]) then
				Led.set(b, x + d[1], y + d[2], c)
			end
		end
	end
end

-- Scenes ---------------------------------------------------------------------------------------------

local function scene(duration: number, draw: (number) -> any)
	return { Duration = duration, Draw = draw }
end

-- A title: big words, a shimmer across them, sparkles about.
local function title(big: { string }, color: number, under: string?, sparkle: number?)
	return scene(6, function(t)
		local b = Led.new()
		local top = if under then 2 else math.floor((Led.H - (#big * 12 - 2)) / 2)
		for i, word in big do
			Led.center(b, top + (i - 1) * 12, word, color, 2)
		end
		if under then
			Led.center(b, Led.H - 5, under, WHITE)
		end
		shimmer(b, t, 34)
		sparkles(b, t, 18, sparkle or GOLD, #big)
		return b
	end)
end

-- A tip: lines of words, the first in `color`, a picture on the left if any.
local function tip(lines: { string }, color: number, art: string?, sparkle: number?)
	return scene(6, function(t)
		local b = Led.new()
		local left = 0
		if art then
			local w, h = artSize(art)
			Led.art(b, art, 2, math.floor((Led.H - h) / 2) + math.floor(math.sin(t * 2.4) * 1.2 + 0.5))
			left = w + 4
		end
		local top = math.floor((Led.H - #lines * Led.Line + 1) / 2)
		for i, line in lines do
			-- (each line typed out in turn)
			local shown = math.clamp(math.floor((t - (i - 1) * 0.5) * 22), 0, #line)
			centerIn(b, left, Led.W - 1, top + (i - 1) * Led.Line, string.sub(line, 1, shown), if i == 1 then color else WHITE)
		end
		sparkles(b, t, 10, sparkle or color, 3)
		return b
	end)
end

-- Enchanting your armor: a gem flies into the helmet, the helmet lights up
-- in its element, a ring bursts out; a new element each time round.
local function enchant()
	local loop = 2.8
	return scene(loop * 4, function(t)
		local b = Led.new()
		local round = math.floor(t / loop) % 4 + 1
		local element = ELEMENTS[round]
		local color = ELEMENT[element]
		local u = t % loop
		local hw, hh = artSize("Helmet")
		local hx, hy = 3, math.floor((Led.H - hh) / 2)
		local cx, cy = hx + hw / 2, hy + hh / 2
		local hit = 1.1
		-- the helmet: lit in the element after the hit, fading back a little
		local glow = if u >= hit then math.max(0.25, 0.75 - (u - hit) * 0.4) else 0
		Led.art(b, "Helmet", hx, hy, color, glow)
		-- the ring bursting out of it
		if u >= hit and u < hit + 0.7 then
			local k = (u - hit) / 0.7
			ring(b, cx, cy, 4 + k * 14, scale(color, 1 - k * 0.6))
		end
		-- the words, right
		centerIn(b, 33, Led.W - 1, 2, "ENCHANT", GOLD)
		centerIn(b, 33, Led.W - 1, 9, "YOUR ARMOR", WHITE)
		if u >= hit then
			centerIn(b, 33, Led.W - 1, 17, Led.ElementNames[element], color)
			centerIn(b, 33, Led.W - 1, 23, "+RESIST", GOOD)
		else
			centerIn(b, 33, Led.W - 1, 20, "SET A GEM", DIM)
		end
		-- the gem, in flight from the right
		if u < hit then
			local k = u / hit
			local sw, sh = artSize(SMALL[element])
			local gx = (Led.W - 4) + (cx - (Led.W - 4)) * k - sw / 2
			local gy = cy - sh / 2 - math.sin(k * math.pi) * 9
			Led.art(b, SMALL[element], math.floor(gx), math.floor(gy))
			-- (its trail)
			for s = 1, 4 do
				local kk = math.max(0, k - s * 0.05)
				Led.set(b, (Led.W - 4) + (cx - (Led.W - 4)) * kk, cy - math.sin(kk * math.pi) * 9, scale(color, 0.6 - s * 0.12))
			end
		end
		sparkles(b, t, 8, color, round)
		return b
	end)
end

-- The HYPERBEAM: a kaiju, then its beam pouring across the screen.
local function hyperbeam(kaiju: string?)
	return scene(7, function(t)
		local b = Led.new()
		local art = kaiju or "KaijuRazorback"
		local w, h = artSize(art)
		local charge = math.clamp(t / 2, 0, 1)
		Led.art(b, art, 1, Led.H - h, CYAN, if t > 2 then 0.25 + 0.15 * math.sin(t * 20) else charge * 0.3)
		centerIn(b, w + 2, Led.W - 1, 1, "PRESS Z", GOLD)
		if t < 2 then
			centerIn(b, w + 2, Led.W - 1, 12, "CHARGING", CYAN)
			centerIn(b, w + 2, Led.W - 1, 19, math.floor(charge * 100) .. "%", WHITE)
		else
			-- the beam: out from the kaiju, flickering, edged white
			local reach = math.clamp((t - 2) * 90, 0, Led.W)
			local mid = 16
			for x = w - 2, math.min(Led.W - 1, w - 2 + reach) do
				local width = 2 + math.floor(math.sin(t * 30 + x * 0.6) * 1 + 1)
				for dy = -width, width do
					local edge = math.abs(dy) == width
					Led.set(b, x, mid + dy, if edge then CYAN elseif math.abs(dy) <= 1 then WHITE else mix(CYAN, WHITE, 0.4))
				end
			end
			centerIn(b, w + 2, Led.W - 1, Led.H - 5, "HYPERBEAM", WHITE)
		end
		return b
	end)
end

-- Mining: gems hop up out of a rock, sparkling.
local function mining()
	return scene(6, function(t)
		local b = Led.new()
		-- (two by two on the left, each hopping in turn)
		for i, element in ELEMENTS do
			local hop = math.abs(math.sin(t * 3 + i * 0.8)) * 3
			local w, h = artSize(SMALL[element])
			local col, row = (i - 1) % 2, (i - 1) // 2
			Led.art(b, SMALL[element], 2 + col * 13, 4 + row * 13 - math.floor(hop))
		end
		centerIn(b, 30, Led.W - 1, 6, "MINE ROCKS", GOLD)
		centerIn(b, 30, Led.W - 1, 13, "FIND GEMS", WHITE)
		centerIn(b, 30, Led.W - 1, 20, "RARE ONES!", GOOD)
		sparkles(b, t, 16, GOLD, 9)
		return b
	end)
end

-- An element: its gem, its weather, what it's for.
local function element(name: string)
	local color = ELEMENT[name]
	return scene(7, function(t)
		local b = Led.new()
		local gem = GEM[name]
		local w, h = artSize(gem)
		local pulse = (math.sin(t * 4) + 1) / 2
		Led.art(b, gem, 2, math.floor((Led.H - h) / 2), WHITE, pulse * 0.25)
		centerIn(b, w + 4, Led.W - 1, 3, Led.ElementNames[name], color)
		centerIn(b, w + 4, Led.W - 1, 12, "IN ARMOR", WHITE)
		centerIn(b, w + 4, Led.W - 1, 18, "RESISTS IT", WHITE)
		WEATHER[name](b, t)
		return b
	end)
end

-- The four elements in turn, each gem lighting up.
local function elementsTitle()
	return scene(6, function(t)
		local b = Led.new()
		Led.center(b, 1, "ELEMENTS", WHITE, 2)
		local lit = math.floor(t * 1.5) % 4 + 1
		for i, name in ELEMENTS do
			local w, h = artSize(SMALL[name])
			local x = 4 + (i - 1) * 17
			Led.art(b, SMALL[name], x, Led.H - h - 1, WHITE, if i == lit then 0.4 else 0)
			if i == lit then
				ring(b, x + w / 2, Led.H - h / 2 - 1, 6 + (t * 1.5 % 1) * 3, scale(ELEMENT[name], 0.7))
			end
		end
		return b
	end)
end

local THREAT = { "I", "II", "III" }
-- A boss on the Bounty Board: WANTED, its picture sliding in, what it is.
local function wanted(boss)
	return scene(6, function(t)
		local b = Led.new()
		local w, h = artSize(boss.Art)
		local slide = math.clamp(t / 0.5, 0, 1)
		Led.art(b, boss.Art, math.floor(-w + (w + 1) * (1 - (1 - slide) ^ 3)), Led.H - h)
		local left = w + 3
		if math.floor(t * 2.5) % 2 == 0 or t > 2 then
			centerIn(b, left, Led.W - 1, 0, "WANTED", RED)
		end
		local lines = wrap(boss.Name or "", math.floor((Led.W - left + 1) / LedFont.Advance))
		for i = 1, math.min(2, #lines) do
			centerIn(b, left, Led.W - 1, 1 + i * Led.Line, lines[i], WHITE)
		end
		local el = boss.Element and Led.ElementNames[boss.Element]
		if el then
			centerIn(b, left, Led.W - 1, 19, el .. " " .. (THREAT[boss.Threat or 1] or ""), ELEMENT[boss.Element])
		end
		local weak = boss.Weakness and Led.ElementNames[boss.Weakness]
		if weak and t > 1.2 then
			centerIn(b, left, Led.W - 1, 25, "WEAK: " .. weak, ELEMENT[boss.Weakness])
		end
		return b
	end)
end

-- What each kind of kaiju does.
local ROLE = {
	Warrior = { "WARRIOR", "HITS HARD" },
	Ranged = { "RANGED", "FROM AFAR" },
	Tank = { "TANK", "TAKES HITS" },
	Assassin = { "ASSASSIN", "STRIKES FAST" },
	Warden = { "SUPPORT", "HEALS YOU" },
}
-- A kaiju: its picture stomping in place, its name, what it does.
local function kaiju(entry)
	return scene(5, function(t)
		local b = Led.new()
		local w, h = artSize(entry.Art)
		local slide = math.clamp(t / 0.45, 0, 1)
		local x = math.floor(Led.W - (Led.W - 1) * (1 - (1 - slide) ^ 3))
		local bob = if slide >= 1 then math.floor(math.abs(math.sin(t * 5)) * 1.6) else 0
		Led.art(b, entry.Art, x, Led.H - h - bob)
		local left = w + 3
		local role = ROLE[entry.Role] or { Led.fit(entry.Role or "", 10), "" }
		centerIn(b, left, Led.W - 1, 4, entry.Name or "", GOLD)
		if slide >= 1 then
			centerIn(b, left, Led.W - 1, 13, role[1], CYAN)
			centerIn(b, left, Led.W - 1, 20, role[2], WHITE)
		end
		sparkles(b, t, 6, CYAN, 11)
		return b
	end)
end

local SCENES = {}
function SCENES.Guide(info)
	local first = info.Kaiju and info.Kaiju[1] and info.Kaiju[1].Art
	return {
		title({ "SAGA", "MINERS" }, GOLD),
		mining(),
		enchant(),
		hyperbeam(first),
		tip({ "YOUR POD", "PRESS E AT", "ITS DOOR" }, CYAN, "Shield"),
		tip({ "DUELS", "ARENA ROW", "PLAY > 1V1" }, GOLD, "Helmet"),
	}
end
function SCENES.Elements(_info)
	local list = { elementsTitle() }
	for _, name in ELEMENTS do
		table.insert(list, element(name))
	end
	table.insert(list, tip({ "ENCHANTER", "SETS GEMS", "IN GEAR" }, rgb(255, 120, 200), "PoisonGem", rgb(255, 120, 200)))
	return list
end
function SCENES.Bounties(info)
	local list = { title({ "WANTED" }, RED, "THE BOUNTY BOARD", RED) }
	for _, boss in info.Bosses or {} do
		table.insert(list, wanted(boss))
	end
	table.insert(list, tip({ "HUNT THEM", "AT BOUNTY", "OFFICE" }, GOLD, "Chest"))
	return list
end
function SCENES.Kaiju(info)
	local list = { title({ "KAIJU" }, CYAN, "THEY FIGHT FOR YOU", CYAN) }
	for _, entry in info.Kaiju or {} do
		table.insert(list, kaiju(entry))
	end
	table.insert(list, hyperbeam(info.Kaiju and info.Kaiju[2] and info.Kaiju[2].Art))
	return list
end

function Led.scenes(board: string, info: any): { any }
	local make = SCENES[board]
	local list = if make then make(if type(info) == "table" then info else {}) else {}
	if #list == 0 then
		table.insert(list, scene(5, function()
			return Led.new()
		end))
	end
	return list
end

-- The kaiju and bosses the screens show, from the pictures there are
-- (LedArt's Kaiju<Name> and Boss<Id>) and the game's own data on them:
-- `kaijuRole(name) -> role?`, `boss(id) -> { Name, Element, Weakness, Threat }?`
-- and `order` (the bosses' ids, in the order to show them).
function Led.catalog(kaijuRole: (string) -> string?, boss: (string) -> any, order: { string }?)
	local info = { Kaiju = {}, Bosses = {} }
	local names = {}
	for key in LedArt do
		if string.sub(key, 1, 5) == "Kaiju" then
			table.insert(names, string.sub(key, 6))
		end
	end
	table.sort(names)
	for _, name in names do
		local ok, role = pcall(kaijuRole, name)
		if ok and role then
			table.insert(info.Kaiju, { Art = "Kaiju" .. name, Name = name, Role = role })
		end
	end
	local ids = {}
	for _, id in order or {} do
		if LedArt["Boss" .. id] then
			table.insert(ids, id)
		end
	end
	for key in LedArt do
		if string.sub(key, 1, 4) == "Boss" and not table.find(ids, string.sub(key, 5)) then
			table.insert(ids, string.sub(key, 5))
		end
	end
	for _, id in ids do
		local ok, spec = pcall(boss, id)
		if ok and type(spec) == "table" then
			table.insert(info.Bosses, {
				Art = "Boss" .. id,
				Name = spec.Name,
				Element = spec.Element,
				Weakness = spec.Weakness,
				Threat = spec.Threat,
			})
		end
	end
	return info
end

return Led
