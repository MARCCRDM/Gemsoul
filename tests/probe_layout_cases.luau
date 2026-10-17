-- PROBE-7's window (ProbeLayout): on every screen its cards, stats and
-- buttons fit, a phone's is drawn near full size with buttons big enough to
-- tap, and each card offers the right thing (buy, refill, take in hand, the
-- free pick's charge). The picks it sells say what they are.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- How IronUi.window scales a design to the screen (and, on a phone, under
-- Roblox's top bar, 44 tall).
local function scaleOn(L, x: number, y: number): number
	local phone = y < 500
	local s = math.min(1, (x - 40) / L.W, (y - (if phone then 16 else 40)) / L.H)
	if phone and (y - L.H * s) / 2 < 44 then
		s = math.min(s, (y - 44 - 8) / L.H)
	end
	return s
end

for _, screen in
	{
		{ 1920, 1080 },
		{ 1366, 768 },
		{ 1280, 720 },
		{ 1024, 600 },
		{ 932, 430 },
		{ 844, 390 },
		{ 812, 375 },
		{ 740, 360 },
		{ 667, 375 },
		{ 568, 320 },
	}
do
	local x, y = screen[1], screen[2]
	local name = x .. "x" .. y
	local L = Layout.design(x, y)
	check(L.Phone == (y < 500), name .. ": wrong design (desktop or phone)")
	-- Three cards side by side, the market under them, all inside the window.
	check(L.CardW * 3 + L.Gap * 2 <= L.W - L.Side * 2, name .. ": the cards run past the window")
	check(L.Top + L.CardH + L.Gap + L.MarketH <= L.H - 6, name .. ": the market runs past the window")
	-- Down a card: art, name, stats, then the footer's line, bar and button.
	check(L.NameY >= L.ArtH and L.StatsY > L.NameY + 18, name .. ": the name sits on the art or the stats")
	check(L.FootY >= L.StatsY + L.Row * 3, name .. ": the footer sits on the stats")
	check(L.FootY + 30 + L.ButtonH <= L.CardH - 6, name .. ": a card's button runs off it")
	check(L.CardW >= 170, name .. ": cards too narrow for their words: " .. L.CardW)
	local s = scaleOn(L, x, y)
	if L.Phone and y >= 360 then
		-- A phone's window is drawn near full size: its words stay readable and
		-- its buttons stay big enough to tap.
		check(s >= 0.9, name .. ": a phone's window drawn too small: " .. s)
		check(L.ButtonH * s >= 36, name .. ": buttons too small to tap")
	elseif not L.Phone then
		check(s >= 0.95 or y < 650, name .. ": a desktop window shrunk: " .. s)
	end
	check(L.W * s <= x and L.H * s <= y, name .. ": the window runs off the screen")
end

-- What each card offers.
local Survey, Titan = Rules.Picks.Survey, Rules.Picks.Titan
local o = Layout.offer(Survey, 23, true, 0)
check(o.Kind == "Charge" and o.Short == 0, "The free pick isn't its charge")
check(Layout.offer(Survey, 60, false, 0).Kind == "Charge", "The free pick out of hand isn't its charge")
o = Layout.offer(Titan, 0, false, 300)
check(o.Kind == "Buy" and o.Short == Titan.Price - 300, "A pick you can't afford doesn't say how short you are")
o = Layout.offer(Titan, 0, false, Titan.Price)
check(o.Kind == "Buy" and o.Short == 0, "Exactly the price wasn't enough")
o = Layout.offer(Titan, 112, true, 5000)
check(o.Kind == "Refill" and o.Short == 0, "The pick in hand isn't a refill")
o = Layout.offer(Titan, 112, false, 100)
check(o.Kind == "Hand" and o.Short == Titan.Price - 100, "A pick you own but aren't holding isn't take-in-hand")

-- Every pick the Probe sells says what it is, in a line that fits a card.
for _, id in Rules.PickOrder do
	local spec = Rules.Picks[id]
	check(type(spec.Tag) == "string" and #spec.Tag > 0, id .. " has no tier tag")
	check(
		type(spec.Blurb) == "string" and #spec.Blurb > 0 and #spec.Blurb <= 34,
		id .. "'s line is missing or too long"
	)
end

print("PASS: " .. checks .. " Probe window checks (every screen fits, phones near full size, offers, pick lines)")
