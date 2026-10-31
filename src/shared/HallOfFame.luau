--[[
	The Hall of Fame: the Shelter's big board on the east wall (Server.
	OutpostServer draws it, from Server.TopPlayers' boards; World.
	OutpostWorld builds the wall it hangs on). Two halls side by side:

	  PLAYER VS PLAYER   1V1 DUELS (Arena 1v1 wins: Duels' Solo),
	                     1V1 + KAIJU (wins in the Kaiju Arena's mixed
	                     match, only while Config.Features.KaijuDuel is on),
	                     GEAR SCORE (the best-geared: GearRolls.gearScore,
	                     every rolled stat on the six worn pieces; in place
	                     of KAIJU BATTLES since 2026-10-31)
	  PLAYER VS ENVIRONMENT  BOUNTY HUNTERS (Rift bosses slain: the bounties
	                     Brutus posts), TOP MINERS (gems mined)

	Each column: first place up top (their face, the number large), then
	the next Rows, plain. Drawn like a stadium's results board: dark, one
	amber accent, tabular figures, thin rules. An empty place reads
	UNCLAIMED. The rows are { Name, Value, UserId? } (TopPlayers.board).

	  HallOfFame.Boards                  the columns, in order: { Id, Group,
	                                     Title, Unit, Color }
	  HallOfFame.Canvas                  the board's SurfaceGui size (pixels)
	  HallOfFame.Size                    the board's face, in studs
	  HallOfFame.layout(width)           where each column sits (pure):
	                                     { { Id, X, W, Group } }, and each
	                                     group's { X, W }
	  HallOfFame.value(n) -> string      a score as the board shows it (pure)
	  HallOfFame.draw(gui, boards, global?)   (re)draws `gui` (a SurfaceGui)
	                                     from boards[Id] = rows
]]
local Config = require(script.Parent.Config)

local HallOfFame = {}

-- A plain results board, like a stadium's: dark, one warm accent, tight
-- tabular figures, thin rules between the columns. No cards, no rainbow.
local BG = Color3.fromRGB(19, 19, 21)
local AMBER = Color3.fromRGB(240, 176, 66)
local TEXT = Color3.fromRGB(232, 228, 218)
local DIM = Color3.fromRGB(122, 120, 114)
local RULE = Color3.fromRGB(54, 54, 58)
local STRIPE = Color3.fromRGB(26, 26, 29)

HallOfFame.Boards = {
	{ Id = "Duel", Group = "PvP", Title = "1V1 DUELS", Unit = "WINS", Color = Color3.fromRGB(255, 96, 80) },
	{ Id = "Gear", Group = "PvP", Title = "GEAR SCORE", Unit = "SCORE", Color = Color3.fromRGB(196, 110, 255) },
	{ Id = "Bosses", Group = "PvE", Title = "BOUNTY HUNTERS", Unit = "BOSSES", Color = Color3.fromRGB(90, 220, 150) },
	{ Id = "Mined", Group = "PvE", Title = "TOP MINERS", Unit = "GEMS", Color = Color3.fromRGB(96, 196, 255) },
}
if Config.Features.KaijuDuel then
	table.insert(
		HallOfFame.Boards,
		2,
		{ Id = "Mixed", Group = "PvP", Title = "1V1 + KAIJU", Unit = "WINS", Color = Color3.fromRGB(255, 150, 64) }
	)
end
HallOfFame.Groups = {
	PvP = { Title = "PLAYER VS PLAYER" },
	PvE = { Title = "PLAYER VS ENVIRONMENT" },
}
-- Places under each champion.
HallOfFame.Rows = 5
HallOfFame.Size = Vector2.new(40, 19) -- studs
HallOfFame.Canvas = Vector2.new(1600, 760) -- pixels: 40 to the stud

local MARGIN, GAP, GROUP_GAP = 40, 28, 56
local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"

-- Where each column sits across `width` pixels: the PvP group's, then the
-- PvE group's, a wider gap between the groups.
function HallOfFame.layout(width: number)
	local count = #HallOfFame.Boards
	local inner = 0
	for i = 2, count do
		local before, here = HallOfFame.Boards[i - 1], HallOfFame.Boards[i]
		inner += if before.Group == here.Group then GAP else GROUP_GAP
	end
	local w = math.floor((width - MARGIN * 2 - inner) / count)
	local columns, groups = {}, {}
	local x = MARGIN
	for i, board in HallOfFame.Boards do
		if i > 1 then
			x += if HallOfFame.Boards[i - 1].Group == board.Group then GAP else GROUP_GAP
		end
		table.insert(columns, { Id = board.Id, X = x, W = w, Group = board.Group })
		local g = groups[board.Group]
		if g then
			g.W = x + w - g.X
		else
			groups[board.Group] = { X = x, W = w }
		end
		x += w
	end
	return columns, groups
end

