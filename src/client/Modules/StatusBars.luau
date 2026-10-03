--[[
	Buff and debuff display, like an RPG's: who is Burning, Slowed (Cryo),
	Frozen, Shocked, Shielded... read from each fighter's "Statuses"
	attribute (see Shared.StatusEffects).

	  StatusBars.strip(parent, compact)  a row of chips; :update(text, now)
	    full chips:    [🔥 Burning  3s]  (name in the element's colour)
	    compact chips: [🔥] with the seconds under it
	    A thin bar under each chip drains as the effect runs out, and a
	    new effect flashes in.
	  StatusBars.step(now)  overhead icons on every enemy and other player
	    nearby, plus a floating "BURNING!" when an effect first lands.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)

local StatusBars = {}

local INK = Color3.fromRGB(12, 17, 28)
local MUTED = Color3.fromRGB(170, 182, 200)
local BUFF_EDGE = Color3.fromRGB(110, 220, 140)

local function make(class: string, props, parent: Instance?)
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

-- Seconds left, short: "12s", "3s", "0.6s".
function StatusBars.timeLeft(seconds: number): string
	if seconds >= 60 then
		return string.format("%dm", math.floor(seconds / 60))
	elseif seconds >= 1 then
		return string.format("%ds", math.ceil(seconds - 0.05))
	end
	return string.format("%.1fs", math.max(0, seconds))
end

local function chip(parent: Instance, id: string, compact: boolean)
	local effect = StatusEffects.Catalog[id]
	local edge = if effect.Debuff then effect.Color else BUFF_EDGE
	local frame = make("Frame", {
		Name = id,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		LayoutOrder = effect.Order,
		Size = if compact then UDim2.fromOffset(26, 34) else UDim2.fromOffset(0, 26),
		AutomaticSize = if compact then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
	}, parent)
	corner(frame, 5)
	local stroke = make("UIStroke", { Color = edge, Thickness = 1.5, Transparency = 0.1 }, frame)
	local icon = make("TextLabel", {
		BackgroundTransparency = 1,
		Text = effect.Icon,
		TextSize = if compact then 15 else 15,
		Font = Enum.Font.GothamBold,
		TextColor3 = effect.Color,
		Size = UDim2.fromOffset(26, if compact then 22 else 24),
	}, frame)
	local timer, name
	if compact then
		timer = make("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.fromOffset(26, 12),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.4,
			Text = "",
		}, frame)
	else
		make("UIPadding", { PaddingRight = UDim.new(0, 8) }, frame)
		local layout = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
		}, frame)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, layout)
		name = make("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = effect.Color:Lerp(Color3.new(1, 1, 1), 0.25),
			TextStrokeTransparency = 0.6,
			Text = StatusEffects.label(id),
			LayoutOrder = 1,
		}, layout)
		timer = make("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = MUTED,
			Text = "",
			LayoutOrder = 2,
		}, layout)
	end
	-- Drains as the effect runs out.
	local drain = make("Frame", {
		BackgroundColor3 = edge,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 3, 1, -1),
		Size = UDim2.new(1, -6, 0, 2),
		ZIndex = 2,
	}, frame)
	return {
		Frame = frame,
		Stroke = stroke,
		Icon = icon,
		Timer = timer,
		Name = name,
		Drain = drain,
		Total = 0,
		Ends = 0,
		BornAt = os.clock(),
	}
end

