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
		Size = UDim2.fromOffset(220, 46),
		StudsOffset = Vector3.new(0, 7, 0), -- above the status icons
		MaxDistance = 140,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
		Enabled = false,
	}, Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))
	local panel = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 14, 24),
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
	}, board)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, panel)
	local stroke = make("UIStroke", { Thickness = 2, Transparency = 0.1 }, panel)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 3),
		Size = UDim2.new(1, -60, 0, 20),
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.4,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, panel)
	local time = make("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 3),
		Size = UDim2.fromOffset(50, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(220, 228, 240),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeTransparency = 0.4,
	}, panel)
	local track = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 34, 48),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 27),
		Size = UDim2.new(1, -16, 0, 11),
	}, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, track)
	local fill = make("Frame", { BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, fill)
	entry = { Root = root, Board = board, Fill = fill, Name = label, Time = time, Stroke = stroke }
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
function FoeCastBar.step(serverNow: number)
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
		entry.Board.Enabled = cast ~= nil
		if cast then
			FoeCastBar.paint(cast, entry.Name, entry.Time, entry.Fill, entry.Stroke)
		end
	end
end

return FoeCastBar
