--[[
	The team's HYPERBEAM, seen (Server.KaijuBeamServer sends it: CombatFx
	"KaijuBeam"; rules and timing: Shared.KaijuBeam). Everyone near sees the
	show; whoever called it gets the cinematic too.

	  Gather    a rune circle spreads under you and a ring lights where each
	            kaiju will stand; one after another they leap there
	            (KaijuBeam.leap: a fighter flips, the support spins), a
	            streak of its colour behind it, and slam down: a shockwave,
	            cracks, a pillar of light, its name called out on your
	            screen. Once they're all down they roar together
	            (CreatureAnimation: KaijuMood "Roar"): pillars of their
	            colours, lines of light joining them to each other and you.
	  Charge    each one's aura flares (a shimmering shell, sparks rising,
	            motes spiralling into its mouth) and its stream pours into
	            the focus in front of you; the orb there swells, crackles
	            with lightning and pulls rings of light into itself.
	  Fire      the beam: a white-hot core in a sleeve of your team's
	            colours, each colour's ribbon twisting round it, a star of
	            light at the focus and a blaze at the far end, rings racing
	            down it, rock thrown up along it, a shockwave, a scorched
	            trail; screens shake near it.
	  Recover   it all fades.

	  The cinematic (yours): letterbox bars and a hotter grade, your kaiju's
	  names called as each lands, HYPERBEAM! as it fires, a white flash;
	  the camera wide and low as they leap in, a low hero shot of the
	  line-up as they roar, round the focus as it charges, side-on as the
	  beam leaves it and then from over your shoulder, and back to you.

	  KaijuBeamFx.start()            once, from Lobby.client
	  KaijuBeamFx.shot(t, origin, forward, focus) -> CFrame, fov   the
	                                 cinematic's camera at `t` (pure: tests)
	  KaijuBeamFx.flight(t, from, to, takeoff, land, height, forward, flip)
	                                 -> CFrame?   a kaiju's pivot in its leap
	                                 at `t` (nil before it's off; pure: tests)
]]
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local KaijuBeam = require(ReplicatedStorage.Shared.KaijuBeam)
local CombatFx = require(script.Parent.CombatFx)
local CombatSound = require(script.Parent.CombatSound)
local IronUi = require(script.Parent.IronUi)
local KaijuMotionFx = require(script.Parent.KaijuMotionFx)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local new = IronUi.new

local KaijuBeamFx = {}

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 226, 120)
local ROCK = Color3.fromRGB(70, 62, 58)
local SCORCH = Color3.fromRGB(30, 20, 18)
local UP = Vector3.new(0, 1, 0)
local BIND = "KaijuHyperbeamCam"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder lying flat: a disc on the ground)

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "KaijuBeamFx"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

local function part(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Neon
	if shape then
		p.Shape = shape
	end
	p.Parent = fxFolder()
	return p
end

local function tween(instance: Instance, seconds: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- A part that flares and is gone in `seconds`.
local function flare(p: BasePart, seconds: number, goal)
	goal.Transparency = goal.Transparency or 1
	tween(p, seconds, goal)
	Debris:AddItem(p, seconds + 0.05)
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The cinematic's camera `t` seconds in: wide and low from out in front as
-- they leap in (craning up as they land), a low hero shot of the line-up
-- as they roar, round the focus as it charges (closing in), side-on as the
-- beam leaves the focus, then over your shoulder down it.
function KaijuBeamFx.shot(t: number, origin: Vector3, forward: Vector3, focus: Vector3): (CFrame, number)
	local at = KaijuBeam.timeline()
	local roar = KaijuBeam.Leap.Roar
	local right = forward:Cross(UP)
	if t < roar then
		local k = smooth(t / roar)
		local eye = origin + forward * (22 - 4 * k) + right * (10 - 3 * k) + UP * (2 + 3 * k)
		return CFrame.lookAt(eye, origin + UP * (2 + k)), 68 - 6 * k
	end
	if t < at.Charge then
		local k = smooth((t - roar) / math.max(at.Charge - roar, 0.05))
		local eye = origin + forward * (14 - 2.5 * k) + right * 0.6 + UP * 0.8
		return CFrame.lookAt(eye, origin + UP * (4.5 + 0.5 * k)), 56 - 4 * k
	end
	if t < at.Fire then
		local k = (t - at.Charge) / (at.Fire - at.Charge)
		local angle = math.rad(70 - 100 * k)
		local around = right * math.cos(angle) + forward * math.sin(angle)
		local eye = focus + around * (13 - 4 * k) + UP * (2.5 + k)
		return CFrame.lookAt(eye, focus), 60 - 10 * k
	end
	local s = t - at.Fire
	if s < 0.4 then
		local k = s / 0.4
		local eye = focus + forward * (12 + 4 * k) + right * 26 + UP * 5
		return CFrame.lookAt(eye, focus + forward * (18 + 4 * k)), 74
	end
	local k = math.clamp(s / (at.Stop - at.Fire), 0, 1)
	local eye = origin - forward * (12 + 4 * k) + UP * (6 + k) + right * 3.5
	return CFrame.lookAt(eye, origin + forward * 40 + UP * 2), 82
end

-- A kaiju's pivot `t` seconds in, leaping from `from` to `to` (pivots),
-- off at `takeoff` and down at `land`, `height` studs up over the line
-- between them, turning to face `forward` on the way; `flip`: "Flip" (a
-- fighter's front flip), "Spin" (the support's turn on the spot), else
-- none. Nil before it's off; `to` once it's down.
function KaijuBeamFx.flight(
	t: number,
	from: CFrame,
	to: CFrame,
	takeoff: number,
	land: number,
	height: number,
	forward: Vector3,
	flip: string?
): CFrame?
	if t < takeoff then
		return nil
	end
	if t >= land then
		return to
	end
	local p = (t - takeoff) / math.max(land - takeoff, 0.05)
	local along, up = KaijuBeam.arc(p, height)
	local position = from.Position:Lerp(to.Position, along) + UP * up
	local look = from.LookVector:Lerp(forward, along)
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 0.05 then
		look = forward
	end
	local frame = CFrame.lookAt(position, position + look.Unit)
	local turn = smooth(p) * math.pi * 2
	if flip == "Flip" then
		frame *= CFrame.Angles(-turn, 0, 0)
	elseif flip == "Spin" then
		frame *= CFrame.Angles(0, turn, 0)
	end
	return frame
end

-- Where a kaiju's stream leaves it: its head's height, a little in front.
local function mouthOf(model: Model, toward: Vector3): Vector3
	local pivot = model:GetPivot()
	local size = model:GetExtentsSize()
	return pivot.Position + UP * size.Y * 0.2 + toward * size.Z * 0.35
end

-- What its name is called out as.
local function nameOf(model: Model): string
	local name = model:GetAttribute("KaijuName")
	if type(name) ~= "string" or name == "" then
		name = model:GetAttribute("KaijuSpecies")
	end
	return string.upper(if type(name) == "string" and name ~= "" then name else model.Name)
end

-- A ring on the ground: `count` short bars round `radius`, turned `spin`.
local function ringBars(count: number, color: Color3, thickness: number)
	local bars = {}
	for i = 1, count do
		local bar = part(Vector3.new(thickness, 0.08, 1), CFrame.new(), color)
		bar.Transparency = 1
		bars[i] = bar
	end
	return bars
end
local function placeRing(bars, center: Vector3, radius: number, spin: number, transparency: number)
	local count = #bars
	local length = 2 * math.pi * radius / count * 0.62
	for i, bar in bars do
		local angle = spin + (i - 1) / count * math.pi * 2
		local at = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		bar.Size = Vector3.new(bar.Size.X, 0.08, length)
		bar.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(angle), 0, math.cos(angle)))
		bar.Transparency = transparency
	end