-- A score as the board shows it: 1,234 up to 99,999; then 120K, 4.5M.
function HallOfFame.value(n: number): string
	n = math.max(0, math.floor(tonumber(n) or 0))
	if n >= 1e6 then
		return (string.format("%.1fM", n / 1e6):gsub("%.0M", "M"))
	elseif n >= 1e5 then
		return string.format("%dK", n // 1000)
	end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function new(class: string, props, parent: Instance?)
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local function text(parent: Instance, value: string, x, y, w, h, size, color, font, align)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or Enum.Font.GothamBold,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function box(parent: Instance, x, y, w, h, color, name: string?)
	return new("Frame", {
		Name = name or "Box",
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
end

-- A square photo (a player's headshot, or an empty frame), a thin edge.
local function face(parent: Instance, userId: number?, x, y, size)
	local holder = box(parent, x, y, size, size, STRIPE, "Face")
	new("UIStroke", { Color = if userId then AMBER else RULE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, holder)
	if userId and userId > 0 then
		new("ImageLabel", {
			Name = "Headshot",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = string.format(HEADSHOT, userId),
		}, holder)
	end
	return holder
end

local MONO = Enum.Font.RobotoMono

-- One column: its title and unit, its first place large, then the next.
local function column(parent: Instance, spec, x: number, y: number, w: number, h: number, rows)
	local col = new("Frame", {
		Name = spec.Id,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	text(col, spec.Title, 0, 0, w - 62, 30, 20, TEXT, Enum.Font.GothamBlack)
	text(col, spec.Unit, w - 62, 6, 62, 22, 13, DIM, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
	box(col, 0, 36, w, 2, RULE, "Rule")

	-- First place: the photo, the name, the number large.
	local top = rows[1]
	text(col, "1", 0, 52, 28, 40, 34, AMBER, MONO)
	face(col, top and top.UserId, 34, 50, 84)
	local champName = text(col, if top then top.Name else "UNCLAIMED", 132, 52, w - 132, 28, 21, if top then TEXT else DIM, Enum.Font.GothamBold)
	champName.Name = "Champion"
	champName:SetAttribute("NoTranslate", top ~= nil) -- (a player's name)
	text(col, if top then HallOfFame.value(top.Value) else "—", 132, 84, w - 132, 50, 44, if top then AMBER else DIM, MONO)
	box(col, 0, 150, w, 1, RULE, "Rule")

	-- The next places: plain rows, every other one a shade lighter.
	local rowH = 72
	for rank = 2, HallOfFame.Rows + 1 do
		local row = rows[rank]
		local ry = 158 + (rank - 2) * rowH
		if ry + rowH > h then
			break
		end
		local strip = box(col, 0, ry, w, rowH, STRIPE, "Row" .. rank)
		strip.BackgroundTransparency = if rank % 2 == 0 then 0 else 1
		text(strip, tostring(rank), 8, 0, 24, rowH, 22, DIM, MONO)
		local value = if row then HallOfFame.value(row.Value) else ""
		local valueW = 16 + 15 * #value
		local name = text(strip, if row then row.Name else "—", 36, 0, w - 36 - valueW - 14, rowH, 21, if row then TEXT else DIM, Enum.Font.GothamMedium)
		name:SetAttribute("NoTranslate", true)
		text(strip, value, w - valueW - 8, 0, valueW, rowH, 26, TEXT, MONO, Enum.TextXAlignment.Right)
	end
	return col
end

-- (Re)draws `gui` from boards[Id] = rows (best first). `global`: the
-- boards are every server's, not just this one's.
function HallOfFame.draw(gui: SurfaceGui, boards: { [string]: { any } }, global: boolean?)
	gui:ClearAllChildren()
	local W, H = HallOfFame.Canvas.X, HallOfFame.Canvas.Y
	local root = box(gui, 0, 0, W, H, BG, "HallOfFame")

	-- The title on the left, where it's from on the right, one amber rule.
	text(root, "HALL OF FAME", MARGIN, 24, 700, 64, 58, TEXT, Enum.Font.GothamBlack)
	text(
		root,
		if global then "ALL SERVERS  ·  UPDATED EVERY 2 MIN" else "THIS SERVER",
		W / 2,
		50,
		W / 2 - MARGIN,
		30,
		18,
		DIM,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Right
	)
	box(root, MARGIN, 100, W - MARGIN * 2, 3, AMBER, "Rule")

	local columns, groups = HallOfFame.layout(W)
	-- Each group's name over its columns, small.
	for id, g in groups do
		text(root, HallOfFame.Groups[id].Title, g.X, 118, g.W, 22, 16, AMBER, Enum.Font.GothamBold)
	end
	-- A thin rule between the columns, a heavier one between the groups.
	for i = 2, #columns do
		local before, here = columns[i - 1], columns[i]
		local between = (before.X + before.W + here.X) / 2
		local heavy = before.Group ~= here.Group
		box(root, math.floor(between) - (if heavy then 1 else 0), 150, if heavy then 3 else 1, H - 150 - 30, if heavy then DIM else RULE, "Divider")
	end
	for i, c in columns do
		local spec = HallOfFame.Boards[i]
		column(root, spec, c.X, 152, c.W, H - 152 - 30, boards[spec.Id] or {})
	end
end

return HallOfFame
