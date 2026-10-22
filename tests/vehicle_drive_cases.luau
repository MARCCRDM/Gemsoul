-- The pilot's screen (Client VehicleDrive): it drives the mech the server
-- made you pilot of (your MechPilot attribute), from your keys or a stick,
-- over the ground (Shared.MechPilot), and tells the server where it went.
-- Waiting for the mech to stream in, the hello, sending (rate, stopping),
-- steering, chat, a wall and pushing through, a rock it shoves (and mines,
-- never pushing through it), a failing cast, a server that
-- isn't answering, menus, getting out, being let go, a respawn, the camera,
-- a controls load that fails once, and a touch screen's own drive stick.
-- The real module under lune, with stand-ins for the services and the HUD.
-- Run by tests/run_vehicle_transition.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local R = roblox
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local entry = { Fn = fn, On = true }
			table.insert(listeners, entry)
			return {
				Disconnect = function()
					entry.On = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in listeners do
				if entry.On then
					entry.Fn(...)
				end
			end
		end,
	}
end

-- Something with attributes and their changed signals.
local function attributed(object)
	object.Attributes, object.Changes = object.Attributes or {}, {}
	function object:GetAttribute(k)
		return self.Attributes[k]
	end
	function object:SetAttribute(k, v)
		self.Attributes[k] = v
		if self.Changes[k] then
			self.Changes[k]:Fire()
		end
	end
	function object:GetAttributeChangedSignal(k)
		self.Changes[k] = self.Changes[k] or signal()
		return self.Changes[k]
	end
	return object
end

-- The player, their body, their screens -----------------------------------------------------
local player = attributed({ Name = "Pilot", CameraMinZoomDistance = 6, CameraMaxZoomDistance = 40 })
player.Attributes.Outpost = true
player.CharacterAdded = signal()
local humanoid = { Sit = false }
player.Character = {
	FindFirstChildOfClass = function(_, class)
		return if class == "Humanoid" then humanoid else nil
	end,
}
local playerGui = { ChildAdded = signal(), ChildRemoved = signal(), Children = {} }
function playerGui:GetChildren()
	return self.Children
end
function player:WaitForChild(name)
	assert(name == "PlayerGui")
	return playerGui
