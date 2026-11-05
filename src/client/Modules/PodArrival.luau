--[[
	Your pod coming down (Server.PodServer lands it, you inside, the first
	time you come into the Outpost): the camera on the pad as it drops out of
	the sky on its thrusters, a jolt as it touches down in its dust, then
	round to the front as it opens up (legs, wings, antenna, doors, the stair,
	the display stall), and back behind you as you walk down the steps.
	Letterboxed, the pad's number under it.

	The pod roll: a card over the shot flicks through pod pieces (Shared.
	PodStyle), slower and slower in step with the pod's paint (Shared.Pods.
	flickAfter), and on touchdown shows what it landed on (the PodRoll
	attribute: "Kind|Id|Rarity|New"), its rarity's colour round it.

	The camera's handed back behind you, clear of the pod (Client.ThirdPerson
	.clearEye), and ThirdPerson keeps off it while this has it (.Held).

	Timed off the PodLanding attribute: the server time the descent starts
	(the pod waits overhead until then). Everyone else just sees it land.

	  PodArrival.start()   once, on the client (Client.OutpostScene)
	  PodArrival.shot(t, pad) -> (eye: CFrame, focus: Vector3)   the camera
	                       `t` seconds into the descent, on the pad `pad`
	  PodArrival.parseRoll(text) -> { Kind, Id, Rarity, New, Name }?
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Pods = require(ReplicatedStorage.Shared.Pods)
local PodStyle = require(ReplicatedStorage.Shared.PodStyle)
local ThirdPerson = require(script.Parent.ThirdPerson)

local PodArrival = {}
PodArrival.Out = 1.6 -- seconds behind you walking down before the camera's yours
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

local KINDS = { Hull = "HULL", Glow = "GLOW", Decor = "YARD DECOR" }

-- The PodRoll attribute, read: nil if it isn't one.
function PodArrival.parseRoll(text: any)
	if type(text) ~= "string" then
		return nil
	end
	local kind, id, rarity, new = string.match(text, "^(%a+)|([%w_]+)|(%a+)|([01])$")
	local entry = kind and PodStyle.find(kind, id)
	if not entry then
		return nil
	end
	return { Kind = kind, Id = id, Rarity = rarity, New = new == "1", Name = entry.Name }
end

-- Every piece the roll can land on (for the flicks).
local function catalogue()
	local all = {}
	for _, kind in { "Hull", "Glow", "Decor" } do
		for _, entry in (if kind == "Hull" then PodStyle.Hulls elseif kind == "Glow" then PodStyle.Glows else PodStyle.Decor) do
			if entry.Id ~= "None" then
				table.insert(all, { Kind = kind, Name = entry.Name, Rarity = entry.Rarity })
			end
		end
	end
	return all
end

