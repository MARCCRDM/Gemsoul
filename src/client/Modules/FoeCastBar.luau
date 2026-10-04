--[[
	Enemy cast bars: what a foe is casting, in its element's colour, with
	the time left and how to get out of it, so you can dodge or block.

	  FoeCastBar.read(model, serverNow)  the cast a fighter is in, or nil:
	    { Name, Kind, Color, Left, Progress, Channel, Hint, Threat }
	  FoeCastBar.step(serverNow)  a bar over the head of every rival and
	    every other player who is casting (the same bar for both).

	Everyone's casts come from the same attributes, set by the server on
	the fighter's model (ActionName, ActionKind, ActionElement,
	ActionStart, ActionAt, ActionHold; see Shared.CombatActions castTime).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)

local FoeCastBar = {}

FoeCastBar.Gold = Color3.fromRGB(255, 190, 80)
-- How to get out of each kind of cast (RivalPose kinds).
FoeCastBar.Hints = {
	Nova = "ROLL OUT OF THE RING",
	Bolt = "SIDESTEP OR BLOCK",
	Heavy = "DODGE  ·  BREAKS GUARD",
	Slash = "BLOCK OR DODGE",
	Channel = "BLOCK OR GET OUT OF RANGE",
}
FoeCastBar.MinWindup = 0.15 -- a named cast at least this long gets a bar

function FoeCastBar.read(model: Instance?, serverNow: number)
	if not model then
		return nil
	end
	local name = model:GetAttribute("ActionName")
	local kind = model:GetAttribute("ActionKind")
	local start, at = model:GetAttribute("ActionStart"), model:GetAttribute("ActionAt")
	local hold = model:GetAttribute("ActionHold")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if type(name) ~= "string" or type(start) ~= "number" or type(at) ~= "number" then
		return nil
	end
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local channel = type(hold) == "number" and serverNow >= at and serverNow < hold
	if not channel and (at - start < FoeCastBar.MinWindup or serverNow >= at + 0.08) then
		return nil
	end
	local element = model:GetAttribute("ActionElement")
	local hintKind = if channel then "Channel" else kind
	return {
		Name = name,
		Kind = kind,
		Color = GemConfig.ElementColors[element or ""] or FoeCastBar.Gold,
		Left = if channel then 0 else math.max(0, at - serverNow),
		Progress = if channel then 1 else math.clamp((serverNow - start) / math.max(at - start, 0.01), 0, 1),
		Channel = channel,
		Hint = FoeCastBar.Hints[hintKind or ""],
		-- A buff on itself is no threat: no dodge cue.
		Threat = kind ~= "Buff",
	}
end

-- [owner] = { Board, Fill, Name, Time, Stroke }
local boards = {}
local nextScan = 0

local function modelOf(owner: Instance): Model?
	local model = if owner:IsA("Player") then owner.Character else owner
	return if model and model:IsA("Model") then model else nil
end

local function make(className: string, props, parent: Instance?)
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