-- A row of status chips. `compact` draws icon-only chips (overheads, the
-- rival panel); otherwise each chip reads "🔥 Burning (Thermal)  3s".
function StatusBars.strip(parent: Instance, compact: boolean?, align: Enum.HorizontalAlignment?)
	local holder = make("Frame", {
		Name = "Statuses",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, if compact then 3 else 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	local strip = { Holder = holder, Chips = {}, Compact = compact == true, Text = nil, Fresh = {} }

	-- `now` is server time. Returns the ids that just appeared.
	function strip.update(_, text: string?, now: number)
		local fresh = {}
		local active = {}
		for _, status in StatusEffects.decode(text) do
			local left = status.Ends - now
			if left > 0 then
				active[status.Id] = status
			end
		end
		for id, entry in strip.Chips do
			if not active[id] then
				entry.Frame:Destroy()
				strip.Chips[id] = nil
			end
		end
		for id, status in active do
			local entry = strip.Chips[id]
			if not entry then
				entry = chip(holder, id, strip.Compact)
				strip.Chips[id] = entry
				table.insert(fresh, id)
			end
			local left = status.Ends - now
			if status.Ends > entry.Ends + 0.05 then
				-- New or refreshed: the drain bar starts full again.
				entry.Ends, entry.Total = status.Ends, math.max(left, 0.1)
				entry.BornAt = os.clock()
			end
			entry.Timer.Text = StatusBars.timeLeft(left)
			entry.Drain.Size = UDim2.new(math.clamp(left / entry.Total, 0, 1), -6, 0, 2)
			if entry.Name and status.Value > 0 then
				local effect = StatusEffects.Catalog[id]
				entry.Name.Text = if id == "Shielded" or id == "EnergySiphon"
					then string.format("%s %d", effect.Name, status.Value)
					elseif string.find(effect.Text, "%d%%", 1, true) then string.format(
						"%s %d%%",
						StatusEffects.label(id),
						status.Value
					)
					else StatusEffects.label(id)
			end
			-- Flash in, and pulse in its last second.
			local age = os.clock() - entry.BornAt
			local flash = math.clamp(1 - age / 0.35, 0, 1)
			local ending = if left < 1 then 0.5 + 0.5 * math.sin(os.clock() * 14) else 0
			entry.Frame.BackgroundColor3 =
				INK:Lerp(StatusEffects.Catalog[id].Color, math.max(flash * 0.7, ending * 0.25))
			entry.Stroke.Thickness = 1.5 + flash * 1.5
		end
		return fresh
	end
	return strip
end

-- Overheads --------------------------------------------------------------------------------

local overheads: { [Instance]: any } = {}
local nextScan = 0

local function rootOf(owner: Instance): BasePart?
	local model = if owner:IsA("Player") then owner.Character else owner
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function popup(entry, id: string)
	local effect = StatusEffects.Catalog[id]
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(200, 22),
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = effect.Color:Lerp(Color3.new(1, 1, 1), 0.2),
		TextStrokeTransparency = 0.25,
		Text = string.upper(effect.Name) .. "!",
	}, entry.Board)
	table.insert(entry.Popups, { Label = label, Born = os.clock() })
end

local function overheadFor(owner: Instance, root: BasePart)
	local entry = overheads[owner]
	if entry and entry.Root == root and entry.Board.Parent then
		return entry
	end
	if entry then
		entry.Board:Destroy()
	end
	local board = make("BillboardGui", {
		Name = "StatusIcons",
		Adornee = root,
		Size = UDim2.fromOffset(190, 36),
		StudsOffset = Vector3.new(0, 5.1, 0),
		MaxDistance = 80,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
	}, Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))
	entry = {
		Root = root,
		Board = board,
		Strip = StatusBars.strip(board, true),
		Popups = {},
	}
	overheads[owner] = entry
	return entry
end

-- Every frame, with server time.
function StatusBars.step(now: number)
	local clock = os.clock()
	if clock >= nextScan then
		nextScan = clock + 0.25
		local seen = {}
		local folder = workspace:FindFirstChild("Enemies")
		for _, model in if folder then folder:GetChildren() else {} do
			seen[model] = true
		end
		for _, other in Players:GetPlayers() do
			if other ~= Players.LocalPlayer then
				seen[other] = true
			end
		end
		for owner, entry in overheads do
			if not seen[owner] or not owner.Parent then
				entry.Board:Destroy()
				overheads[owner] = nil
			end
		end
		for owner in seen do
			local root = rootOf(owner)
			if root and owner:GetAttribute("Statuses") ~= nil then
				overheadFor(owner, root)
			end
		end
	end
	for owner, entry in overheads do
		local text = owner:GetAttribute("Statuses")
		local fresh = entry.Strip:update(text, now)
		for _, id in fresh do
			if StatusEffects.Catalog[id].Debuff then
				popup(entry, id)
			end
		end
		for i = #entry.Popups, 1, -1 do
			local pop = entry.Popups[i]
			local age = clock - pop.Born
			if age > 1.1 then
				pop.Label:Destroy()
				table.remove(entry.Popups, i)
			else
				pop.Label.Position = UDim2.new(0.5, 0, 0, -age * 26)
				pop.Label.TextTransparency = math.clamp((age - 0.6) / 0.5, 0, 1)
				pop.Label.TextStrokeTransparency = 0.25 + 0.75 * math.clamp((age - 0.6) / 0.5, 0, 1)
			end
		end
	end
end

return StatusBars
