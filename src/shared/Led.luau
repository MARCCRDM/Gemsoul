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

	and between them SAGA TOONS, short spin-off cartoons of the kaiju and
	bosses (Led.Toons), each ending on a tip for a new miner: BONK! (Tung Tung Tung Sahur vs a rock) and MINE!
	(Grandape and Razorback, one chest) on the Guide, HOT N COLD (Drago
	melts Frigo; Frigo freezes Drago) on Elements, DISGUISE (Tralalero
	hides from its own poster) on Bounties, SNEEZE (Skyjelly's HYPERBEAM)
	on Kaiju.

	  Led.W, Led.H, Led.Boards, Led.ElementNames
	  Led.new() -> buffer;  Led.get(buffer, x, y) -> rgb?
	  Led.text(buffer, x, y, text, rgb, scale?) -> width;  Led.width(text, scale?)
	  Led.center(buffer, y, text, rgb, scale?);  Led.art(buffer, art, x, y, tint?, k?)
	  Led.fit(text, chars) -> text   capitals the font has, cut to fit
	  Led.scenes(board, info) -> { { Duration, Draw = (t) -> buffer } }
	  Led.toon(name) -> scene?   an episode (nil: no art for its cast)
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

-- Cartoons ------------------------------------------------------------------------------------------
-- SAGA TOONS: short spin-off cartoons of the kaiju and bosses, a dozen
-- seconds each, shot by shot: the cast walk, hop, squash and stretch,
-- talk in speech bubbles, BONK and blast each other.

local FOOT = Led.H - 2 -- the row the cast stand on (the ground's under it)
local SKY_DOTS = rgb(40, 46, 66)

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return 1 - (1 - k) ^ 3
end
local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * math.clamp(k, 0, 1)
end

-- A picture with its feet at (cx, foot): flipped (`Flip`), stretched (`SX`,
-- `SY`), tinted (`Tint`, `K`). Returns its width, height and top.
local function sprite(b, name: string, cx: number, foot: number, o: any?): (number, number, number)
	local art = LedArt[name]
	if not art then
		return 0, 0, foot
	end
	o = o or {}
	local w = math.max(1, math.floor(art.W * (o.SX or 1) + 0.5))
	local h = math.max(1, math.floor(art.H * (o.SY or 1) + 0.5))
	local colors = {}
	for i, c in art.Palette do
		local own = rgb(c[1], c[2], c[3])
		colors[i] = if o.Tint and o.K then mix(own, o.Tint, o.K) else own
	end
	local left, top = math.floor(cx - w / 2 + 0.5), math.floor(foot) - h + 1
	for dy = 0, h - 1 do
		local row = art.Rows[math.min(art.H, math.floor(dy * art.H / h) + 1)]
		for dx = 0, w - 1 do
			local sx = math.min(art.W, math.floor(dx * art.W / w) + 1)
			if o.Flip then
				sx = art.W - sx + 1
			end
			local index = string.find(DIGITS, string.sub(row, sx, sx), 1, true)
			if index and colors[index] then
				Led.set(b, left + dx, top + dy, colors[index])
			end
		end
	end
	return w, h, top
end

-- A speech bubble across the top, its tail down toward `cx`.
local function bubble(b, cx: number, text: string, color: number?)
	text = Led.fit(text, Led.Chars - 1)
	local w = Led.width(text) + 4
	local left = math.clamp(math.floor(cx - w / 2), 0, Led.W - w)
	for y = 0, 6 do
		for x = left, left + w - 1 do
			local edge = y == 0 or y == 6 or x == left or x == left + w - 1
			local corner = (y == 0 or y == 6) and (x == left or x == left + w - 1)
			Led.set(b, x, y, if corner then nil elseif edge then WHITE else nil)
		end
	end
	local tail = math.clamp(math.floor(cx), left + 2, left + w - 3)
	Led.set(b, tail, 7, WHITE)
	Led.set(b, tail + (if cx < left + w / 2 then -1 else 1), 8, WHITE)
	Led.text(b, left + 2, 1, text, color or WHITE)
end

-- A burst of rays round (cx, cy).
local function burst(b, cx: number, cy: number, r: number, color: number)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.2
		for s = math.floor(r * 0.45), math.floor(r) do
			Led.set(b, cx + math.cos(a) * s, cy + math.sin(a) * s * 0.8, color)
		end
	end
end

-- Stars going round a dazed head.
local function dizzy(b, cx: number, y: number, t: number)
	for i = 0, 2 do
		local a = t * 6 + i * math.pi * 2 / 3
		Led.set(b, cx + math.cos(a) * 5, y + math.sin(a) * 1.5, if i == 0 then WHITE else GOLD)
	end
end

-- A "!" over a head.
local function shout(b, cx: number, y: number, color: number)
	for dy = 0, 2 do
		Led.set(b, cx, y + dy, color)
	end
	Led.set(b, cx, y + 4, color)
end

-- A rock: a lump, shaded, cracked `crack` (0..2) of the way.
local function rock(b, cx: number, foot: number, crack: number, apart: number?)
	apart = apart or 0
	for y = 0, 9 do
		local half = math.floor(math.sqrt(math.max(0, 1 - ((y - 9) / 10) ^ 2)) * 8 + 0.5)
		for x = -half, half do
			local shade = if x < -half / 3 then rgb(150, 156, 170) elseif x > half / 2 then rgb(78, 82, 96) else rgb(112, 118, 134)
			local side = if x < 0 then -apart else apart
			Led.set(b, cx + x + side, foot - 9 + y, shade)
		end
	end
	if crack >= 1 then
		for i, d in { { 0, 0 }, { 1, 1 }, { 0, 2 }, { -1, 3 }, { 0, 4 } } do
			if i <= 3 or crack >= 2 then
				Led.set(b, cx + d[1], foot - 8 + d[2], rgb(30, 32, 40))
			end
		end
	end
end

-- The ground: a line along the bottom, a few dots of sky.
local function ground(b, shake: number?)
	shake = shake or 0
	for x = 0, Led.W - 1 do
		Led.set(b, x, Led.H - 1, if (x + shake) % 6 == 0 then rgb(70, 80, 104) else rgb(46, 54, 74))
	end
	for i = 1, 5 do
		Led.set(b, hash(i * 9) * Led.W, 2 + hash(i * 4) * 10, SKY_DOTS)
	end
end

-- A title card: SAGA TOONS, the episode's name, the stars peeking up.
local function card(b, name: string, cast: { string }, t: number)
	Led.center(b, 1, "SAGA TOONS", GOLD)
	if Led.width(name, 2) <= Led.W - 2 then
		Led.center(b, 8, name, WHITE, 2)
	else
		Led.center(b, 11, name, WHITE)
	end
	for i, who in cast do
		local x = if i == 1 then 8 else Led.W - 9
		local peek = ease(t / 0.6)
		sprite(b, who, x, FOOT + math.floor((1 - peek) * 12), { SX = 0.6, SY = 0.6, Flip = i == 2 })
	end
	shimmer(b, t, 40)
	sparkles(b, t, 10, GOLD, #name)
end

-- Hopping along: how high off the ground at `t`.
local function hop(t: number, speed: number?): number
	return math.floor(math.abs(math.sin(t * (speed or 9))) * 2 + 0.5)
end

-- The lesson at the end: TIP, a few typed lines, the star bobbing beside them.
local function lesson(b, who: string, lines: { string }, color: number, u: number, t: number)
	sprite(b, who, 11, FOOT - hop(u, 4))
	Led.text(b, 26, 1, "TIP", GOLD)
	for i, line in lines do
		local shown = math.clamp(math.floor((u - (i - 1) * 0.35) * 26), 0, #line)
		centerIn(b, 24, Led.W - 1, 1 + i * Led.Line, string.sub(line, 1, shown), if i == 1 then color else WHITE)
	end
	sparkles(b, t, 8, color, #lines)
end

-- An episode: its title card, then its shots, each { seconds, draw(b, u, k, t) }
-- (u: seconds into the shot, k: 0..1 through it, t: into the episode), then
-- its lesson (a tip for a new miner: { who, lines, color }).
local function episode(name: string, cast: { string }, shots: { any }, tip: any?)
	if tip then
		shots = table.clone(shots)
		table.insert(shots, { 2.2, function(b, u, _k, t)
			lesson(b, tip[1], tip[2], tip[3], u, t)
		end })
	end
	for _, who in cast do
		if not LedArt[who] then
			return nil
		end
	end
	local total = 1.6
	for _, shot in shots do
		total += shot[1]
	end
	return scene(total, function(t)
		local b = Led.new()
		if t < 1.6 then
			card(b, name, cast, t)
			ground(b)
			return b
		end
		local at = 1.6
		for i, shot in shots do
			if t < at + shot[1] or i == #shots then
				local u = t - at
				shot[2](b, u, math.clamp(u / shot[1], 0, 1), t)
				break
			end
			at += shot[1]
		end
		ground(b)
		return b
	end)
end

local TOONS = {}

-- BONK!: Tung Tung Tung Sahur wants a gem out of a rock. The rock wins, then
-- it doesn't.
function TOONS.Bonk()
	local S, ROCK = "MiniBossSahurTrio", 52
	local function rockAt(b, crack, apart, shake)
		rock(b, ROCK + (shake or 0), FOOT, crack, apart)
	end
	return episode("BONK!", { S }, {
		{ 2.0, function(b, u, k)
			rockAt(b, 0)
			sprite(b, S, lerp(-8, 24, k), FOOT - hop(u))
		end },
		{ 1.4, function(b, u)
			rockAt(b, 0)
			sprite(b, S, 24, FOOT)
			bubble(b, 24, "EASY GEMS", GOLD)
		end },
		{ 1.2, function(b, u, k)
			local lunge = if k < 0.3 then ease(k / 0.3) else 1 - ease((k - 0.3) / 0.7)
			local shake = if k > 0.3 and k < 0.7 then (if math.floor(u * 30) % 2 == 0 then 1 else -1) else 0
			rockAt(b, 0, 0, shake)
			sprite(b, S, 24 + lunge * 16, FOOT)
			if k > 0.3 then
				burst(b, ROCK - 6, FOOT - 9, 6, WHITE)
				Led.text(b, 36, 2, "BONK", GOLD)
			end
		end },
		{ 1.6, function(b, u, k, t)
			rockAt(b, 0)
			local squash = 0.12 * math.cos(u * 14) * (1 - k)
			local _, _, top = sprite(b, S, 24, FOOT, { SY = 0.85 - squash, SX = 1.12 + squash })
			dizzy(b, 24, top - 2, t)
			bubble(b, 24, "OW!", RED)
		end },
		{ 1.2, function(b, u, k)
			local lunge = if k < 0.25 then ease(k / 0.25) else 1 - ease((k - 0.25) / 0.75)
			rockAt(b, if k > 0.25 then 2 else 0)
			sprite(b, S, 24 + lunge * 17, FOOT, { SX = 1 + lunge * 0.15 })
			if k > 0.25 then
				burst(b, ROCK - 6, FOOT - 9, 8, GOLD)
				Led.text(b, 32, 2, "CRACK!", WHITE)
			end
		end },
		{ 2.2, function(b, u, k)
			rockAt(b, 2, math.floor(ease(k * 2) * 4))
			local _, _, top = sprite(b, S, 24, FOOT)
			-- the gem pops up out of the rock and lands on his head
			local gk = math.clamp(k / 0.6, 0, 1)
			local gw, gh = artSize("SmallFire")
			local gx = lerp(ROCK, 24, gk) - gw / 2
			local gy = lerp(FOOT - 10, top - gh, gk) - math.sin(gk * math.pi) * 14
			Led.art(b, "SmallFire", math.floor(gx), math.floor(gy))
			if k > 0.6 then
				shout(b, 24 + 8, top - 4, GOLD)
			end
		end },
		{ 2.4, function(b, u, k, t)
			rock(b, ROCK, FOOT, 2, 4)
			local jump = math.floor(math.abs(math.sin(u * 7)) * 5)
			local _, _, top = sprite(b, S, 24, FOOT - jump)
			local gw, gh = artSize("SmallFire")
			Led.art(b, "SmallFire", 24 - math.floor(gw / 2), top - gh)
			bubble(b, 24, "RARE ONE!", GOOD)
			sparkles(b, t, 14, GOLD, 21)
		end },
	}, { S, { "MINE ROCKS", "FOR GEMS", "RARE ONES!" }, GOLD })
end

-- HOT N COLD: Bombardiro Drago melts Frigo Camelo. Frigo comes back, and
-- Drago's weak to Cryo.
function TOONS.HotCold()
	local D, F = "MiniBossDrago", "MiniBossFrigo"
	local DX, FX = 15, 57
	local ICE = rgb(150, 220, 255)
	return episode("HOT N COLD", { D, F }, {
		{ 1.4, function(b, u, k)
			sprite(b, D, lerp(-10, DX, ease(k)), FOOT - hop(u))
			sprite(b, F, lerp(Led.W + 10, FX, ease(k)), FOOT - hop(u + 0.2), { Flip = true })
		end },
		{ 1.4, function(b)
			sprite(b, D, DX, FOOT)
			sprite(b, F, FX, FOOT, { Flip = true })
			bubble(b, DX, "HOT STUFF", ELEMENT.Fire)
		end },
		{ 2.0, function(b, u, k)
			sprite(b, D, DX, FOOT)
			-- Frigo melts: shorter, wider, redder, dripping
			local melt = ease(k)
			sprite(b, F, FX, FOOT, { Flip = true, SY = 1 - melt * 0.72, SX = 1 + melt * 0.5, Tint = ELEMENT.Fire, K = 0.15 + 0.25 * math.sin(u * 20) ^ 2 })
			-- the fire: a stream of embers from Drago's mouth
			for i = 1, 22 do
				local life = (u * 2.2 + i / 22) % 1
				local x = lerp(DX + 7, FX - 4, life)
				local y = FOOT - 12 + math.sin(i * 1.7 + u * 9) * (1 + life * 3)
				Led.set(b, x, y, if life < 0.3 then rgb(255, 240, 150) elseif life < 0.7 then rgb(255, 150, 50) else ELEMENT.Fire)
			end
		end },
		{ 1.2, function(b, u)
			sprite(b, D, DX, FOOT - hop(u, 12))
			sprite(b, F, FX, FOOT, { Flip = true, SY = 0.28, SX = 1.5, Tint = ICE, K = 0.3 })
			bubble(b, DX, "HA HA!", ELEMENT.Fire)
		end },
		{ 1.6, function(b, u, k, t)
			sprite(b, D, DX, FOOT)
			sprite(b, F, FX, FOOT, { Flip = true, SY = lerp(0.28, 1, ease(k)), SX = lerp(1.5, 1, ease(k)), Tint = WHITE, K = 0.35 })
			ring(b, FX, FOOT - 9, 4 + k * 9, scale(ICE, 1 - k * 0.5))
			WEATHER.Frost(b, t)
		end },
		{ 1.8, function(b, u, k)
			local freeze = ease(k)
			sprite(b, D, DX, FOOT, { Tint = ICE, K = freeze * 0.6 })
			sprite(b, F, FX, FOOT, { Flip = true })
			-- the cold: a fan of frost from Frigo to Drago
			for i = 1, 26 do
				local life = (u * 1.8 + i / 26) % 1
				local x = lerp(FX - 6, DX + 4, life)
				local y = FOOT - 10 + math.sin(i * 2.3) * (1 + life * 5)
				Led.set(b, x, y, if i % 3 == 0 then WHITE else ICE)
			end
			if k > 0.5 then
				local h = math.floor((k - 0.5) * 2 * 22)
				for y = FOOT - h + 1, FOOT do
					Led.set(b, DX - 10, y, ICE)
					Led.set(b, DX + 10, y, ICE)
				end
			end
		end },
		{ 2.2, function(b, u, k, t)
			local shiver = if math.floor(u * 16) % 2 == 0 then 1 else 0
			sprite(b, D, DX + shiver, FOOT, { Tint = ICE, K = 0.6 })
			for y = FOOT - 21, FOOT do
				Led.set(b, DX - 10, y, ICE)
				Led.set(b, DX + 10, y, ICE)
			end
			for x = DX - 10, DX + 10 do
				Led.set(b, x, FOOT - 22, ICE)
			end
			sprite(b, F, FX, FOOT - hop(u, 6), { Flip = true })
			if k < 0.5 then
				bubble(b, DX, "B-B-BRR", ICE)
			else
				bubble(b, FX, "WEAK TO CRYO!", ELEMENT.Frost)
			end
			sparkles(b, t, 8, ICE, 31)
		end },
	}, { F, { "BOSSES HAVE", "A WEAKNESS", "HIT IT!" }, ELEMENT.Frost })
end

-- SNEEZE: Dreadmaw laughs at little Skyjelly's HYPERBEAM. Once.
function TOONS.Sneeze()
	local J, M = "MiniKaijuSkyjelly", "MiniKaijuDreadmaw"
	local JX, MX = 14, 54
	return episode("SNEEZE", { J, M }, {
		{ 1.6, function(b, u, k)
			sprite(b, J, JX, FOOT - math.floor(math.sin(u * 4) + 1))
			local step = math.floor(u * 3)
			local shake = if (u * 3) % 1 < 0.2 then 1 else 0
			sprite(b, M, lerp(Led.W + 12, MX, (step + 1) / 5), FOOT - shake, { Flip = true })
		end },
		{ 1.2, function(b, u)
			local shake = if math.floor(u * 24) % 2 == 0 then 1 else -1
			sprite(b, J, JX + shake, FOOT, { SY = 0.92 })
			sprite(b, M, MX, FOOT, { Flip = true, SX = 1.08, SY = 1.08 })
			bubble(b, MX, "RAWR!", RED)
		end },
		{ 2.0, function(b, u, k, t)
			local _, _, top = sprite(b, J, JX, FOOT, { Tint = CYAN, K = k * 0.5 })
			sprite(b, M, MX, FOOT, { Flip = true })
			Led.text(b, 28, 1, "CHARGE " .. math.floor(k * 100) .. "%", CYAN)
			-- sparks drawn in to it
			for i = 1, 10 do
				local life = (u * 1.5 + i / 10) % 1
				local a = i * 2.4
				Led.set(b, JX + math.cos(a) * 14 * (1 - life), top + 8 + math.sin(a) * 9 * (1 - life), CYAN)
			end
		end },
		{ 1.4, function(b, u, k)
			sprite(b, J, JX, FOOT, { SY = if k < 0.15 then 0.85 else 1 })
			sprite(b, M, MX, FOOT, { Flip = true })
			-- one little spark, off its nose
			local x = if k < 0.6 then lerp(JX + 8, MX - 8, k / 0.6) else lerp(MX - 8, MX - 16, (k - 0.6) / 0.4)
			local y = FOOT - 10 - (if k < 0.6 then 0 else math.sin((k - 0.6) / 0.4 * math.pi) * 4)
			Led.set(b, x, y, WHITE)
			Led.set(b, x + 1, y, CYAN)
			Led.text(b, JX - 2, 1, "PEW", CYAN)
		end },
		{ 1.6, function(b, u)
			sprite(b, J, JX, FOOT, { SY = 0.9 })
			sprite(b, M, MX, FOOT - hop(u, 14), { Flip = true })
			bubble(b, MX, "HA HA HA", RED)
		end },
		{ 1.8, function(b, u, k)
			local w = sprite(b, J, JX, FOOT, { Tint = CYAN, K = 0.35 + 0.15 * math.sin(u * 30) })
			local flash = k > 0.25
			sprite(b, M, MX, FOOT, { Flip = true, Tint = WHITE, K = if flash then 0.7 else 0 })
			if k > 0.15 then
				local reach = math.clamp((k - 0.15) * 300, 0, Led.W)
				for x = JX + math.floor(w / 2), math.min(Led.W - 1, JX + reach) do
					local width = 2 + math.floor(math.sin(u * 30 + x * 0.6) + 1)
					for dy = -width, width do
						Led.set(b, x, FOOT - 9 + dy, if math.abs(dy) == width then CYAN elseif math.abs(dy) <= 1 then WHITE else mix(CYAN, WHITE, 0.4))
					end
				end
			end
		end },
		{ 2.2, function(b, u, k, t)
			sprite(b, J, JX, FOOT - math.floor(math.sin(u * 4) + 1))
			if k < 0.5 then
				local fly = ease(k * 2)
				sprite(b, M, lerp(MX, Led.W + 6, fly), FOOT - fly * 40, { Flip = true, SY = 1 + fly * 0.4, SX = 1 - fly * 0.3 })
			else
				local tw = (k - 0.5) * 2
				burst(b, Led.W - 8, 4, 2 + math.sin(tw * math.pi) * 3, WHITE)
				Led.text(b, Led.W - 26, 9, "DING", GOLD)
			end
			if k > 0.3 then
				bubble(b, JX, "OOPS", CYAN)
			end
			sparkles(b, t, 6, CYAN, 41)
		end },
	}, { J, { "HYPERBEAM", "CHARGE IT UP", "THEN PRESS Z" }, CYAN })
end

-- MINE!: Grandape and Razorback find the same chest.
function TOONS.Mine()
	local G, R = "MiniKaijuGrandape", "MiniKaijuRazorback"
	local CX = 36
	local function chest(b, x, k)
		-- (a chest: brown box, gold band and lock)
		local left = math.floor(x) - 5
		for y = FOOT - 7, FOOT do
			for dx = 0, 10 do
				local c = if y == FOOT - 4 then GOLD elseif y < FOOT - 4 then rgb(160, 96, 48) else rgb(120, 70, 34)
				Led.set(b, left + dx, y - (k or 0), c)
			end
		end
		Led.set(b, left + 5, FOOT - 3 - (k or 0), GOLD)
		Led.set(b, left + 5, FOOT - 2 - (k or 0), GOLD)
	end
	local GEMS = { "SmallFire", "SmallFrost", "SmallShock", "SmallPoison" }
	return episode("MINE!", { G, R }, {
		{ 1.6, function(b, u, k, t)
			chest(b, CX)
			sparkles(b, t, 6, GOLD, 51)
			sprite(b, G, lerp(-10, 18, ease(k)), FOOT - hop(u))
			sprite(b, R, lerp(Led.W + 10, 56, ease(k)), FOOT - hop(u + 0.3), { Flip = true })
		end },
		{ 0.8, function(b, u)
			chest(b, CX)
			local _, _, gt = sprite(b, G, 18, FOOT - (if u < 0.3 then 2 else 0))
			local _, _, rt = sprite(b, R, 56, FOOT - (if u < 0.3 then 2 else 0), { Flip = true })
			shout(b, 18, gt - 6, GOLD)
			shout(b, 56, rt - 6, GOLD)
		end },
		{ 2.6, function(b, u, k)
			local pull = math.sin(u * 5)
			chest(b, CX + pull * 4)
			sprite(b, G, 22 + pull * 4, FOOT, { SX = 1 + math.max(0, -pull) * 0.1 })
			sprite(b, R, 52 + pull * 4, FOOT, { Flip = true, SX = 1 + math.max(0, pull) * 0.1 })
			if math.floor(u / 0.65) % 2 == 0 then
				bubble(b, 22, "MINE!", GOLD)
			else
				bubble(b, 52, "MINE!", CYAN)
			end
		end },
		{ 1.4, function(b, u, k)
			chest(b, CX, if k < 0.3 then math.floor(math.sin(u * 40) + 1) else 0)
			local back = ease(math.clamp((k - 0.3) / 0.7, 0, 1))
			sprite(b, G, 22 - back * 10, FOOT, { SY = 1 - back * 0.15 })
			sprite(b, R, 52 + back * 10, FOOT, { Flip = true, SY = 1 - back * 0.15 })
			if k > 0.3 then
				burst(b, CX, FOOT - 6, 4 + back * 8, GOLD)
				Led.text(b, CX - 9, 1, "POP!", WHITE)
			end
		end },
		{ 2.0, function(b, u, k, t)
			chest(b, CX)
			sprite(b, G, 12, FOOT)
			sprite(b, R, 62, FOOT, { Flip = true })
			for i, gem in GEMS do
				local gw, gh = artSize(gem)
				local dir = if i <= 2 then -1 else 1
				local spread = (if i % 2 == 0 then 8 else 16)
				local x = CX + dir * spread * k - gw / 2
				local arc = math.sin(math.clamp(k * 1.4, 0, 1) * math.pi) * (10 + i * 2)
				local y = FOOT - gh + 1 - arc
				Led.art(b, gem, math.floor(x), math.floor(y))
			end
			sparkles(b, t, 10, WHITE, 61)
		end },
		{ 2.0, function(b, u, k, t)
			local meet = ease(math.clamp(k / 0.5, 0, 1))
			chest(b, CX)
			local gx = lerp(12, 28, meet)
			local rx = lerp(62, 46, meet)
			local _, _, gt = sprite(b, G, gx, FOOT - (if k > 0.5 then hop(u, 8) else 0))
			local _, _, rt = sprite(b, R, rx, FOOT - (if k > 0.5 then hop(u + 0.2, 8) else 0), { Flip = true })
			if k <= 0.5 then
				Led.art(b, "SmallFire", math.floor(gx) - 4, gt - 9)
				Led.art(b, "SmallFrost", math.floor(rx) - 4, rt - 9)
			else
				burst(b, CX, FOOT - 14, 5, GOLD)
				Led.center(b, 1, "SHARE!", GOOD)
			end
			sparkles(b, t, 8, GOLD, 71)
		end },
		{ 1.8, function(b, u, k, t)
			-- each sets its gem in its armor: lit up in the gem's element
			chest(b, CX)
			local glow = 0.5 + 0.15 * math.sin(u * 10)
			sprite(b, G, 28, FOOT, { Tint = ELEMENT.Fire, K = glow })
			sprite(b, R, 46, FOOT, { Flip = true, Tint = ELEMENT.Frost, K = glow })
			ring(b, 28, FOOT - 9, 4 + k * 9, scale(ELEMENT.Fire, 1 - k * 0.6))
			ring(b, 46, FOOT - 9, 4 + k * 9, scale(ELEMENT.Frost, 1 - k * 0.6))
			Led.center(b, 1, "+RESIST", GOOD)
		end },
	}, { G, { "SET GEMS IN", "YOUR ARMOR", "AT ENCHANTER" }, rgb(255, 120, 200) })
end

-- DISGUISE: Tralalero sees its own WANTED poster, puts a helmet on. Bulwark
-- isn't fooled.
function TOONS.Disguise()
	local T, K = "MiniBossTralaleroTwin", "MiniKaijuBulwark"
	local PX = 60
	local function poster(b)
		for y = 4, FOOT - 2 do
			for x = PX - 9, PX + 9 do
				local edge = y == 4 or y == FOOT - 2 or x == PX - 9 or x == PX + 9
				Led.set(b, x, y, if edge then GOLD else nil)
			end
		end
		for x = PX - 8, PX + 8 do
			Led.set(b, x, 5, RED)
			Led.set(b, x, 6, RED)
		end
		sprite(b, T, PX, FOOT - 3, { SX = 0.7, SY = 0.85 })
	end
	local function helmet(b, cx, top)
		-- (a little helmet: a dome and a visor)
		for dy = 0, 4 do
			local half = if dy == 0 then 3 elseif dy == 1 then 4 else 5
			for dx = -half, half do
				Led.set(b, cx + dx, top + dy, if dy == 3 then CYAN else rgb(190, 196, 210))
			end
		end
	end
	return episode("DISGUISE", { T, K }, {
		{ 1.8, function(b, u, k)
			poster(b)
			sprite(b, T, lerp(-10, 34, k), FOOT - hop(u))
		end },
		{ 1.0, function(b, u)
			poster(b)
			local _, _, top = sprite(b, T, 34, FOOT - (if u < 0.35 then 3 else 0))
			shout(b, 34, top - 7, RED)
		end },
		{ 1.6, function(b, u, k)
			poster(b)
			local _, _, top = sprite(b, T, 34, FOOT)
			helmet(b, 34, math.floor(lerp(-6, top - 1, ease(k))))
		end },
		{ 1.8, function(b, u)
			poster(b)
			local _, _, top = sprite(b, T, 34, FOOT - hop(u, 5))
			helmet(b, 34, top - 1)
			bubble(b, 34, "NO ONE WILL KNOW", WHITE)
		end },
		{ 1.8, function(b, u, k)
			poster(b)
			local _, _, top = sprite(b, T, 34, FOOT)
			helmet(b, 34, top - 1)
			sprite(b, K, lerp(-12, 13, ease(k)), FOOT - hop(u, 6))
			if k > 0.5 then
				bubble(b, 13, "HMM?", GOLD)
			end
		end },
		{ 1.4, function(b, u, k)
			poster(b)
			local _, _, top = sprite(b, T, 34, FOOT - (if k > 0.3 then 2 else 0))
			local fly = math.clamp((k - 0.3) / 0.7, 0, 1)
			helmet(b, 34 + math.floor(fly * 20), math.floor(top - 1 - math.sin(fly * math.pi) * 8 + fly * 10))
			sprite(b, K, 15, FOOT)
			bubble(b, 15, "GOTCHA!", RED)
		end },
		{ 2.2, function(b, u, k, t)
			poster(b)
			local run = ease(k)
			sprite(b, T, lerp(34, Led.W + 14, run), FOOT - hop(u, 16))
			sprite(b, K, lerp(15, Led.W + 4, math.clamp(run * 1.1 - 0.1, 0, 1)), FOOT - hop(u, 14))
			for i = 1, 4 do
				local dx = lerp(34, Led.W + 14, run) - 10 - i * 3
				Led.set(b, dx, FOOT - (i % 2), DIM)
			end
			Led.text(b, 2, 1, "BOUNTY ON!", RED)
		end },
	}, { K, { "BOUNTIES", "TAKE ONE AT", "THE OFFICE" }, RED })
end

Led.Toons = { "Bonk", "HotCold", "Sneeze", "Mine", "Disguise" }
-- An episode (a scene), if there's art for its cast.
function Led.toon(name: string)
	local make = TOONS[name]
	local ep = if make then make() else nil
	if ep then
		ep.Toon = name
	end
	return ep
end
-- Puts episode `name` into `list` (at `at`), if it can be shown.
local function addToon(list: { any }, name: string, at: number?)
	local ep = Led.toon(name)
	if ep then
		table.insert(list, math.clamp(at or #list + 1, 1, #list + 1), ep)
	end
end

local SCENES = {}
function SCENES.Guide(info)
	local first = info.Kaiju and info.Kaiju[1] and info.Kaiju[1].Art
	local list = {
		title({ "SAGA", "MINERS" }, GOLD),
		mining(),
		enchant(),
		hyperbeam(first),
		tip({ "YOUR POD", "PRESS E AT", "ITS DOOR" }, CYAN, "Shield"),
		tip({ "DUELS", "ARENA ROW", "PLAY > 1V1" }, GOLD, "Helmet"),
	}
	addToon(list, "Bonk", 3)
	addToon(list, "Mine")
	return list
end
function SCENES.Elements(_info)
	local list = { elementsTitle() }
	for _, name in ELEMENTS do
		table.insert(list, element(name))
	end
	addToon(list, "HotCold")
	table.insert(list, tip({ "ENCHANTER", "SETS GEMS", "IN GEAR" }, rgb(255, 120, 200), "PoisonGem", rgb(255, 120, 200)))
	return list
end
function SCENES.Bounties(info)
	local list = { title({ "WANTED" }, RED, "THE BOUNTY BOARD", RED) }
	for _, boss in info.Bosses or {} do
		table.insert(list, wanted(boss))
	end
	addToon(list, "Disguise", 7)
	table.insert(list, tip({ "HUNT THEM", "AT BOUNTY", "OFFICE" }, GOLD, "Chest"))
	return list
end
function SCENES.Kaiju(info)
	local list = { title({ "KAIJU" }, CYAN, "THEY FIGHT FOR YOU", CYAN) }
	for _, entry in info.Kaiju or {} do
		table.insert(list, kaiju(entry))
	end
	addToon(list, "Sneeze", 9)
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