-- The roll's card, under the top bar. Returns show(piece, final), pop()
-- and the card.
local function rollCard(gui: ScreenGui)
	local card = Instance.new("Frame")
	card.Name = "PodRoll"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0.11, 16)
	card.Size = UDim2.fromOffset(320, 86)
	card.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
	card.BackgroundTransparency = 0.15
	card.ZIndex = 3
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = card
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local function text(y: number, h: number, size: number, font: Enum.Font): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(12, y)
		label.Size = UDim2.new(1, -24, 0, h)
		label.Font = font
		label.TextSize = size
		label.TextColor3 = Color3.fromRGB(230, 236, 245)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.ZIndex = 4
		label.Parent = card
		return label
	end
	local head = text(8, 14, 12, Enum.Font.GothamBold)
	head.Text = "POD ROLL"
	head.TextColor3 = Color3.fromRGB(150, 160, 178)
	local name = text(24, 30, 26, Enum.Font.GothamBlack)
	local sub = text(58, 18, 14, Enum.Font.GothamBold)
	local tag = Instance.new("TextLabel")
	tag.Name = "New"
	tag.AnchorPoint = Vector2.new(1, 0)
	tag.Position = UDim2.new(1, -8, 0, 8)
	tag.Size = UDim2.fromOffset(46, 18)
	tag.BackgroundColor3 = Color3.fromRGB(255, 214, 90)
	tag.Font = Enum.Font.GothamBlack
	tag.TextSize = 12
	tag.TextColor3 = Color3.fromRGB(20, 16, 6)
	tag.Text = "NEW"
	tag.Visible = false
	tag.ZIndex = 5
	tag.Parent = card
	local tagCorner = Instance.new("UICorner")
	tagCorner.CornerRadius = UDim.new(0, 5)
	tagCorner.Parent = tag
	local function show(piece, final: boolean)
		local rarity = PodStyle.rarity(piece.Rarity)
		name.Text = piece.Name
		sub.Text = (KINDS[piece.Kind] or piece.Kind) .. "  ·  " .. rarity.Name
		sub.TextColor3 = rarity.Color
		stroke.Color = rarity.Color
		head.Text = if final and piece.New then "POD ROLL  ·  UNLOCKED" else "POD ROLL"
		tag.Visible = final and piece.New == true
	end
	local function pop()
		scale.Scale = 1.25
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		stroke.Thickness = 4
		TweenService:Create(stroke, TweenInfo.new(0.8), { Thickness = 2 }):Play()
	end
	return show, pop, card
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
	return gui, function()
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
	local gui, unbox = letterbox(player:GetAttribute("PodIndex"))
	local landing = Pods.Landing
	local done = landing.Fall + landing.Deploy
	local released: number? = nil
	local finished = false
	ThirdPerson.Held = true
	-- The roll's card: flicking until touchdown, then what it landed on.
	local show, pop, card = rollCard(gui)
	local pieces = catalogue()
	local flick = -landing.Lead
	-- (no roll, no card: the server sets PodRoll before PodLanding)
	local revealed = PodArrival.parseRoll(player:GetAttribute("PodRoll")) == nil
	card.Visible = not revealed
	local rng = Random.new()
	-- Behind you, clear of the pod, facing out from it (as ThirdPerson
	-- puts it once it's yours again).
	local forward = Vector3.new(spawn.LookVector.X, 0, spawn.LookVector.Z)
	forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
	local function behind(root: BasePart): (Vector3, Vector3)
		local focus = root.Position + Vector3.new(0, 2, 0)
		return ThirdPerson.clearEye(focus, forward, ThirdPerson.LobbyZoom, 8, player.Character), focus
	end
	local function finish()
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(BIND)
		card.Visible = false
		unbox()
		ThirdPerson.Held = false
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid then
			camera.CameraSubject = humanoid
		end
		if root and player:GetAttribute("Outpost") then
			local eye, focus = behind(root)
			camera.CFrame = CFrame.lookAt(eye, focus)
			camera.Focus = CFrame.new(focus)
		end
		camera.CameraType = Enum.CameraType.Custom
		running = false
		-- (ThirdPerson again, from your spot: held at its zoom a moment)
		if player:GetAttribute("Outpost") then
			ThirdPerson.enter(spawn)
		end
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
		-- (the roll's card)
		if not revealed then
			if t >= landing.Fall then
				revealed = true
				local piece = PodArrival.parseRoll(player:GetAttribute("PodRoll"))
				if piece then
					show(piece, true)
					pop()
				end
			elseif t >= flick then
				show(pieces[rng:NextInteger(1, #pieces)], false)
				flick = t + Pods.flickAfter(t)
			end
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local eye, focus = PodArrival.shot(math.min(t, done), pad)
		if released then
			-- (out to the side of the stair as you walk down it, the pod
			-- behind you: not behind you, that's inside the pod)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local k = ease((os.clock() - released) / PodArrival.Out)
				local back, look = behind(root)
				eye = eye:Lerp(CFrame.lookAt(back, look), k)
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
