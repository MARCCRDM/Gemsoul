--[[
	A gem raid's critters on screen (Shared.Frontier.Raid; the server's
	KaijuWilds and FrontierServer send these through CombatFx):

	  giggle(position, kind)   a snatcher's evil giggle ("Giggle") or its
	                           cackle ("Cackle", landing a trip, grabbing a
	                           gem): heard where it is (CombatSound), with
	                           "hee hee!" bobbing up over it
	  recovered(from, to, color?)   a snatched gem dropped: it pops out of
	                           its snatcher at `from` and arcs back to whoever
	                           it was taken from at `to`, "GOT IT BACK!"

	Words in the world aren't seen by client/Translate, so they're
	translated here (Shared.Lang).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local CombatSound = require(script.Parent.CombatSound)

local CritterFx = {}

CritterFx.Laughs = {
	Giggle = { Text = "hee hee!", Color = Color3.fromRGB(190, 255, 120), Size = 18 },
	Cackle = { Text = "NYEH HEH HEH!", Color = Color3.fromRGB(215, 120, 255), Size = 22 },
}
CritterFx.Back = { Text = "GOT IT BACK!", Color = Color3.fromRGB(255, 214, 90), Size = 20 }
CritterFx.MaxWords = 6 -- on screen at once (a swarm giggling is one din)
CritterFx.Flight = 0.55 -- seconds a dropped gem takes to fly back

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "CritterFx"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

local function anchorAt(position: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.1
	part.CFrame = CFrame.new(position)
	part.Parent = fxFolder()
	return part
end

local words = 0
-- Words bobbing up and fading at `position`.
function CritterFx.words(position: Vector3, spec): boolean
	if words >= CritterFx.MaxWords then
		return false
	end
	words += 1
	local anchor = anchorAt(position)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(190, 34)
	board.AlwaysOnTop = true
	board.MaxDistance = 90
	board.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = Lang.translate(spec.Text)
	label.TextSize = spec.Size
	label.TextColor3 = spec.Color
	label.TextStrokeColor3 = Color3.fromRGB(30, 10, 40)
	label.TextStrokeTransparency = 0.15
	label.Rotation = math.random(-12, 12)
	label.Parent = board
	TweenService:Create(board, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(math.random() * 2 - 1, 3.2, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.15, function()
		words -= 1
		anchor:Destroy()
	end)
	return true
end

function CritterFx.giggle(position: Vector3, kind: string?)
	if typeof(position) ~= "Vector3" then
		return
	end
	local laugh = CritterFx.Laughs[kind or "Giggle"] or CritterFx.Laughs.Giggle
	CombatSound.play(if kind == "Cackle" then "Cackle" else "Giggle", position)
	CritterFx.words(position, laugh)
end

function CritterFx.recovered(from: Vector3, to: Vector3, color: Color3?)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	local stone = anchorAt(from)
	stone.Transparency = 0
	stone.Material = Enum.Material.Neon
	stone.Color = if typeof(color) == "Color3" then color else Color3.fromRGB(120, 230, 255)
	stone.Size = Vector3.one * 0.9
	CombatSound.play("Combo", from)
	local start = from + Vector3.new(0, 2, 0)
	local finish = to + Vector3.new(0, 1.5, 0)
	local began = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local p = math.clamp((os.clock() - began) / CritterFx.Flight, 0, 1)
		local at = start:Lerp(finish, p) + Vector3.new(0, math.sin(p * math.pi) * 6, 0)
		stone.CFrame = CFrame.new(at) * CFrame.Angles(p * 9, p * 6, math.rad(45))
		if p >= 1 then
			connection:Disconnect()
			stone:Destroy()
			CombatSound.play("Heal", to)
			CritterFx.words(to + Vector3.new(0, 2.5, 0), CritterFx.Back)
		end
	end)
end

return CritterFx