end
-- (Roblox's controls fail to load the first time: a phone, still starting.)
local controlStub, moveVec, controlsFail, controlLoads = {}, nil, 1, 0
function controlStub:GetMoveVector()
	return moveVec
end
local playerScripts = {
	FindFirstChild = function(_, name)
		return if name == "PlayerModule"
			then { Module = {
				GetControls = function()
					controlLoads += 1
					if controlsFail > 0 then
						controlsFail -= 1
						error("PlayerModule isn't ready")
					end
					return controlStub
				end,
			} }
			else nil
	end,
}
function player:FindFirstChild(name)
	return if name == "PlayerScripts" then playerScripts else nil
end
local function screen(name, enabled)
	local item = attributed({ Name = name, Enabled = enabled, Parent = playerGui, Toggled = signal() })
	function item:IsA(kind)
		return kind == "ScreenGui"
	end
	function item:GetPropertyChangedSignal(prop)
		assert(prop == "Enabled")
		return self.Toggled
	end
	function item:setEnabled(on)
		self.Enabled = on
		self.Toggled:Fire()
	end
	return item
end
local dashboard = screen("Dashboard", false)
table.insert(playerGui.Children, dashboard)
-- (The daily caches' screen is always on, only its button hidden.)
table.insert(playerGui.Children, screen("StreakRewards", true))

-- The mech, as it streams in: its chassis at the root, its hull.
local CENTRE = R.Vector3.new(0, 0, 7000)
local function makeMech(id, kind)
	local model = attributed({ Name = kind, Parent = "Machines" })
	local chassisData = {
		Name = "Chassis",
		CFrame = R.CFrame.new(CENTRE + R.Vector3.new(0, 6.2, 0)),
		Size = R.Vector3.new(7.6, 12, 6.2),
	}
	local chassis = setmetatable({}, {
		__index = function(_, k)
			if k == "Position" then
				return chassisData.CFrame.Position
			end
			return chassisData[k]
		end,
		__newindex = function(_, k, v)
			if k == "CFrame" then
				chassisData.Sets = (chassisData.Sets or 0) + 1
			end
			chassisData[k] = v
		end,
	})
	local hull = setmetatable({ Size = R.Vector3.new(7.6, 10.4, 6.2) }, {
		__index = function(_, k)
			if k == "CFrame" then
				return chassisData.CFrame * R.CFrame.new(0, 0.8, 0)
			end
			return nil
		end,
	})
	model.PrimaryPart, model.Chassis, model.Data = chassis, chassis, chassisData
	function model:FindFirstChild(name)
		return if name == "Hull" then hull else nil
	end
	model.Attributes.MechId, model.Attributes.MechKind, model.Attributes.CameraFit = id, kind, 24
	return model
end
local mech = makeMech("Hauler1", "Hauler")
local streamed = {}

-- Services and remotes ------------------------------------------------------------------------
local clockNow = 0
local keysDown, focusedBox = {}, nil
local UserInputService = {
	JumpRequest = signal(),
	InputBegan = signal(),
	InputChanged = signal(),
	InputEnded = signal(),
	TouchEnabled = false,
	KeyboardEnabled = true,
}
function UserInputService:IsKeyDown(key)
	return keysDown[key.Name] == true
end
function UserInputService:GetFocusedTextBox()
	return focusedBox
end
local GuiService = { MenuIsOpen = false, Changed = signal() }
function GuiService:GetPropertyChangedSignal(name)
	assert(name == "MenuIsOpen")
	return self.Changed
end
local sent, reports, exits = {}, {}, 0
local remotes = {
	MechMove = {
		FireServer = function(_, at, yaw, speed, turn)
			table.insert(sent, { At = at, Yaw = yaw, Speed = speed, Turn = turn, Time = clockNow })
		end,
	},
	MechReport = {
		FireServer = function(_, text)
			table.insert(reports, text)
		end,
	},
	MechExit = {
		FireServer = function()
			exits += 1
		end,
	},
}
local remotesHere = true
local ReplicatedStorage = {
	FindFirstChild = function(_, name)
		return if name == "Remotes" and remotesHere
			then {
				FindFirstChild = function(_, n)
					return remotes[n]
				end,
			}
			else nil
	end,
}
local renderSteps = {}
local RunService = {
	BindToRenderStep = function(_, name, priority, fn)
		renderSteps[name] = { Priority = priority, Fn = fn }
	end,
}
local Players = {
	LocalPlayer = player,
	GetPlayers = function()
		return { player }
	end,
}
-- The world, from this screen: open ground at y = 0, or a wall (or a rock),
-- or a cast that fails.
local wallAt, castsFail, casts = nil, false, 0
local wallIsRock = false
local plainWall = {
	Name = "Wall",
	IsA = function()
		return false
	end,
}
local rock = {
	Name = "Rock7",
	Parent = "Nodes",
	Tags = { OutpostNode = true },
	IsA = function(_, class)
		return class == "Model"
	end,
}
local rockBody = {
	Name = "Body",
	Parent = rock,
	IsA = function(_, class)
		return class == "BasePart"
	end,
}
local workspace = {
	Gravity = 196.2,
	FindFirstChild = function()
		return nil
	end,
	Blockcast = function(_, from, _size, direction)
		casts += 1
		if castsFail then
			error("Blockcast failed")
		end
		if wallAt then
			-- (A wall across the way at Z = wallAt, the hull's front 3 studs ahead.)
			local gap = from.Position.Z - 3 - wallAt
			if gap >= 0 and gap <= direction.Magnitude and direction.Z < 0 then
				return { Distance = gap, Instance = if wallIsRock then rockBody else plainWall }
			end
		end
		return nil
	end,
	Raycast = function(_, origin)
		return { Position = R.Vector3.new(origin.X, 0, origin.Z) }
	end,
}
local toasts, printed, warned = {}, {}, {}
local modules = {
	IronUi = { Colors = {}, Bold = "Bold", Body = "Body", Heading = "Heading" },
	UiKit = {
		toast = function(text)
			table.insert(toasts, text)
		end,
		round = function() end,
	},
	MechAnimation = {},
	-- (The real one: HOP OUT's size and place, MobileLayout.Drive.)
	MobileLayout = luau.load(fs.readFile(ROOT .. "/src/client/Modules/MobileLayout.luau"), {
		debugName = "MobileLayout",
		environment = setmetatable({ Vector2 = R.Vector2 }, { __index = _G }),
	})(),
}
local texts = {}
local buttons, named = {}, {}
function modules.IronUi.new(class, props, parent)
	props = props or {}
	props.Parent = parent
	if class == "TextButton" then
		props.Activated, props.InputBegan = signal(), signal()
		buttons[props.Name or props.Text] = props
	end
	if props.Name then
		named[props.Name] = props
	end
	return props
end
function modules.IronUi.text(_parent, text)
	local label = { Text = text }
	table.insert(texts, label)
	return label
end
local hudGui = { Enabled = false }
function modules.UiKit.gui()
	return hudGui
end
local Rules = luau.load(fs.readFile(ROOT .. "/src/shared/Outpost.luau"), {
	debugName = "Outpost",
	environment = setmetatable({ CFrame = R.CFrame, Color3 = R.Color3 }, { __index = _G }),
})()
local MechPilot = luau.load(fs.readFile(ROOT .. "/src/shared/MechPilot.luau"), {
	debugName = "MechPilot",
	environment = setmetatable({
		game = {
			GetService = function()
				return {
					GetTagged = function()
						return streamed
					end,
				}
			end,
		},
		CFrame = R.CFrame,
		Vector3 = R.Vector3,
	}, { __index = _G }),
})()
local WalkMine = luau.load(fs.readFile(ROOT .. "/src/shared/WalkMine.luau"), {
	debugName = "WalkMine",
	environment = setmetatable({ Vector3 = R.Vector3 }, { __index = _G }),
})()
local services = {
	CollectionService = {
		HasTag = function(_, instance, tag)
			return type(instance) == "table" and instance.Tags ~= nil and instance.Tags[tag] == true
		end,
	},
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	UserInputService = UserInputService,
	GuiService = GuiService,
}
local Enum = setmetatable({
	RenderPriority = { Camera = { Value = 200 } },
	CameraMode = { LockFirstPerson = "LockFirstPerson" },
	RaycastFilterType = { Exclude = "Exclude" },
	TextXAlignment = { Right = "Right" },
}, { __index = R.Enum })
local VehicleDrive = luau.load(fs.readFile(ROOT .. "/src/client/Modules/VehicleDrive.luau"), {
	debugName = "VehicleDrive",
	environment = setmetatable({
		game = {
			GetService = function(_, name)
				return assert(services[name], "No stand-in for " .. name)
			end,
		},
		script = { Parent = { IronUi = "IronUi", UiKit = "UiKit", MechAnimation = "MechAnimation", MobileLayout = "MobileLayout" } },
		require = function(target)
			if type(target) == "string" then
				return assert(modules[target], target)
			end
			if target == ReplicatedStorage.Shared then
				return nil
			end
			return target.Module
		end,
		workspace = workspace,
		Enum = Enum,
		CFrame = R.CFrame,
		Vector3 = R.Vector3,
		Vector2 = R.Vector2,
		Color3 = R.Color3,
		UDim2 = R.UDim2,
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		os = setmetatable({
			clock = function()
				return clockNow
			end,
		}, { __index = os }),
		task = {
			spawn = function(fn, ...)
				fn(...)
			end,
		},
		print = function(...)
			table.insert(printed, table.concat({ ... }, " "))
		end,
		warn = function(...)
			table.insert(warned, table.concat({ ... }, " "))
		end,
	}, { __index = _G }),
})
-- (It requires Shared.Outpost and Shared.MechPilot off ReplicatedStorage.)
ReplicatedStorage.Shared =
	{ Outpost = { Module = Rules }, MechPilot = { Module = MechPilot }, WalkMine = { Module = WalkMine } }
VehicleDrive = VehicleDrive()
local hopOut = buttons["HOP OUT"]
-- Said once a ride: the server isn't hearing you.
local DEAF = "The server isn't answering: others can't see you move."
local function said(text)
	local count = 0
	for _, toast in toasts do
		if toast == text then
			count += 1
		end
	end
	return count
end

local step = renderSteps.MechPilotDrive
check(step and step.Priority < 200, "Driving isn't bound before the camera moves")
-- (The server answers each move, unless it's gone quiet. Turning on the
-- spot, only MechMotion changes.)
local quietServer, motionOnly, echoes = false, false, 0
local function serverEcho()
	echoes += 1
	if motionOnly then
		mech:SetAttribute("MechMotion", R.Vector3.new(echoes, 0, 0))
	else
		mech:SetAttribute("MechPosition", mech.Chassis.Position)
	end
end
local function frames(n, dt)
	dt = dt or 1 / 60
	for _ = 1, n do
		clockNow += dt
		local count = #sent
		step.Fn(dt)
		if #sent > count and not quietServer then
			serverEcho()
		end
	end
end

-- Not a pilot: nothing.
frames(5)
check(not VehicleDrive.isDriving() and #sent == 0 and not hudGui.Enabled, "Drove with no mech")

-- The server makes you its pilot before the mech has streamed in: it waits.
player:SetAttribute("MechPilot", "Hauler1")
frames(5)
check(not VehicleDrive.isDriving() and #sent == 0, "Started driving a mech that isn't here")
-- (You can still get out.)
UserInputService.JumpRequest:Fire()
check(exits == 1, "Couldn't get out before the mech streamed in")
clockNow += 1
table.insert(streamed, mech)
frames(1)
check(VehicleDrive.isDriving() and hudGui.Enabled, "Didn't start once the mech arrived")
check(
	#sent == 1 and sent[1].Speed == 0 and (sent[1].At - mech.Chassis.Position).Magnitude < 1e-3,
	"No hello for the server"
)
check(printed[#printed]:find("Piloting Hauler1", 1, true) ~= nil, "Starting wasn't logged")
check(player.CameraMinZoomDistance == 24 and humanoid.Sit, "No camera fit, or not sat down")
-- No driving card (it was in the way): only HOP OUT, in its place.
check(#texts == 0, "The driving card is back")
local drive = modules.MobileLayout.Drive
check(
	hopOut
		and hopOut.Size.X.Offset == drive.W
		and hopOut.Size.Y.Offset == drive.H
		and hopOut.Position.Y.Offset == -drive.Bottom,
	"HOP OUT isn't in its place"
)
check(hopOut.Text == "HOP OUT  ·  SPACE", "HOP OUT doesn't name its key on a keyboard: " .. hopOut.Text)

-- W: it moves at once, from this screen, and the server hears about it.
local start = mech.Chassis.Position
keysDown = { W = true }
local before = #sent
frames(120)
local here = mech.Chassis.Position
check(start.Z - here.Z > 15 and math.abs(here.X - start.X) < 1e-3, "W didn't drive it forward")
local moves = #sent - before
check(moves >= 25 and moves <= 32, "Not about 15 moves a second: " .. moves .. " in 2 s")
local lastMove = sent[#sent]
check((lastMove.At - here).Magnitude < 2 and lastMove.Speed > 20, "The server wasn't told where it is")
serverEcho()
-- Let go: it brakes, and once stopped says so once, then goes quiet.
keysDown = {}
frames(120)
check(sent[#sent].Speed == 0, "Stopping wasn't sent")
local quiet = #sent
frames(60)
check(#sent == quiet, "Kept sending while it stood still")
-- Setting off after standing a while isn't the server going quiet (standing
-- still, nothing was sent, so nothing came back).
frames(300)
keysDown = { W = true }
frames(3)
keysDown = {}
check(said(DEAF) == 0 and #reports == 0, "Setting off after a stand counted as the server going quiet")
frames(120)
-- Steering: A turns it left.
keysDown = { A = true }
frames(30)
check(sent[#sent].Yaw > 0.2 and sent[#sent].Turn > 0, "A didn't turn it left")
keysDown = {}
frames(30)
-- Typing in chat drives nothing.
focusedBox = {}
keysDown = { W = true }
local stoodAt = mech.Chassis.Position
frames(30)
check((mech.Chassis.Position - stoodAt).Magnitude < 1e-3, "Typing in chat drove the mech")
focusedBox = nil
keysDown = {}
-- A thumbstick (the controls' move vector) drives it too, though the
-- controls failed to load the first time.
moveVec = R.Vector3.new(0, 0, -1)
stoodAt = mech.Chassis.Position
frames(60)
check(controlLoads >= 2, "A controls load that failed was never tried again")
check((mech.Chassis.Position - stoodAt).Magnitude > 3, "The thumbstick didn't drive it")
moveVec = nil
frames(120)

-- A wall: it stops short, says so, then pushes through after a moment.
local heading = sent[#sent].Yaw
mech.Data.CFrame = R.CFrame.new(mech.Chassis.Position) -- (facing -Z again)
player:SetAttribute("MechPilot", nil)
frames(1)
player:SetAttribute("MechPilot", "Hauler1")
frames(1)
check(VehicleDrive.isDriving() and heading ~= nil, "Couldn't pick it back up")
wallAt = mech.Chassis.Position.Z - 3 - 8
keysDown = { W = true }
frames(90) -- (8 studs from a standstill: there in about 1.1 s)
check(mech.Chassis.Position.Z - 3 >= wallAt + 0.4 - 1e-3, "Drove into the wall")
frames(75) -- (pushing a moment longer)
check(toasts[#toasts] and toasts[#toasts]:find("pushing through", 1, true), "It never pushed through")
local castsBefore = casts
frames(30)
check(casts == castsBefore and mech.Chassis.Position.Z - 3 < wallAt, "Pushing through didn't get past the wall")
frames(60)
check(casts > castsBefore, "It never went back to checking the way ahead")
wallAt = nil
check(VehicleDrive.shoving() == nil, "A wall counted as a rock to mine")
-- A rock in the way (Shared.WalkMine): it shoves it, and that mines it
-- (Client.OutpostScene asks VehicleDrive.shoving); it never pushes through a
-- rock it's mining, however long. Let go, or the rock's gone, and it isn't.
keysDown = {}
frames(120)
wallAt, wallIsRock = mech.Chassis.Position.Z - 3 - 8, true
local toastsBefore = #toasts
keysDown = { W = true }
frames(90)
check(VehicleDrive.shoving() == rock, "Driving into a rock isn't shoving it")
frames(60 * 4)
check(mech.Chassis.Position.Z - 3 >= wallAt + 0.4 - 1e-3, "Pushed through a rock it was mining")
check(VehicleDrive.shoving() == rock and #toasts == toastsBefore, "Stopped shoving the rock, or said it was pushing through")
keysDown = {}
frames(30)
check(VehicleDrive.shoving() == nil, "Still shoving a rock after letting go")
keysDown = { W = true }
frames(10)
check(VehicleDrive.shoving() == rock, "Driving into it again isn't shoving it")
rock.Parent = nil
check(VehicleDrive.shoving() == nil, "Still shoving a rock that's gone")
rock.Parent = "Nodes"
wallAt, wallIsRock = nil, false
frames(60) -- (W still held: under way again)
-- A cast that fails doesn't hold it still.
castsFail = true
stoodAt = mech.Chassis.Position
frames(30)
check((mech.Chassis.Position - stoodAt).Magnitude > 3, "A failing cast held the mech still")
castsFail = false

-- A server that isn't answering: you're told once, then one report.
quietServer = true
frames(60)
check(said(DEAF) == 0, "Said the server wasn't answering too soon")
frames(90)
check(said(DEAF) == 1, "Didn't say the server isn't answering")
frames(150)
check(#reports == 1 and warned[#warned]:find("isn't hearing", 1, true), "A server that isn't answering wasn't reported")
frames(300)
check(#reports == 1 and said(DEAF) == 1, "Reported or told again in the same ride")
quietServer = false
serverEcho()
frames(1)
keysDown = {}
frames(120)
-- Turning on the spot: the server answers with MechMotion alone.
motionOnly, keysDown = true, { D = true }
frames(60 * 5)
check(said(DEAF) == 1, "Turning on the spot counted as no answer")
check(#reports == 1, "Turning on the spot was reported")
motionOnly, keysDown = false, {}
frames(120)

-- A menu hides HOP OUT, and that's all: it still drives, and you can
-- still get out.
check(hudGui.Enabled, "An always-on screen (the daily caches) hid HOP OUT")
dashboard:setEnabled(true)
keysDown = { W = true }
stoodAt = mech.Chassis.Position
frames(30)
check(not hudGui.Enabled, "HOP OUT stayed over a menu")
check((mech.Chassis.Position - stoodAt).Magnitude > 0.5, "A menu took the controls")
local exitsBefore = exits
clockNow += 1
UserInputService.JumpRequest:Fire()
check(exits == exitsBefore + 1, "Couldn't jump out with a menu open")
dashboard:setEnabled(false)
frames(1)
check(hudGui.Enabled, "HOP OUT didn't come back after the menu")
-- Space, jump and HOP OUT all ask once (Space and jump come together).
clockNow += 1
UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.Space })
UserInputService.JumpRequest:Fire()
check(exits == exitsBefore + 2, "Space didn't ask to get out, or asked twice")
clockNow += 1
check(buttons["HOP OUT"] ~= nil, "No HOP OUT button")
buttons["HOP OUT"].Activated:Fire()
check(exits == exitsBefore + 3, "HOP OUT didn't ask to get out")
-- Not while typing in the chat.
clockNow += 1
focusedBox = {}
UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.Space })
check(exits == exitsBefore + 3, "Typing a space in the chat got you out")
focusedBox = nil
keysDown = {}

-- The server lets go (you're out): it stops driving, the camera comes back.
player:SetAttribute("MechPilot", nil)
local count = #sent
frames(10)
check(not VehicleDrive.isDriving() and not hudGui.Enabled and #sent == count, "Kept driving after being let go")
check(player.CameraMinZoomDistance == 6 and player.CameraMaxZoomDistance == 40, "The camera wasn't given back")
-- Busy (a fight): no driving, even as its pilot.
player:SetAttribute("MechPilot", "Hauler1")
frames(1)
check(VehicleDrive.isDriving(), "Couldn't get back in")
player:SetAttribute("CombatSession", "Duel")
frames(1)
check(not VehicleDrive.isDriving() and not hudGui.Enabled, "Drove in a fight")
player:SetAttribute("CombatSession", nil)
frames(1)
check(VehicleDrive.isDriving(), "Didn't drive again after the fight")
-- (The fight's first-person camera keeps its zoom.)
player.CameraMode = "LockFirstPerson"
player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 0.5, 0.5
player:SetAttribute("CombatSession", "Rival")
frames(1)
check(player.CameraMinZoomDistance == 0.5, "Getting out spoilt the first-person camera")
player.CameraMode = nil
player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 6, 40
player:SetAttribute("CombatSession", nil)
frames(1)
-- A respawn: done with that body.
player.CharacterAdded:Fire({})
check(not VehicleDrive.isDriving(), "Kept driving after a respawn")
-- The mech streamed out: it stops, and picks up again when it's back.
frames(1)
check(VehicleDrive.isDriving(), "Didn't pick the mech up again")
mech.Parent = nil
frames(1)
check(not VehicleDrive.isDriving(), "Drove a mech that streamed out")
mech.Parent = "Machines"
frames(1)
check(VehicleDrive.isDriving(), "Didn't pick the mech up once it was back")
-- A touch screen: a drive stick of its own, bottom left, that drives with
-- Roblox's controls giving nothing (a scene can switch them off on a phone).
-- No auto-jump in the cockpit (a jump is the way out); it comes back after.
check(buttons.DriveStick == nil, "A drive stick without a touch screen")
player:SetAttribute("MechPilot", nil)
frames(1)
UserInputService.TouchEnabled, humanoid.AutoJumpEnabled = true, true
player:SetAttribute("MechPilot", "Hauler1")
frames(1)
local pad, knob, layout = buttons.DriveStick, named.Knob, modules.MobileLayout.Stick
check(pad and pad.Parent == hudGui and knob and knob.Parent == pad, "No drive stick on a touch screen")
check(
	pad.Size.X.Offset == layout.Size
		and pad.Position.X.Offset == layout.Left
		and pad.Position.Y.Offset == -layout.Bottom,
	"The drive stick isn't in its place"
)
check(humanoid.AutoJumpEnabled == false, "Auto-jump stayed on in the cockpit")
pad.AbsolutePosition, pad.AbsoluteSize = R.Vector2.new(20, 172), R.Vector2.new(layout.Size, layout.Size)
local centre = R.Vector3.new(20 + layout.Size / 2, 172 + layout.Size / 2, 0)
local touch = { UserInputType = Enum.UserInputType.Touch, Position = centre + R.Vector3.new(0, -40, 0) }
moveVec = R.Vector3.zero
-- Up: forward.
stoodAt = mech.Chassis.Position
pad.InputBegan:Fire(touch)
frames(60)
check((mech.Chassis.Position - stoodAt).Magnitude > 3 and sent[#sent].Speed > 0, "Pushing the stick up didn't drive it")
check(knob.Position.Y.Offset < -30 and knob.Position.X.Offset == 0, "The stick's knob didn't follow the thumb")
-- Dragged right (well past the rim: as far as it goes): it turns right.
touch.Position = centre + R.Vector3.new(200, 0, 0)
UserInputService.InputChanged:Fire(touch)
frames(30)
check(sent[#sent].Turn < 0, "Dragging the stick right didn't turn it right")
check(math.abs(knob.Position.X.Offset - layout.Size / 2) < 1e-6, "The knob left the stick")
-- Another finger (the camera) moves nothing.
UserInputService.InputChanged:Fire({ UserInputType = Enum.UserInputType.Touch, Position = centre })
check(knob.Position.X.Offset > 0, "Another finger moved the stick")
-- Let go: it stops.
UserInputService.InputEnded:Fire(touch)
frames(120)
check(sent[#sent].Speed == 0 and sent[#sent].Turn == 0, "Letting go of the stick didn't stop it")
check(knob.Position.X.Offset == 0 and knob.Position.Y.Offset == 0, "The knob didn't spring back")
-- A menu over the screen lets go of it (it's hidden), and it stops.
touch.Position = centre + R.Vector3.new(0, -50, 0)
pad.InputBegan:Fire(touch)
frames(10)
dashboard:setEnabled(true)
frames(120)
check(not hudGui.Enabled and sent[#sent].Speed == 0, "A menu over the stick left the mech driving")
dashboard:setEnabled(false)
frames(1)
UserInputService.InputEnded:Fire(touch)
-- Out: auto-jump is back.
player:SetAttribute("MechPilot", nil)
frames(1)
check(humanoid.AutoJumpEnabled == true, "Auto-jump didn't come back after the mech")
player:SetAttribute("MechPilot", "Hauler1")
frames(1)
moveVec = nil

-- No remotes yet: it still drives (and says nothing).
remotesHere = false
keysDown = { W = true }
stoodAt = mech.Chassis.Position
frames(30)
check((mech.Chassis.Position - stoodAt).Magnitude > 1, "Missing remotes stopped it driving")
remotesHere = true
keysDown = {}

print(
	"PASS: "
		.. checks
		.. " vehicle drive checks (the pilot's screen: driving, sending, walls, shoving a rock, a quiet server, menus, getting out, the touch stick)"
)
