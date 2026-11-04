-- lune run tests/spawn_facing_cases.luau <repo>
-- Into every dungeon facing the right way (Server.SpawnFacing, Client
-- SpawnFacing): the character placed level, facing the way in, and the
-- camera swung round behind it looking the same way (a teleport leaves the
-- camera where it was, so forward could be straight back).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local ROOT = process.args[1] or "."
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local checks = 0
local function check(value, message)
	checks += 1
	if not value then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(message) .. "\n")
		process.exit(1)
	end
end
local function near(a, b)
	return (a - b).Magnitude < 1e-3
end
-- (The look of a CFrame facing `dir`, as this CFrame library makes it: lune's
-- lookAt doesn't point its LookVector the way Roblox's does, so facings are
-- compared with its own.)
local function facing(dir)
	return CFrame.lookAt(Vector3.new(), dir).LookVector
end

local env = setmetatable({ CFrame = CFrame, Vector3 = Vector3 }, { __index = _G })
local Server = luau.load(fs.readFile(ROOT .. "/src/server/Systems/SpawnFacing.luau"), { debugName = "SpawnFacing", environment = env })()

-- toward: level, at the spot, facing the target.
local at = Vector3.new(10, 5, 10)
local c = Server.toward(at, Vector3.new(10, 40, 50))
check(near(c.Position, at) and near(c.LookVector, facing(Vector3.new(0, 0, 1))), "toward isn't level, facing the target")
c = Server.toward(at, at)
check(near(c.LookVector, facing(Vector3.new(0, 0, 1))), "toward the same spot isn't a sound facing")

-- place: the character moved there, level, at rest; the client told.
local attributes, pivoted = {}, nil
local root = {
	AssemblyLinearVelocity = Vector3.new(5, 5, 5),
	AssemblyAngularVelocity = Vector3.new(1, 1, 1),
	IsA = function(_, class) return class == "BasePart" end,
}
local character = {
	PivotTo = function(_, cf) pivoted = cf end,
	FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then root else nil end,
}
local player = {
	Character = character,
	GetAttribute = function(_, k) return attributes[k] end,
	SetAttribute = function(_, k, v) attributes[k] = v end,
}
local tilted = CFrame.lookAt(at, at + Vector3.new(1, -1, 0))
Server.place(player, tilted)
local level = Vector3.new(tilted.LookVector.X, 0, tilted.LookVector.Z).Unit
check(pivoted and near(pivoted.Position, at) and math.abs(pivoted.LookVector.Y) < 1e-3 and pivoted.LookVector:Dot(level) > 0.999, "Not placed level, facing the way")
check(near(root.AssemblyLinearVelocity, Vector3.new()) and near(root.AssemblyAngularVelocity, Vector3.new()), "Still moving once placed")
check(attributes.SpawnFace == pivoted and attributes.SpawnFaceN == 1, "The client isn't told of the facing")
Server.place(player, tilted)
check(attributes.SpawnFaceN == 2, "The same spot twice doesn't turn them again")

-- The client's camera: behind the character, above, looking the way it faces.
local client = fs.readFile(ROOT .. "/src/client/SpawnFacing.client.luau")
local from = client:find("local SpawnFacing = {}", 1, true)
local to = client:find("local turns = 0", 1, true)
local Client = luau.load(client:sub(from, to - 1) .. "return SpawnFacing", { debugName = "cameraFor", environment = env })()
for _, dir in { Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0.6, 0, -0.8) } do
	local placed = CFrame.lookAt(at, at + dir)
	local ahead = placed.LookVector -- (where the character faces)
	local cam = Client.cameraFor(placed)
	local back = cam.Position - at
	check(back:Dot(ahead) < -10 and back.Y > 2, "The camera isn't behind and above")
	-- (and looks the way they face: a facing made the same way)
	local look = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z).Unit
	check(look:Dot(facing(ahead)) > 0.99, "The camera doesn't look the way they face")
end
check(client:find('GetAttributeChangedSignal("SpawnFaceN")', 1, true) ~= nil and client:find("camera.CFrame = SpawnFacing.cameraFor", 1, true) ~= nil, "The client doesn't turn the camera")

-- Every dungeon's way in uses it: the Rift (in, and beside a friend), the
-- pathway, open world and beachhead dungeons (in, on to a room, back up),
-- the raids, the kaiju pit.
local uses = {
	["src/server/Systems/RiftServer.luau"] = 3,
	["src/server/Systems/Dungeons.luau"] = 3,
	["src/server/Systems/Raids.luau"] = 1,
	["src/server/Systems/KaijuPitServer.luau"] = 1,
}
for path, count in uses do
	local source = fs.readFile(ROOT .. "/" .. path)
	local _, n = source:gsub("SpawnFacing%.place%(", "")
	check(n >= count, path .. " places only " .. n .. " of its " .. count .. " ways in facing the right way")
end
local rift = fs.readFile(ROOT .. "/src/server/Systems/RiftServer.luau")
check(rift:find("player.Character:PivotTo(spot)", 1, true) == nil, "The Rift's way in still leaves the camera behind")
print(string.format("PASS: %d spawn facing checks (level, facing the way in, the camera behind, in every dungeon)", checks))
process.exit(0)
