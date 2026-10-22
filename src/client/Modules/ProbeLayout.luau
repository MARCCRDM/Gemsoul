--[[
	The SWING REFILLS window, worked out without Roblox (OutpostScene draws it; the
	numbers are tested on their own, tests/probe_layout_cases.luau):

	  ProbeLayout.design(screenX, screenY) -> L   where everything sits, in the
	      window's own design size. A phone on its side (under 500 tall) gets
	      a design as wide as its screen and shorter cards, so the window is
	      drawn near full size and its words stay readable.
	  ProbeLayout.saving(refill, base) -> how much less each swing costs in
	      `refill` than in `base` (their Robux), as a whole percent (0 when
	      it's no cheaper)
]]
local ProbeLayout = {}

-- W x H is the window; the body (cards, then the market under them) starts
-- Top down and Side in. Row is a stat's height, ButtonH a card's button.
ProbeLayout.Desk = {
	W = 800,
	H = 468,
	Top = 78,
	Side = 20,
	Gap = 14,
	CardH = 300,
	ArtH = 108,
	MarketH = 56,
	Row = 18,
	ButtonH = 36,
}
ProbeLayout.Phone = {
	H = 338,
	Top = 66,
	Side = 14,
	Gap = 8,
	CardH = 214,
	ArtH = 54,
	MarketH = 40,
	Row = 16,
	ButtonH = 40,
}

function ProbeLayout.design(screenX: number, screenY: number)
	local phone = screenY < 500
	local L = table.clone(if phone then ProbeLayout.Phone else ProbeLayout.Desk)
	L.Phone = phone
	if phone then
		L.W = math.clamp(screenX - 40, 560, ProbeLayout.Desk.W)
	end
	L.CardW = math.floor((L.W - L.Side * 2 - L.Gap * 2) / 3)
	-- Down a card: the art, the name (and on a desktop a line about it), the
	-- three stats, then the footer (a line, a bar, the button).
	L.NameY = L.ArtH + (if phone then 4 else 8)
	L.StatsY = if phone then L.NameY + 22 else L.NameY + 46
	L.FootY = L.StatsY + L.Row * 3 + (if phone then 8 else 10)
	return L
end

function ProbeLayout.saving(refill, base): number
	local each, baseEach = refill.Robux / refill.Swings, base.Robux / base.Swings
	return math.max(0, math.floor((1 - each / baseEach) * 100 + 0.5))
end

return ProbeLayout
