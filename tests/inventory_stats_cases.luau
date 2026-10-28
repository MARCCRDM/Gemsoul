-- lune run tests/inventory_stats_cases.luau <repo>
-- The Inventory shows every armor stat on a phone too: the stats card in a
-- sheet that STATS opens, and all of a piece's stats on its card (source
-- guards on InventoryV2 and the Spanish table).
local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOT = process.args[1] or "."
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local src = fs.readFile(ROOT .. "/src/client/Modules/InventoryV2.luau")
local function has(needle: string): boolean
	return string.find(src, needle, 1, true) ~= nil
end

-- 1. Compact: the card's box goes into the sheet, not a hidden frame.
check(has("local function buildStatsSheet(canvas: Frame): Frame"), "no stats sheet builder")
check(has("box = buildStatsSheet(canvas)"), "compact doesn't build the card into the sheet")
check(not has('{ Name = "Stats", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false },'), "the card is still built hidden on a phone")
check(has('Name = "StatsSheet",') and has("Visible = false,\n\t\tZIndex = 30,"), "the sheet isn't a hidden layer over the screen")
check(has('new("ScrollingFrame", {\n\t\tName = "Scroller",'), "the sheet doesn't scroll")
check(has("local inner = y + 10 - top + 12") and has("ui.StatsScroller.CanvasSize = UDim2.fromOffset(0, inner)"), "the sheet's scroll isn't sized to the card")
check(has("box.Position = UDim2.fromOffset(-(x - 16) + 12, -top)"), "the card isn't slid to the sheet's corner")
check(has('place(text(panel, "YOUR STATS", 12, C.Teal, HEAVY), 16, 10, 200, 18)'), "the sheet has no title")
check(has("scrim.Activated:Connect(hide)") and has("close.Activated:Connect(hide)"), "the sheet can't be closed by a tap outside or ×")

-- 2. ALL STATS (desktop summary, phone STATS page) and the rating tiles open
-- the sheet; the rating sits on the COMBAT RATINGS pill.
check(has('plainButton(box, "ALL STATS  ·  AUTO EQUIP  ›"'), "no ALL STATS on the desktop summary")
check(has('plainButton(stats, "ALL STATS"'), "no ALL STATS on the phone's STATS page")
check(has("all.Activated:Connect(openStats)") and has("tile.Activated:Connect(openStats)"), "ALL STATS / the tiles don't open the sheet")
check(has("ui.StatsSheet.Visible = true"), "openStats doesn't open the sheet")
check(has('ui.Pill.Text = "RATING  " .. whole(total)'), "the rating isn't on the COMBAT RATINGS pill")

-- 3. A piece's card lists every stat on it, both layouts.
check(has("local function allStats(roll): string"), "no allStats")
check(has("local statsText = allStats(roll)") and has("ui.PerkStats.Text = statsText"), "the piece card doesn't list its stats")
check(has("ui.PerkStats.Visible = true"), "the stats line is still keys-only")
check(has("ui.PerkStats.TextColor3 = if tryPiece then C.Gold else C.Good"), "a tried-on piece's stats aren't gold")
check(has("ui.PerkName.Size = UDim2.fromOffset(RIGHT_W - 36 - need - 6, 14)"), "the perk's name doesn't make room for the stats")
check(has('ui.PerkStats.TextColor3 = C.Dim\n\t\tui.PerkStats.Text = if surge'), "a key's cost line lost its colour")

-- 4. Spanish.
local lang = fs.readFile(ROOT .. "/src/shared/LangEs.luau")
for _, key in { '["STATS"] =', '["RATING  {1}"] =', '["ALL STATS"] =', '["YOUR STATS"] =' } do
	check(string.find(lang, key, 1, true) ~= nil, "no Spanish for " .. key)
end

-- 5. The docs say so.
local docs = fs.readFile(ROOT .. "/docs/mobile.md")
check(string.find(docs, "The stats card is a sheet", 1, true) ~= nil, "docs/mobile.md doesn't describe the sheet")

print("PASS: " .. checks .. " inventory stats checks (the stats sheet on a phone, ALL STATS and the rating, every stat on a piece's card, Spanish, docs)")
