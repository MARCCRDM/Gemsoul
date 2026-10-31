-- PROBE-7's window (ProbeLayout): on every screen its cards, stats and
-- buttons fit, a phone's is drawn near full size with buttons big enough to
-- tap, it knows what a bigger refill saves (by the swing, in Robux), and the
-- pick and the refills it sells say what they are.
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
	-- The two strips under the cards (the market, then free swings for an
	-- invite): inside the body, under the cards, never on each other; on a
	-- phone side by side (so the window stays as short), else one under another.
	local market, invite = Layout.strip(L, 1), Layout.strip(L, 2)
	for n, r in { market, invite } do
		check(r.X >= 0 and r.X + r.W <= L.W - L.Side * 2 and r.Y >= L.CardH + L.Gap, name .. ": strip " .. n .. " leaves the body")
		check(L.Top + r.Y + r.H <= L.H - 6, name .. ": strip " .. n .. " runs past the window")
		check(r.W >= (if L.Phone then 250 else 600), name .. ": strip " .. n .. " too narrow: " .. r.W)
	end
	local apart = market.X + market.W <= invite.X or invite.Y >= market.Y + market.H
	check(apart, name .. ": the invite strip covers the market")
	check((invite.Y == market.Y) == L.Phone, name .. ": strips side by side on a phone, stacked on a computer")
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

-- How much a bigger refill saves, as its line says.
local Refill, Mega = Rules.Refills.Refill, Rules.Refills.Mega
check(Layout.saving(Refill, Refill) == 0, "A refill saves against itself")
check(Layout.saving(Mega, Refill) == 32, "The Mega Refill doesn't save 32% a swing: " .. Layout.saving(Mega, Refill))
check(string.find(Mega.Blurb, Layout.saving(Mega, Refill) .. "%", 1, true), "The Mega Refill's line has the wrong saving")
check(Layout.saving({ Swings = 10, Robux = 100 }, Refill) == 0, "A dearer refill shows a saving")

-- The pick and every refill say what they are, in a line that fits a card.
local cards = { Rules.Picks.Survey }
for _, id in Rules.RefillOrder do
	table.insert(cards, Rules.Refills[id])
end
check(#cards == 3, "The Probe doesn't show the pick and two refills")
for _, spec in cards do
	check(type(spec.Tag) == "string" and #spec.Tag > 0, spec.Name .. " has no tag")
	check(
		type(spec.Blurb) == "string" and #spec.Blurb > 0 and #spec.Blurb <= 36,
		spec.Name .. "'s line is missing or too long"
	)
end

print(
	"PASS: " .. checks .. " Probe window checks (every screen fits, phones near full size, savings, card lines)"
)
