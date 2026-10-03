--[[
	The matchup panel (beside the rival panel): you vs the Arena rival in the
	numbers each side really fights with (health, damage per hit, hits to
	win, speed; the better side gets a +), and two tabs of plain-language
	strengths (+) and weaknesses (-): the rival's, and yours. The server
	works it out (Shared.Matchup) and puts it in the rival's "Matchup"
	attribute.
]]
local HttpService = game:GetService("HttpService")

local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local MatchupUI = {}

local P = IronUi.Colors
local YOU_COLOR, FOE_COLOR = Color3.fromRGB(110, 210, 255), Color3.fromRGB(255, 110, 100)
local MUTED = Color3.fromRGB(150, 162, 182)
local LINES = 5

function MatchupUI.new(gui: Instance)
	local new, text = IronUi.new, IronUi.text
	local panel = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 17, 28),
		BackgroundTransparency = 0.12,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -272, 0, 62),
		Size = UDim2.fromOffset(250, 186),
		Visible = false,
	}, gui)
	UiKit.round(panel, 10)
	new("UIStroke", { Color = Color3.fromRGB(70, 96, 128), Transparency = 0.45, Thickness = 1 }, panel)
	local function label(size, color, x, y, w, h, font)
		local l = text(panel, "", size, color, font or IronUi.Bold)
		l.TextStrokeColor3, l.TextStrokeTransparency = Color3.new(0, 0, 0), 0.45
		l.AutomaticSize, l.TextWrapped = Enum.AutomaticSize.None, false
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Position, l.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
		return l
	end
	local title = label(11, P.Gold, 10, 5, 230, 16)
	local youHead, foeHead = label(9, YOU_COLOR, 104, 22, 60, 12), label(9, FOE_COLOR, 176, 22, 64, 12)
	youHead.Text, foeHead.Text = "YOU", "RIVAL"
	youHead.TextXAlignment, foeHead.TextXAlignment = Enum.TextXAlignment.Center, Enum.TextXAlignment.Center
	local rows = {}
	for i = 1, 4 do
		local y = 34 + (i - 1) * 15
		local row = {
			Stat = label(11, Color3.fromRGB(200, 210, 225), 10, y, 92, 15, IronUi.Chunky),
			You = label(12, YOU_COLOR, 104, y, 60, 15),
			Foe = label(12, FOE_COLOR, 176, y, 64, 15),
		}
		row.You.TextXAlignment, row.Foe.TextXAlignment = Enum.TextXAlignment.Center, Enum.TextXAlignment.Center
		rows[i] = row
	end
	local self = { Side = "Foe", Source = nil, Data = nil }
	local tabs = {}
	local function tab(caption, x, side)
		local b = new("TextButton", {
			BackgroundColor3 = Color3.fromRGB(28, 36, 54),
			Position = UDim2.fromOffset(x, 96),
			Size = UDim2.fromOffset(112, 18),
			Font = IronUi.Bold,
			TextSize = 10,
			TextColor3 = P.Text,
			Text = caption,
			AutoButtonColor = true,
		}, panel)
		UiKit.round(b, 5)
		b.Activated:Connect(function()
			self.Side = side
		end)
		tabs[side] = b
	end
	tab("RIVAL'S EDGE / WEAK", 10, "Foe")
	tab("YOUR EDGE / WEAK", 128, "You")
	local lines = {}
	for i = 1, LINES do
		local line = label(10, P.Text, 10, 118 + (i - 1) * 13, 230, 13, IronUi.Chunky)
		line.RichText = true
		lines[i] = line
	end

	function self.draw(_, model: Model?, viewport: Vector2, rivalShown: boolean)
		local raw = model and model:GetAttribute("Matchup")
		panel.Visible = rivalShown and type(raw) == "string" and viewport.X >= 1250
		if not panel.Visible or not model then
			return
		end
		if raw ~= self.Source then
			self.Source = raw
			local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
			self.Data = if ok then data else nil
		end
		local data = self.Data
		if not data then
			panel.Visible = false
			return
		end
		title.Text = "MATCHUP  ·  YOU vs " .. string.upper(model:GetAttribute("RivalName") or model.Name)
		for i, row in rows do
			local stat = data.Rows and data.Rows[i]
			row.Stat.Visible, row.You.Visible, row.Foe.Visible = stat ~= nil, stat ~= nil, stat ~= nil
			if stat then
				row.Stat.Text = string.upper(stat.Stat)
				row.You.Text = tostring(stat.You) .. (if stat.Better == "You" then " +" else "")
				row.Foe.Text = tostring(stat.Foe) .. (if stat.Better == "Foe" then " +" else "")
				row.You.TextTransparency = if stat.Better == "Foe" then 0.35 else 0
				row.Foe.TextTransparency = if stat.Better == "You" then 0.35 else 0
			end
		end
		for side, b in tabs do
			b.BackgroundColor3 = if side == self.Side then Color3.fromRGB(60, 78, 110) else Color3.fromRGB(28, 36, 54)
		end
		-- Up to two strengths, then weaknesses, for the chosen side.
		local out = {}
		local edges = (if self.Side == "Foe" then data.FoeEdges else data.YourEdges) or {}
		local weak = (if self.Side == "Foe" then data.FoeWeak else data.YourWeak) or {}
		local edgeColor = if self.Side == "Foe" then "#FF6E64" else "#6ED2FF"
		for i = 1, math.min(2, #edges) do
			table.insert(out, string.format('<font color="%s"><b>+</b></font> %s', edgeColor, edges[i]))
		end
		for i = 1, math.min(LINES - #out, #weak) do
			table.insert(out, string.format('<font color="#9AA6B8"><b>-</b></font> %s', weak[i]))
		end
		for i, line in lines do
			line.Text = out[i] or ""
		end
	end
	self.Panel = panel
	return self
end

-- For the panel's colours elsewhere.
MatchupUI.Colors = { You = YOU_COLOR, Foe = FOE_COLOR, Muted = MUTED }

return MatchupUI
