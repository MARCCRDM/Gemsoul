--[[
	Your pod coming down (Server.PodServer lands it, you inside, the first
	time you come into the Outpost): the camera on the pad as it drops out of
	the sky on its thrusters, a jolt as it touches down in its dust, then
	round to the front as it opens up (legs, wings, antenna, doors, the stair,
	the display stall), and back behind you as you walk down the steps.
	Letterboxed, the pad's number under it.

	Timed off the PodLanding attribute: the server time the descent starts
	(the pod waits overhead until then). Everyone else just sees it land.

	  PodArrival.start()   once, on the client (Client.OutpostScene)
	  PodArrival.shot(t, pad) -> (eye: CFrame, focus: Vector3)   the camera
	                       `t` seconds into the descent, on the pad `pad`
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Pods = require(ReplicatedStorage.Shared.Pods)

local PodArrival = {}
PodArrival.Out = 1.4 -- seconds behind you walking down before the camera's yours
local BIND = "PodArrival"

local player = Players.LocalPlayer
local running = false

local function ease(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- The pod's hull, `t` seconds into the descent, over the pad.
local function hullAt(t: number, pad: CFrame): Vector3
	local landing = Pods.Landing
	local height = if t < 0 then landing.Height elseif t < landing.Fall then Pods.altitude(t) else 0
	return (pad * CFrame.new(0, Pods.Base + 2.3 * Pods.Scale + height, 0)).Position
end

-- Where the camera is `t` seconds in: low off the pad's front corner looking
-- up at it coming down, a jolt on touchdown, then round to the doors.
function PodArrival.shot(t: number, pad: CFrame): (CFrame, Vector3)
	local landing = Pods.Landing
	local low = (pad * CFrame.new(-20, 4, -34)).Position
	local front = (pad * CFrame.new(5, 6.5, -24)).Position
	local doors = (pad * CFrame.new(0, 4, 0)).Position
	local hull = hullAt(t, pad)
	local eye, focus
	if t < landing.Fall then
		eye, focus = low, hull
	else
		local k = ease((t - landing.Fall - 0.35) / (landing.Deploy * 0.7))
		eye, focus = low:Lerp(front, k), hull:Lerp(doors, k)
	end
	-- (the jolt as it touches down)
	local since = t - landing.Fall
	if since > 0 and since < 0.6 then
		local shake = (1 - since / 0.6) * 0.7
		eye += Vector3.new(math.sin(t * 61) * shake, math.sin(t * 47 + 1) * shake, math.cos(t * 53) * shake)
	end
	return CFrame.lookAt(eye, focus), focus
end

-- Where the camera hands back to you: up behind your shoulder, out past
-- the pod's end (not its stall's), so the view runs past you to the field
-- and the pod's never in the way.
function PodArrival.endEye(pad: CFrame): Vector3
	return (pad * CFrame.new(-14, 10, -3)).Position
end

local function letterbox(padIndex: number?)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PodArrival"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.ResetOnSpawn = false
	local bars = {}
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.new(1, 0, 0, 0)
		bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.Parent = gui
		table.insert(bars, bar)
	end
	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -18)
	caption.Size = UDim2.new(0.8, 0, 0, 26)
	caption.Font = Enum.Font.GothamBold
	caption.TextSize = 20
	caption.TextColor3 = Color3.fromRGB(230, 236, 245)
	caption.TextTransparency = 1
	caption.Text = if padIndex then string.format("POD LANDING  ·  PAD %02d", padIndex) else "POD LANDING"
	caption.ZIndex = 2
	caption.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, bar in bars do
		TweenService:Create(bar, info, { Size = UDim2.new(1, 0, 0.11, 0) }):Play()
	end
	TweenService:Create(caption, info, { TextTransparency = 0 }):Play()
	return function()
		local out = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, bar in bars do
			TweenService:Create(bar, out, { Size = UDim2.new(1, 0, 0, 0) }):Play()
		end
		TweenService:Create(caption, out, { TextTransparency = 1 }):Play()
		task.delay(0.6, function()
			gui:Destroy()
		end)
	end
end

local function film(start: number)
	if running then
		return
	end
	local spawn = player:GetAttribute("PodSpawn")
	if typeof(spawn) ~= "CFrame" then
		return
	end
	running = true
	local pad = Pods.padFrom(spawn)
	local camera = workspace.CurrentCamera
	local unbox = letterbox(player:GetAttribute("PodIndex"))
	local landing = Pods.Landing
	local done = landing.Fall + landing.Deploy
	local released: number? = nil
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(BIND)
		unbox()
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		camera.CameraType = Enum.CameraType.Custom
		running = false
	end
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 6, function()
		local t = workspace:GetServerTimeNow() - start
		local riding = player:GetAttribute("PodLanding") ~= nil
		if not riding and not released then
			released = os.clock() -- (out of the pod: the walk down)
		end
		-- (left the Outpost, or far too long: give the camera back)
		if not player:GetAttribute("Outpost") or t > done + 6 then
			finish()
			return
		end
		if released and os.clock() - released > PodArrival.Out then
			finish()
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local eye, focus = PodArrival.shot(math.min(t, done), pad)
		if released then
			-- (out to the side of the stair as you walk down it, the pod
			-- behind you: not behind you, that's inside the pod)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local k = ease((os.clock() - released) / PodArrival.Out)
				local look = root.Position + Vector3.new(0, 2, 0)
				eye = eye:Lerp(CFrame.lookAt(PodArrival.endEye(pad), look), k)
				focus = focus:Lerp(look, k)
			end
		end
		camera.CFrame = eye
		camera.Focus = CFrame.new(focus)
	end)
end

function PodArrival.start()
	local function changed()
		local start = player:GetAttribute("PodLanding")
		if typeof(start) == "number" then
			task.spawn(film, start)
		end
	end
	player:GetAttributeChangedSignal("PodLanding"):Connect(changed)
	changed()
end

return PodArrival