end

-- The cinematic's overlay: letterbox bars, the roll call, the title and a flash.
local function overlay(calls: { { Name: string, Color: Color3 } }, palette: { Color3 })
	local gui = UiKit.gui("KaijuBeamCinematic", 40)
	local top = new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 2,
	}, gui)
	local bottom = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 2,
	}, gui)
	local flash = new("Frame", {
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
	}, gui)
	local title = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.78),
		Size = UDim2.fromScale(0.9, 0.12),
		BackgroundTransparency = 1,
		Text = "HYPERBEAM!",
		Font = IronUi.Heading,
		TextScaled = true,
		TextColor3 = WHITE,
		TextTransparency = 1,
		ZIndex = 4,
	}, gui)
	new("UITextSizeConstraint", { MaxTextSize = 72 }, title)
	local stroke = new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, Transparency = 1 }, title)
	local points = {}
	for i, color in palette do
		table.insert(points, ColorSequenceKeypoint.new(if #palette == 1 then 0 else (i - 1) / (#palette - 1), color))
	end
	if #points == 1 then
		table.insert(points, ColorSequenceKeypoint.new(1, palette[1]:Lerp(WHITE, 0.5)))
	end
	local gradient = new("UIGradient", { Color = ColorSequence.new(points) }, title)
	local scale = new("UIScale", { Scale = 0.6 }, title)
	-- The roll call: each name in its colour, popping in as it lands.
	local row = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromScale(0.94, 0.05),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, gui)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 18),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local names = {}
	for i, call in calls do
		local label = new("TextLabel", {
			LayoutOrder = i,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			Text = call.Name,
			Font = IronUi.Heading,
			TextScaled = true,
			TextColor3 = call.Color:Lerp(WHITE, 0.25),
			TextTransparency = 1,
			ZIndex = 4,
		}, row)
		new("UITextSizeConstraint", { MaxTextSize = 24 }, label)
		local outline = new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 1 }, label)
		local pop = new("UIScale", { Scale = 1 }, label)
		names[i] = { Label = label, Stroke = outline, Scale = pop, Color = label.TextColor3 }
	end
	return {
		Gui = gui,
		Show = function(bar: number)
			local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(top, info, { Size = UDim2.new(1, 0, bar, 0) }):Play()
			TweenService:Create(bottom, info, { Size = UDim2.new(1, 0, bar, 0) }):Play()
		end,
		Call = function(i: number)
			local name = names[i]
			if not name then
				return
			end
			name.Label.TextTransparency, name.Stroke.Transparency = 0, 0
			name.Scale.Scale = 1.9
			tween(name.Scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		end,
		Rally = function()
			-- They roar: every name flares gold and settles back.
			for _, name in names do
				name.Label.TextColor3 = GOLD
				name.Scale.Scale = 1.25
				tween(name.Label, 0.6, { TextColor3 = name.Color })
				tween(name.Scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end,
		Title = function()
			title.TextTransparency, stroke.Transparency = 0, 0
			scale.Scale = 1.6
			tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		end,
		Flash = function(strength: number)
			flash.BackgroundTransparency = 1 - strength
			tween(flash, 0.35, { BackgroundTransparency = 1 })
		end,
		Spin = function(now: number)
			gradient.Offset = Vector2.new(math.sin(now * 3) * 0.3, 0)
		end,
		Hide = function()
			local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(top, info, { Size = UDim2.new(1, 0, 0, 0) }):Play()
			TweenService:Create(bottom, info, { Size = UDim2.new(1, 0, 0, 0) }):Play()
			TweenService:Create(title, info, { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, info, { Transparency = 1 }):Play()
			for _, name in names do
				TweenService:Create(name.Label, info, { TextTransparency = 1 }):Play()
				TweenService:Create(name.Stroke, info, { Transparency = 1 }):Play()
			end
			task.delay(0.4, function()
				gui:Destroy()
			end)
		end,
	}
end

-- The camera, held for the cinematic and handed back after.
local held = nil -- { Camera, Type, Subject, Fov, From }
local function holdCamera()
	local camera = workspace.CurrentCamera
	if not camera or held then
		return
	end
	held = {
		Camera = camera,
		Type = camera.CameraType,
		Subject = camera.CameraSubject,
		Fov = camera.FieldOfView,
		From = camera.CFrame,
	}
end
local function releaseCamera()
	RunService:UnbindFromRenderStep(BIND)
	local was = held
	held = nil
	if not was then
		return
	end
	local camera = was.Camera
	if camera and camera.Parent then
		camera.CameraType = if was.Type == Enum.CameraType.Scriptable then Enum.CameraType.Custom else was.Type
		camera.FieldOfView = was.Fov
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject = if was.Subject and was.Subject.Parent then was.Subject else humanoid
	end
end

local function play(data)
	if type(data) ~= "table" or typeof(data.Origin) ~= "Vector3" or typeof(data.Forward) ~= "Vector3" then
		return
	end
	local origin, forward, focus = data.Origin, data.Forward, data.Focus or data.Origin
	local start = tonumber(data.Start) or workspace:GetServerTimeNow()
	local models, elements, places = data.Models or {}, data.Elements or {}, data.Places or {}
	local froms, ends, leaps = data.Froms or {}, data.Ends or {}, data.Leaps or {}
	local mine = data.Owner == player
	local camera = workspace.CurrentCamera
	-- Too far off to see: nothing (the server's done the work).
	if not mine and camera and (camera.CFrame.Position - origin).Magnitude > 260 then
		return
	end
	local at = KaijuBeam.timeline()
	local b = KaijuBeam.Beam
	local leapRules = KaijuBeam.Leap
	local palette = {}
	for i, element in elements do
		palette[i] = GemConfig.ElementColors[element] or GOLD
	end
	if #palette == 0 then
		palette = { GOLD }
	end
	local right = forward:Cross(UP)
	local made = {}
	local function keep(instance)
		table.insert(made, instance)
		return instance
	end
	local ground = origin - UP * 2.8

	-- Your team, each with its leap: from where it stands to its place.
	local units, calls = {}, {}
	for i, model in models do
		if typeof(model) ~= "Instance" or not model:IsA("Model") or not model.Parent then
			continue
		end
		local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local from = if typeof(froms[i]) == "CFrame" then froms[i] else model:GetPivot()
		local to = ends[i]
		if typeof(to) ~= "CFrame" then
			local place = places[i]
			if typeof(place) ~= "Vector3" then
				continue
			end
			to = CFrame.lookAt(place + UP * 2, place + UP * 2 + forward)
		end
		local lift = if humanoid and root then humanoid.HipHeight + root.Size.Y / 2 else 2
		local takeoff = tonumber(leaps[i]) or (KaijuBeam.leap(#units + 1))
		local unit = {
			Index = i,
			Model = model,
			Root = root,
			Humanoid = humanoid,
			Element = elements[i],
			Color = palette[i] or GOLD,
			From = from,
			To = to,
			Feet = to.Position - UP * lift, -- (where it stands, on the ground)
			Takeoff = takeoff,
			Land = takeoff + leapRules.Air,
			Height = KaijuBeam.leapHeight((to.Position - from.Position).Magnitude),
			Flip = if (tonumber(model:GetAttribute("KaijuHover")) or 0) > 0 then "Spin" else "Flip",
			Size = model:GetExtentsSize(),
			TrailAt = 0,
		}
		table.insert(units, unit)
		table.insert(calls, { Name = nameOf(model), Color = unit.Color })
	end

	-- The rune circle under you: a disc spreading, two rings of bars
	-- turning opposite ways, in your team's colours.
	local sigil = keep(part(Vector3.new(0.1, 2, 2), CFrame.new(ground) * FLAT, GOLD, Enum.PartType.Cylinder))
	sigil.Transparency = 0.55
	tween(sigil, 0.9, { Size = Vector3.new(0.1, 20, 20), Transparency = 0.88 }, Enum.EasingStyle.Quint)
	local inner = ringBars(18, palette[1], 0.35)
	local outer = ringBars(28, palette[#palette], 0.3)
	for _, bar in inner do
		keep(bar)
	end
	for _, bar in outer do
		keep(bar)
	end
	-- Each place: a ring lit where it'll land.
	for _, unit in units do
		local mark = keep(part(Vector3.new(0.12, 1, 1), CFrame.new(unit.Feet + UP * 0.06) * FLAT, unit.Color, Enum.PartType.Cylinder))
		mark.Transparency = 0.5
		tween(mark, 0.5, { Size = Vector3.new(0.12, 4.5, 4.5) }, Enum.EasingStyle.Back)
		unit.Mark = mark
	end

	-- The focus: its swirling shell, its core, rings and lightning.
	local shell = keep(part(Vector3.one * 0.5, CFrame.new(focus), palette[1], Enum.PartType.Ball, Enum.Material.ForceField))
	shell.Transparency = 0.35
	local core = keep(part(Vector3.one * 0.3, CFrame.new(focus), WHITE, Enum.PartType.Ball))
	core.Transparency = 1
	local light = keep(Instance.new("PointLight"))
	light.Color, light.Range, light.Brightness, light.Shadows = palette[1], 22, 0, false
	light.Parent = core
	local rings = {}
	for i = 1, 3 do
		local r = keep(part(Vector3.new(0.15, 0.1, 0.1), CFrame.new(focus), palette[(i - 1) % #palette + 1], Enum.PartType.Cylinder))
		r.Transparency = 1
		rings[i] = r
	end
	local bolts = {}
	for i = 1, 12 do
		local seg = keep(part(Vector3.new(0.12, 0.12, 1), CFrame.new(focus), WHITE))
		seg.Transparency = 1
		bolts[i] = seg
	end
	-- The streams: a coloured flow and a white-hot thread from each
	-- kaiju's mouth into the focus.
	local anchor = keep(part(Vector3.one * 0.2, CFrame.new(focus), WHITE))
	anchor.Transparency = 1
	local into = Instance.new("Attachment")
	into.Parent = anchor
	for _, unit in units do
		local from = keep(part(Vector3.one * 0.2, CFrame.new(unit.Feet + UP * 3), WHITE))
		from.Transparency = 1
		local out = Instance.new("Attachment")
		out.Parent = from
		local flow = keep(Instance.new("Beam"))
		flow.Attachment0, flow.Attachment1 = out, into
		flow.Color = ColorSequence.new(unit.Color, unit.Color:Lerp(WHITE, 0.5))
		flow.LightEmission, flow.LightInfluence = 1, 0
		flow.FaceCamera = true
		flow.Segments = 16
		flow.Texture = SPARKLE
		flow.TextureMode = Enum.TextureMode.Wrap
		flow.TextureLength = 2.5
		flow.TextureSpeed = 3
		flow.Width0, flow.Width1 = 0, 0
		flow.Transparency = NumberSequence.new(0, 0.2)
		flow.Parent = from
		local thread = keep(Instance.new("Beam"))
		thread.Attachment0, thread.Attachment1 = out, into
		thread.Color = ColorSequence.new(WHITE)
		thread.LightEmission, thread.LightInfluence = 1, 0
		thread.FaceCamera = true
		thread.Segments = 16
		thread.Width0, thread.Width1 = 0, 0
		thread.Parent = from
		unit.From3 = from
		unit.Flow, unit.Thread = flow, thread
	end
	-- The beam itself: its core and sleeve, each colour's ribbon, rings
	-- racing down it, the star at the focus, the blaze at its end, the scorch.
	local length = b.Length
	local axis = CFrame.lookAt(focus, focus + forward)
	local along = axis * CFrame.new(0, 0, -length / 2) * CFrame.Angles(0, math.rad(90), 0)
	local beamCore = keep(part(Vector3.new(length, 0.1, 0.1), along, WHITE, Enum.PartType.Cylinder))
	beamCore.Transparency = 1
	local sleeve = keep(part(Vector3.new(length, 0.1, 0.1), along, palette[1], Enum.PartType.Cylinder))
	sleeve.Transparency = 1
	local ribbons = {}
	local beads = 16
	for c, color in palette do
		local strand = {}
		for j = 1, beads do
			local bead = keep(part(Vector3.one * 0.6, axis, color:Lerp(WHITE, 0.15), Enum.PartType.Ball))
			bead.Transparency = 1
			strand[j] = bead
		end
		ribbons[c] = strand
	end
	local racers = {}
	for i = 1, 3 do
		local r = keep(part(Vector3.new(0.4, b.Width, b.Width), axis * CFrame.Angles(0, math.rad(90), 0), palette[(i - 1) % #palette + 1], Enum.PartType.Cylinder))
		r.Transparency = 1
		racers[i] = r
	end
	local spikes = {}
	for i = 1, 4 do
		local spike = keep(part(Vector3.new(0.3, 0.3, 1), CFrame.new(focus), WHITE))
		spike.Transparency = 1
		spikes[i] = spike
	end
	local blaze = keep(part(Vector3.one, CFrame.new(focus + forward * length), palette[1], Enum.PartType.Ball))
	blaze.Transparency = 1
	local scorch = keep(part(Vector3.new(b.Width * 0.7, 0.08, 0.1), CFrame.lookAt(ground, ground + forward), SCORCH, nil, Enum.Material.SmoothPlastic))
	scorch.Transparency = 1

	-- Yours: the cinematic.
	local over = nil
	local grade, bloom = nil, nil
	local punchAt = -10 -- (a jolt of the view: the beam firing)
	if mine then
		over = overlay(calls, palette)
		over.Show(0.1)
		holdCamera()
		grade = keep(Instance.new("ColorCorrectionEffect"))
		grade.Name = "KaijuBeamGrade"
		grade.Parent = Lighting
		bloom = keep(Instance.new("BloomEffect"))
		bloom.Name = "KaijuBeamBloom"
		bloom.Intensity, bloom.Size, bloom.Threshold = 0, 32, 0.9
		bloom.Parent = Lighting
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 6, function()
			local cam = workspace.CurrentCamera
			local state = held
			if not cam or not state then
				return
			end
			local t = workspace:GetServerTimeNow() - start
			local view, fov = KaijuBeamFx.shot(t, origin, forward, focus)
			-- The ground trembles as it charges, and jolts as it fires.
			local phase, k = KaijuBeam.phase(t)
			local shake = if phase == "Charge" then 0.05 * k * k else 0
			local jolt = t - punchAt
			if jolt >= 0 and jolt < 0.6 then
				shake += 0.5 * (1 - jolt / 0.6) ^ 2
				fov += 10 * (1 - jolt / 0.6) ^ 2
			end
			if shake > 0 then
				local n = os.clock()
				view *= CFrame.new(math.sin(n * 47) * shake, math.sin(n * 59 + 1) * shake, 0)
					* CFrame.Angles(0, 0, math.sin(n * 37) * shake * 0.04)
			end
			cam.CameraType = Enum.CameraType.Scriptable
			local ease = smooth(t / 0.45)
			if ease < 1 then
				view = state.From:Lerp(view, ease)
				fov = state.Fov + (fov - state.Fov) * ease
			end
			cam.CFrame = view
			cam.FieldOfView = fov
		end)
	end
	CombatSound.play("Cast", origin, { Volume = 1.3, Pitch = 0.7 })

	-- Off: a puff where it leaves the ground.
	local function takeOff(unit)
		if unit.Root and unit.Humanoid then
			KaijuMotionFx.footstep(unit.Model, unit.Root, unit.Humanoid, 0)
		end
		CombatSound.play("Hop", unit.From.Position, { Volume = 0.9 })
	end
	-- Down: a shockwave, cracks, a pillar of light, its name called.
	local function slam(unit, call: number)
		local feet = unit.Feet
		local reach = math.clamp(unit.Size.X * 1.6, 7, 16)
		local wave = part(Vector3.new(0.15, 2, 2), CFrame.new(feet + UP * 0.1) * FLAT, unit.Color, Enum.PartType.Cylinder)
		wave.Transparency = 0.15
		flare(wave, 0.5, { Size = Vector3.new(0.05, reach * 2, reach * 2) })
		local pillar = part(Vector3.new(26, 1.8, 1.8), CFrame.new(feet + UP * 13) * FLAT, unit.Color:Lerp(WHITE, 0.3), Enum.PartType.Cylinder)
		pillar.Transparency = 0.35
		flare(pillar, 0.55, { Size = Vector3.new(34, 0.2, 0.2) })
		for c = 1, 7 do
			local angle = (c / 7 + math.random() * 0.08) * math.pi * 2
			local long = 2.5 + math.random() * reach * 0.35
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local crack = keep(part(
				Vector3.new(0.25, 0.06, long),
				CFrame.lookAt(feet + UP * 0.04 + dir * long / 2, feet + UP * 0.04 + dir * long),
				SCORCH,
				nil,
				Enum.Material.SmoothPlastic
			))
			crack.Transparency = 0.1
			task.delay(1.8, function()
				if crack.Parent then
					tween(crack, 1.2, { Transparency = 1 })
				end
			end)
		end
		if unit.Mark then
			unit.Mark.Transparency = 0.1
			tween(unit.Mark, 0.6, { Transparency = 0.65, Size = Vector3.new(0.12, 5.5, 5.5) })
		end
		CombatFx.burst(feet + UP * 0.4, unit.Color, "Sparks", 1.4)
		CombatFx.burst(feet + UP * 0.2, ROCK, "Smoke", 1.1)
		CombatFx.shakeNear(feet, 0.14, 0.3, 50)
		CombatSound.play("Stomp", feet, { Volume = 1.2, Pitch = 0.85 })
		CombatSound.element("Impact", unit.Element, feet, { Volume = 0.6 })
		if over then
			over.Call(call)
		end
	end
	-- Together: they roar, pillars of their colours, lines of light
	-- joining them to each other and to you.
	local links = {}
	local function rally()
		local hub = keep(part(Vector3.one * 0.2, CFrame.new(ground + UP * 0.15), WHITE))
		hub.Transparency = 1
		local hubAt = Instance.new("Attachment")
		hubAt.Parent = hub
		local spots = {}
		for _, unit in units do
			local spot = keep(part(Vector3.one * 0.2, CFrame.new(unit.Feet + UP * 0.15), WHITE))
			spot.Transparency = 1
			local a = Instance.new("Attachment")
			a.Parent = spot
			table.insert(spots, { Attachment = a, Color = unit.Color })
			local pillar = part(Vector3.new(0.5, 4, 4), CFrame.new(unit.Feet + UP * 0.25) * FLAT, unit.Color, Enum.PartType.Cylinder)
			pillar.Transparency = 0.25
			tween(pillar, 0.3, { Size = Vector3.new(50, 1.3, 1.3), CFrame = CFrame.new(unit.Feet + UP * 25) * FLAT })
			task.delay(0.3, function()
				if pillar.Parent then
					flare(pillar, 0.45, { Size = Vector3.new(50, 0.1, 0.1) })
				end
			end)
			Debris:AddItem(pillar, 1)
		end
		local function link(a0: Attachment, a1: Attachment, c0: Color3, c1: Color3)
			local line = keep(Instance.new("Beam"))
			line.Attachment0, line.Attachment1 = a0, a1
			line.Color = ColorSequence.new(c0, c1)
			line.LightEmission, line.LightInfluence = 1, 0
			line.FaceCamera = false
			line.Width0, line.Width1 = 0.5, 0.5
			line.Transparency = NumberSequence.new(0.05)
			line.Parent = a0.Parent
			table.insert(links, line)
		end
		for i, spot in spots do
			link(hubAt, spot.Attachment, GOLD, spot.Color)
			local nextSpot = spots[i + 1]
			if nextSpot then
				link(spot.Attachment, nextSpot.Attachment, spot.Color, nextSpot.Color)
			end
		end
		sigil.Transparency = 0.6
		tween(sigil, 0.8, { Transparency = 0.88 })
		CombatFx.shakeNear(origin, 0.2, 0.5, 60)
		CombatSound.play("Combo", origin, { Volume = 1.1, Pitch = 0.8 })
		if over then
			over.Rally()
		end
		if grade then
			grade.Brightness = 0.12
			tween(grade, 0.6, { Brightness = 0 })
		end
	end
	-- Charging: each one's aura (a shimmering shell, sparks rising) and
	-- motes spiralling into its mouth.
	local auras = {}
	local function powerUp()
		for _, unit in units do
			local size = unit.Size
			local shellSize = math.max(size.X, size.Y, size.Z) * 1.25
			local aura = keep(part(Vector3.one * shellSize * 0.4, unit.To, unit.Color, Enum.PartType.Ball, Enum.Material.ForceField))
			aura.Transparency = 0.2
			tween(aura, 0.4, { Size = Vector3.one * shellSize }, Enum.EasingStyle.Back)
			local base = keep(part(Vector3.one * 0.2, CFrame.new(unit.Feet), WHITE))
			base.Transparency = 1
			local a = Instance.new("Attachment")
			a.Parent = base
			local sparks = keep(Instance.new("ParticleEmitter"))
			sparks.Texture = SPARKLE
			sparks.Color = ColorSequence.new(unit.Color:Lerp(WHITE, 0.4), unit.Color)
			sparks.LightEmission = 1
			sparks.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.9),
				NumberSequenceKeypoint.new(1, 0),
			})
			sparks.Transparency = NumberSequence.new(0, 1)
			sparks.Lifetime = NumberRange.new(0.5, 0.9)
			sparks.Speed = NumberRange.new(5, 10)
			sparks.SpreadAngle = Vector2.new(25, 25)
			sparks.EmissionDirection = Enum.NormalId.Top
			sparks.Acceleration = Vector3.new(0, 6, 0)
			sparks.Rate = 45
			sparks.Parent = a
			local motes = {}
			for m = 1, 6 do
				local mote = keep(part(Vector3.one * 0.45, CFrame.new(unit.Feet), unit.Color:Lerp(WHITE, 0.3), Enum.PartType.Ball))
				motes[m] = mote
			end
			table.insert(auras, { Unit = unit, Aura = aura, Sparks = sparks, Motes = motes, Shell = shellSize })
		end
		CombatSound.play("Charge", focus, { Volume = 1.2, Pitch = 0.7 })
	end

	local fired, cleared, rallied, powered = false, false, false, false
	local implodeAt, boltsAt, debrisAt = 0, 0, 0
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = workspace:GetServerTimeNow() - start
		local now = os.clock()
		local phase, k = KaijuBeam.phase(t)
		if over then
			over.Spin(now)
		end
		-- The rune circle turns (and brightens as it charges).
		if phase == "Gather" or phase == "Charge" or phase == "Fire" then
			local grow = smooth(t / 0.9)
			local glow = if phase == "Charge" then 0.25 - 0.15 * k else 0.45
			placeRing(inner, ground + UP * 0.07, 5.5 * grow, now * 0.8, glow)
			placeRing(outer, ground + UP * 0.07, 9 * grow, -now * 0.5, glow + 0.1)
		end
		-- The leaps: each carried along its arc, a streak behind it, and
		-- slammed down (held there a beat, till the server's place for it
		-- arrives: the same spot).
		for call, unit in units do
			local frame = KaijuBeamFx.flight(t, unit.From, unit.To, unit.Takeoff, unit.Land, unit.Height, forward, unit.Flip)
			if frame and unit.Model.Parent and t < unit.Land + 0.5 then
				unit.Model:PivotTo(frame)
			end
			if t >= unit.Takeoff and not unit.Off then
				unit.Off = true
				takeOff(unit)
			end
			if frame and t < unit.Land and now >= unit.TrailAt then
				unit.TrailAt = now + 0.03
				local streak = part(Vector3.one * math.clamp(unit.Size.Y * 0.45, 0.8, 3), frame, unit.Color, Enum.PartType.Ball)
				streak.Transparency = 0.35
				flare(streak, 0.35, { Size = Vector3.one * 0.1 })
			end
			if t >= unit.Land and not unit.Down then
				unit.Down = true
				slam(unit, call)
			end
		end
		if t >= leapRules.Roar and not rallied then
			rallied = true
			rally()
		end
		if phase == "Gather" or phase == "Charge" then
			-- The streams grow and the orb swells as it charges.
			local charge = if phase == "Charge" then k else 0
			if phase == "Charge" and not powered then
				powered = true
				powerUp()
			end
			for _, unit in units do
				if unit.Model.Parent and t >= unit.Land then
					unit.From3.CFrame = CFrame.new(mouthOf(unit.Model, forward))
				end
				local w = if phase == "Charge" then 0.3 + 1.6 * charge else 0
				unit.Flow.Width0, unit.Flow.Width1 = w, w * 0.6
				unit.Thread.Width0, unit.Thread.Width1 = w * 0.3, w * 0.2
				local wobble = math.sin(now * 9 + unit.Index) * 1.5
				unit.Flow.CurveSize0, unit.Flow.CurveSize1 = 2 + wobble, -1 - wobble
				unit.Thread.CurveSize0, unit.Thread.CurveSize1 = 2 + wobble, -1 - wobble
			end
			for _, a in auras do
				local unit = a.Unit
				a.Aura.Transparency = 0.15 + 0.15 * math.sin(now * 12 + unit.Index)
				local mouth = mouthOf(unit.Model, forward)
				for m, mote in a.Motes do
					-- Spiralling up round it and in to its mouth.
					local cycle = (now * 0.9 + m / #a.Motes) % 1
					local angle = now * 5 + m * math.pi * 2 / #a.Motes
					local radius = a.Shell * 0.55 * (1 - cycle)
					local base = unit.Feet:Lerp(mouth, cycle)
					mote.CFrame = CFrame.new(base + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
					mote.Transparency = 0.1 + 0.8 * cycle
				end
			end
			local tremble = Vector3.new(math.sin(now * 61), math.sin(now * 53), math.sin(now * 47)) * 0.15 * charge
			local d = 0.6 + 4.6 * charge * charge
			shell.CFrame = CFrame.new(focus + tremble)
			shell.Size = Vector3.one * d * 1.5
			shell.Color = palette[1 + math.floor(now * 6) % #palette]
			core.CFrame = CFrame.new(focus + tremble)
			core.Size = Vector3.one * d * 0.7
			core.Transparency = if phase == "Charge" then 0 else 1
			light.Brightness = 1 + 8 * charge
			for i, r in rings do
				r.Transparency = if phase == "Charge" then 0.3 else 1
				r.Size = Vector3.new(0.15, d * (1.8 + 0.45 * i), d * (1.8 + 0.45 * i))
				r.CFrame = CFrame.new(focus)
					* CFrame.Angles(now * (3 + i) * (if i % 2 == 1 then 1 else -1), now * i, math.rad(90) + now * 2 * i)
			end
			if phase == "Charge" then
				-- Rings of light pulled in to it.
				if now >= implodeAt then
					implodeAt = now + 0.14
					local pull = part(Vector3.new(0.12, d * 5, d * 5), CFrame.new(focus) * CFrame.Angles(math.random() * 3, math.random() * 3, 0) * FLAT, palette[math.random(1, #palette)], Enum.PartType.Cylinder)
					pull.Transparency = 0.5
					flare(pull, 0.3, { Size = Vector3.new(0.12, d, d), Transparency = 0.2 })
				end
				-- Lightning crackling round it.
				if now >= boltsAt then
					boltsAt = now + 0.06
					for arc = 0, 2 do
						local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
						dir = if dir.Magnitude > 0.01 then dir.Unit else UP
						local point = focus + dir * d * 0.5
						for s = 1, 4 do
							local seg = bolts[arc * 4 + s]
							local jag = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * d * 0.5
							local nextPoint = point + dir * d * 0.35 + jag
							local span = (nextPoint - point).Magnitude
							seg.Size = Vector3.new(0.1 + 0.08 * charge, 0.1 + 0.08 * charge, span)
							seg.CFrame = CFrame.lookAt((point + nextPoint) / 2, nextPoint)
							seg.Color = palette[(arc % #palette) + 1]:Lerp(WHITE, 0.5)
							seg.Transparency = if charge > 0.15 and math.random() < 0.85 then 0 else 1
							point = nextPoint
						end
					end
				end
			end
			if grade then
				grade.Contrast = 0.15 * charge
				grade.Saturation = 0.25 * charge
				grade.TintColor = WHITE:Lerp(palette[1], 0.08 * charge)
			end
			if bloom then
				bloom.Intensity = 0.6 * charge
			end
		elseif phase == "Fire" then
			if not fired then
				fired = true
				punchAt = t
				for _, unit in units do
					unit.Flow.Width0, unit.Flow.Width1 = 0, 0
					unit.Thread.Width0, unit.Thread.Width1 = 0, 0
				end
				for _, r in rings do
					r.Transparency = 1
				end
				for _, seg in bolts do
					seg.Transparency = 1
				end
				for _, a in auras do
					a.Sparks.Enabled = false
					tween(a.Aura, 0.4, { Transparency = 1, Size = Vector3.one * a.Shell * 1.5 })
					for _, mote in a.Motes do
						mote.Transparency = 1
					end
				end
				for _, line in links do
					line.Width0, line.Width1 = 1.1, 1.1
				end
				-- The shot: a flash and shockwaves at the focus, sound, shake.
				for w = 1, 2 do
					local wave = part(Vector3.new(0.2, 4, 4), axis * CFrame.Angles(0, math.rad(90), 0), if w == 1 then WHITE else palette[1], Enum.PartType.Cylinder)
					wave.Transparency = 0.35
					flare(wave, 0.25 + 0.15 * w, { Size = Vector3.new(0.1, 12 + 8 * w, 12 + 8 * w) })
				end
				local dust = part(Vector3.new(0.1, 4, 4), CFrame.new(ground + UP * 0.1) * FLAT, ROCK, Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
				dust.Transparency = 0.4
				flare(dust, 0.7, { Size = Vector3.new(0.05, 40, 40) })
				CombatFx.flash(focus, palette[1], 10, 50, 0.6)
				CombatFx.burst(focus, WHITE, "Sparks", 2.5)
				CombatFx.shakeNear(focus, 0.6, 1.3, 80)
				CombatSound.play("Blast", focus, { Volume = 1.4, Pitch = 0.8 })
				CombatSound.play("Beam", focus, { Volume = 1.3, Pitch = 0.6 })
				for _, unit in units do
					CombatSound.element("Cast", unit.Element, focus, { Volume = 0.5 })
				end
				if over then
					over.Title()
					over.Flash(0.75)
				end
				scorch.Transparency = 0.25
				blaze.Transparency = 0.1
			end
			-- The beam: out to its length at once, its sleeve breathing in the
			-- team's colours, each colour's ribbon twisting round it, rings
			-- racing down it, rock flung up along it.
			local fade = if k > 0.8 then (k - 0.8) / 0.2 else 0
			local grow = math.min(1, k * 8)
			local w = b.Width * (0.55 + 0.08 * math.sin(now * 40)) * grow
			beamCore.Size = Vector3.new(length, w * 0.45, w * 0.45)
			beamCore.Transparency = fade
			sleeve.Size = Vector3.new(length, w, w)
			sleeve.Color = palette[1 + math.floor(now * 10) % #palette]
			sleeve.Transparency = 0.35 + 0.65 * fade
			local twist = #palette
			for c, strand in ribbons do
				for j, bead in strand do
					local s = (j - 1) / (beads - 1)
					local angle = now * 9 + s * math.pi * 6 + c * math.pi * 2 / twist
					local radius = w * 0.62
					bead.CFrame = axis * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, -s * length * grow)
					bead.Size = Vector3.one * (0.5 + w * 0.12)
					bead.Transparency = 0.05 + 0.95 * fade
				end
			end
			for i, r in racers do
				local travel = ((now * 1.6 + i / #racers) % 1) * length
				r.CFrame = axis * CFrame.new(0, 0, -travel) * CFrame.Angles(0, math.rad(90), 0)
				r.Size = Vector3.new(0.4, w * 1.6, w * 1.6)
				r.Transparency = 0.3 + 0.7 * fade
			end
			for i, spike in spikes do
				local angle = now * 2 + i * math.pi / 2
				local long = w * (1.1 + 0.25 * math.sin(now * 30 + i))
				spike.Size = Vector3.new(0.7, 0.7, long)
				spike.CFrame = axis * CFrame.Angles(0, 0, angle) * CFrame.new(0, long / 2, 0) * CFrame.Angles(math.rad(90), 0, 0)
				spike.Transparency = 0.35 + 0.65 * fade
			end
			blaze.CFrame = CFrame.new(focus + forward * length * grow)
			blaze.Size = Vector3.one * w * (1.6 + 0.3 * math.sin(now * 25))
			blaze.Color = palette[1 + math.floor(now * 8) % #palette]
			blaze.Transparency = 0.1 + 0.9 * fade
			shell.Size = Vector3.one * (3.5 * (1 - fade))
			core.Size = Vector3.one * (2.8 * (1 - fade))
			light.Brightness = 10 * (1 - fade)
			scorch.Size = Vector3.new(b.Width * 0.7, 0.08, math.max(0.1, length * grow))
			scorch.CFrame = CFrame.lookAt(ground, ground + forward) * CFrame.new(0, 0, -scorch.Size.Z / 2)
			if fade < 0.5 and now >= debrisAt then
				debrisAt = now + 0.05
				local where = ground + forward * (math.random() * length * grow) + right * ((math.random() - 0.5) * b.Width)
				local chunk = part(Vector3.new(0.5, 0.4, 0.6) * (0.8 + math.random()), CFrame.new(where), ROCK, nil, Enum.Material.Slate)
				local rise = where + UP * (3 + math.random() * 5) + right * ((math.random() - 0.5) * 4)
				tween(chunk, 0.45, {
					CFrame = CFrame.new(rise) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
				}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				task.delay(0.45, function()
					if chunk.Parent then
						tween(chunk, 0.45, { CFrame = CFrame.new(where - UP * 0.5), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					end
				end)
				Debris:AddItem(chunk, 1)
			end
			if grade then
				grade.Brightness = 0.35 * (1 - k)
				grade.Contrast = 0.2
				grade.Saturation = 0.3
			end
			if bloom then
				bloom.Intensity = 1.2 * (1 - k) + 0.2
			end
		elseif phase == "Recover" then
			if not cleared then
				cleared = true
				for _, instance in made do
					if instance:IsA("BasePart") and instance ~= scorch then
						tween(instance, 0.3, { Transparency = 1 })
					elseif instance:IsA("Beam") then
						instance.Enabled = false
					elseif instance:IsA("ParticleEmitter") then
						instance.Enabled = false
					end
				end
				tween(scorch, 2.5, { Transparency = 1 })
				if over then
					over.Hide()
					over = nil
				end
				if mine then
					releaseCamera()
				end
				if grade then
					tween(grade, 0.4, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = WHITE })
				end
				if bloom then
					tween(bloom, 0.4, { Intensity = 0 })
				end
			end
		elseif t >= at.Done then
			connection:Disconnect()
			if over then
				over.Hide()
			end
			if mine then
				releaseCamera()
			end
			task.delay(2.6, function()
				for _, instance in made do
					instance:Destroy()
				end
			end)
		end
	end)
end

-- (The show itself, for tools/vfx_sim's renders.)
KaijuBeamFx._play = play

local started = false
function KaijuBeamFx.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFx")
		fx.OnClientEvent:Connect(function(kind, data)
			if kind == "KaijuBeam" then
				local ok, err = pcall(play, data)
				if not ok then
					warn("[KaijuBeamFx]", err)
					releaseCamera()
				end
			end
		end)
	end)
	-- (Respawned mid-blast: your camera back.)
	player.CharacterAdded:Connect(function()
		if held then
			releaseCamera()
		end
	end)
end

return KaijuBeamFx
