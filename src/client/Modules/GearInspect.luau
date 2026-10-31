--[[
	Another player's gear (Server.GearInspect): GEAR on the card beside a
	miner near you (PlayerCard) opens it. A window with their name, level
	and gear score, and a card for each of the six pieces they wear: its
	name in its rarity's colour, its rarity, the gem in its socket (in its
	element's colour), its perk and its rolled stats. Nothing to press but
	close: it's theirs.

	  GearInspect.open(userId)
	  GearInspect.statText(stat, amount) -> string   one stat, as shown (pure)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local GearInspect = {}

local P = IronUi.Colors
local new = IronUi.new
local W, H = 720, 460
local CARD_W, CARD_H = 330, 104

local NAMES = { Health = "HP", Power = "Power", Defense = "Defense", Speed = "Speed", Critical = "Crit", Cooldown = "Cooldown" }
local PERCENT = { Critical = true, Cooldown = true }

-- One rolled stat as the card shows it: "+120 HP", "+4% Crit".
function GearInspect.statText(stat: string, amount: number): string
	if PERCENT[stat] then
		return string.format("+%d%% %s", math.floor(amount * 100 + 0.5), NAMES[stat] or stat)
	end
	return string.format("+%d %s", math.floor(amount + 0.5), NAMES[stat] or stat)
end

local function rarityColor(name: string?): Color3
	for _, rarity in GearRolls.Rarities do
		if rarity.Name == name then
			return rarity.Color
		end
	end
	return P.Dim
end

-- One line at a fixed size.
local function line(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font, x, y, w, h): TextLabel
	local label = IronUi.text(parent, value, size, color, font)
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	return label
end

local window: IronUi.Window? = nil
local body: Frame
local status: TextLabel
local asked = 0

local function build()
	local w = IronUi.window("GearInspect", 12, W, H, "⛨", P.Teal)
	w.Close.Activated:Connect(function()
		w.Gui.Enabled = false
	end)
	w.Shade.Activated:Connect(function()
		w.Gui.Enabled = false
	end)
	body = new("Frame", {
		Name = "Pieces",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 80),
		Size = UDim2.new(1, -40, 1, -96),
	}, w.Panel)
	status = line(w.Panel, "", 13, P.Dim, IronUi.Bold, 20, 80, W - 40, 20)
	window = w
	return w
end

local function card(piece, index: number)
	local col, row = (index - 1) % 2, (index - 1) // 2
	local color = if piece.Name then rarityColor(piece.Rarity) else P.Dim
	local frame = new("Frame", {
		Name = piece.Slot,
		BackgroundColor3 = Color3.fromRGB(18, 23, 34),
		Position = UDim2.fromOffset(col * (CARD_W + 20), row * (CARD_H + 14)),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
	}, body)
	UiKit.round(frame, 10)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.55 }, frame)
	-- The rarity down the left edge.
	new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(0, 3, 1, -20) }, frame)
	line(frame, string.upper(piece.Label or piece.Slot), 10, P.Dim, IronUi.Bold, 14, 8, 150, 13)
	if not piece.Name then
		line(frame, "Nothing worn", 14, P.Dim, IronUi.Body, 14, 26, CARD_W - 28, 18)
		return
	end
	local rarity = line(frame, string.upper(piece.Rarity or ""), 10, color, IronUi.Bold, CARD_W - 164, 8, 150, 13)
	rarity.TextXAlignment = Enum.TextXAlignment.Right
	local name = line(frame, piece.Name, 16, color:Lerp(P.Text, 0.2), IronUi.Heading, 14, 24, CARD_W - 28, 20)
	name:SetAttribute("NoTranslate", true)
	-- Its gem, a dot in its element's colour; else an empty socket.
	local gem = piece.Gem
	local gemColor = gem and GemConfig.ElementColors[gem.Element] or P.Dim
	local dot = new("Frame", { BackgroundColor3 = gemColor, Position = UDim2.fromOffset(14, 52), Size = UDim2.fromOffset(10, 10), Rotation = 45 }, frame)
	if not gem then
		dot.BackgroundTransparency = 1
		new("UIStroke", { Color = P.Dim, Thickness = 1 }, dot)
	end
	local gemText = if gem then gem.Name else "Empty socket"
	if piece.Perk then
		gemText ..= "   ·   " .. piece.Perk
	end
	line(frame, gemText, 12, if gem then gemColor:Lerp(P.Text, 0.35) else P.Dim, IronUi.Bold, 32, 49, CARD_W - 46, 16)
	-- Its rolled stats, in one line.
	local parts = {}
	for _, s in piece.Stats or {} do
		table.insert(parts, GearInspect.statText(s.Stat, s.Amount))
	end
	local stats = line(frame, if #parts > 0 then table.concat(parts, "  ") else "No rolled stats", 12, P.Text, IronUi.Body, 14, 74, CARD_W - 28, 18)
	stats.TextScaled = #parts > 3
	if stats.TextScaled then
		new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 8 }, stats)
	end
end

local function draw(summary)
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	local w = window :: IronUi.Window
	w.Title.Text = string.upper(summary.Name or "Miner") .. "'S GEAR"
	w.Subtitle.Text = string.format("Level %d miner   ·   Gear score %d", summary.Level or 1, summary.Score or 0)
	status.Text = ""
	for i, piece in summary.Pieces or {} do
		card(piece, i)
	end
end

function GearInspect.open(userId: number)
	local w = window or build()
	asked += 1
	local mine = asked
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	w.Title.Text = "GEAR"
	w.Subtitle.Text = ""
	status.Text = "Looking at their gear..."
	w.Gui.Enabled = true
	task.spawn(function()
		local result = GemClient.request("InspectGear", userId)
		if mine ~= asked or not w.Gui.Enabled then
			return
		end
		if result and result.Ok then
			draw(result)
		else
			status.Text = result and result.Message or "Couldn't see their gear."
		end
	end)
end

return GearInspect