-- Drawn from UI geometry so the caution icon never depends on an emoji font.
function FoeCastBar.widget(parent, width, compact)
	local panel = make("Frame", {
		Name = "CastWarning",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, if compact then 64 else 88),
	}, parent)
	local icon = make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(30, 28),
	}, panel)
	local edges = {}
	for _, points in { { 15, 2, 1, 26 }, { 1, 26, 29, 26 }, { 29, 26, 15, 2 } } do
		local dx, dy = points[3] - points[1], points[4] - points[2]
		table.insert(
			edges,
			make("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = FoeCastBar.Gold,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset((points[1] + points[3]) / 2, (points[2] + points[4]) / 2),
				Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 2),
				Rotation = math.deg(math.atan2(dy, dx)),
			}, icon)
		)
	end
	for _, rect in { { 14, 10, 3, 8 }, { 14, 21, 3, 3 } } do
		table.insert(
			edges,
			make("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = FoeCastBar.Gold,
				Position = UDim2.fromOffset(rect[1], rect[2]),
				Size = UDim2.fromOffset(rect[3], rect[4]),
			}, icon)
		)
	end
	local function label(y, height, size)
		return make("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, height),
			Font = Enum.Font.GothamBold,
			TextSize = size,
			TextColor3 = Color3.fromRGB(230, 237, 245),
			TextStrokeTransparency = 0.25,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "",
		}, panel)
	end
	local name = label(30, 18, if compact then 11 else 13)
	local track = make("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(24, 30, 43),
		Position = UDim2.new(0, 20, 0, 50),
		Size = UDim2.new(1, -65, 0, 3),
	}, panel)
	local fill = make("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
	local stroke = make("UIStroke", { Thickness = 1, Transparency = 0.6 }, track)
	local time = label(45, 14, 10)
	time.Position, time.Size = UDim2.new(1, -43, 0, 45), UDim2.fromOffset(43, 14)
	local hint = label(65, 16, 10)
	hint.Visible = not compact
	return { Panel = panel, Name = name, Time = time, Fill = fill, Stroke = stroke, Edges = edges, Hint = hint }
end

function FoeCastBar.draw(entry, cast, compact)
	local urgent = FoeCastBar.paint(cast, entry.Name, entry.Time, entry.Fill, entry.Stroke)
	-- Only the small symbol pulses; the cast name stays steady and readable.
	local color = if urgent then Color3.fromRGB(255, 100, 80) else FoeCastBar.Gold
	for _, edge in entry.Edges do
		edge.BackgroundColor3 = color
		edge.BackgroundTransparency = if urgent then 0.12 * (1 + math.sin(os.clock() * 10)) else 0
	end
	entry.Hint.Visible = not compact and cast.Threat and cast.Hint ~= nil
	entry.Hint.Text = cast.Hint or ""
	return urgent
end

local function boardFor(owner: Instance, root: BasePart)
	local entry = boards[owner]
	if entry and entry.Root == root and entry.Board.Parent then
		return entry
	end
	if entry then
		entry.Board:Destroy()
	end
	local board = make("BillboardGui", {
		Name = "FoeCastBar",
		Adornee = root,
		Size = UDim2.fromOffset(170, 64),
		StudsOffset = Vector3.new(0, 7, 0),
		MaxDistance = 80,
		AlwaysOnTop = false,
		ResetOnSpawn = false,
		Enabled = false,
	}, Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))
	entry = FoeCastBar.widget(board, 170, true)
	entry.Root, entry.Board = root, board
	boards[owner] = entry
	return entry
end

-- Fills one bar from a cast (`read`'s result); shared with the HUD bar.
function FoeCastBar.paint(cast, name: TextLabel, time: TextLabel, fill: Frame, stroke: UIStroke)
	name.Text = string.upper(cast.Name)
	name.TextColor3 = cast.Color:Lerp(Color3.new(1, 1, 1), 0.25)
	time.Text = if cast.Channel then "CHANNEL" else string.format("%.1fs", cast.Left)
	fill.Size = UDim2.fromScale(cast.Progress, 1)
	fill.BackgroundColor3 = cast.Color
	-- The last moments flash red: the time to hop, roll or raise the shield.
	local urgent = cast.Threat and (cast.Channel or cast.Left <= 0.35)
	stroke.Color = if urgent and math.sin(os.clock() * 30) > 0 then Color3.fromRGB(255, 90, 80) else cast.Color
	return urgent
end

-- Every frame, with server time.
function FoeCastBar.step(serverNow: number, hudModel: Model?)
	if os.clock() >= nextScan then
		nextScan = os.clock() + 0.25
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
		for owner, entry in boards do
			if not seen[owner] or not owner.Parent then
				entry.Board:Destroy()
				boards[owner] = nil
			end
		end
		for owner in seen do
			local model = modelOf(owner)
			local root = model and model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and model:GetAttribute("ActionName") ~= nil then
				boardFor(owner, root)
			end
		end
	end
	for owner, entry in boards do
		local cast = FoeCastBar.read(modelOf(owner), serverNow)
		entry.Board.Enabled = cast ~= nil and modelOf(owner) ~= hudModel
		if cast then
			FoeCastBar.draw(entry, cast, true)
		end
	end
end

return FoeCastBar
