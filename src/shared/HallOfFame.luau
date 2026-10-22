--[[
	The Hall of Fame: the Shelter's big board on the east wall (Server.
	OutpostServer draws it, from Server.TopPlayers' boards; World.
	OutpostWorld builds the wall it hangs on). Two halls side by side:

	  PVP HALL OF FAME   1V1 DUELS (Arena 1v1 wins: Duels' Solo),
	                     1V1 + KAIJU (wins in the Kaiju Arena's mixed
	                     match: you duel while your kaiju battle theirs),
	                     KAIJU BATTLES (Kaiju Arena battle wins)
	  PVE HALL OF FAME   BOUNTY HUNTERS (Rift bosses slain: the bounties
	                     Brutus posts), TOP MINERS (gems mined)

	Each column: its champion up top (their face, a gold ring, the number),
	then the next Rows, medals for second and third. An empty place reads
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
local HallOfFame = {}

local GOLD = Color3.fromRGB(255, 202, 96)
local SILVER = Color3.fromRGB(206, 214, 228)
local BRONZE = Color3.fromRGB(214, 140, 86)
local INK = Color3.fromRGB(8, 11, 20)
local CARD = Color3.fromRGB(16, 21, 36)
local ROW = Color3.fromRGB(22, 28, 46)
local TEXT = Color3.fromRGB(236, 240, 248)
local DIM = Color3.fromRGB(128, 140, 166)
local PVP = Color3.fromRGB(255, 84, 72)
local PVE = Color3.fromRGB(80, 214, 196)

HallOfFame.Boards = {
	{ Id = "Duel", Group = "PvP", Title = "1V1 DUELS", Unit = "WINS", Color = Color3.fromRGB(255, 96, 80) },
	{ Id = "Mixed", Group = "PvP", Title = "1V1 + KAIJU", Unit = "WINS", Color = Color3.fromRGB(255, 150, 64) },
	{ Id = "Kaiju", Group = "PvP", Title = "KAIJU BATTLES", Unit = "WINS", Color = Color3.fromRGB(196, 110, 255) },
	{ Id = "Bosses", Group = "PvE", Title = "BOUNTY HUNTERS", Unit = "BOSSES", Color = Color3.fromRGB(90, 220, 150) },
	{ Id = "Mined", Group = "PvE", Title = "TOP MINERS", Unit = "GEMS", Color = Color3.fromRGB(96, 196, 255) },
}
HallOfFame.Groups = {
	PvP = { Title = "PVP HALL OF FAME", Color = PVP },
	PvE = { Title = "PVE HALL OF FAME", Color = PVE },
}
-- Places under each champion.
HallOfFame.Rows = 5
HallOfFame.Size = Vector2.new(40, 19) -- studs
HallOfFame.Canvas = Vector2.new(1600, 760) -- pixels: 40 to the stud

local MARGIN, GAP, GROUP_GAP = 30, 14, 36
local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"

-- Where each column sits across `width` pixels: the PvP group's three,
-- then the PvE group's two, a wider gap between the groups.
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

local function box(parent: Instance, x, y, w, h, color, radius: number?, name: string?)
	local f = new("Frame", {
		Name = name or "Box",
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	if radius then
		new("UICorner", { CornerRadius = UDim.new(0, radius) }, f)
	end
	return f
end

local function medal(rank: number): Color3
	return if rank == 1 then GOLD elseif rank == 2 then SILVER elseif rank == 3 then BRONZE else DIM
end

-- A round face (a player's headshot, or an empty slot) ringed in `ring`.
local function face(parent: Instance, userId: number?, x, y, size, ring: Color3)
	local holder = box(parent, x, y, size, size, ROW, size // 2, "Face")
	new("UIStroke", { Color = ring, Thickness = math.max(2, size // 22), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, holder)
	if userId and userId > 0 then
		local img = new("ImageLabel", {
			Name = "Headshot",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = string.format(HEADSHOT, userId),
		}, holder)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, img)
	else
		text(holder, "?", 0, 0, size, size, size // 2, DIM, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	end
	return holder
end

-- One column: its title, its champion, then the next places.
local function column(parent: Instance, spec, x: number, y: number, w: number, h: number, rows)
	local card = box(parent, x, y, w, h, CARD, 14, spec.Id)
	new("UIStroke", { Color = spec.Color, Thickness = 2, Transparency = 0.55 }, card)
	box(card, 0, 0, w, 6, spec.Color, nil, "Stripe")
	text(card, spec.Title, 18, 16, w - 36, 32, 25, TEXT, Enum.Font.GothamBlack)
	text(card, spec.Unit, 18, 48, w - 36, 18, 15, spec.Color, Enum.Font.GothamBold)

	-- The champion.
	local top = rows[1]
	local champ = box(card, 12, 76, w - 24, 172, Color3.fromRGB(26, 24, 30), 12, "Champion")
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(70, 56, 30), Color3.fromRGB(24, 24, 32)),
		Rotation = 90,
	}, champ)
	new("UIStroke", { Color = GOLD, Thickness = 2, Transparency = if top then 0.1 else 0.6 }, champ)
	face(champ, top and top.UserId, 14, 14, 92, if top then GOLD else DIM)
	text(champ, "1ST", 118, 16, w - 150, 24, 22, GOLD, Enum.Font.GothamBlack)
	local champName = text(champ, if top then top.Name else "UNCLAIMED", 118, 42, w - 150, 30, 24, if top then TEXT else DIM, Enum.Font.GothamBold)
	champName:SetAttribute("NoTranslate", top ~= nil) -- (a player's name)
	text(champ, "CHAMPION", 118, 74, w - 150, 18, 14, DIM, Enum.Font.GothamBold)
	text(
		champ,
		if top then HallOfFame.value(top.Value) else "—",
		16,
		114,
		w - 56,
		48,
		44,
		if top then spec.Color else DIM,
		Enum.Font.GothamBlack
	)

	-- The next places.
	local rowH, rowGap = 52, 6
	for rank = 2, HallOfFame.Rows + 1 do
		local row = rows[rank]
		local ry = 258 + (rank - 2) * (rowH + rowGap)
		if ry + rowH > h - 8 then
			break
		end
		local strip = box(card, 12, ry, w - 24, rowH, ROW, 10, "Row" .. rank)
		local tint = medal(rank)
		local badge = box(strip, 10, (rowH - 32) // 2, 32, 32, if rank <= 3 then tint else Color3.fromRGB(40, 48, 70), 16)
		text(badge, tostring(rank), 0, 0, 32, 32, 18, if rank <= 3 then INK else TEXT, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
		local name = text(strip, if row then row.Name else "—", 52, 0, w - 24 - 52 - 84, rowH, 21, if row then TEXT else DIM, Enum.Font.GothamBold)
		name:SetAttribute("NoTranslate", true)
		text(
			strip,
			if row then HallOfFame.value(row.Value) else "",
			w - 24 - 88,
			0,
			76,
			rowH,
			24,
			if row then spec.Color else DIM,
			Enum.Font.GothamBlack,
			Enum.TextXAlignment.Right
		)
	end
	return card
end

-- (Re)draws `gui` from boards[Id] = rows (best first). `global`: the
-- boards are every server's, not just this one's.
function HallOfFame.draw(gui: SurfaceGui, boards: { [string]: { any } }, global: boolean?)
	gui:ClearAllChildren()
	local W, H = HallOfFame.Canvas.X, HallOfFame.Canvas.Y
	local root = box(gui, 0, 0, W, H, INK, nil, "HallOfFame")
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(20, 26, 46), Color3.fromRGB(6, 8, 16)),
		Rotation = 90,
	}, root)

	-- The title, between gold rules.
	text(root, "HALL OF FAME", 0, 14, W, 70, 66, GOLD, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
	for _, s in { -1, 1 } do
		box(root, W / 2 + s * 330 - (if s < 0 then 260 else 0), 48, 260, 3, GOLD, nil, "Rule")
	end
	text(
		root,
		if global then "THE BEST ON EVERY SERVER  ·  UPDATED EVERY TWO MINUTES" else "THE BEST IN THIS SERVER",
		0,
		84,
		W,
		22,
		18,
		DIM,
		Enum.Font.GothamBold,
		Enum.TextXAlignment.Center
	)

	local columns, groups = HallOfFame.layout(W)
	-- Each group's banner over its columns.
	for id, g in groups do
		local spec = HallOfFame.Groups[id]
		local band = box(root, g.X, 118, g.W, 40, Color3.fromRGB(12, 16, 28), 10, "Group" .. id)
		new("UIStroke", { Color = spec.Color, Thickness = 2, Transparency = 0.2 }, band)
		box(band, 14, 12, 16, 16, spec.Color, 8, "Dot")
		text(band, spec.Title, 40, 0, g.W - 56, 40, 24, spec.Color, Enum.Font.GothamBlack)
	end
	for i, c in columns do
		local spec = HallOfFame.Boards[i]
		column(root, spec, c.X, 170, c.W, H - 170 - 24, boards[spec.Id] or {})
	end
end

return HallOfFame
