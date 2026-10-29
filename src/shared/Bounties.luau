--[[
	Brutus's bounties: every boss behind the Rift Gates, posted in one place
	(his booth in the Shelter, by the Hall of Fame). From his counter you
	pick any of them, from any biome's ladder (Shared.RiftRun.Ladders: a
	boss still opens once you've beaten the one before it on its ladder),
	and go through with your party, the same trip as through that biome's
	gate (Server.RiftServer: "RiftEnter", "Bounty", bossId; its card is the
	gate's lobby, Client.RiftClient, with a tab for each biome).

	  Bounties.Gate                 what RiftServer's "vein" is for his counter
	  Bounties.Reach                studs from the counter you can post from
	  Bounties.list() -> { { Biome, Element, Bosses } }   each biome's
	                                ladder, in the Loop's order (Frontier.Biomes)
	  Bounties.elementOf(bossId) -> element?   whose ladder a boss is on
	  Bounties.Poster               a WANTED poster's canvas (pixels)
	  Bounties.poster(gui, boss, element)   draws one on a SurfaceGui (Server.
	                                OutpostServer, the booth's back wall)
	  Bounties.Board                the board out on the hall floor (Client.
	                                BountyBoard): Spot (in the Shelter's
	                                frame) and Period (seconds a bounty's up)
	  Bounties.entries() -> { { Boss, Element, Biome } }   every bounty, in
	                                the board's order
	  Bounties.boardAt(now) -> (front, back, share)   what its two faces show
	                                at `now` (the server's clock), never the
	                                same one, and how far through its turn
]]
local BossLoot = require(script.Parent.BossLoot)
local Frontier = require(script.Parent.Frontier)
local GemConfig = require(script.Parent.GemConfig)
local RiftRun = require(script.Parent.RiftRun)

local Bounties = {}

Bounties.Gate = "Bounty"
Bounties.Reach = 16
Bounties.Poster = Vector2.new(280, 380)

-- Each biome's ladder, in the Loop's order.
function Bounties.list()
	local list = {}
	for _, biome in Frontier.Biomes do
		local bosses = RiftRun.ladder(biome.Element)
		if #bosses > 0 then
			table.insert(list, { Biome = biome.Name, Element = biome.Element, Bosses = bosses })
		end
	end
	return list
end

-- The board on the hall floor, on the way in from the garage between the
-- Kennel and the Hall of Fame, a face to the garage and a face to the main
-- door: one bounty on each face, both changing every Period seconds,
-- everyone's at the same time (the server's clock).
Bounties.Board = {
	Spot = Vector3.new(46, 0.86, 10),
	Period = 12,
}

-- Every bounty, each biome's ladder in turn: { Boss, Element, Biome }.
function Bounties.entries()
	local out = {}
	for _, entry in Bounties.list() do
		for _, boss in entry.Bosses do
			table.insert(out, { Boss = boss, Element = entry.Element, Biome = entry.Biome })
		end
	end
	return out
end

-- The bounties on the board's two faces at `now`, and how far through
-- their turn (0 to 1). The back shows the one halfway round the list from
-- the front's, so the two are never the same (with two or more).
function Bounties.boardAt(now: number)
	local list = Bounties.entries()
	local n = #list
	if n == 0 then
		return nil, nil, 0
	end
	local period = Bounties.Board.Period
	local turn = math.floor(now / period)
	local front = list[turn % n + 1]
	local back = list[(turn + math.max(1, n // 2)) % n + 1]
	return front, back, (now % period) / period
end

-- The element whose ladder `bossId` is on (nil: no such bounty).
function Bounties.elementOf(bossId: any): string?
	for element, ids in RiftRun.Ladders do
		if table.find(ids, bossId) then
			return element
		end
	end
	return nil
end

local INK = Color3.fromRGB(14, 12, 12)
local PAPER = Color3.fromRGB(214, 200, 170)
local RED = Color3.fromRGB(178, 40, 34)

local function label(parent: Instance, text: string, y: number, h: number, size: number, color: Color3, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(14, y)
	l.Size = UDim2.fromOffset(Bounties.Poster.X - 28, h)
	l.Text = text
	l.TextSize = size
	l.TextWrapped = true
	l.TextColor3 = color
	l.Font = font or Enum.Font.GothamBold
	l.Parent = parent
	return l
end

-- A WANTED poster for `boss` (a DungeonRules.Bosses entry) on `gui`: the
-- word in red stencil, its name, its element's band, its threat, and what
-- it pays.
function Bounties.poster(gui: SurfaceGui, boss, element: string?)
	gui:ClearAllChildren()
	local W, H = Bounties.Poster.X, Bounties.Poster.Y
	local sheet = Instance.new("Frame")
	sheet.Name = "Poster"
	sheet.BorderSizePixel = 0
	sheet.BackgroundColor3 = PAPER
	sheet.Size = UDim2.fromOffset(W, H)
	sheet.Parent = gui
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(120, 100, 76)
	edge.Thickness = 6
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = sheet
	label(sheet, "WANTED", 14, 60, 54, RED, Enum.Font.GothamBlack)
	local rule = Instance.new("Frame")
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = INK
	rule.Position = UDim2.fromOffset(14, 80)
	rule.Size = UDim2.fromOffset(W - 28, 3)
	rule.Parent = sheet
	label(sheet, string.upper(boss.Name or "?"), 92, 96, 30, INK, Enum.Font.GothamBlack)
	-- Its element, a band in its colour.
	local tint = GemConfig.ElementColors[boss.Element] or Color3.fromRGB(120, 120, 120)
	local band = Instance.new("Frame")
	band.BorderSizePixel = 0
	band.BackgroundColor3 = tint
	band.Position = UDim2.fromOffset(14, 196)
	band.Size = UDim2.fromOffset(W - 28, 40)
	band.Parent = sheet
	local word = label(band, string.upper(GemConfig.elementName(boss.Element) or boss.Element or ""), 0, 40, 24, INK, Enum.Font.GothamBlack)
	word.Position = UDim2.fromOffset(0, 0)
	word.Size = UDim2.fromOffset(W - 28, 40)
	local threat = BossLoot.threat(boss)
	label(sheet, "THREAT " .. BossLoot.numeral(threat), 248, 40, 30, if threat >= RiftRun.GroupThreat then RED else INK, Enum.Font.GothamBlack)
	label(
		sheet,
		if threat >= RiftRun.GroupThreat then "BRING A PARTY" else "REWARD: BOSS CACHE",
		292,
		30,
		20,
		INK,
		Enum.Font.GothamBold
	)
	local biome = nil
	for _, b in Frontier.Biomes do
		if b.Element == element then
			biome = b
		end
	end
	label(sheet, if biome then "LAST SEEN: " .. string.upper(biome.Name) else "", 326, 30, 17, Color3.fromRGB(70, 60, 50), Enum.Font.GothamBold)
end

return Bounties
