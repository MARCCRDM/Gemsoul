--[[
	A kaiju battle's camera (Client.KaijuBattleUI drives it): once the
	fight starts, an overview of the court from high over your end, like a
	spectator's, both sides in view (your foe's beyond yours). It leans
	after the fight as the kaiju move, and you can look round it: drag (the
	right mouse button, or a finger off the controls) to swing round the
	court, the wheel or a pinch to come in or back. It stays on through the
	result and hands your own camera back once the battle's gone, or as soon
	as you're well away from the court (up the stairs, say). Not in a 1V1 +
	KAIJU battle: you're in the fight yourself, so your camera stays yours.

	  KaijuBattleCam.view(center, axis, side, focus?, yaw?, zoom?) -> CFrame
	                                  where it looks from (pure: tests)
	  KaijuBattleCam.follow(state)    the battle as last told: on for its
	                                  Battle and Over, off otherwise
	  KaijuBattleCam.stop()           your camera back
	  KaijuBattleCam.active() -> boolean
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local KaijuBattleCam = {}

-- Over your end of the court: this far back from its middle and this high
-- (inside the hall downstairs, whichever court: Shared.KaijuPit), at this
-- field of view. You can swing round it up to Yaw either way, and come in
-- or back between the zooms.
KaijuBattleCam.Back = 25
KaijuBattleCam.Height = 17
KaijuBattleCam.Fov = 55
KaijuBattleCam.Yaw = math.rad(60)
KaijuBattleCam.Zoom = { 0.8, 1.1 }
-- How far toward the fight it leans (a share of the way from the court's
-- middle to the kaiju's), and how far it leans at most.
KaijuBattleCam.Lean = 0.5
KaijuBattleCam.LeanMost = 8
-- Further than this from the court's middle, it lets go.
KaijuBattleCam.Reach = 90
KaijuBattleCam.EaseIn = 0.8

local BIND = "KaijuBattleCam"

-- From over `side`'s end ("A" stands at -axis, Shared.KaijuBattle),
-- swung `yaw` round the court's middle and `zoom` times as far, looking at
-- `focus` (the middle, a touch toward the foe's half, if not given).
function KaijuBattleCam.view(
	center: Vector3,
	axis: Vector3,
	side: string,
	focus: Vector3?,
	yaw: number?,
	zoom: number?
): CFrame
	local flat = Vector3.new(axis.X, 0, axis.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, 1)
	local home = if side == "B" then flat else -flat
	local turn = CFrame.Angles(0, yaw or 0, 0)
	local back = turn:VectorToWorldSpace(home)
	local z = zoom or 1
	local eye = center + back * KaijuBattleCam.Back * z + Vector3.new(0, KaijuBattleCam.Height * z, 0)
	local at = focus or (center - home * 1.5)
	return CFrame.lookAt(eye, at)
end

local player = Players.LocalPlayer
local on = nil -- { Center, Axis, Side, Units, Focus, Since, Camera, Type, Subject, Fov }
local yaw, zoom = 0, 1
local dragging: InputObject? = nil
local pinch: number? = nil
local mouseWas: Enum.MouseBehavior? = nil -- (held still while the right button drags)
local connections = {}

local function rootOf(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The kaiju still up, on average (nil: none).
local function fightAt(units): Vector3?
	local sum, n = Vector3.zero, 0
	for _, unit in units or {} do
		local model = unit.Model
		local root = model and model.Parent and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart"))
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if root and (not humanoid or humanoid.Health > 0) then
			sum += (root :: BasePart).Position
			n += 1
		end
	end
	return if n > 0 then sum / n else nil
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function KaijuBattleCam.active(): boolean
	return on ~= nil
end

function KaijuBattleCam.stop()
	RunService:UnbindFromRenderStep(BIND)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	dragging, pinch = nil, nil
	if mouseWas then
		UserInputService.MouseBehavior, mouseWas = mouseWas, nil
	end
	local was = on
	on = nil
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

local function frame(dt: number)
	local state = on
	local camera = workspace.CurrentCamera
	if not state or not camera then
		return
	end
	local root = rootOf()
	if root and (root.Position - state.Center).Magnitude > KaijuBattleCam.Reach then
		KaijuBattleCam.stop()
		return
	end
	-- Lean after the fight, a little.
	local home = if state.Side == "B" then state.Axis else -state.Axis
	local want = state.Center - home * 1.5
	local fight = fightAt(state.Units)
	if fight then
		local lean = Vector3.new(fight.X - state.Center.X, 0, fight.Z - state.Center.Z) * KaijuBattleCam.Lean
		if lean.Magnitude > KaijuBattleCam.LeanMost then
			lean = lean.Unit * KaijuBattleCam.LeanMost
		end
		want = state.Center + lean
	end
	state.Focus = state.Focus:Lerp(want, 1 - math.exp(-dt * 2))
	local view = KaijuBattleCam.view(state.Center, state.Axis, state.Side, state.Focus, yaw, zoom)
	camera.CameraType = Enum.CameraType.Scriptable
	local t = smooth((os.clock() - state.Since) / KaijuBattleCam.EaseIn)
	if t < 1 then
		camera.CFrame = state.From:Lerp(view, t)
		camera.FieldOfView = state.Fov + (KaijuBattleCam.Fov - state.Fov) * t
	else
		camera.CFrame = view
		camera.FieldOfView = KaijuBattleCam.Fov
	end
end

-- Dragging swings it round; the wheel or a pinch comes in or back.
local function listen()
	local function swing(dx: number)
		yaw = math.clamp(yaw - dx * 0.006, -KaijuBattleCam.Yaw, KaijuBattleCam.Yaw)
	end
	local function closer(by: number)
		zoom = math.clamp(zoom * by, KaijuBattleCam.Zoom[1], KaijuBattleCam.Zoom[2])
	end
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				dragging = input
				mouseWas = mouseWas or UserInputService.MouseBehavior
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			elseif input.UserInputType == Enum.UserInputType.Touch then
				-- (Not the left of the screen: the thumbstick's.)
				local camera = workspace.CurrentCamera
				local width = if camera then camera.ViewportSize.X else 1000
				if input.Position.X > width * 0.4 and not dragging then
					dragging = input
				end
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input, processed)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				if not processed then
					closer(if input.Position.Z > 0 then 0.92 else 1 / 0.92)
				end
			elseif input.UserInputType == Enum.UserInputType.MouseMovement then
				if dragging and dragging.UserInputType == Enum.UserInputType.MouseButton2 then
					swing(input.Delta.X)
				end
			elseif input == dragging then
				swing(input.Delta.X)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				if dragging and dragging.UserInputType == Enum.UserInputType.MouseButton2 then
					dragging = nil
				end
				if mouseWas then
					UserInputService.MouseBehavior, mouseWas = mouseWas, nil
				end
			elseif input == dragging then
				dragging = nil
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.TouchPinch:Connect(function(_, scale, _, inputState, processed)
			if processed then
				return
			end
			if inputState == Enum.UserInputState.Begin then
				pinch = scale
			elseif pinch and scale > 0 then
				closer(pinch / scale)
				pinch = scale
			end
		end)
	)
end

function KaijuBattleCam.follow(state)
	local phase = state and state.Phase
	-- (In a 1V1 + KAIJU battle you're fighting too: your own camera.)
	if
		not state
		or (phase ~= "Battle" and phase ~= "Over")
		or not state.Center
		or not state.Axis
		or state.Mode == "Mixed"
	then
		KaijuBattleCam.stop()
		return
	end
	if on and on.Id == state.Id then
		on.Units = state.Units
		return
	end
	KaijuBattleCam.stop()
	local root = rootOf()
	if root and (root.Position - state.Center).Magnitude > KaijuBattleCam.Reach then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local axis = Vector3.new(state.Axis.X, 0, state.Axis.Z)
	axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.new(0, 0, 1)
	local home = if state.Side == "B" then axis else -axis
	on = {
		Id = state.Id,
		Center = state.Center,
		Axis = axis,
		Side = state.Side,
		Units = state.Units,
		Focus = state.Center - home * 1.5,
		Since = os.clock(),
		From = camera.CFrame,
		Camera = camera,
		Type = camera.CameraType,
		Subject = camera.CameraSubject,
		Fov = camera.FieldOfView,
	}
	yaw, zoom = 0, 1
	listen()
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 3, frame)
end

return KaijuBattleCam
