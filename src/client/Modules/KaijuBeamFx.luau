--[[
	The team's HYPERBEAM, seen (Server.KaijuBeamServer sends it: CombatFx
	"KaijuBeam"; rules and timing: Shared.KaijuBeam). Everyone near sees the
	show; whoever called it gets the cinematic too.

	  Gather    a ring lights up on the ground where each kaiju takes its
	            place (in its element's colour), and a sigil spreads under
	            you; they run in.
	  Charge    from each of them a stream of its colour pours into the
	            focus in front of you (their cast's charge-up glows at their
	            mouths: CreatureAnimation), the orb there swelling and
	            trembling, rings spinning round it.
	  Fire      the beam: a white-hot core in a sleeve of your team's
	            colours, rings racing down it, a flash and a shockwave at
	            the focus, a scorched trail along the ground; screens shake
	            near it.
	  Recover   it all fades.

	  The cinematic (yours): letterbox bars, HYPERBEAM! and your kaiju's
	  names, the picture graded hotter; the camera from in front of your
	  line-up as they gather, round the focus as it charges, then from
	  over your shoulder as it fires, and back to you.

	  KaijuBeamFx.start()            once, from Lobby.client
	  KaijuBeamFx.shot(t, origin, forward, focus) -> CFrame, fov   the
	                                 cinematic's camera at `t` (pure: tests)
]]
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
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local new = IronUi.new

local KaijuBeamFx = {}

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 226, 120)
local UP = Vector3.new(0, 1, 0)
local BIND = "KaijuHyperbeamCam"

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

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The cinematic's camera `t` seconds in: in front of the line-up as they
-- gather (looking back at you and them), round the focus as it charges
-- (closing in), over your shoulder down the beam as it fires.
function KaijuBeamFx.shot(t: number, origin: Vector3, forward: Vector3, focus: Vector3): (CFrame, number)
	local at = KaijuBeam.timeline()
	local right = forward:Cross(UP)
	local hero = CFrame.lookAt(origin + forward * 17 + right * 5 + UP * 3.5, origin + UP * 2.5)
	if t < at.Charge then
		return hero, 62
	end
	if t < at.Fire then
		local k = (t - at.Charge) / (at.Fire - at.Charge)
		local angle = math.rad(70 - 100 * k)
		local around = right * math.cos(angle) + forward * math.sin(angle)
		local eye = focus + around * (13 - 4 * k) + UP * (2.5 + k)
		return CFrame.lookAt(eye, focus), 60 - 10 * k
	end
	local k = math.clamp((t - at.Fire) / (at.Stop - at.Fire), 0, 1)
	local eye = origin - forward * (12 + 4 * k) + UP * (6 + k) + right * 3.5
	return CFrame.lookAt(eye, origin + forward * 40 + UP * 2), 82
end

-- Where a kaiju's stream leaves it: its head's height, a little in front.
local function mouthOf(model: Model, toward: Vector3): Vector3
	local pivot = model:GetPivot()
	local size = model:GetExtentsSize()
	return pivot.Position + UP * size.Y * 0.2 + toward * size.Z * 0.35
end

