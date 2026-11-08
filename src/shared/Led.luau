--[[
	The Outpost's LED screens (four giants in the sky round the settlement,
	World.OutpostWorld's LedScreens; Client.LedScreens lights them): guides
	and tips, animated, as pixels. A screen is W x H LEDs; a frame is a
	buffer of them, each off (nil) or one colour (0xRRGGBB). Text is
	Shared.LedFont's 3x5 (twice the size for titles); pictures are Shared.
	LedArt's (the game's art and its kaiju and bosses, converted by
	tools/led_art.py).

	Each screen plays its board's scenes one after another, each a few
	seconds: a header (the topic, which scene of how many), a body that
	builds in (art on the left, three lines on the right, or a diagram
	across the screen), a bar along the bottom for the time left. The facts
	are the game's own (Shared.GameGuide says the same).

	  Guide      N   start here: mine, gear up, team up, fight, tasks
	  Controls   NE  attack, block, dodge, Surges, HYPERBEAM, catch, keys
	  Elements   E   the cycle, each element, armor resists, WEAK!/RESIST
	  Gems       SE  rarity, the Legendaries, richer further out, spare
	                 gems, EQUIP BEST
	  Bounties   S   each Rift boss: element, threat, weakness
	  Rift       SW  veins to gates to bosses, ladders, telegraphs, threat,
	                 party, loot
	  Kaiju      W   your team, each kaiju and its role, healing, teams,
	                 the Kaiju Arena
	  Outpost    NW  the map (each place lit in turn), critters, falling,
	                 mechs, your pod

	and among them SAGA TOONS, short cartoons of the kaiju and bosses
	(Led.Toons), each ending on a tip: MINE! on the Guide, SNEEZE on
	Controls, HOT N COLD on Elements, BONK! on Gems, DISGUISE on Bounties.

	  Led.W, Led.H, Led.Boards, Led.ElementNames
	  Led.new() -> buffer;  Led.get(buffer, x, y) -> rgb?
	  Led.text(buffer, x, y, text, rgb, scale?) -> width;  Led.width(text, scale?)
	  Led.center(buffer, y, text, rgb, scale?);  Led.art(buffer, art, x, y, tint?, k?)
	  Led.fit(text, chars) -> text   capitals the font has, cut to fit
	  Led.scenes(board, info) -> { { Duration, Draw = (t) -> buffer } }
	  Led.toon(name) -> scene?   an episode (nil: no art for its cast)
	  Led.basics(name, cues, seconds, touch?) -> scene   a new miner's lesson,
	      one of Led.BasicsOrder, in time with the narrator (Client.BasicsScreen)
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
Led.Boards = { "Guide", "Controls", "Elements", "Gems", "Bounties", "Rift", "Kaiju", "Outpost" }
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
-- Guides --------------------------------------------------------------------------------------------
-- The screens' look: a header (what it's about, in the board's colour, and
-- which scene of how many), a rule drawn in under it, the body below it,
-- and a thin bar along the bottom for how far through the scene is. The
-- body is art on the left (ART: 22 LEDs) and three lines of text on the
-- right, sliding in one after another; or a diagram across the whole
-- screen. Everything says something true about the game (Shared.GameGuide
-- has the same facts).

local SOFT = rgb(150, 162, 186) -- (secondary text)
local RULE = rgb(44, 52, 72) -- (rules and frames)
local TEXT_X = 24 -- the text column (12 letters)
local ROW = { 9, 15, 21 } -- the body's three lines
local RARITY = {
	{ "COMMON", rgb(200, 200, 200) },
	{ "UNCOMMON", rgb(90, 220, 120) },
	{ "RARE", rgb(80, 160, 255) },
	{ "ULTRA RARE", rgb(255, 90, 220) },
	{ "LEGENDARY", rgb(255, 176, 60) },
}
local LEGENDS = {
	{ "STARFIRE", "RUBY", "Fire", rgb(255, 46, 46) },
	{ "AURORA", "SAPPHIRE", "Frost", rgb(60, 120, 255) },
	{ "STORMHEART", "CITRINE", "Shock", rgb(255, 236, 90) },
	{ "VENOMHEART", "EMERALD", "Poison", rgb(0, 255, 120) },
}
local BEATS = { Fire = "Frost", Frost = "Shock", Shock = "Poison", Poison = "Fire" }
local WEAK_TO = { Frost = "Fire", Shock = "Frost", Poison = "Shock", Fire = "Poison" }

-- `c` faded to `k` (never all the way: an LED at 0 is a black dot).
local function fade(c: number, k: number): number
	return scale(c, math.max(0.15, k))
end

-- An entrance: 0 before `at`, easing to 1 over `len`.
local function enter(t: number, at: number, len: number?): number
	return ease((t - at) / (len or 0.4))
end

local function rect(b, x: number, y: number, w: number, h: number, c: number?)
	for yy = y, y + h - 1 do
		for xx = x, x + w - 1 do
			Led.set(b, xx, yy, c)
		end
	end
end
local function hline(b, x0: number, x1: number, y: number, c: number)
	for x = x0, x1 do
		Led.set(b, x, y, c)
	end
end
local function box(b, x: number, y: number, w: number, h: number, c: number)
	hline(b, x, x + w - 1, y, c)
	hline(b, x, x + w - 1, y + h - 1, c)
	for yy = y, y + h - 1 do
		Led.set(b, x, yy, c)
		Led.set(b, x + w - 1, yy, c)
	end
end
local function line(b, x0: number, y0: number, x1: number, y1: number, c: number)
	local n = math.max(math.abs(x1 - x0), math.abs(y1 - y0), 1)
	for i = 0, n do
		Led.set(b, x0 + (x1 - x0) * i / n + 0.5, y0 + (y1 - y0) * i / n + 0.5, c)
	end
end
-- Draws with `draw(tmp)`, keeping only the columns x0..x1.
local function clip(b, x0: number, x1: number, draw)
	local tmp = Led.new()
	draw(tmp)
	for i, c in tmp.P do
		local x = (i - 1) % Led.W
		if x >= x0 and x <= x1 then
			b.P[i] = c
		end
	end
end
-- Text in runs of colours: { { text, colour } }.
local function runs(b, x: number, y: number, parts)
	for _, part in parts do
		local s = Led.fit(part[1])
		Led.text(b, x, y, s, part[2])
		x += #s * LedFont.Advance
	end
end
-- Text too long for its column scrolls along it (a marquee): text, or
-- runs ({ { text, colour } }).
local function marquee(b, x: number, y: number, chars: number, text: any, color: number?, t: number)
	local parts = if type(text) == "table" then text else { { text, color } }
	local count = 0
	for _, part in parts do
		count += #Led.fit(part[1])
	end
	if count <= chars then
		runs(b, x, y, parts)
		return
	end
	local span = (count + 4) * LedFont.Advance
	local hold = 0.8
	local off = math.floor(math.max(0, (t - hold) * 14) % span)
	clip(b, x, x + chars * LedFont.Advance - 2, function(tmp)
		runs(tmp, x - off, y, parts)
		runs(tmp, x - off + span, y, parts)
	end)
end

local function header(b, t: number, label: string, index: number?, total: number?, accent: number, x0: number)
	Led.text(b, x0, 0, Led.fit(label, 13), accent)
	if index and total then
		local s = string.format("%02d/%02d", index, total)
		if x0 + Led.width(Led.fit(label, 13)) + 3 < Led.W - Led.width(s) then
			Led.text(b, Led.W - Led.width(s), 0, s, SOFT)
		end
	end
	local reach = x0 + math.floor(enter(t, 0, 0.6) * (Led.W - x0))
	hline(b, x0, reach - 1, 6, RULE)
	hline(b, x0, math.min(reach, x0 + 9) - 1, 6, accent)
end
local function progress(b, t: number, duration: number, accent: number, x0: number)
	local w = math.floor(math.clamp(t / duration, 0, 1) * (Led.W - x0))
	hline(b, x0, x0 + w - 1, Led.H - 1, scale(accent, 0.45))
end
-- The body's lines, from x: each slides in from the right in turn; a line
-- is text (white) or runs ({ { text, colour } }).
local function body(b, t: number, list: { any }, x: number?, at: number?)
	x = x or TEXT_X
	for i, item in list do
		local k = enter(t, (at or 0.3) + (i - 1) * 0.15, 0.45)
		if k > 0 then
			local dx = math.floor((1 - k) * 12 + 0.5)
			clip(b, x, Led.W - 1, function(tmp)
				if type(item) == "table" then
					runs(tmp, x + dx, ROW[i], item)
				else
					Led.text(tmp, x + dx, ROW[i], item, WHITE)
				end
			end)
		end
	end
end

