--[[
	Other players' plates: over every other player near you, their name and
	their level (MinerLevel), and once they're hit, their health bar under
	them, in the same colours as a body's outline (BodyHealth.outlineColor:
	green, amber, red) with a pale trail of the last blow draining away. The
	bar stays while they're hurt and for Hold seconds after a blow, then
	folds away again at full health. Roblox's own name and health over them
	are off (a plate of ours in their place, never two).

	They sit in PlayerGui (so they're in the player's language: "Lv" reads
	"Nv" in Spanish), each adorning its player's head, drawn within Range
	studs of the camera.

	  PlayerPlates.start()                       one for every other player
	  PlayerPlates.plate(name, level, phone?)    -> BillboardGui   builds one
	                        (Title, Level, Back with Trail and Fill inside)
	  PlayerPlates.draw(plate, share, trail, showBar)   fills it in
	  PlayerPlates.showBar(share, sinceHit) -> boolean   whether the bar
	                        shows: hurt, or hit within Hold (pure)
	  PlayerPlates.Size, PhoneSize, Range, Hold, Drain
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BodyHealth = require(script.Parent.BodyHealth)

local PlayerPlates = {}

PlayerPlates.Size = Vector2.new(150, 40) -- name and level over the bar
PlayerPlates.PhoneSize = Vector2.new(118, 32)
PlayerPlates.Range = 110 -- studs from the camera
PlayerPlates.Hold = 8 -- seconds the bar stays after a blow, at full health
PlayerPlates.Drain = 0.8 -- how much of the bar the trail drains a second
PlayerPlates.Lift = 2.4 -- studs over the head
PlayerPlates.BubbleLift = 2.5 -- chat bubbles this much higher, over the plate

local INK = Color3.fromRGB(12, 11, 16)
local EDGE = Color3.fromRGB(70, 66, 84)
local GOLD = Color3.fromRGB(255, 204, 92)
local TRAIL = Color3.fromRGB(255, 236, 200)
local NAME = Color3.fromRGB(242, 240, 236)

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

-- Whether the health bar shows: hurt at all, or hit within Hold seconds.
function PlayerPlates.showBar(share: number, sinceHit: number?): boolean
	return share < 0.999 or (sinceHit ~= nil and sinceHit >= 0 and sinceHit < PlayerPlates.Hold)
end

function PlayerPlates.plate(name: string, level: number?, phone: boolean?): BillboardGui
	local size = if phone then PlayerPlates.PhoneSize else PlayerPlates.Size
	local k = size.Y / PlayerPlates.Size.Y
	local function px(n: number): number
		return math.max(1, math.floor(n * k + 0.5))
	end
	local plate = make("BillboardGui", {
		Name = "PlayerPlate",
		Size = UDim2.fromOffset(size.X, size.Y),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = PlayerPlates.Range,
		ResetOnSpawn = false,
		StudsOffsetWorldSpace = Vector3.new(0, PlayerPlates.Lift, 0),
	})
	-- The level, a chip at the start of the row; the name beside it.
	local chip = make("TextLabel", {
		Name = "Level",
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(px(38), px(17)),
		Font = Enum.Font.GothamBlack,
		TextSize = math.max(px(11), 8),
		TextColor3 = GOLD,
		Text = "Lv " .. tostring(level or 1),
	}, plate)
	make("UICorner", { CornerRadius = UDim.new(0, px(4)) }, chip)
	local title = make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(42), 0),
		Size = UDim2.new(1, -px(42), 0, px(17)),
		Font = Enum.Font.GothamBold,
		TextSize = px(14),
		TextColor3 = NAME,
		TextStrokeColor3 = INK,
		TextStrokeTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextScaled = true,
		Text = name,
	}, plate)
	make("UITextSizeConstraint", { MaxTextSize = px(14), MinTextSize = math.min(px(14), if phone then 8 else 10) }, title)
	local back = make("Frame", {
		Name = "Back",
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, px(22)),
		Size = UDim2.new(1, 0, 0, px(10)),
		Visible = false,
	}, plate)
	make("UICorner", { CornerRadius = UDim.new(0, px(3)) }, back)
	make("UIStroke", { Name = "Edge", Color = EDGE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, back)
	make("Frame", {
		Name = "Trail",
		BackgroundColor3 = TRAIL,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, back)
	make("Frame", {
		Name = "Fill",
		BackgroundColor3 = BodyHealth.outlineColor(1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, back)
	return plate
end

-- Fills `plate` in: `share` of their health (the trail at `trail`, never
-- under it), shown or folded away (`showBar`).
function PlayerPlates.draw(plate: BillboardGui, share: number, trail: number, showBar: boolean)
	local x = math.clamp(share, 0, 1)
	local back = plate:FindFirstChild("Back") :: Frame
	back.Visible = showBar
	local fill = back:FindFirstChild("Fill") :: Frame
	fill.Size = UDim2.fromScale(x, 1)
	fill.BackgroundColor3 = BodyHealth.outlineColor(x)
	local behind = back:FindFirstChild("Trail") :: Frame
	behind.Size = UDim2.fromScale(math.max(x, math.clamp(trail, 0, 1)), 1)
end

-- A phone: touch and no keyboard, or a short screen.
local function onPhone(): boolean
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize
	return (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		or (view ~= nil and math.min(view.X, view.Y) < 500)
end

type Entry = {
	Player: Player,
	Humanoid: Humanoid,
	Plate: BillboardGui,
	Share: number,
	Trail: number,
	HitAt: number?,
	Connections: { RBXScriptConnection },
}
local entries: { [Player]: Entry } = {}

local function shareOf(humanoid: Humanoid): number
	if humanoid.MaxHealth <= 0 then
		return 0
	end
	return math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
end

local function redraw(entry: Entry)
	local since = if entry.HitAt then os.clock() - entry.HitAt else nil
	PlayerPlates.draw(entry.Plate, entry.Share, entry.Trail, PlayerPlates.showBar(entry.Share, since))
end

local function drop(other: Player)
	local entry = entries[other]
	if entry then
		entries[other] = nil
		for _, connection in entry.Connections do
			connection:Disconnect()
		end
		entry.Plate:Destroy()
	end
end

local function watch(other: Player, character: Model)
	drop(other)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local head = character:WaitForChild("Head", 10) :: BasePart?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not humanoid or not head or not playerGui or other.Character ~= character then
		return
	end
	-- (Roblox's own name and health: ours instead.)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local share = shareOf(humanoid)
	local entry: Entry = {
		Player = other,
		Humanoid = humanoid,
		Plate = PlayerPlates.plate(other.DisplayName, other:GetAttribute("MinerLevel"), onPhone()),
		Share = share,
		Trail = share,
		HitAt = nil,
		Connections = {},
	}
	entries[other] = entry
	entry.Plate.Adornee = head
	redraw(entry)
	entry.Plate.Parent = playerGui
	table.insert(entry.Connections, humanoid.HealthChanged:Connect(function()
		local now = shareOf(humanoid)
		if now < entry.Share then
			entry.HitAt = os.clock()
		else
			entry.Trail = now -- (healed: nothing to drain)
		end
		entry.Share = now
		redraw(entry)
	end))
	table.insert(entry.Connections, other:GetAttributeChangedSignal("MinerLevel"):Connect(function()
		local chip = entry.Plate:FindFirstChild("Level") :: TextLabel
		chip.Text = "Lv " .. tostring(other:GetAttribute("MinerLevel") or 1)
	end))
	table.insert(entry.Connections, humanoid.Died:Connect(function()
		entry.Plate.Enabled = false
	end))
end

local function track(other: Player)
	if other == Players.LocalPlayer then
		return
	end
	other.CharacterAdded:Connect(function(character)
		watch(other, character)
	end)
	other.CharacterRemoving:Connect(function()
		drop(other)
	end)
	if other.Character then
		task.spawn(watch, other, other.Character)
	end
end

local started = false
function PlayerPlates.start()
	if started then
		return
	end
	started = true
	-- (Chat bubbles float over the plates, not on them.)
	pcall(function()
		game:GetService("TextChatService").BubbleChatConfiguration.VerticalStudsOffset = PlayerPlates.BubbleLift
	end)
	for _, other in Players:GetPlayers() do
		track(other)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(drop)
	-- The trails draining, and a bar folding away once its Hold is up.
	RunService.Heartbeat:Connect(function(dt)
		for _, entry in entries do
			if entry.Trail > entry.Share then
				entry.Trail = math.max(entry.Share, entry.Trail - PlayerPlates.Drain * dt)
			end
			redraw(entry)
		end
	end)
end

return PlayerPlates