-- The cinematic's overlay: letterbox bars, the title and the names.
local function overlay(names: { string }, palette: { Color3 })
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
	local sub = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.85),
		Size = UDim2.fromScale(0.9, 0.04),
		BackgroundTransparency = 1,
		Text = table.concat(names, "   ·   "),
		Font = IronUi.Bold,
		TextScaled = true,
		TextColor3 = GOLD,
		TextTransparency = 1,
		ZIndex = 4,
	}, gui)
	new("UITextSizeConstraint", { MaxTextSize = 22 }, sub)
	local scale = new("UIScale", { Scale = 0.6 }, title)
	return {
		Gui = gui,
		Show = function(bar: number)
			local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(top, info, { Size = UDim2.new(1, 0, bar, 0) }):Play()
			TweenService:Create(bottom, info, { Size = UDim2.new(1, 0, bar, 0) }):Play()
			TweenService:Create(sub, info, { TextTransparency = 0 }):Play()
		end,
		Title = function()
			title.TextTransparency, stroke.Transparency = 0, 0
			scale.Scale = 1.6
			TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
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
			TweenService:Create(sub, info, { TextTransparency = 1 }):Play()
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
	local mine = data.Owner == player
	local camera = workspace.CurrentCamera
	-- Too far off to see: nothing (the server's done the work).
	if not mine and camera and (camera.CFrame.Position - origin).Magnitude > 260 then
		return
	end
	local at = KaijuBeam.timeline()
	local b = KaijuBeam.Beam
	local palette, names = {}, {}
	for i, element in elements do
		palette[i] = GemConfig.ElementColors[element] or GOLD
		local model = models[i]
		local name = model and model.Parent and model:GetAttribute("KaijuName")
		if type(name) == "string" and name ~= "" then
			table.insert(names, string.upper(name))
		end
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
	-- Gather: a ring at each place, the sigil under you.
	local ground = origin - UP * 2.8
	local sigil = keep(part(
		Vector3.new(0.1, 2, 2),
		CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
		GOLD,
		Enum.PartType.Cylinder
	))
	sigil.Transparency = 0.35
	TweenService:Create(sigil, TweenInfo.new(at.Charge, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 22, 22),
		Transparency = 0.7,
	}):Play()
	local marks = {}
	for i, place in places do
		if typeof(place) == "Vector3" then
			local mark = keep(part(
				Vector3.new(0.12, 1, 1),
				CFrame.new(place - UP * 0.9) * CFrame.Angles(0, 0, math.rad(90)),
				palette[i] or GOLD,
				Enum.PartType.Cylinder
			))
			mark.Transparency = 0.25
			TweenService:Create(mark, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.12, 6, 6),
			}):Play()
			marks[i] = mark
		end
	end
	-- The focus: its core, its shell and rings.
	local shell = keep(part(Vector3.one * 0.5, CFrame.new(focus), palette[1], Enum.PartType.Ball))
	shell.Transparency = 0.35
	local core = keep(part(Vector3.one * 0.3, CFrame.new(focus), WHITE, Enum.PartType.Ball))
	local light = keep(Instance.new("PointLight"))
	light.Color, light.Range, light.Brightness, light.Shadows = palette[1], 18, 0, false
	light.Parent = core
	local rings = {}
	for i = 1, 2 do
		local r = keep(part(Vector3.new(0.15, 0.1, 0.1), CFrame.new(focus), palette[(i - 1) % #palette + 1], Enum.PartType.Cylinder))
		r.Transparency = 1
		rings[i] = r
	end
	-- The streams: a Beam from each kaiju's mouth into the focus.
	local anchor = keep(part(Vector3.one * 0.2, CFrame.new(focus), WHITE))
	anchor.Transparency = 1
	local into = Instance.new("Attachment")
	into.Parent = anchor
	local streams = {}
	for i, model in models do
		if typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
			local from = keep(part(Vector3.one * 0.2, CFrame.new(mouthOf(model, forward)), WHITE))
			from.Transparency = 1
			local out = Instance.new("Attachment")
			out.Parent = from
			local beam = keep(Instance.new("Beam"))
			beam.Attachment0, beam.Attachment1 = out, into
			beam.Color = ColorSequence.new(palette[i] or GOLD, WHITE)
			beam.LightEmission, beam.LightInfluence = 1, 0
			beam.FaceCamera = true
			beam.Segments = 12
			beam.CurveSize0, beam.CurveSize1 = 2, -1
			beam.Width0, beam.Width1 = 0, 0
			beam.Transparency = NumberSequence.new(0.1, 0.3)
			beam.Parent = from
			streams[i] = { Beam = beam, From = from, Model = model }
		end
	end
	-- The beam itself: its core and sleeve, rings racing down it, the scorch.
	local length = b.Length
	local beamFrame = CFrame.lookAt(focus, focus + forward) * CFrame.new(0, 0, -length / 2) * CFrame.Angles(0, math.rad(90), 0)
	local beamCore = keep(part(Vector3.new(length, 0.1, 0.1), beamFrame, WHITE, Enum.PartType.Cylinder))
	beamCore.Transparency = 1
	local sleeve = keep(part(Vector3.new(length, 0.1, 0.1), beamFrame, palette[1], Enum.PartType.Cylinder))
	sleeve.Transparency = 1
	local racers = {}
	for i = 1, 3 do
		local r = keep(part(Vector3.new(0.4, b.Width, b.Width), CFrame.lookAt(focus, focus + forward) * CFrame.Angles(0, math.rad(90), 0), palette[(i - 1) % #palette + 1], Enum.PartType.Cylinder))
		r.Transparency = 1
		racers[i] = r
	end
	local scorch = keep(part(
		Vector3.new(b.Width * 0.7, 0.08, 0.1),
		CFrame.lookAt(ground, ground + forward),
		Color3.fromRGB(30, 20, 18),
		nil,
		Enum.Material.SmoothPlastic
	))
	scorch.Transparency = 1
	-- Yours: the cinematic.
	local over = nil
	local grade = nil
	if mine then
		over = overlay(names, palette)
		over.Show(0.1)
		holdCamera()
		grade = keep(Instance.new("ColorCorrectionEffect"))
		grade.Name = "KaijuBeamGrade"
		grade.Parent = Lighting
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 6, function()
			local cam = workspace.CurrentCamera
			local state = held
			if not cam or not state then
				return
			end
			local t = workspace:GetServerTimeNow() - start
			local view, fov = KaijuBeamFx.shot(t, origin, forward, focus)
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
	local fired, cleared = false, false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = workspace:GetServerTimeNow() - start
		local now = os.clock()
		local phase, k = KaijuBeam.phase(t)
		if over then
			over.Spin(now)
		end
		if phase == "Gather" or phase == "Charge" then
			-- The streams grow and the orb swells as it charges.
			local charge = if phase == "Charge" then k else 0
			for _, stream in streams do
				if stream.Model.Parent then
					stream.From.CFrame = CFrame.new(mouthOf(stream.Model, forward))
				end
				local w = 0.2 + 1.4 * charge
				stream.Beam.Width0, stream.Beam.Width1 = w, w * 0.5
				stream.Beam.Transparency = NumberSequence.new(if phase == "Charge" then 0 else 0.9, 0.2)
			end
			local tremble = Vector3.new(math.sin(now * 61), math.sin(now * 53), math.sin(now * 47)) * 0.12 * charge
			local d = 0.6 + 4.2 * charge * charge
			shell.CFrame = CFrame.new(focus + tremble)
			shell.Size = Vector3.one * d * 1.35
			shell.Color = palette[1 + math.floor(now * 6) % #palette]
			core.CFrame = CFrame.new(focus + tremble)
			core.Size = Vector3.one * d * 0.7
			light.Brightness = 1 + 7 * charge
			for i, r in rings do
				r.Transparency = if phase == "Charge" then 0.35 else 1
				r.Size = Vector3.new(0.15, d * (1.9 + 0.5 * i), d * (1.9 + 0.5 * i))
				r.CFrame = CFrame.new(focus)
					* CFrame.Angles(now * (3 + i) * (if i == 1 then 1 else -1), 0, math.rad(90) + now * 2 * i)
			end
			if grade then
				grade.Contrast = 0.15 * charge
				grade.Saturation = 0.25 * charge
				grade.TintColor = WHITE:Lerp(palette[1], 0.08 * charge)
			end
		elseif phase == "Fire" then
			if not fired then
				fired = true
				for _, stream in streams do
					stream.Beam.Width0, stream.Beam.Width1 = 0, 0
				end
				for _, r in rings do
					r.Transparency = 1
				end
				-- The shot: a flash and a shockwave at the focus, sound, shake.
				local wave = keep(part(Vector3.new(0.2, 4, 4), CFrame.lookAt(focus, focus + forward) * CFrame.Angles(0, math.rad(90), 0), WHITE, Enum.PartType.Cylinder))
				wave.Transparency = 0.1
				TweenService:Create(wave, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(0.1, 34, 34),
					Transparency = 1,
				}):Play()
				CombatFx.flash(focus, palette[1], 8, 40, 0.5)
				CombatFx.shakeNear(focus, 0.5, 1.2, 70)
				CombatSound.play("Blast", focus, { Volume = 1.3, Pitch = 0.85 })
				CombatSound.play("Beam", focus, { Volume = 1.2, Pitch = 0.6 })
				if over then
					over.Title()
				end
				scorch.Transparency = 0.25
			end
			-- The beam: out to its length at once, its sleeve breathing in the
			-- team's colours, rings racing down it.
			local fade = if k > 0.8 then (k - 0.8) / 0.2 else 0
			local grow = math.min(1, k * 8)
			local w = b.Width * (0.55 + 0.08 * math.sin(now * 40)) * grow
			beamCore.Size = Vector3.new(length, w * 0.45, w * 0.45)
			beamCore.Transparency = fade
			sleeve.Size = Vector3.new(length, w, w)
			sleeve.Color = palette[1 + math.floor(now * 10) % #palette]
			sleeve.Transparency = 0.35 + 0.65 * fade
			for i, r in racers do
				local travel = ((now * 1.6 + i / #racers) % 1) * length
				r.CFrame = CFrame.lookAt(focus, focus + forward) * CFrame.new(0, 0, -travel) * CFrame.Angles(0, math.rad(90), 0)
				r.Size = Vector3.new(0.4, w * 1.6, w * 1.6)
				r.Transparency = 0.3 + 0.7 * fade
			end
			shell.Size = Vector3.one * (4.5 * (1 - fade))
			core.Size = Vector3.one * (2.6 * (1 - fade))
			light.Brightness = 9 * (1 - fade)
			scorch.Size = Vector3.new(b.Width * 0.7, 0.08, math.max(0.1, length * grow))
			scorch.CFrame = CFrame.lookAt(ground, ground + forward) * CFrame.new(0, 0, -scorch.Size.Z / 2)
			if grade then
				grade.Brightness = 0.35 * (1 - k)
				grade.Contrast = 0.2
				grade.Saturation = 0.3
			end
		elseif phase == "Recover" then
			if not cleared then
				cleared = true
				for _, instance in made do
					if instance:IsA("BasePart") and instance ~= scorch then
						TweenService:Create(instance, TweenInfo.new(0.3), { Transparency = 1 }):Play()
					end
				end
				TweenService:Create(scorch, TweenInfo.new(2.5), { Transparency = 1 }):Play()
				if over then
					over.Hide()
					over = nil
				end
				if mine then
					releaseCamera()
				end
				if grade then
					TweenService:Create(grade, TweenInfo.new(0.4), {
						Brightness = 0,
						Contrast = 0,
						Saturation = 0,
						TintColor = WHITE,
					}):Play()
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