-- A guide scene: header, body (`draw(b, t)`), the bar. Made once its board
-- knows how many it has (for the header's 03/07): finish() below.
local function guide(label: string, accent: number, duration: number, draw, x0: number?)
	return {
		Guide = true,
		Make = function(index: number, total: number)
			return scene(duration, function(t)
				local b = Led.new()
				draw(b, t)
				header(b, t, label, index, total, accent, x0 or 0)
				progress(b, t, duration, accent, x0 or 0)
				return b
			end)
		end,
	}
end
-- The usual one: art on the left (`art(b, t)`), three lines on the right.
local function card(label: string, accent: number, lines: { any }, art, duration: number?)
	return guide(label, accent, duration or 7, function(b, t)
		if art then
			art(b, t)
		end
		body(b, t, lines)
	end)
end

-- A keycap: its label in a frame, a shadow under it; pressed, it's down a
-- row and lit. Returns its width.
local function keycap(b, x: number, y: number, label: string, accent: number, pressed: boolean?): number
	local w = Led.width(label)
	local pad = if w + 4 > 22 then 1 else 2
	local cw = w + pad * 2
	if pressed then
		rect(b, x + 1, y + 2, cw - 2, 5, scale(accent, 0.3))
		box(b, x, y + 1, cw, 7, accent)
		Led.text(b, x + pad, y + 2, label, WHITE)
	else
		rect(b, x + 1, y + 1, cw - 2, 5, nil)
		box(b, x, y, cw, 7, SOFT)
		hline(b, x + 1, x + cw - 2, y + 7, RULE)
		Led.text(b, x + pad, y + 1, label, WHITE)
	end
	return cw
end
-- A mouse, its left or right button lit.
local function mouse(b, x: number, y: number, which: string?, accent: number)
	box(b, x, y, 9, 12, SOFT)
	for yy = y + 1, y + 4 do
		Led.set(b, x + 4, yy, SOFT)
	end
	hline(b, x + 1, x + 7, y + 5, SOFT)
	if which == "Left" then
		rect(b, x + 1, y + 1, 3, 4, accent)
	elseif which == "Right" then
		rect(b, x + 5, y + 1, 3, 4, accent)
	end
end

-- A row of steps joined by a line, lit one after another by a light
-- running along it; labels above and below in turn so they never touch.
local function steps(labels: { string }, accent: number, duration: number)
	return function(b, t)
		local n = #labels
		local y = 17
		local xs = {}
		for i = 1, n do
			xs[i] = math.floor(6 + (i - 1) * (Led.W - 13) / (n - 1) + 0.5)
		end
		local head = math.clamp((t - 0.6) / (duration - 2), 0, 1) * (xs[n] - xs[1]) + xs[1]
		hline(b, xs[1], xs[n], y, RULE)
		hline(b, xs[1], math.floor(head), y, scale(accent, 0.6))
		for i, x in xs do
			local lit = head >= x - 0.5
			rect(b, x - 1, y - 1, 3, 3, if lit then accent else SOFT)
			if lit then
				Led.set(b, x, y, WHITE)
				local since = (head - x) / 6
				if since < 1 then
					box(b, x - 2, y - 2, 5, 5, fade(accent, 1 - since))
				end
			end
			local label = labels[i]
			local w = Led.width(label)
			local ly = if i % 2 == 1 then 10 else 21
			Led.text(b, math.clamp(x - math.floor(w / 2), 0, Led.W - w), ly, label, if lit then WHITE else SOFT)
		end
		Led.set(b, head, y, WHITE)
	end
end

-- A cut gem in pixels, `w` across (odd), its top at `top`: the table and
-- crown lit from the left, the girdle, the pavilion in facets to its point.
local function pixelGem(b, cx: number, top: number, w: number, c: number, glint: number?)
	local half = math.floor(w / 2)
	local rows = {}
	for r = 0, 2 do
		table.insert(rows, { half - 3 + r, "Crown", r })
	end
	table.insert(rows, { half, "Girdle", 3 })
	local h = half
	local r = 4
	while h > 0 do
		h = math.max(0, math.floor(half - (r - 3) * 1.25 + 0.5))
		table.insert(rows, { h, "Pavilion", r })
		r += 1
	end
	for _, row in rows do
		local hw, part, y = row[1], row[2], row[3]
		for x = -hw, hw do
			local k = (x + hw) / math.max(1, 2 * hw)
			local col
			if part == "Crown" then
				col = if y == 0 then mix(c, WHITE, 0.55) elseif k < 0.34 then mix(c, WHITE, 0.4) elseif k < 0.67 then mix(c, WHITE, 0.15) else scale(c, 0.75)
			elseif part == "Girdle" then
				col = mix(c, WHITE, 0.3)
			else
				local facet = math.floor((x + (y - 3) * (if x < 0 then 1 else -1)) / 3) % 2 == 0
				col = if facet then (if x < 0 then mix(c, WHITE, 0.1) else c) else scale(c, if x < 0 then 0.8 else 0.6)
			end
			Led.set(b, cx + x, top + y, col)
		end
	end
	if glint then
		local g = (glint % 1)
		if g < 0.3 then
			local x, y = cx - half + 2, top + 1
			Led.set(b, x, y, WHITE)
			Led.set(b, x - 1, y, mix(c, WHITE, 0.7))
			Led.set(b, x + 1, y, mix(c, WHITE, 0.7))
			Led.set(b, x, y - 1, mix(c, WHITE, 0.7))
		end
	end
	return #rows
end

-- Art ------------------------------------------------------------------------------------------------
-- (each in the left column: x 0 to 21, rows 8 to 28)

-- A pick at a rock: three swings crack it, the third splits it and a gem
-- rises out, a different element each time round.
local function artMine(b, t: number)
	local loop = 3.6
	local u = t % loop
	local element = ELEMENTS[math.floor(t / loop) % 4 + 1]
	local hits = { 0.5, 1.15, 1.8 }
	local done = 0
	for _, h in hits do
		if u >= h then
			done += 1
		end
	end
	local split = if done >= 3 then math.floor(ease((u - hits[3]) / 0.3) * 3 + 0.5) else 0
	local shake = 0
	for _, h in hits do
		if u >= h and u < h + 0.12 then
			shake = if math.floor(u * 40) % 2 == 0 then 1 else -1
		end
	end
	rock(b, 9 + shake, 27, math.min(done, 2), split)
	if done < 3 or u < hits[3] + 0.25 then
		-- the pick: raised, swung down onto the rock's top, back up
		local angle = 205
		for _, h in hits do
			if u >= h - 0.28 and u < h then
				angle = lerp(205, 138, ((u - (h - 0.28)) / 0.28) ^ 2)
			elseif u >= h and u < h + 0.25 then
				angle = lerp(138, 205, ease((u - h) / 0.25))
			end
		end
		local a = math.rad(angle)
		local px, py = 19, 10
		local hx, hy = px + math.cos(a) * 11, py + math.sin(a) * 11
		line(b, px, py, hx, hy, rgb(150, 100, 56))
		local nx, ny = -math.sin(a), math.cos(a)
		line(b, hx - nx * 3, hy - ny * 3, hx + nx * 3, hy + ny * 3, rgb(210, 218, 230))
	end
	for _, h in hits do
		if u >= h and u < h + 0.1 then
			for _, d in { { -2, -1 }, { 2, -1 }, { -1, -2 }, { 1, -2 } } do
				Led.set(b, 9 + d[1], 18 + d[2], WHITE)
			end
		end
	end
	if done >= 3 then
		local k = enter(u, hits[3] + 0.1, 0.6)
		local gw, gh = artSize(SMALL[element])
		Led.art(b, SMALL[element], 9 - math.floor(gw / 2), math.floor(lerp(20, 9, k)))
		if k >= 1 then
			local p = ((u - hits[3] - 0.7) / 0.8) % 1
			box(b, 9 - math.floor(gw / 2) - 1 - math.floor(p * 3), 8 - math.floor(p * 3), gw + 2 + math.floor(p * 3) * 2, gh + 2 + math.floor(p * 3) * 2, fade(ELEMENT[element], 1 - p))
		end
	end
end

-- A gem dropping into a helmet's socket: the helmet takes its element.
local function artGear(b, t: number)
	local loop = 3
	local u = t % loop
	local element = ELEMENTS[math.floor(t / loop) % 4 + 1]
	local color = ELEMENT[element]
	local landed = u >= 0.9
	local glow = if landed then math.max(0, 0.6 - (u - 0.9) * 0.35) else 0
	sprite(b, "Helmet", 10, 27, { SX = 0.72, SY = 0.72, Tint = color, K = glow })
	local gw, gh = artSize(SMALL[element])
	local y = if landed then 17 else lerp(6, 17, (u / 0.9) ^ 2)
	Led.art(b, SMALL[element], 10 - math.floor(gw / 2), math.floor(y))
	if landed and u < 1.6 then
		local k = (u - 0.9) / 0.7
		ring(b, 10, 21, 3 + k * 9, fade(color, 1 - k))
	end
end

-- Your team from above: you, the lead out ahead, two behind it, the
-- support between, each going out to its place in turn.
local FORMATION = { { 10, 10, ELEMENT.Fire }, { 5, 15, ELEMENT.Frost }, { 15, 15, ELEMENT.Shock }, { 10, 20, GOOD } }
local function artTeam(b, t: number)
	local px, py = 10, 26
	rect(b, px - 1, py - 1, 3, 3, WHITE)
	for i, slot in FORMATION do
		local k = enter(t, 0.3 + (i - 1) * 0.3, 0.5)
		local x = math.floor(lerp(px, slot[1], k) + 0.5)
		local y = math.floor(lerp(py, slot[2], k) + 0.5)
		rect(b, x - 1, y - 1, 3, 3, slot[3])
		if i == 4 then
			Led.set(b, x, y - 1, WHITE)
			Led.set(b, x - 1, y, WHITE)
			Led.set(b, x, y, WHITE)
			Led.set(b, x + 1, y, WHITE)
			Led.set(b, x, y + 1, WHITE)
		end
	end
	-- (the way you're going)
	local p = (t * 0.8) % 1
	Led.set(b, px, py - 3 - math.floor(p * 3), fade(WHITE, 1 - p))
end

-- A boss taking hits: a flash on each, its damage rising off it.
local function artFight(b, t: number, who: string?)
	local period = 0.8
	local n = math.floor(t / period)
	local u = t % period
	sprite(b, who or "MiniBossDrago", 11, 27, { Tint = WHITE, K = if u < 0.08 then 0.7 else 0 })
	local numbers = { "84", "125", "97", "140" }
	local s = numbers[n % #numbers + 1]
	local k = u / period
	Led.text(b, 12 - math.floor(Led.width(s) / 2) + (if n % 2 == 0 then 4 else -4), math.floor(14 - k * 5), s, scale(if s == "125" or s == "140" then GOLD else WHITE, 1 - k * 0.6))
end

-- A checklist ticking itself off.
local function artTasks(b, t: number)
	local loop = 3.6
	local u = t % loop
	for i, y in { 10, 16, 22 } do
		local done = u >= 0.6 + (i - 1) * 0.7
		box(b, 1, y, 5, 5, if done then GOOD else SOFT)
		hline(b, 8, 20, y + 2, if done then scale(GOOD, 0.5) else RULE)
		if done then
			Led.set(b, 2, y + 2, GOOD)
			Led.set(b, 3, y + 3, GOOD)
			Led.set(b, 4, y + 1, GOOD)
		end
	end
end

-- Swings at a dummy, from either side in turn.
local function artAttack(b, t: number, accent: number)
	local period = 0.55
	local n = math.floor(t / period)
	local u = (t % period) / period
	mouse(b, 6, 8, if u < 0.25 then "Left" else nil, accent)
	rect(b, 9, 22, 3, 6, SOFT)
	Led.set(b, 10, 21, SOFT)
	if u < 0.5 then
		local side = if n % 2 == 0 then -1 else 1
		for i = 0, 4 do
			local a = math.rad(-100 + side * 20 + (i - 2) * 22 * side + u * 40 * side)
			Led.set(b, 10 + math.cos(a) * 7 * side, 24 + math.sin(a) * 5, fade(WHITE, 1 - u * 1.4 + i * 0.05))
		end
	end
end

-- Holding guard as a shot comes in; every other one blocked just in time:
-- a perfect block's flash.
local function artBlock(b, t: number, accent: number)
	local loop = 1.6
	local u = t % loop
	local perfect = math.floor(t / loop) % 2 == 1
	local held = if perfect then u >= 0.86 and u < 1.2 else u >= 0.2 and u < 1.3
	mouse(b, 6, 8, if held then "Right" else nil, accent)
	local hit = 1
	if u < hit then
		local x = math.floor(lerp(21, 7, u / hit))
		Led.set(b, x, 24, RED)
		Led.set(b, x + 1, 24, scale(RED, 0.5))
	end
	if held then
		for y = 21, 27 do
			Led.set(b, 5, y, accent)
		end
	end
	if u >= hit and u < hit + 0.18 then
		if perfect then
			for _, d in { { 2, -3 }, { 3, 0 }, { 2, 3 }, { 4, -2 }, { 4, 2 } } do
				Led.set(b, 5 + d[1], 24 + d[2], WHITE)
			end
		else
			Led.set(b, 6, 24, SOFT)
		end
	end
end

-- A slam's red ring grows where you stand; SPACE, and you're out of it.
local function artDodge(b, t: number, accent: number)
	local loop = 1.8
	local u = t % loop
	local pressed = u >= 0.7 and u < 0.85
	keycap(b, 0, 8, "SPACE", accent, pressed)
	local k = math.clamp(u / 0.9, 0, 1)
	if u < 1.05 then
		ring(b, 8, 23, 1 + k * 4, if u >= 0.9 then WHITE else scale(RED, 0.5 + k * 0.5))
	end
	local dx = if u >= 0.7 then lerp(0, 10, ease((u - 0.7) / 0.2)) else 0
	rect(b, math.floor(7 + dx), 22, 2, 2, WHITE)
	if u >= 0.7 and u < 1 then
		for s = 1, 3 do
			Led.set(b, 7 + dx - s * 2, 23, scale(WHITE, 0.5 - s * 0.12))
		end
	end
end

-- Hits fill the Charge bar; full, Q, E and R cast in turn.
local function artSurges(b, t: number, accent: number)
	local loop = 3.2
	local u = t % loop
	local colors = { ELEMENT.Fire, ELEMENT.Frost, ELEMENT.Shock }
	local full = u >= 1.4
	for i, key in { "Q", "E", "R" } do
		local cast = full and u >= 1.5 + (i - 1) * 0.4 and u < 1.5 + (i - 1) * 0.4 + 0.3
		keycap(b, (i - 1) * 7, 8, key, colors[i], cast)
	end
	local fill = math.clamp(math.floor(u / 0.28) / 5, 0, 1)
	if full then
		fill = math.clamp(1 - (u - 1.5) / 1.2, 0, 1)
	end
	box(b, 0, 18, 21, 4, RULE)
	hline(b, 1, 1 + math.floor(18 * fill), 19, if full then WHITE else accent)
	hline(b, 1, 1 + math.floor(18 * fill), 20, if full then accent else scale(accent, 0.6))
	Led.text(b, 0, 23, "CHARGE", SOFT)
end

-- The HYPERBEAM: charged, then Z, then the beam.
local function artBeam(b, t: number, accent: number)
	local loop = 3
	local u = t % loop
	local fire = u >= 1.6
	keycap(b, 7, 8, "Z", accent, fire and u < 1.8)
	local charge = math.clamp(u / 1.5, 0, 1)
	local s = math.floor(charge * 100) .. "%"
	if not fire then
		Led.text(b, 11 - math.floor(Led.width(s) / 2), 19, s, if charge >= 1 then WHITE else accent)
	else
		local reach = math.floor(math.clamp((u - 1.6) * 80, 0, 22))
		for x = 0, reach do
			local w = 1 + math.floor(math.sin(u * 30 + x) * 0.5 + 0.5)
			for dy = -w, w do
				Led.set(b, x, 22 + dy, if math.abs(dy) == w then accent elseif dy == 0 then WHITE else mix(accent, WHITE, 0.5))
			end
		end
	end
end

-- A wild kaiju worn down till it glows gold, then caught.
local function artCatch(b, t: number, accent: number)
	local loop = 3.4
	local u = t % loop
	local hp = math.clamp(1 - u / 1.4, 0.12, 1)
	local gold = u >= 1.4
	local caught = u >= 2.2
	keycap(b, 7, 8, "C", accent, caught and u < 2.4)
	if not caught then
		local glow = if gold then 0.5 + 0.3 * math.sin(u * 14) else 0
		rect(b, 8, 21, 5, 5, mix(ELEMENT.Poison, GOLD, glow))
		box(b, 4, 18, 13, 2, RULE)
		hline(b, 5, 5 + math.floor(10 * hp), 18, if gold then GOLD else RED)
	else
		local k = math.clamp((u - 2.2) / 0.5, 0, 1)
		if k < 1 then
			box(b, math.floor(8 - 4 * (1 - k)), math.floor(21 - 4 * (1 - k)), math.floor(5 + 8 * (1 - k)), math.floor(5 + 8 * (1 - k)), GOLD)
		else
			Led.art(b, SMALL.Shock, 6, 19)
		end
	end
end

-- A gem with its own weather round it (kept to the art column).
local function artElement(name: string)
	return function(b, t)
		clip(b, 0, 21, function(tmp)
			WEATHER[name](tmp, t)
		end)
		for i, c in b.P do
			if (i - 1) % Led.W <= 21 then
				b.P[i] = scale(c, 0.55)
			end
		end
		pixelGem(b, 10, 12, 19, ELEMENT[name], t * 0.6)
	end
end

-- Armor's resist filling, a gem a piece, up to its 35% cap.
local function artResist(b, t: number, accent: number)
	local loop = 4
	local u = t % loop
	box(b, 7, 8, 8, 17, RULE)
	local pieces = math.clamp(math.floor(u / 0.5), 0, 5)
	for i = 1, pieces do
		rect(b, 8, 24 - i * 3, 6, 2, if i == 5 then WHITE else accent)
	end
	local s = math.floor(pieces * 7) .. "%"
	Led.text(b, 11 - math.floor(Led.width(s) / 2), 25, s, if pieces == 5 then WHITE else SOFT)
end

-- Rarity as a staircase, each step lit in turn.
local function artRarity(b, t: number)
	local lit = math.floor(t / 1.2) % 5 + 1
	for i, r in RARITY do
		local h = 3 + i * 3
		local k = enter(t, 0.2 + i * 0.12, 0.4)
		local hh = math.floor(h * k)
		rect(b, 1 + (i - 1) * 4, 27 - hh + 1, 3, hh, if i == lit then r[2] else scale(r[2], 0.45))
	end
end

-- A gem going into a kaiju's health bar.
local function artHeal(b, t: number)
	local loop = 2.6
	local u = t % loop
	sprite(b, "MiniKaijuGrandape", 11, 27, { SX = 0.85, SY = 0.85 })
	box(b, 2, 8, 18, 3, RULE)
	local hp = if u < 1 then 0.3 else lerp(0.3, 1, ease((u - 1) / 0.6))
	hline(b, 3, 3 + math.floor(15 * hp), 9, if hp >= 1 then GOOD else scale(GOOD, 0.7))
	if u < 1 then
		Led.art(b, SMALL.Poison, 16, math.floor(lerp(20, 8, u)))
	end
end

-- Five gear slots, filled at one tap.
local function artEquip(b, t: number, accent: number)
	local loop = 3
	local u = t % loop
	local tapped = u >= 0.8
	local colors = { RARITY[5][2], RARITY[4][2], RARITY[5][2], RARITY[3][2], RARITY[4][2] }
	for i = 1, 5 do
		local x = 1 + ((i - 1) % 3) * 7
		local y = 9 + math.floor((i - 1) / 3) * 7
		box(b, x, y, 6, 6, RULE)
		if tapped and u >= 0.8 + i * 0.06 then
			rect(b, x + 1, y + 1, 4, 4, colors[i])
		end
	end
	keycap(b, 0, 21, "EQUIP", accent, u >= 0.7 and u < 0.95)
end

-- A WANTED notice on a board.
local function artNotice(b, t: number)
	box(b, 2, 8, 18, 20, GOLD)
	rect(b, 3, 9, 16, 3, RED)
	for i, y in { 15, 19, 23 } do
		local k = enter(t, 0.3 + i * 0.15, 0.3)
		hline(b, 5, 5 + math.floor(11 * k), y, SOFT)
	end
end

-- A Rift vein pulsing in the rock.
local function artVein(b, t: number)
	local vein = { { 1, 26 }, { 5, 23 }, { 8, 24 }, { 11, 19 }, { 14, 20 }, { 17, 14 }, { 20, 11 } }
	local violet = rgb(190, 90, 255)
	for i = 1, #vein - 1 do
		local p = (t * 1.2 - i * 0.15) % 1
		line(b, vein[i][1], vein[i][2], vein[i + 1][1], vein[i + 1][2], mix(scale(violet, 0.5), WHITE, math.max(0, 1 - p * 3) * 0.8))
	end
	-- the gate at its end
	local k = (math.sin(t * 3) + 1) / 2
	box(b, 15, 7, 7, 9, mix(violet, WHITE, k * 0.4))
end

-- A boss's slam: the red zone grows, you step out of it.
local function artTelegraph(b, t: number)
	local loop = 2.2
	local u = t % loop
	local k = math.clamp(u / 1.3, 0, 1)
	sprite(b, "MiniBossSahurTrio", 6, 20, { SX = 0.6, SY = 0.6 })
	if u < 1.45 then
		for y = 21, 27 do
			for x = 1, 20 do
				local d = ((x - 9) / 9) ^ 2 + ((y - 24) / 3.5) ^ 2
				if d <= k * k then
					Led.set(b, x, y, if u >= 1.3 then WHITE else scale(RED, 0.35 + 0.3 * k))
				end
			end
		end
	end
	local out = if u >= 0.9 then ease((u - 0.9) / 0.25) else 0
	rect(b, math.floor(14 + out * 6), 23, 2, 2, WHITE)
end

-- Three of you against one.
local function artParty(b, t: number)
	sprite(b, "MiniBossFrigo", 15, 27, { SX = 0.75, SY = 0.75 })
	for i, y in { 11, 18, 25 } do
		local k = enter(t, 0.2 + i * 0.25, 0.5)
		rect(b, math.floor(lerp(-3, 3, k)), y, 2, 2, ({ WHITE, CYAN, GOLD })[i])
	end
end

-- A cache opening.
local function artLoot(b, t: number)
	local loop = 3
	local u = t % loop
	local open = u >= 0.8
	sprite(b, "Chest", 11, 27, { SX = 0.7, SY = 0.7, Tint = GOLD, K = if open then 0.25 else 0 })
	if open and u < 2 then
		local k = (u - 0.8) / 1.2
		for i = 0, 5 do
			local a = math.rad(-150 + i * 24)
			Led.set(b, 11 + math.cos(a) * (4 + k * 7), 17 + math.sin(a) * (3 + k * 6), fade(GOLD, 1 - k))
		end
	end
end

-- Critters closing in; your kaiju meeting them.
local function artCritters(b, t: number)
	local loop = 3
	local u = t % loop
	rect(b, 9, 19, 3, 3, WHITE)
	for i, from in { { 0, 9 }, { 20, 11 }, { 1, 27 }, { 20, 27 } } do
		local k = math.clamp(u / 1.6, 0, 1) * 0.7
		Led.set(b, lerp(from[1], 10, k), lerp(from[2], 20, k), RED)
	end
	if u >= 1.1 then
		local k = enter(u, 1.1, 0.4)
		for i, to in { { 4, 13 }, { 16, 14 }, { 6, 25 } } do
			rect(b, math.floor(lerp(10, to[1], k)), math.floor(lerp(20, to[2], k)), 2, 2, ({ ELEMENT.Fire, ELEMENT.Frost, ELEMENT.Shock })[i])
		end
	end
end

-- Down: your newest gems carried off.
local function artFall(b, t: number)
	local loop = 2.6
	local u = t % loop
	rect(b, 5, 25, 5, 2, SOFT)
	for i, element in { "Fire", "Frost", "Shock" } do
		local k = math.clamp((u - i * 0.25) / 1.4, 0, 1)
		Led.set(b, lerp(9, 21, k), 24 - i * 3 - k * 3, scale(ELEMENT[element], 1 - k * 0.7))
		Led.set(b, lerp(10, 22, k), 24 - i * 3 - k * 3, RED)
	end
end

-- A mech: legs, cab, a drill turning.
local function artMech(b, t: number)
	local step = math.floor(t * 4) % 2
	rect(b, 5, 13, 9, 7, rgb(255, 176, 60))
	rect(b, 7, 14, 5, 3, CYAN)
	rect(b, 6, 20, 2, 7 - step, SOFT)
	rect(b, 11, 20, 2, 6 + step, SOFT)
	hline(b, 14, 16, 17, SOFT)
	for i = 0, 3 do
		local on = (i + math.floor(t * 12)) % 2 == 0
		Led.set(b, 17 + i, 16, if on then WHITE else SOFT)
		Led.set(b, 17 + i, 18, if on then SOFT else WHITE)
	end
	Led.set(b, 21, 17, WHITE)
end

-- Your pod: its door slides open, the stair out.
local function artPod(b, t: number, accent: number)
	local loop = 3
	local u = t % loop
	for y = 0, 10 do
		local half = math.floor(math.sqrt(math.max(0, 1 - ((y - 10) / 11) ^ 2)) * 9 + 0.5)
		hline(b, 10 - half, 10 + half, 13 + y, rgb(200, 206, 220))
	end
	local open = math.clamp((u - 0.4) / 0.6, 0, 1)
	rect(b, 8, 18, 5, 6, scale(accent, 0.4 + open * 0.6))
	hline(b, 3, 17, 24, accent)
	if open >= 1 then
		for s = 0, 2 do
			hline(b, 9 - s, 12 + s, 25 + s, SOFT)
		end
	end
end

-- Full-screen pieces --------------------------------------------------------------------------------

-- The element cycle: each beats the next round the ring.
local CYCLE_AT = { Fire = { 14, 9 }, Frost = { 23, 18 }, Shock = { 14, 27 }, Poison = { 5, 18 } }
local function cycle(b, t: number)
	local turn = math.floor(t / 1.6) % 4 + 1
	local u = (t % 1.6) / 1.6
	local from = ELEMENTS[turn]
	local to = BEATS[from]
	for _, name in ELEMENTS do
		local at = CYCLE_AT[name]
		local lit = name == from or (name == to and u > 0.5)
		rect(b, at[1] - 1, at[2] - 1, 3, 3, if lit then ELEMENT[name] else scale(ELEMENT[name], 0.4))
	end
	ring(b, 14, 18, 9, RULE)
	-- the light going from one to the next, round the ring
	local a0 = ({ Fire = -90, Frost = 0, Shock = 90, Poison = 180 })[from]
	local a = math.rad(a0 + 90 * math.clamp(u * 1.6, 0, 1))
	Led.set(b, 14 + math.cos(a) * 9, 18 + math.sin(a) * 9 * 0.9, WHITE)
	local x = 32
	runs(b, x, 9, { { Led.ElementNames[from], ELEMENT[from] } })
	runs(b, x, 15, { { "BEATS", SOFT } })
	if u > 0.4 then
		runs(b, x, 21, { { Led.ElementNames[to], ELEMENT[to] } })
	end
end

-- WEAK! and RESIST: what the hits say.
local function hitsDemo(b, t: number)
	local u = t % 2.4
	local first = u < 1.2
	local k = (u % 1.2) / 1.2
	local rise = math.floor(k * 3)
	if first then
		Led.text(b, 4, 12 - rise, "WEAK!", GOLD, 2)
		Led.text(b, 50, 13, "+25%", GOLD)
	else
		Led.text(b, 4, 12 - rise, "RESIST", SOFT)
		Led.text(b, 4, 18 - rise, "LESS DAMAGE", SOFT)
	end
	Led.text(b, 4, 24, "ON EVERY HIT", SOFT)
end

-- Richer rocks further from home, more danger too.
local function further(b, t: number)
	Led.text(b, 0, 9, "RICHER FURTHER OUT", WHITE)
	-- home on the left
	rect(b, 1, 21, 6, 5, SOFT)
	Led.set(b, 2, 20, SOFT)
	Led.set(b, 3, 19, SOFT)
	Led.set(b, 4, 19, SOFT)
	Led.set(b, 5, 20, SOFT)
	local walker = math.clamp((t - 0.4) / 5, 0, 1)
	for x = 9, 70, 2 do
		Led.set(b, x, 26, RULE)
	end
	for i, x in { 18, 33, 48, 63 } do
		local r = RARITY[i + 1]
		local size = 1 + i
		local seen = walker * 62 + 9 >= x - 6
		rect(b, x - size, 26 - size, size * 2 + 1, size, if seen then rgb(100, 106, 120) else RULE)
		if seen then
			Led.set(b, x, 25 - size, r[2])
			Led.set(b, x + 1, 25 - size, r[2])
		end
		if i >= 3 and seen and math.floor(t * 4 + i) % 2 == 0 then
			Led.set(b, x + size + 3, 22, RED)
		end
	end
	rect(b, math.floor(9 + walker * 60), 22, 2, 3, WHITE)
	if walker > 0.6 then
		Led.text(b, 48, 16, "DANGER", RED)
	end
end

-- The Rift's ladders: a column an element, its bosses one above another,
-- each beaten one opening the next.
local function ladders(info)
	return function(b, t)
		local cols = {}
		for _, name in ELEMENTS do
			cols[name] = {}
		end
		for _, boss in info.Bosses or {} do
			if cols[boss.Element] then
				table.insert(cols[boss.Element], boss)
			end
		end
		local beaten = math.floor(math.max(0, t - 0.6) / 0.9)
		for c, name in ELEMENTS do
			local x = 4 + (c - 1) * 18
			Led.art(b, SMALL[name], x, 8)
			for i, _boss in cols[name] do
				local y = 27 - (i - 1) * 5
				local state = if i <= beaten then "Beaten" elseif i == beaten + 1 then "Open" else "Locked"
				local color = if state == "Beaten" then ELEMENT[name] elseif state == "Open" then WHITE else RULE
				box(b, x, y - 2, 9, 4, color)
				if state == "Beaten" then
					rect(b, x + 1, y - 1, 7, 2, scale(ELEMENT[name], 0.5))
				elseif state == "Open" and math.floor(t * 3) % 2 == 0 then
					rect(b, x + 3, y - 1, 3, 2, WHITE)
				end
			end
		end
	end
end

-- Threat I to III: who each is for.
local function threat(b, t: number)
	local list = {
		{ "I", "BUILT FOR ONE", rgb(255, 202, 91) },
		{ "II", "HARDER", rgb(255, 140, 60) },
		{ "III", "BRING A PARTY", RED },
	}
	for i, row in list do
		local k = enter(t, 0.3 + (i - 1) * 0.3, 0.45)
		if k > 0 then
			local dx = math.floor((1 - k) * 14)
			clip(b, 0, Led.W - 1, function(tmp)
				Led.text(tmp, 2 + dx, ROW[i], row[1], row[3])
				Led.text(tmp, 18 + dx, ROW[i], row[2], WHITE)
			end)
		end
	end
end

-- The settlement from above (left), each place lit in turn with what it's
-- for (right).
local MAP_R = 14
local function mapAt(x: number, z: number): (number, number)
	local s = MAP_R / 345
	return 14.5 + x * s, 15 + z * s
end
local PLACES = {
	{ "ARENA ROW", { "DUELS AND", "PRACTICE" }, function()
		return 0, 0
	end },
	{ "YOUR POD", { "YOUR HOME,", "UP NORTH" }, function()
		return 0, -268
	end },
	{ "ENCHANTER", { "GEMS INTO", "YOUR GEAR" }, function()
		return math.cos(math.rad(62)) * 150, math.sin(math.rad(62)) * 150
	end },
	{ "MARKET", { "STORE AND", "SELL GEMS" }, function()
		return math.cos(math.rad(40)) * 255, math.sin(math.rad(40)) * 255
	end },
	{ "HABITAT", { "KAIJU", "DAYCARE" }, function()
		return math.cos(math.rad(160)) * 255, math.sin(math.rad(160)) * 255
	end },
	{ "PLAZA", { "SHUTTLE", "ARRIVALS" }, function()
		return 0, 200
	end },
}
local function map(b, t: number)
	local each = 2
	local which = math.floor(t / each) % #PLACES + 1
	local u = t % each
	local accent = GOOD
	-- the wall, the field's ring, the pods' terraces, the stages
	for i = 0, 63 do
		local a = i / 64 * math.pi * 2
		local x, y = mapAt(math.cos(a) * 345, math.sin(a) * 345)
		Led.set(b, x, y, SOFT)
		local fx, fy = mapAt(math.cos(a) * 160, math.sin(a) * 160)
		Led.set(b, fx, fy, RULE)
	end
	for _, row in { 245, 292 } do
		for deg = 186, 354, 12 do
			local a = math.rad(deg)
			local x, y = mapAt(math.cos(a) * row, math.sin(a) * row)
			Led.set(b, x, y, scale(CYAN, 0.5))
		end
	end
	for _, d in { { -48, 0 }, { 48, 0 }, { -48, 84 }, { 48, 84 }, { -48, -84 }, { 48, -84 } } do
		local x, y = mapAt(d[1], d[2])
		Led.set(b, x, y, scale(GOLD, 0.6))
	end
	-- the one lit now
	local place = PLACES[which]
	local px, py = mapAt(place[3]())
	local p = (u * 1.5) % 1
	rect(b, math.floor(px) - 1, math.floor(py) - 1, 3, 3, accent)
	box(b, math.floor(px) - 2 - math.floor(p * 2), math.floor(py) - 2 - math.floor(p * 2), 5 + math.floor(p * 2) * 2, 5 + math.floor(p * 2) * 2, fade(accent, 1 - p))
	-- what it is
	Led.text(b, 32, 9, place[1], accent)
	for i, s in place[2] do
		local k = enter(u, 0.15 + i * 0.12, 0.35)
		if k > 0 then
			Led.text(b, 32 + math.floor((1 - k) * 8), 9 + i * Led.Line, s, WHITE)
		end
	end
end

-- The whole list of keys.
local function keys(b, t: number, accent: number)
	for i, row in { { "X", "PICK / KIT" }, { "TAB", "NEXT TARGET" }, { "1-4", "KAIJU TEAMS" } } do
		local k = enter(t, 0.2 + (i - 1) * 0.3, 0.4)
		if k > 0 then
			local y = 8 + (i - 1) * 7
			local pressed = ((t - i * 0.8) % 2.4) < 0.25
			keycap(b, 2, y, row[1], accent, pressed)
			Led.text(b, 22 + math.floor((1 - k) * 10), y + 1, row[2], WHITE)
		end
	end
end

-- The bounties: how many, counted up.
local function bountyCount(info)
	return function(b, t)
		local n = #(info.Bosses or {})
		local shown = math.floor(math.clamp(t / 1.2, 0, 1) * n + 0.5)
		local s = shown .. (if shown == 1 then " BOSS" else " BOSSES")
		Led.center(b, 10, s, WHITE, 2)
		local ladders = {}
		for _, boss in info.Bosses or {} do
			ladders[boss.Element or ""] = true
		end
		local count = 0
		for _ in ladders do
			count += 1
		end
		if t > 1.4 then
			Led.center(b, 22, count .. " ELEMENT LADDERS", SOFT)
		end
	end
end

-- Kaiju and bosses ------------------------------------------------------------------------------------

local THREAT = { "I", "II", "III" }
local ROLE = {
	Warrior = { "WARRIOR", "HITS HARD" },
	Ranged = { "RANGED", "FROM AFAR" },
	Tank = { "TANK", "TAKES HITS" },
	Assassin = { "ASSASSIN", "STRIKES FAST" },
	Warden = { "SUPPORT", "HEALS YOU" },
}
local function slideIn(t: number): number
	return math.floor((1 - enter(t, 0.1, 0.5)) * -24)
end
local function kaijuCard(entry)
	local role = ROLE[entry.Role] or { Led.fit(entry.Role or "", 12), "" }
	return card("KAIJU", CYAN, {
		{ { entry.Name or "", GOLD } },
		{ { role[1], CYAN } },
		role[2],
	}, function(b, t)
		local art = "Mini" .. entry.Art
		if not LedArt[art] then
			art = entry.Art
		end
		sprite(b, art, 11 + slideIn(t), 28)
	end, 5)
end
local function bossCard(boss)
	local el = boss.Element and Led.ElementNames[boss.Element]
	local weak = boss.Weakness and Led.ElementNames[boss.Weakness]
	return guide("BOUNTY", RED, 6, function(b, t)
		local art = "Mini" .. boss.Art
		if not LedArt[art] then
			art = boss.Art
		end
		sprite(b, art, 11 + slideIn(t), 28)
		if enter(t, 0.3, 0.4) > 0 then
			marquee(b, TEXT_X, ROW[1], 12, boss.Name or "", WHITE, t)
		end
		if el and enter(t, 0.5, 0.4) > 0 then
			Led.text(b, TEXT_X, ROW[2], el, ELEMENT[boss.Element])
			-- its threat, as pips
			local x = TEXT_X + Led.width(el) + 3
			for i = 1, 3 do
				rect(b, x + (i - 1) * 3, ROW[2] + 1, 2, 3, if i <= (boss.Threat or 1) then RED else RULE)
			end
		end
		if weak and enter(t, 0.7, 0.4) > 0 then
			marquee(b, TEXT_X, ROW[3], 12, { { "WEAK: ", SOFT }, { weak, ELEMENT[boss.Weakness] } }, nil, t)
		end
	end)
end

-- The boards -----------------------------------------------------------------------------------------

-- Puts episode `name` into `list` (at `at`), if it can be shown.
local function addToon(list: { any }, name: string, at: number?)
	local ep = Led.toon(name)
	if ep then
		table.insert(list, math.clamp(at or #list + 1, 1, #list + 1), ep)
	end
end
-- The board's guide scenes made, numbered among themselves.
local function finish(list: { any }): { any }
	local total = 0
	for _, item in list do
		if item.Guide then
			total += 1
		end
	end
	local out, n = {}, 0
	for _, item in list do
		if item.Guide then
			n += 1
			table.insert(out, item.Make(n, total))
		else
			table.insert(out, item)
		end
	end
	return out
end

local SCENES = {}
function SCENES.Guide(info)
	local list = {
		guide("START HERE", GOLD, 7, steps({ "MINE", "GEAR", "TEAM", "FIGHT", "TASKS" }, GOLD, 7)),
		card("01 MINE", GOLD, { "BREAK ROCKS.", "EVERY ROCK", "HOLDS A GEM" }, artMine),
		card("02 GEAR UP", GOLD, { "SOCKET GEMS", "INTO GEAR IN", "INVENTORY" }, artGear),
		card("03 TEAM UP", GOLD, { "UP TO THREE", "KAIJU FIGHT", "BESIDE YOU" }, artTeam),
		card("04 FIGHT", GOLD, { "BEAT RIVALS,", "PLAYERS AND", "RIFT BOSSES" }, function(b, t)
			artFight(b, t)
		end),
		card("05 TASKS", GOLD, { "NOT SURE?", "OPEN TASKS.", "STEPS PAY" }, artTasks),
	}
	addToon(list, "Mine")
	return finish(list)
end
function SCENES.Controls(_info)
	local list = {
		card("ATTACK", CYAN, { { { "CLICK", CYAN } }, "SWING AT", "FOES, ROCKS" }, function(b, t)
			artAttack(b, t, CYAN)
		end),
		card("BLOCK", CYAN, { { { "HOLD R-CLICK", CYAN } }, "TIME IT FOR", "A PERFECT" }, function(b, t)
			artBlock(b, t, CYAN)
		end),
		card("DODGE", CYAN, { { { "SPACE", CYAN } }, "ROLL CLEAR", "OF BIG HITS" }, function(b, t)
			artDodge(b, t, CYAN)
		end),
		card("SURGES", CYAN, { "HITS FILL", "CHARGE.", { { "Q E R", CYAN }, { ": CAST", WHITE } } }, function(b, t)
			artSurges(b, t, CYAN)
		end),
		card("HYPERBEAM", CYAN, { "YOUR KAIJU", "CHARGE IT.", { { "FIRE: ", WHITE }, { "Z", CYAN } } }, function(b, t)
			artBeam(b, t, CYAN)
		end),
		card("CATCH", CYAN, { "WEAR IT DOWN", "TILL GOLD,", { { "THEN ", WHITE }, { "C", CYAN } } }, function(b, t)
			artCatch(b, t, CYAN)
		end),
		guide("MORE KEYS", CYAN, 7, function(b, t)
			keys(b, t, CYAN)
		end),
	}
	addToon(list, "Sneeze")
	return finish(list)
end
function SCENES.Elements(_info)
	local list = { guide("THE CYCLE", WHITE, 7, cycle) }
	for _, name in ELEMENTS do
		local beats, weak = BEATS[name], WEAK_TO[name]
		local _ = weak
		table.insert(list, card(Led.ElementNames[name], ELEMENT[name], {
			{ { "BEATS", SOFT } },
			{ { Led.ElementNames[beats], ELEMENT[beats] } },
			"+25% DAMAGE",
		}, artElement(name)))
	end
	table.insert(list, card("ARMOR", WHITE, { "EACH GEM", "RESISTS ITS", "OWN ELEMENT" }, function(b, t)
		artResist(b, t, CYAN)
	end))
	table.insert(list, guide("HITS", GOLD, 6, hitsDemo))
	addToon(list, "HotCold")
	return finish(list)
end
function SCENES.Gems(_info)
	local list = {
		guide("RARITY", GOLD, 7, function(b, t)
			artRarity(b, t)
			local lit = math.floor(t / 1.2) % 5 + 1
			body(b, t, { { { RARITY[lit][1], RARITY[lit][2] } }, "RARER GEMS", "ARE STRONGER" })
		end),
		guide("LEGENDARY", RARITY[5][2], 8, function(b, t)
			local i = math.floor(t / 2) % 4 + 1
			local u = t % 2
			local legend = LEGENDS[i]
			-- (prismatic: a shine running over it)
			local gem = Led.new()
			pixelGem(gem, 10, 12, 19, legend[4], t * 0.8)
			local band = (t * 14) % 40 - 10
			for idx, c in gem.P do
				local x, y = (idx - 1) % Led.W, (idx - 1) // Led.W
				local d = math.abs((x + y) - band - 12)
				b.P[idx] = if d < 3 then mix(c, WHITE, (1 - d / 3) * 0.6) else c
			end
			local _ = u
			body(b, u, { { { legend[1], legend[4] } }, { { legend[2], legend[4] } }, { { Led.ElementNames[legend[3]], SOFT } } }, nil, 0)
		end),
		guide("GO FURTHER", GOLD, 7, further),
		card("SPARE GEMS", GOLD, { "HEAL KAIJU", "OR SELL ON", "THE MARKET" }, artHeal),
		card("EQUIP BEST", GOLD, { "ONE TAP PUTS", "YOUR BEST", "GEMS ON" }, function(b, t)
			artEquip(b, t, GOLD)
		end),
	}
	addToon(list, "Bonk")
	return finish(list)
end
function SCENES.Bounties(info)
	local list = { guide("BOUNTIES", RED, 5, bountyCount(info)) }
	for _, boss in info.Bosses or {} do
		table.insert(list, bossCard(boss))
	end
	table.insert(list, card("BOUNTY BOARD", RED, { "TAKE THEM AT", "THE BOUNTY", "BOARD" }, artNotice))
	addToon(list, "Disguise", 7)
	return finish(list)
end
function SCENES.Kaiju(info)
	local list = {
		card("YOUR TEAM", CYAN, { "3 FIGHTERS", { { "+1 SUPPORT", GOOD } }, "THAT HEALS" }, artTeam),
	}
	for _, entry in info.Kaiju or {} do
		table.insert(list, kaijuCard(entry))
	end
	table.insert(list, card("HEALING", CYAN, { "THEY DON'T", "SELF-HEAL.", "GEMS HEAL" }, artHeal))
	table.insert(list, card("TEAMS", CYAN, { "SET UP FOUR", "TEAMS. SWAP", { { "WITH ", WHITE }, { "1-4", CYAN } } }, function(b, t)
		for i = 1, 4 do
			keycap(b, 1 + ((i - 1) % 2) * 10, 9 + math.floor((i - 1) / 2) * 10, tostring(i), CYAN, math.floor(t / 0.7) % 4 + 1 == i)
		end
	end))
	table.insert(list, card("KAIJU ARENA", CYAN, { "BATTLE OTHER", "PLAYERS IN", "THE SHELTER" }, function(b, t)
		box(b, 0, 21, 8, 3, RULE)
		box(b, 13, 21, 8, 3, RULE)
		local k = math.abs(math.sin(t * 3))
		rect(b, math.floor(2 + k * 3), 17, 3, 3, ELEMENT.Fire)
		rect(b, math.floor(16 - k * 3), 17, 3, 3, ELEMENT.Frost)
		if k > 0.95 then
			Led.set(b, 10, 16, WHITE)
			Led.set(b, 10, 20, WHITE)
		end
	end))
	return finish(list)
end
function SCENES.Rift(info)
	local violet = rgb(190, 90, 255)
	local list = {
		guide("THE RIFT", violet, 7, steps({ "VEIN", "GATE", "BOSS", "LOOT" }, violet, 7)),
		card("RIFT VEINS", violet, { "VEINS IN THE", "QUARRY LEAD", "TO A GATE" }, artVein),
		guide("LADDERS", violet, 7, ladders(info)),
		card("TELEGRAPHS", violet, { "BIG HITS ARE", "TELEGRAPHED.", "MOVE OUT" }, artTelegraph),
		guide("THREAT", violet, 6, threat),
		card("PARTY UP", violet, { "BOSSES HIT", "HARD. BRING", "FRIENDS" }, artParty),
		card("LOOT", violet, { "BEAT A BOSS:", "CACHE ROLL,", "NEXT OPENS" }, artLoot),
	}
	return finish(list)
end
function SCENES.Outpost(_info)
	local list = {
		guide("MAP", GOOD, 12, map, 32),
		card("CRITTERS", GOOD, { "MINE A WHILE", "AND THEY", "COME FOR YOU" }, artCritters),
		card("IF YOU FALL", GOOD, { "THEY GRAB", "YOUR NEWEST", "GEMS" }, artFall),
		card("MECHS", GOOD, { "MECHS IN THE", "GARAGE MINE", "FASTER" }, artMech),
		card("YOUR POD", GOOD, { { { "E", GOOD }, { " AT ITS", WHITE } }, "DOOR OPENS", "MY POD" }, function(b, t)
			artPod(b, t, GOOD)
		end),
	}
	return finish(list)
end

-- The basics -----------------------------------------------------------------------------------------
-- A new miner's first screen is a lesson (Client.BasicsScreen, full screen):
-- the narrator's basics lines (Client.Narration's Basics...), each its own
-- scene here, moving on phrase by phrase in time with the voice (`cues`:
-- when each phrase starts). The first phrase names the topic big; the rest
-- show it. `touch`: a phone's buttons named instead of the keyboard's.

-- (the lesson as it plays now: attack, block, abilities. Dodge and
-- Resources stay drawn, out of the order.)
Led.BasicsOrder = { "BasicsAttack", "BasicsBlock", "BasicsAbilities" }
local CHARGE_BLUE, STAMINA_GREEN = rgb(70, 130, 255), rgb(65, 195, 112)
local B_TEXT = 28 -- (the text column: 11 letters; the art's left of it)
local KEYS = {
	Desk = { Attack = "CLICK", Block = "R-CLICK", Dodge = "SPACE" },
	Touch = { Attack = "ATTACK", Block = "BLOCK", Dodge = "DODGE" },
}
local SAY = {
	Desk = { Attack = "CLICK", Block = "R-CLICK", Dodge = "SPACE" },
	Touch = { Attack = "ATTACK", Block = "BLOCK", Dodge = "DODGE" },
}

-- Which phrase is being read at `t`, and how long since it started.
local function cueAt(cues: { number }, t: number): (number, number)
	local k = 1
	for i, start in cues do
		if t >= start - 0.05 then
			k = i
		end
	end
	return k, t - (cues[k] or 0)
end

-- A word wiped in big, left to right, centred on row `y`.
local function bigWord(b, u: number, word: string, color: number, y: number)
	local reveal = math.floor(enter(u, 0, 0.45) * Led.W)
	clip(b, 0, reveal, function(tmp)
		Led.center(tmp, y, word, color, 2)
	end)
	if reveal < Led.W then
		for yy = y - 1, y + 10 do
			Led.set(b, reveal, yy, WHITE)
		end
	end
end

-- The text column's lines, sliding in in turn from `at`.
local function sayLines(b, u: number, list: { any }, at: number?)
	for i, item in list do
		local k = enter(u, (at or 0.1) + (i - 1) * 0.15, 0.4)
		if k > 0 then
			local dx = math.floor((1 - k) * 10 + 0.5)
			clip(b, B_TEXT, Led.W - 1, function(tmp)
				if type(item) == "table" then
					runs(tmp, B_TEXT + dx, ROW[i], item)
				else
					Led.text(tmp, B_TEXT + dx, ROW[i], item, WHITE)
				end
			end)
		end
	end
end

-- The control, its press shown: the mouse's button for a click (its left to
-- attack, its right to block), else its cap.
local function control(b, keys, id: string, pressed: boolean, x: number?)
	local label = keys[id]
	if label == "CLICK" or label == "R-CLICK" then
		mouse(b, x or 2, 8, if pressed then (if label == "CLICK" then "Left" else "Right") else nil, CYAN)
	else
		keycap(b, x or 0, 9, label, CYAN, pressed)
	end
end

-- A training dummy, struck: its flash.
local function dummy(b, x: number, hit: boolean)
	rect(b, x - 1, 20, 3, 8, if hit then WHITE else SOFT)
	rect(b, x - 2, 18, 5, 2, if hit then WHITE else SOFT)
	Led.set(b, x, 17, SOFT)
end

-- A swing's arc round (x, y), from the left or right, `k` through it.
local function arc(b, x: number, y: number, side: number, k: number, r: number, color: number)
	for i = 0, 5 do
		local a = math.rad(-150 + i * 24 + k * 30) * side
		local s = 1 - math.abs(i - 2.5) / 3
		Led.set(b, x + math.cos(a) * r * side, y + math.sin(a) * r * 0.7, fade(color, s * (1 - k * 0.6)))
	end
end

local BASICS = {}

function BASICS.BasicsAttack(b, k: number, u: number, keys, say)
	if k == 1 then
		bigWord(b, u, "ATTACK", GOLD, 12)
		return
	end
	if k == 2 or k == 3 then
		local period = if k == 3 then 0.38 else 0.6
		local n = math.floor(u / period)
		local p = (u % period) / period
		control(b, keys, "Attack", p < 0.3)
		dummy(b, 18, p < 0.18)
		if p < 0.6 then
			arc(b, 18, 23, if n % 2 == 0 then 1 else -1, p / 0.6, 6, WHITE)
		end
		if k == 2 then
			sayLines(b, u, { { { say.Attack, CYAN } }, "TO SWING", "YOUR WEAPON" })
		else
			local combo = math.min(9, n + 1)
			sayLines(b, u, { "KEEP", "SWINGING:", { { "COMBO ", WHITE }, { "X" .. combo, GOLD } } })
		end
		return
	end
	-- the heavy: held, a ring closing in on the dummy, then the blow
	local hold = 1.1
	local p = u % 2
	local held = p < hold
	control(b, keys, "Attack", held)
	dummy(b, 18, p >= hold and p < hold + 0.15)
	if held then
		local r = 7 - (p / hold) * 4
		ring(b, 18, 23, r, fade(GOLD, 0.4 + 0.6 * p / hold))
	elseif p < hold + 0.5 then
		local q = (p - hold) / 0.5
		arc(b, 18, 23, 1, q, 7, GOLD)
		arc(b, 18, 23, -1, q, 5, GOLD)
	end
	sayLines(b, u, { "HOLD IT", "DOWN FOR A", { { "HEAVY BLOW", GOLD } } })
end

function BASICS.BasicsBlock(b, k: number, u: number, keys, say)
	if k == 1 then
		bigWord(b, u, "BLOCK", CYAN, 12)
		return
	end
	local function shield(on: boolean, color: number)
		if on then
			for y = 18, 27 do
				Led.set(b, 5, y, color)
				Led.set(b, 6, y, scale(color, 0.6))
			end
		end
	end
	if k == 2 then
		-- held up: blows land on the guard
		local p = u % 1.1
		control(b, keys, "Block", true, 15)
		shield(true, CYAN)
		local x = math.floor(lerp(24, 8, math.clamp(p / 0.8, 0, 1)))
		if p < 0.8 then
			Led.set(b, x, 23, RED)
			Led.set(b, x + 1, 23, scale(RED, 0.5))
		elseif p < 0.95 then
			Led.set(b, 8, 22, WHITE)
			Led.set(b, 8, 24, WHITE)
		end
		sayLines(b, u, { { { "HOLD ", WHITE }, { say.Block, CYAN } }, "TO RAISE", "YOUR GUARD" })
		return
	end
	-- the timing: the guard goes up just before the blow lands
	local loop = 1.8
	local p = u % loop
	local land = 1.3
	local up = p >= land - 0.18 and p < land + 0.3
	control(b, keys, "Block", up, 15)
	shield(up, if k == 4 and p >= land then GOLD else CYAN)
	if p < land then
		local x = math.floor(lerp(24, 8, p / land))
		Led.set(b, x, 23, RED)
		Led.set(b, x + 1, 23, scale(RED, 0.5))
	elseif p < land + 0.3 and k == 4 then
		for _, d in { { 2, -4 }, { 3, -1 }, { 3, 2 }, { 5, -3 }, { 5, 3 }, { 6, 0 } } do
			Led.set(b, 6 + d[1], 23 + d[2], GOLD)
		end
	end
	if k == 3 then
		sayLines(b, u, { "TIME IT", "JUST BEFORE", "IT LANDS" })
	else
		sayLines(b, u, { { { "PERFECT", GOLD } }, "BLOCK: IT", "COSTS NONE" })
	end
end

local ABILITY_COLORS = { ELEMENT.Fire, ELEMENT.Frost, ELEMENT.Shock }
function BASICS.BasicsAbilities(b, k: number, u: number, _keys, _say)
	if k == 1 then
		bigWord(b, u, "ABILITIES", GOLD, 12)
		return
	end
	local caps = { "Q", "E", "R" }
	local lit = 0
	if k == 2 then
		lit = math.clamp(math.floor((u - 1.2) / 0.55) + 1, 0, 3)
	elseif k >= 3 then
		lit = 3
	end
	local casting = if k == 4 then math.floor(u / 0.9) % 3 + 1 else nil
	local castP = if k == 4 then (u % 0.9) / 0.9 else 0
	for i, cap in caps do
		local x = (i - 1) * 8
		local on = i <= lit
		keycap(b, x, 10, cap, ABILITY_COLORS[i], casting == i and castP < 0.3)
		if on then
			-- its gem over it
			local gx = x + 3
			Led.set(b, gx, 9, ABILITY_COLORS[i])
			Led.set(b, gx - 1, 9, scale(ABILITY_COLORS[i], 0.6))
			Led.set(b, gx + 1, 9, scale(ABILITY_COLORS[i], 0.6))
			Led.set(b, gx, 8, mix(ABILITY_COLORS[i], WHITE, 0.5))
		end
	end
	if k >= 3 then
		-- the Charge bar, a chunk spent on each cast
		local fill = if k == 3 then 0.75 - (u % 2 >= 1 and 0.25 or 0) else 0.75 - (if castP > 0.3 then 0.25 else 0)
		box(b, 0, 19, 24, 4, RULE)
		hline(b, 1, 1 + math.floor(21 * fill), 20, CHARGE_BLUE)
		hline(b, 1, 1 + math.floor(21 * fill), 21, scale(CHARGE_BLUE, 0.7))
		Led.text(b, 0, 23, "CHARGE", CHARGE_BLUE)
	end
	if casting and castP >= 0.25 then
		-- the cast: a burst from its key
		local q = (castP - 0.25) / 0.75
		ring(b, (casting - 1) * 8 + 3, 13, 2 + q * 8, fade(ABILITY_COLORS[casting], 1 - q))
	end
	if k == 2 then
		sayLines(b, u, { "YOUR GEMS", "GIVE YOU", { { "Q  E  R", GOLD } } })
	elseif k == 3 then
		sayLines(b, u, { "EACH ONE", "COSTS", { { "CHARGE", CHARGE_BLUE } } })
	else
		sayLines(b, u, { "CAST THEM", "TO TURN", "A FIGHT" })
	end
end

function BASICS.BasicsDodge(b, k: number, u: number, keys, say)
	if k == 1 then
		bigWord(b, u, "DODGE", CYAN, 12)
		return
	end
	local big = k == 3
	local loop = if big then 2.2 else 1.6
	local p = u % loop
	local press = if big then 1.25 else 0.7
	control(b, keys, "Dodge", p >= press and p < press + 0.15)
	local land = press + 0.25
	local kk = math.clamp(p / land, 0, 1)
	if p < land + 0.15 then
		local r = (if big then 8 else 4) * kk + 1
		for y = 17, 28 do
			for x = 0, 25 do
				local d = ((x - 9) / math.max(1, r)) ^ 2 + ((y - 23) / math.max(1, r * 0.55)) ^ 2
				if d <= 1 then
					Led.set(b, x, y, if p >= land then WHITE else scale(RED, 0.3 + 0.5 * kk))
				end
			end
		end
	end
	local dx = if p >= press then lerp(0, if big then 14 else 10, ease((p - press) / 0.2)) else 0
	rect(b, math.floor(8 + dx), 22, 2, 2, WHITE)
	if p >= press and p < press + 0.35 then
		for s = 1, 3 do
			Led.set(b, 8 + dx - s * 2, 23, fade(WHITE, 0.5 - s * 0.12))
		end
	end
	if k == 2 then
		sayLines(b, u, { { { say.Dodge, CYAN } }, "ROLL OUT OF", "THE WAY" })
	else
		sayLines(b, u, { "SAVE IT FOR", "THE BIG", { { "ATTACKS", RED } } })
	end
end

function BASICS.BasicsResources(b, k: number, u: number, _keys, _say)
	if k == 1 then
		bigWord(b, u, "CHARGE", CHARGE_BLUE, 8)
		if u > 0.5 then
			bigWord(b, u - 0.5, "STAMINA", STAMINA_GREEN, 19)
		end
		return
	end
	if k == 6 then
		bigWord(b, u, "TRAINING", GOLD, 9)
		if u > 0.6 then
			Led.center(b, 22, "BEGINS NOW", WHITE)
		end
		return
	end
	-- the two bars, as the fight's HUD has them
	local function bar(y: number, fill: number, color: number, label: string, flash: boolean?)
		Led.text(b, 0, y, label, color)
		box(b, 32, y - 1, 40, 7, RULE)
		local w = math.floor(38 * math.clamp(fill, 0, 1))
		rect(b, 33, y, w, 5, if flash then mix(color, WHITE, 0.5) else color)
		rect(b, 33, y, w, 1, mix(color, WHITE, 0.35))
	end
	local charge, stamina = 0.2, 1
	local chargeFlash, staminaFlash = false, false
	local note = nil
	if k == 2 then
		local hits = math.floor(u / 0.45)
		charge = math.min(1, 0.2 + hits * 0.08)
		chargeFlash = (u % 0.45) < 0.1
		note = { "+5", CHARGE_BLUE, "EACH HIT" }
	elseif k == 3 then
		local casts = math.floor(u / 0.8)
		charge = math.max(0.1, 0.9 - casts * 0.25)
		chargeFlash = (u % 0.8) < 0.12
		note = { "CAST", CHARGE_BLUE, "SPENDS IT" }
	elseif k == 4 then
		charge = 0.4
		local spends = math.floor(u / 0.7)
		stamina = math.max(0.15, 1 - spends * 0.14)
		staminaFlash = (u % 0.7) < 0.1
		local what = ({ "SWING", "BLOCK", "DODGE" })[spends % 3 + 1]
		note = { what, STAMINA_GREEN, "USES IT" }
	elseif k == 5 then
		charge = 0.4
		stamina = math.min(1, 0.2 + u * 0.3)
		note = { "EASE OFF", STAMINA_GREEN, "REFILLS" }
	end
	bar(9, charge, CHARGE_BLUE, "CHARGE", chargeFlash)
	if k >= 4 then
		bar(17, stamina, STAMINA_GREEN, "STAMINA", staminaFlash)
	end
	if note then
		runs(b, 0, 24, { { note[1] .. " ", note[2] }, { note[3], WHITE } })
	end
end

-- One of the lesson's scenes: `name` (Led.BasicsOrder), timed off `cues`
-- (the phrases' starts) over `seconds`; `touch`: a phone.
function Led.basics(name: string, cues: { number }, seconds: number, touch: boolean?)
	local draw = BASICS[name]
	local index = table.find(Led.BasicsOrder, name) or 1
	local keys = if touch then KEYS.Touch else KEYS.Desk
	local say = if touch then SAY.Touch else SAY.Desk
	return scene(seconds, function(t)
		local b = Led.new()
		local k, u = cueAt(cues, t)
		if draw then
			draw(b, k, u, keys, say)
		end
		header(b, t, "BASICS", index, #Led.BasicsOrder, GOLD, 0)
		progress(b, t, seconds, GOLD, 0)
		return b
	end)
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
