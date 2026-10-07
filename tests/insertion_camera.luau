-- Run the actual client callbacks; camera rendering itself is not simulated.
local now, callbacks, refreshes, podUpdates = 100, {}, 0, 0
local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, value)
			for _, fn in handlers do
				fn(value)
			end
		end,
	}
end
local function object(kind)
	local attrs = {}
	return {
		Parent = true,
		Kind = kind,
		Enabled = true,
		LocalTransparencyModifier = 0.4,
		SetAttribute = function(_, key, value)
			attrs[key] = value
		end,
		GetAttribute = function(_, key)
			return attrs[key]
		end,
		IsA = function(_, name)
			return name == kind
		end,
	}
end
local cmt = {}
local function cf()
	return setmetatable({ Kind = "CFrame" }, cmt)
end
cmt.__mul = function()
	return cf()
end
cmt.__index = {
	Lerp = function()
		return cf()
	end,
}
local CFrame = { new = cf, Angles = cf }
local function typeof(v)
	return type(v) == "table" and v.Kind or type(v)
end
local Color3 = {
	new = function()
		return {}
	end,
	fromRGB = function()
		return {}
	end,
}
local Vector2 = {
	new = function()
		return {}
	end,
}
local UDim2 = {
	new = function()
		return {}
	end,
	fromScale = function()
		return {}
	end,
}
local Enum = {
	Font = { GothamMedium = 1 },
	CameraType = { Custom = "Custom", Scriptable = "Scriptable" },
	RenderPriority = { Camera = { Value = 200 } },
}
local created = {}
local Instance = {
	new = function(kind)
		local item = object(kind)
		table.insert(created, item)
		return item
	end,
}
local body, root, head, humanoid = object("BasePart"), object("BasePart"), object("BasePart"), object("Humanoid")
root.Position, head.Position, root.CFrame = { Y = 4 }, { Y = 6 }, cf()
humanoid.Health = 100
local character = object("Model")
character.DescendantAdded = signal()
function character:FindFirstChild(name)
	return if name == "Head" then head else root
end
function character:FindFirstChildOfClass()
	return humanoid
end
function character:GetDescendants()
	return { body }
end
local hud = object("ScreenGui")
hud.Name = "CombatHud"
local player = object("Player")
player.Character = character
player.PlayerGui = {
	FindFirstChild = function(_, name)
		return if name == "CombatHud" then hud else nil
	end,
}
function player:WaitForChild()
	return self.PlayerGui
end
local camera = { Parent = true, CameraType = "Custom", CameraSubject = humanoid, FieldOfView = 75, CFrame = cf() }
local workspace = {
	CurrentCamera = camera,
	ChildAdded = signal(),
	GetChildren = function()
		return {}
	end,
	GetServerTimeNow = function()
		return now
	end,
}
local RunService = {
	BindToRenderStep = function(_, name, _, fn)
		callbacks[name] = fn
	end,
}
local Players = { LocalPlayer = player }
local game = {
	GetService = function(_, name)
		return if name == "Players" then Players elseif name == "RunService" then RunService else {}
	end,
}
local Pod = {
	new = function()
		return {
			Ready = true,
			update = function()
				podUpdates += 1
			end,
			destroy = function() end,
		}
	end,
}
local LobbyUI = {
	refresh = function()
		refreshes += 1
	end,
}
local checks = 0
local function check(ok, why)
	checks += 1
	assert(ok, why)
end
-- MODULES HERE
local function frame()
	callbacks.InsertionCameraHandoff()
	callbacks.ArenaInsertionCamera()
end
frame()
check(refreshes == 0, "Idle insertion script refreshed lobby every frame")
local marker = object("Folder")
marker.Name = "OrbitalInsertion"
function marker:FindFirstChild()
	return { Value = character }
end
workspace.ChildAdded:Fire(marker)
-- Rival-only arrival: ordinary camera and viewmodel must retain ownership.
player:SetAttribute("ArenaDropUntil", now + 3)
character:SetAttribute("ArenaDropOrigin", cf())
for i = 1, 120 do
	now += 1 / 60
	local normalPov = cf()
	camera.CFrame = normalPov
	frame()
	check(camera.CFrame == normalPov and camera.CameraType == "Custom", "Rival spawn stole first-person camera")
	check(body.LocalTransparencyModifier == 0.4 and hud.Enabled, "Rival spawn competed with body/HUD visibility")
end
check(podUpdates == 120, "Rival pod stopped rendering when camera stayed in gameplay")
check(refreshes == 0 and camera.FieldOfView == 75, "Rival spawn changed HUD/FOV")
-- Own insertion must still take control, with exactly one handoff boundary.
local start, ends = now, now + Motion.duration(1)
marker:SetAttribute("Start", start)
character:SetAttribute("ArenaDropStart", start)
player:SetAttribute("ArenaDropUntil", ends)
now += 0.3
frame()
check(
	camera.CameraType == "Scriptable" and not hud.Enabled and body.LocalTransparencyModifier == 1,
	"Own pod lost cinematic control"
)
now = ends - Motion.Handoff - 0.05
callbacks.InsertionCameraHandoff()
check(camera.CameraType == "Scriptable", "Native camera resumed before cinematic handoff boundary")
callbacks.ArenaInsertionCamera()
now = ends - Motion.Handoff / 2
frame()
check(camera.CameraType == "Custom", "Own pod never released native camera")
now = ends + 0.01
frame()
check(camera.CameraType == "Custom" and camera.FieldOfView == 75 and hud.Enabled, "Own drop did not restore gameplay")
check(body.LocalTransparencyModifier == 0.4 and refreshes == 1, "Own drop failed single visibility cleanup")
character:SetAttribute("ArenaDropStart", nil)
player:SetAttribute("ArenaDropUntil", now + 3)
local normalPov = cf()
camera.CFrame = normalPov
frame()
check(camera.CFrame == normalPov and refreshes == 1, "Replacement after own drop retriggered camera ownership")
print("PASS: " .. checks .. " real insertion camera callback checks")
