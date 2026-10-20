--[[
	Levelling up, and a kaiju team called back or deployed, on screen (the
	server sends these through CombatFx; everyone near sees them):

	  play(target, level, kind, color?, name?)   a level up on `target` (a
	                           player's character or a kaiju's model; `kind`
	                           "Miner" or "Kaiju"): a column of light out of
	                           the ground, two rings running out over it,
	                           sparks spiralling up round the body, a flash,
	                           and the new level on a plate over the head. A
	                           miner's is amber; a kaiju's its element's
	                           colour, at its size.
	  banner(title, level, lines)   yours: a plate at the top of the screen,
	                           LEVEL UP and the number, and what it brought
	  callBack(at, radius, color, to)   a kaiju called back: it folds into a
	                           point of light, and a shard of it flies to you
	  deploy(at, radius, color, from)   deployed: a shard flies out of you,
	                           and the kaiju opens out of it

	Built from plain parts, posed every frame from one clock (pose(effect,
	t)), so nothing hangs on a tween; gone after Seconds. Words in the
	world aren't seen by client/Translate, so the plate's are translated
	here (Shared.Lang).

	Pure, and tested without Roblox (tests/levelup_fx_cases.luau):
	  LevelUpFx.build(feet, height, color, title, level) -> Effect   at rest
	  LevelUpFx.pose(effect, t)    where everything is t seconds in
	  LevelUpFx.step(dt)           moves every effect on (and clears the done)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(ReplicatedStorage.Shared.Lang)

local LevelUpFx = {}

LevelUpFx.Seconds = 2.6 -- a level up, start to gone
LevelUpFx.Motes = 14
LevelUpFx.Miner = Color3.fromRGB(255, 202, 91) -- a miner's: the game's amber
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(14, 12, 6)

local function ease(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

local folder: Folder? = nil
local function fxFolder(): Instance
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "LevelUpFx"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

local function piece(parent: Instance, size: Vector3, color: Color3, shape: string?): BasePart
	local p = Instance.new("Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = 1
	p.Parent = parent
	return p
end

export type Effect = {
	Model: Model,
	Feet: CFrame,
	Height: number,
	Scale: number,
	Column: BasePart,
	Core: BasePart,
	Rings: { BasePart },
	Motes: { BasePart },
	Light: PointLight,
	Plate: BillboardGui,
	Group: CanvasGroup?,
	Pop: UIScale,
	T: number,
	Follow: BasePart?,
	Below: number, -- from the root followed down to the feet
	Anchor: BasePart, -- the light and the plate hang off it
}

local live: { Effect } = {}

-- A level up's parts at rest, its feet at `feet`, for a body `height` studs
-- tall: the column, its white core, two ground rings, the sparks, a light,
-- and the plate (`title` over `level`).
function LevelUpFx.build(feet: CFrame, height: number, color: Color3, title: string, level: number): Effect
	local model = Instance.new("Model")
	model.Name = "LevelUp"
	local s = math.max(0.3, height / 5)
	local column = piece(model, Vector3.new(1, 2.4 * s, 2.4 * s), color, "Cylinder")
	column.Name = "Column"
	local core = piece(model, Vector3.new(1, 0.8 * s, 0.8 * s), WHITE, "Cylinder")
	core.Name = "Core"
	local rings = {}
	for i = 1, 2 do
		local ring = piece(model, Vector3.new(0.08, 1, 1), if i == 1 then color else WHITE, "Cylinder")
		ring.Name = "Ring"
		table.insert(rings, ring)
	end
	local motes = {}
	for _ = 1, LevelUpFx.Motes do
		local mote = piece(model, Vector3.one * 0.22 * s, color:Lerp(WHITE, 0.45), "Ball")
		mote.Name = "Mote"
		table.insert(motes, mote)
	end
	local anchor = piece(model, Vector3.one * 0.1, color)
	anchor.Name = "Anchor"
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18 * s
	light.Brightness = 0
	light.Shadows = false
	light.Parent = anchor
	-- The plate over the head: the title small in the colour, the number
	-- large in white, on a dark band with a rule of the colour over it.
	local plate = Instance.new("BillboardGui")
	plate.Name = "Plate"
	plate.Size = UDim2.fromOffset(170, 62)
	plate.StudsOffset = Vector3.new(0, height + 1.6, 0)
	plate.AlwaysOnTop = true
	plate.MaxDistance = 140
	plate.LightInfluence = 0
	plate.Parent = anchor
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = plate
	local pop = Instance.new("UIScale")
	pop.Scale = 0.6
	pop.Parent = group
	local band = Instance.new("Frame")
	band.BackgroundColor3 = INK
	band.BackgroundTransparency = 0.3
	band.BorderSizePixel = 0
	band.Position = UDim2.fromOffset(15, 4)
	band.Size = UDim2.new(1, -30, 1, -8)
	band.Parent = group
	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = color
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.Parent = band
	local top = Instance.new("TextLabel")
	top.Name = "Title"
	top.BackgroundTransparency = 1
	top.Position = UDim2.fromOffset(0, 5)
	top.Size = UDim2.new(1, 0, 0, 14)
	top.Font = Enum.Font.GothamBold
	top.Text = Lang.translate(title)
	top.TextSize = 12
	top.TextColor3 = color
	top.Parent = band
	local number = Instance.new("TextLabel")
	number.Name = "Level"
	number.BackgroundTransparency = 1
	number.Position = UDim2.fromOffset(0, 19)
	number.Size = UDim2.new(1, 0, 0, 30)
	number.Font = Enum.Font.GothamBlack
	number.Text = Lang.translate(string.format("LEVEL %d", level))
	number.TextSize = 26
	number.TextColor3 = WHITE
	number.Parent = band
	return {
		Model = model,
		Feet = feet,
		Height = height,
		Scale = s,
		Column = column,
		Core = core,
		Rings = rings,
		Motes = motes,
		Light = light,
		Plate = plate,
		Group = group,
		Pop = pop,
		T = 0,
		Follow = nil,
		Below = 0,
		Anchor = anchor,
	}
end

-- Everything as it is `t` seconds in (from the feet up; nothing after
-- Seconds).
function LevelUpFx.pose(effect: Effect, t: number)
	local feet, s, height = effect.Feet, effect.Scale, effect.Height
	local up = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's length is X: stood up
	-- The column: shoots up in a third of a second, widens, fades by 1.1s.
	local rise = ease(t / 0.32)
	local tall = math.max(0.05, (height * 2.6 + 6 * s) * rise)
	local fade = math.clamp((t - 0.25) / 0.85, 0, 1)
	local wide = 1 + 0.5 * ease(t / 0.9)
	effect.Column.Size = Vector3.new(tall, 2.4 * s * wide, 2.4 * s * wide)
	effect.Column.CFrame = feet * CFrame.new(0, tall / 2, 0) * up
	effect.Column.Transparency = 0.35 + 0.65 * fade
	effect.Core.Size = Vector3.new(tall, 0.8 * s * (1 - 0.6 * fade), 0.8 * s * (1 - 0.6 * fade))
	effect.Core.CFrame = feet * CFrame.new(0, tall / 2, 0) * up
	effect.Core.Transparency = 0.1 + 0.9 * math.clamp((t - 0.15) / 0.6, 0, 1)
	-- The rings: run out over the ground, the second a moment later.
	for i, ring in effect.Rings do
		local k = math.clamp((t - (i - 1) * 0.16) / 0.75, 0, 1)
		local r = (0.8 + 6.5 * ease(k)) * s
		ring.Size = Vector3.new(0.08, r * 2, r * 2)
		ring.CFrame = feet * CFrame.new(0, 0.06 + i * 0.02, 0) * up
		ring.Transparency = if k <= 0 or k >= 1 then 1 else 0.15 + 0.85 * k
	end
	-- The sparks: spiral up round the body, closing in, then fade.
	local n = #effect.Motes
	for i, mote in effect.Motes do
		local delay = (i - 1) / n * 0.35
		local k = math.clamp((t - delay) / 1.5, 0, 1)
		local angle = (i / n) * math.pi * 2 + k * 7
		local r = (2.4 - 1.5 * k) * s
		local y = (0.2 + k * (height + 2.2 * s))
		mote.CFrame = feet * CFrame.new(math.cos(angle) * r, y, math.sin(angle) * r)
		mote.Transparency = if k <= 0 or k >= 1 then 1 else 0.1 + 0.9 * math.clamp((k - 0.6) / 0.4, 0, 1)
	end
	-- The flash.
	effect.Anchor.CFrame = feet
	effect.Light.Brightness = 7 * math.clamp(1 - t / 0.9, 0, 1)
	-- The plate: pops in, rises a little, fades at the end.
	effect.Pop.Scale = if t < 0.12 then 0.6 + 4.6 * t elseif t < 0.3 then 1.15 - (t - 0.12) / 0.18 * 0.15 else 1
	effect.Plate.StudsOffset = Vector3.new(0, height + 1.6 + 0.5 * ease(t / LevelUpFx.Seconds), 0)
	if effect.Group then
		effect.Group.GroupTransparency = math.clamp((t - (LevelUpFx.Seconds - 0.6)) / 0.6, 0, 1)
	end
end

-- Moves every level up on `dt` (following its body), and clears the done.
function LevelUpFx.step(dt: number)
	for i = #live, 1, -1 do
		local effect = live[i]
		effect.T += dt
		if effect.T >= LevelUpFx.Seconds or not effect.Model.Parent then
			effect.Model:Destroy()
			table.remove(live, i)
		else
			local follow = effect.Follow
			if follow and follow.Parent then
				effect.Feet = CFrame.new(follow.CFrame.Position - Vector3.new(0, effect.Below, 0))
			end
			LevelUpFx.pose(effect, effect.T)
		end
	end
end

local stepping = false
local function run()
	if stepping then
		return
	end
	stepping = true
	local RunService = game:GetService("RunService")
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		LevelUpFx.step(dt)
		if #live == 0 then
			connection:Disconnect()
			stepping = false
		end
	end)
end

-- A body's root, its feet and its height.
local function measure(target: Instance): (BasePart?, Vector3?, number)
	local model = if target:IsA("Model") then target else target:FindFirstAncestorOfClass("Model")
	local root = model
		and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart"))
	if not model or not root or not root:IsA("BasePart") then
		return nil, nil, 5
	end
	local ok, box, size = pcall(function()
		return model:GetBoundingBox()
	end)
	if not ok or typeof(box) ~= "CFrame" then
		return root, root.Position - Vector3.new(0, 3, 0), 5
	end
	local bottom = box.Position.Y - size.Y / 2
	return root, Vector3.new(root.Position.X, bottom, root.Position.Z), math.max(1, size.Y)
end

local function sound(name: string, position: Vector3?)
	pcall(function()
		require(script.Parent.CombatSound).play(name, position)
	end)
end

-- A level up on `target` (a character or a kaiju's model).
function LevelUpFx.play(target: Instance?, level: number, kind: string?, color: Color3?, name: string?)
	if not target or typeof(target) ~= "Instance" or not target.Parent then
		return
	end
	local root, feet, height = measure(target)
	if not root or not feet then
		return
	end
	local kaiju = kind == "Kaiju"
	local effect = LevelUpFx.build(
		CFrame.new(feet),
		height,
		color or LevelUpFx.Miner,
		if kaiju and name then string.upper(name) else "LEVEL UP",
		level
	)
	effect.Follow = root
	effect.Below = root.Position.Y - feet.Y
	LevelUpFx.pose(effect, 0)
	effect.Model.Parent = fxFolder()
	table.insert(live, effect)
	sound(if kaiju then "KaijuLevelUp" else "LevelUp", root.Position)
	run()
end

-- Yours: LEVEL UP at the top of the screen, the number, and what it
-- brought (a line or two). One at a time; the next waits its turn.
local queue: { { Title: string, Level: number, Lines: { string }, Color: Color3 } } = {}
local showing = false
function LevelUpFx.banner(title: string, level: number, lines: { string }?, color: Color3?)
	table.insert(queue, { Title = title, Level = level, Lines = lines or {}, Color = color or LevelUpFx.Miner })
	if showing then
		return
	end
	showing = true
	task.spawn(function()
		local Players = game:GetService("Players")
		local TweenService = game:GetService("TweenService")
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		while #queue > 0 do
			local entry = table.remove(queue, 1) :: any
			local gui = Instance.new("ScreenGui")
			gui.Name = "LevelUpBanner"
			gui.DisplayOrder = 40
			gui.IgnoreGuiInset = false
			gui.ResetOnSpawn = false
			gui.Parent = playerGui
			local short = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y < 540
			local w, h = if short then 300 else 380, if short then 70 else 88
			local group = Instance.new("CanvasGroup")
			group.AnchorPoint = Vector2.new(0.5, 0)
			group.Position = UDim2.new(0.5, 0, 0, if short then 8 else 70)
			group.Size = UDim2.fromOffset(w, h)
			group.BackgroundColor3 = Color3.fromRGB(11, 13, 20)
			group.BackgroundTransparency = 0.12
			group.GroupTransparency = 1
			group.BorderSizePixel = 0
			group.Parent = gui
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(70, 80, 96)
			stroke.Thickness = 1
			stroke.Parent = group
			local rule = Instance.new("Frame")
			rule.BackgroundColor3 = entry.Color
			rule.BorderSizePixel = 0
			rule.AnchorPoint = Vector2.new(0.5, 0)
			rule.Position = UDim2.fromScale(0.5, 0)
			rule.Size = UDim2.new(0, 0, 0, 2)
			rule.Parent = group
			local function line(text: string, y: number, size: number, color: Color3, font: Enum.Font)
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Position = UDim2.fromOffset(0, y)
				label.Size = UDim2.new(1, 0, 0, size + 4)
				label.Font = font
				label.Text = text
				label.TextSize = size
				label.TextColor3 = color
				label.Parent = group
				return label
			end
			line(entry.Title, if short then 6 else 9, if short then 11 else 12, entry.Color, Enum.Font.GothamBold)
			line(
				string.format("LEVEL %d", entry.Level),
				if short then 20 else 25,
				if short then 24 else 30,
				WHITE,
				Enum.Font.GothamBlack
			)
			if entry.Lines[1] then
				line(
					entry.Lines[1],
					if short then 48 else 62,
					if short then 10 else 12,
					Color3.fromRGB(177, 193, 216),
					Enum.Font.GothamMedium
				)
			end
			TweenService:Create(group, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
			TweenService:Create(rule, TweenInfo.new(0.45, Enum.EasingStyle.Quart), { Size = UDim2.new(1, 0, 0, 2) })
				:Play()
			task.wait(2.6)
			TweenService:Create(group, TweenInfo.new(0.4), { GroupTransparency = 1 }):Play()
			task.wait(0.45)
			gui:Destroy()
		end
		showing = false
	end)
end

-- A shard of light from `from` to `to` (a kaiju into its Gemsoul and back).
local function shard(from: Vector3, to: Vector3, color: Color3, seconds: number)
	local TweenService = game:GetService("TweenService")
	local gem = piece(fxFolder(), Vector3.new(0.45, 0.8, 0.45), color:Lerp(WHITE, 0.3))
	gem.Transparency = 0.05
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = color, 8, 2, false
	light.Parent = gem
	local t0 = os.clock()
	local RunService = game:GetService("RunService")
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local k = math.clamp((os.clock() - t0) / seconds, 0, 1)
		local lift = math.sin(k * math.pi) * 3
		gem.CFrame = CFrame.new(from:Lerp(to, ease(k)) + Vector3.new(0, lift, 0))
			* CFrame.Angles(0, k * 12, math.rad(45))
		if k >= 1 then
			connection:Disconnect()
			TweenService:Create(gem, TweenInfo.new(0.15), { Transparency = 1, Size = Vector3.one * 0.1 }):Play()
			task.delay(0.2, function()
				gem:Destroy()
			end)
		end
	end)
end

-- A ball of light at `at` from one size to another, fading.
local function burst(at: Vector3, from: number, to: number, color: Color3, seconds: number)
	local TweenService = game:GetService("TweenService")
	local ball = piece(fxFolder(), Vector3.one * from, color, "Ball")
	ball.CFrame = CFrame.new(at)
	ball.Transparency = 0.25
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = color, math.max(from, to) * 3, 3, false
	light.Parent = ball
	TweenService:Create(ball, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * to,
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(seconds), { Brightness = 0 }):Play()
	task.delay(seconds + 0.1, function()
		ball:Destroy()
	end)
end

-- A kaiju called back at `at` (`radius` its size): it folds into a point,
-- and a shard of it flies to its owner at `to`.
function LevelUpFx.callBack(at: Vector3, radius: number?, color: Color3?, to: Vector3?)
	local tint = color or LevelUpFx.Miner
	local r = math.max(1, tonumber(radius) or 3)
	burst(at, r * 1.2, 0.2, tint, 0.3)
	sound("CallBack", at)
	if typeof(to) == "Vector3" then
		task.delay(0.22, function()
			shard(at, to, tint, 0.45)
		end)
	end
end

-- A kaiju deployed at `at`: a shard flies to it from its owner at `from`,
-- and it opens out of the light.
function LevelUpFx.deploy(at: Vector3, radius: number?, color: Color3?, from: Vector3?)
	local tint = color or LevelUpFx.Miner
	local r = math.max(1, tonumber(radius) or 3)
	local wait = 0
	if typeof(from) == "Vector3" then
		shard(from, at, tint, 0.35)
		wait = 0.33
	end
	task.delay(wait, function()
		burst(at, 0.3, r * 1.6, tint, 0.45)
		sound("Deploy", at)
	end)
end

-- What the server sends (through CombatFx) ------------------------------------------------

local function elementColor(element: any): Color3?
	if type(element) ~= "string" then
		return nil
	end
	return require(ReplicatedStorage.Shared.GemConfig).ElementColors[element]
end

-- "LevelUp", target, level, kind, element?, name?, detail?: the light on
-- whoever levelled; yours (or your kaiju's) with its banner too.
function LevelUpFx.onLevelUp(target: any, level: any, kind: any, element: any, name: any, detail: any)
	if typeof(target) ~= "Instance" or type(level) ~= "number" then
		return
	end
	local color = elementColor(element)
	LevelUpFx.play(target, level, kind, color, if type(name) == "string" then name else nil)
	local me = game:GetService("Players").LocalPlayer
	local line = if type(detail) == "string" then { detail } else nil
	if kind == "Kaiju" then
		if target:GetAttribute("KaijuOwner") == me.UserId then
			LevelUpFx.banner(string.upper(if type(name) == "string" then name else "YOUR KAIJU"), level, line, color)
		end
	elseif target == me or target == me.Character then
		LevelUpFx.banner("LEVEL UP", level, line)
	end
end

-- "CallBack", at, radius, element, to: one of a team called back.
function LevelUpFx.onCallBack(at: any, radius: any, element: any, to: any)
	if typeof(at) == "Vector3" then
		LevelUpFx.callBack(at, radius, elementColor(element), if typeof(to) == "Vector3" then to else nil)
	end
end

-- "Deploy", at, radius, element, from: one of a team deployed.
function LevelUpFx.onDeploy(at: any, radius: any, element: any, from: any)
	if typeof(at) == "Vector3" then
		LevelUpFx.deploy(at, radius, elementColor(element), if typeof(from) == "Vector3" then from else nil)
	end
end

LevelUpFx._live = live
return LevelUpFx
