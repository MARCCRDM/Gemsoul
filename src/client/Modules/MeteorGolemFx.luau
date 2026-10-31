--[[
	The Meteor Golem's fall, as you see it (Shared.MeteorGolem; the server's
	side, the crater and the golem itself: Server.MeteorGolemServer).

	For everyone near: the meteor streaking down out of the sky to where it
	lands (Remotes.MeteorGolem "Fall", { Spot, Start, Owner }, its clock the
	server's), a flash, a shake and a blast as it hits; a shake and embers at
	each of the golem's blows ("Blow", { At, Radius }) and as it falls apart
	("Fell", { At }).

	For whoever it's come for, a cinematic: black bars in, the camera over
	their shoulder following the meteor down, then on the crater, then low
	in front of it looking up as the golem climbs out, its name card up
	("MAGMA GOLEM"), and at Awake the camera eases back to them and the bars
	go (the fight's on).

	  MeteorGolemFx.start()
	  MeteorGolemFx.meteorAt(spot, t) -> Vector3     where the meteor is, t
	                        seconds into its fall (pure)
	  MeteorGolemFx.shot(t, spot, eye) -> CFrame?    the cinematic's camera t
	                        seconds in, from `eye` (where they stood): nil
	                        once it's over (pure)
	  MeteorGolemFx.Sky, Ease
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Rules = require(ReplicatedStorage.Shared.MeteorGolem)
local CombatFx = require(script.Parent.CombatFx)
local CombatSound = require(script.Parent.CombatSound)

local MeteorGolemFx = {}

MeteorGolemFx.Sky = Vector3.new(-90, 260, 70) -- where it starts, from where it lands
MeteorGolemFx.Ease = 0.8 -- seconds the camera takes to come back to you after Awake
MeteorGolemFx.Near = 450 -- studs: further off and you don't see it come down

local MAGMA = Color3.fromRGB(255, 112, 32)
local MAGMA_HOT = Color3.fromRGB(255, 214, 120)
local INK = Color3.fromRGB(8, 7, 10)
local BIND = "MeteorGolemCinematic"
local RESTORE = "MeteorGolemCinematicRestore"

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Where the meteor is, `t` seconds into its fall: from Sky down to `spot`,
-- speeding up as it comes (pure).
function MeteorGolemFx.meteorAt(spot: Vector3, t: number): Vector3
	local u = math.clamp(t / Rules.Fall, 0, 1)
	return spot + MeteorGolemFx.Sky * (1 - u * u)
end

-- The cinematic's camera, `t` seconds in, for someone who stood at `eye`
-- watching it land at `spot` (pure): nil from Awake on.
--   0 .. Fall       over their shoulder, looking up at the meteor coming
--   Fall .. Crack   pulled back off to the side, on the smoking crater
--   Crack .. Awake  low in front of it, looking up as the golem climbs out
function MeteorGolemFx.shot(t: number, spot: Vector3, eye: Vector3): CFrame?
	if t < 0 or t >= Rules.Awake then
		return nil
	end
	local toward = spot - eye
	toward = Vector3.new(toward.X, 0, toward.Z)
	toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
	local right = toward:Cross(Vector3.yAxis)
	if t < Rules.Fall then
		local from = eye - toward * 9 + right * 3.5 + Vector3.new(0, 3.5, 0)
		local rock = MeteorGolemFx.meteorAt(spot, t)
		-- (it's in the sky at first: look between it and where it lands)
		local look = rock:Lerp(spot, 0.35 + 0.65 * smooth(t / Rules.Fall))
		return CFrame.lookAt(from, look)
	end
	if t < Rules.Crack then
		local u = smooth((t - Rules.Fall) / (Rules.Crack - Rules.Fall))
		local from = spot - toward * (30 - 6 * u) + right * 16 + Vector3.new(0, 11 - 3 * u, 0)
		return CFrame.lookAt(from, spot + Vector3.new(0, 2, 0))
	end
	local u = smooth((t - Rules.Crack) / (Rules.Awake - Rules.Crack))
	local from = spot - toward * (24 - 4 * u) + right * (5 - 2 * u) + Vector3.new(0, 2.2, 0)
	return CFrame.lookAt(from, spot + Vector3.new(0, 4 + 6 * u, 0))
end

-- The meteor ----------------------------------------------------------------------------------------------

local function meteor(spot: Vector3, start: number)
	local ball = Instance.new("Part")
	ball.Name = "Meteor"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(7, 7, 7)
	ball.Material = Enum.Material.Neon
	ball.Color = MAGMA_HOT
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow = true, false, false, false, false
	ball.CFrame = CFrame.new(MeteorGolemFx.meteorAt(spot, 0))
	local shell = ball:Clone()
	shell.Name = "Shell"
	shell.Size = Vector3.new(11, 11, 11)
	shell.Color = MAGMA
	shell.Transparency = 0.55
	shell.Parent = ball
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 3, 0), Vector3.new(0, -3, 0)
	a0.Parent, a1.Parent = ball, ball
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.7
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(MAGMA_HOT, Color3.fromRGB(120, 30, 10))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = ball
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = MAGMA, 40, 3
	light.Parent = ball
	ball.Parent = workspace
	local now = workspace:GetServerTimeNow()
	-- (whistling in as it comes)
	task.delay(math.max(0, start + Rules.Fall - 1.1 - now), function()
		CombatSound.play("NovaWarn", spot, { Volume = 1.4, Pitch = 0.6 })
	end)
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = workspace:GetServerTimeNow() - start
		if t >= Rules.Fall then
			connection:Disconnect()
			ball:Destroy()
			CombatFx.flash(spot + Vector3.new(0, 4, 0), MAGMA_HOT, 8, 70, 0.9)
			CombatFx.burst(spot + Vector3.new(0, 2, 0), MAGMA, "Embers", 4)
			CombatFx.burst(spot + Vector3.new(0, 1, 0), Color3.fromRGB(70, 60, 56), "Smoke", 4)
			CombatFx.shakeNear(spot, 0.06, 0.9, 140)
			CombatSound.play("Blast", spot, { Volume = 2, Pitch = 0.55 })
			return
		end
		local at = MeteorGolemFx.meteorAt(spot, t)
		local ahead = MeteorGolemFx.meteorAt(spot, t + 0.05)
		ball.CFrame = if (ahead - at).Magnitude > 0.01 then CFrame.lookAt(at, ahead) * CFrame.Angles(math.rad(90), 0, 0) else CFrame.new(at)
	end)
end

-- The cinematic -------------------------------------------------------------------------------------------

local function bars(): (ScreenGui, Frame, Frame, TextLabel, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MeteorGolemCinematic"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	local function bar(top: boolean): Frame
		local f = Instance.new("Frame")
		f.BackgroundColor3 = INK
		f.BorderSizePixel = 0
		-- (just off the screen, top and bottom: slid in by their AnchorPoint)
		f.AnchorPoint = Vector2.new(0, if top then 1 else 0)
		f.Position = UDim2.fromScale(0, if top then 0 else 1)
		f.Size = UDim2.fromScale(1, 0.12)
		f.Parent = gui
		return f
	end
	local top, bottom = bar(true), bar(false)
	local name = Instance.new("TextLabel")
	name.Name = "Title"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.fromScale(0.5, 0.8)
	name.Size = UDim2.fromScale(0.8, 0.09)
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.TextColor3 = MAGMA_HOT
	name.TextStrokeColor3 = INK
	name.TextTransparency = 1
	name.TextStrokeTransparency = 1
	name.Text = string.upper(Rules.Boss.Name)
	name.Parent = gui
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 64
	limit.Parent = name
	local sub = Instance.new("TextLabel")
	sub.Name = "Subtitle"
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.fromScale(0.5, 0.8)
	sub.Size = UDim2.fromScale(0.8, 0.04)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(240, 226, 210)
	sub.TextTransparency = 1
	sub.Text = "BOSS  ·  WEAK TO " .. string.upper(Rules.Boss.Weakness)
	sub.Parent = gui
	local subLimit = Instance.new("UITextSizeConstraint")
	subLimit.MaxTextSize = 24
	subLimit.Parent = sub
	return gui, top, bottom, name, sub
end

local playing = false
local function cinematic(spot: Vector3, start: number)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if playing or not root or not camera then
		return
	end
	playing = true
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	local gui, top, bottom, name, sub = bars() -- (the bars just off the screen)
	gui.Parent = player:WaitForChild("PlayerGui")
	local slide = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(top, slide, { AnchorPoint = Vector2.new(0, 0) }):Play()
	TweenService:Create(bottom, slide, { AnchorPoint = Vector2.new(0, 1) }):Play()
	local carded = false
	local last: CFrame? = nil
	local base: CFrame?, set: CFrame? = nil, nil
	local endedAt: number? = nil
	local function finish()
		RunService:UnbindFromRenderStep(BIND)
		RunService:UnbindFromRenderStep(RESTORE)
		playing = false
		local out = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(top, out, { AnchorPoint = Vector2.new(0, 1) }):Play()
		TweenService:Create(bottom, out, { AnchorPoint = Vector2.new(0, 0) }):Play()
		TweenService:Create(name, out, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(sub, out, { TextTransparency = 1 }):Play()
		task.delay(0.6, function()
			gui:Destroy()
		end)
	end
	-- (The camera's own controller works from where it left the camera:
	-- put it back before it runs, so ours never drifts it.)
	RunService:BindToRenderStep(RESTORE, Enum.RenderPriority.Camera.Value - 1, function()
		if base and set and camera.CFrame == set then
			camera.CFrame = base
		end
		base, set = nil, nil
	end)
	-- After every other camera step (combat +2, first person +3, third person +4).
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 5, function()
		local t = workspace:GetServerTimeNow() - start
		if not player.Character or player.Character ~= character then
			finish()
			return
		end
		if t >= Rules.Rise + 0.4 and not carded then
			carded = true
			local fade = TweenInfo.new(0.5)
			TweenService:Create(name, fade, { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
			TweenService:Create(sub, fade, { TextTransparency = 0 }):Play()
		end
		local shot = MeteorGolemFx.shot(t, spot, eye)
		if shot then
			last = shot
		else
			-- Awake: eased back from the last shot to their own camera.
			endedAt = endedAt or t
			local u = smooth((t - endedAt) / MeteorGolemFx.Ease)
			if u >= 1 or not last then
				finish()
				return
			end
			shot = (last :: CFrame):Lerp(camera.CFrame, u)
		end
		base = camera.CFrame
		camera.CFrame = shot :: CFrame
		set = camera.CFrame
	end)
	-- (Never stuck in it: whatever happens, it's over a little after Awake.)
	task.delay(math.max(0, start + Rules.Awake + MeteorGolemFx.Ease + 2 - workspace:GetServerTimeNow()), function()
		if playing then
			finish()
		end
	end)
end

local started = false
function MeteorGolemFx.start()
	if started then
		return
	end
	started = true
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MeteorGolem") :: RemoteEvent
	remote.OnClientEvent:Connect(function(kind: string, data)
		if type(data) ~= "table" then
			return
		end
		local player = Players.LocalPlayer
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if kind == "Fall" and typeof(data.Spot) == "Vector3" and type(data.Start) == "number" then
			if root and (root.Position - data.Spot).Magnitude > MeteorGolemFx.Near then
				return
			end
			meteor(data.Spot, data.Start)
			if data.Owner == player.UserId then
				cinematic(data.Spot, data.Start)
			end
		elseif kind == "Blow" and typeof(data.At) == "Vector3" then
			local radius = tonumber(data.Radius) or 6
			CombatFx.burst(data.At + Vector3.new(0, 1, 0), MAGMA, "Embers", radius / 4)
			CombatFx.burst(data.At, Color3.fromRGB(70, 60, 56), "Smoke", radius / 5)
			CombatFx.shakeNear(data.At, 0.035, 0.4, radius * 5)
			CombatSound.play("Blast", data.At, { Pitch = 0.7 })
		elseif kind == "Fell" and typeof(data.At) == "Vector3" then
			CombatFx.flash(data.At, MAGMA_HOT, 6, 50, 1.2)
			CombatFx.burst(data.At, MAGMA, "Embers", 3)
			CombatFx.burst(data.At, Color3.fromRGB(70, 60, 56), "Smoke", 3)
			CombatFx.shakeNear(data.At, 0.05, 0.8, 90)
			CombatSound.play("Blast", data.At, { Volume = 1.6, Pitch = 0.5 })
		end
	end)
end

return MeteorGolemFx
