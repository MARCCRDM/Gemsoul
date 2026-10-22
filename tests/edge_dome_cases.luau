-- lune run tests/edge_dome_cases.luau <repo>
-- The Outpost's edge for now (client Modules/EdgeDome): a force-field dome
-- over the server's invisible walls (Shared.Outpost.Edge), its panels on
-- the dome, meeting all the way round, facing in; none of it from the
-- middle, more as you come near, lit round where you look; EXPANSION
-- COMING SOON on it straight ahead of you, facing in, in Spanish too.
-- Run by tests/run_edge_dome.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local checks = 0
local function check(ok: any, message: string)
	checks += 1
	assert(ok, message)
end
local function source(path: string): string
	return fs.readFile(ROOT .. "/" .. path)
end
local function has(text: string, piece: string): boolean
	return text:find(piece, 1, true) ~= nil
end

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local env = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	CFrame = CFrame,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Instance = roblox.Instance,
}, { __index = _G })
local Outpost = luau.load(source("src/shared/Outpost.luau"), { debugName = "Outpost", environment = env })()
env.game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return { Shared = { Outpost = Outpost } }
		end
		return { LocalPlayer = {} }
	end,
}
env.require = function(module)
	return module
end
local EdgeDome = luau.load(source("src/client/Modules/EdgeDome.luau"), { debugName = "EdgeDome", environment = env })()

-- Where it stands -------------------------------------------------------------------------------------------
check(Outpost.Edge and Outpost.Edge > Outpost.Radius + 20, "The edge isn't past the quarry's benches")
check(EdgeDome.Radius < Outpost.Edge and EdgeDome.Radius > Outpost.Edge - 4, "The dome isn't on the walls")
local world = source("src/server/World/OutpostWorld.luau")
check(
	has(world, "OutpostWorld.Rules.Edge") and has(world, "math.cos(a) * edge, 40, math.sin(a) * edge"),
	"The walls don't stand at Shared.Outpost.Edge"
)

-- Its panels ---------------------------------------------------------------------------------------------
local R = EdgeDome.Radius
for _, column in { -400, -3, 0, 1, 57, 248 } do
	for row = 0, EdgeDome.Rows - 1 do
		local frame, size = EdgeDome.cell(column, row)
		check(math.abs(frame.Position.Magnitude - R) < 1e-3, "A panel off the dome")
		-- (Facing the middle.)
		check(frame.LookVector:Dot(-frame.Position.Unit) > 0.999, "A panel not facing in")
		check(size.X > 0.5 * EdgeDome.Panel and size.Y > 0.9 * EdgeDome.Panel and size.Z < 1, "A panel's size")
		-- (It reaches its neighbours: no gaps round the edge or up it.)
		local right = EdgeDome.cell(column + 1, row)
		local up = EdgeDome.cell(column, row + 1)
		check((right.Position - frame.Position).Magnitude <= size.X + 1e-3, "A gap between panels round the edge")
		check((up.Position - frame.Position).Magnitude <= size.Y + 1e-3, "A gap between panels up the dome")
	end
end
-- (Round the whole edge, the grid meets itself.)
do
	local first = EdgeDome.cell(0, 0)
	local n = EdgeDome.column(math.pi * 2 - 1e-9) + 1
	local again = EdgeDome.cell(n, 0)
	check((again.Position - first.Position).Magnitude < 1e-3, "The grid doesn't meet itself round the edge")
end
check(EdgeDome.column(0.0001) == 0 and EdgeDome.column(-0.0001) == -1, "Columns round the edge")
-- Its rows reach well over a miner's head.
do
	local top = EdgeDome.cell(0, EdgeDome.Rows - 1)
	check(top.Position.Y > 80, "The dome's too low to read as a dome")
end
-- (Its patch is a handful of parts, not the whole dome.)
check(EdgeDome.Columns * EdgeDome.Rows <= 220, "Too many panels in the patch")

-- How much shows --------------------------------------------------------------------------------------------
check(EdgeDome.reveal(EdgeDome.Near + 1) == 0 and EdgeDome.reveal(400) == 0, "The dome shows from the middle")
check(EdgeDome.reveal(EdgeDome.Full) == 1 and EdgeDome.reveal(0) == 1 and EdgeDome.reveal(-5) == 1, "Up close it isn't all there")
do
	local last = -1
	for gap = EdgeDome.Near, 0, -5 do
		local r = EdgeDome.reveal(gap)
		check(r >= last, "More of it shows further off")
		last = r
	end
end
check(EdgeDome.glow(0, 1) == 1 and EdgeDome.glow(0, 0) == 0, "The glow where you look")
check(EdgeDome.glow(EdgeDome.Spread + 1, 1) == 0, "Lit far from where you look")
check(EdgeDome.glow(20, 1) > EdgeDome.glow(40, 1) and EdgeDome.glow(40, 1) > 0, "The glow doesn't fade out")
check(EdgeDome.glow(30, 0.3) < EdgeDome.glow(30, 1), "Further off, as much lights up")

-- The message --------------------------------------------------------------------------------------------
for _, angle in { 0, 1.1, 2.6, -2, math.pi } do
	local offset = Vector3.new(math.cos(angle) * 430, 8, math.sin(angle) * 430)
	local frame = EdgeDome.facing(offset, 11)
	local flat = Vector3.new(frame.Position.X, 0, frame.Position.Z)
	check(math.abs(frame.Position.Magnitude - (R - 0.6)) < 1e-3, "The message isn't on the dome")
	check(flat.Unit:Dot(Vector3.new(offset.X, 0, offset.Z).Unit) > 0.9999, "The message isn't straight ahead")
	check(frame.LookVector:Dot(-flat.Unit) > 0.999, "The message doesn't face in")
	check(math.abs(frame.UpVector.Y - 1) < 1e-6, "The message isn't upright")
	local low = EdgeDome.Floor + EdgeDome.Message.Y / 2 + 1
	check(math.abs(frame.Position.Y - low) < 0.1, "Low down, the message isn't clear of the benches: " .. frame.Position.Y)
	local high = EdgeDome.facing(offset, 40)
	check(math.abs(high.Position.Y - 40) < 0.1, "Up high, the message isn't at eye height: " .. high.Position.Y)
end
check(EdgeDome.facing(Vector3.zero, 5).Position.Magnitude > R - 1, "From the very middle, no message")
check(EdgeDome.Text == "EXPANSION COMING SOON", "The message doesn't say the expansion's coming")
-- Its board: the words, unseen till it's lit; lit, there; never past its edges.
do
	local gui = roblox.Instance.new("SurfaceGui")
	EdgeDome.board(gui)
	local title, ghost, line = gui:FindFirstChild("Title"), gui:FindFirstChild("Ghost"), gui:FindFirstChild("Line")
	check(title and title.Text == EdgeDome.Text and ghost and ghost.Text == EdgeDome.Text, "No words on the message")
	check(line and line.Text == EdgeDome.Line, "No line under the message")
	check(title.ZIndex > ghost.ZIndex, "The ghost drawn over the words")
	check(title.TextTransparency == 1 and line.TextTransparency == 1, "Seen before it's lit")
	EdgeDome.paint(gui, 0, 3)
	check(title.TextTransparency >= 0.999 and ghost.TextTransparency >= 0.999, "Seen at nothing revealed")
	for _, t in { 0.4, 1.3, 2.61, 7 } do
		EdgeDome.paint(gui, 1, t)
		check(title.TextTransparency <= 0.2 and line.TextTransparency <= 0.3, "Fully revealed, the words don't show")
		check(ghost.TextTransparency > title.TextTransparency, "The ghost as strong as the words")
	end
	EdgeDome.paint(gui, 0.5, 1)
	check(title.TextTransparency > 0.3 and title.TextTransparency < 0.7, "Half revealed, not half there")
	local W, H = EdgeDome.Message.X * EdgeDome.Pixels, EdgeDome.Message.Y * EdgeDome.Pixels
	for _, child in gui:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "Ghost" and child.Name ~= "Scan" then
			local right = child.Position.X.Offset + child.Size.X.Offset
			local bottom = child.Position.Y.Offset + child.Size.Y.Offset
			check(child.Position.X.Offset >= 0 and right <= W and bottom <= H, child.Name .. " off the message")
		end
	end
	for t = 0, 10, 0.37 do
		EdgeDome.paint(gui, 1, t)
		check(gui:FindFirstChild("Scan").Position.Y.Offset >= 0 and gui:FindFirstChild("Scan").Position.Y.Offset < H, "The scan line off the message")
	end
end

-- Wired in, and in Spanish ---------------------------------------------------------------------------------
local lobby = source("src/client/Lobby.client.luau")
check(has(lobby, "require(script.Parent.Modules.EdgeDome).start()"), "The dome never starts")
local module = source("src/client/Modules/EdgeDome.luau")
check(has(module, 'gui.Parent = player:WaitForChild("PlayerGui")'), "The message isn't in PlayerGui (no Spanish)")
check(has(module, "Material = Enum.Material.ForceField") and has(module, "CanCollide = false"), "The panels aren't a field")
check(has(module, 'player:GetAttribute("RiftRun") == nil'), "The dome shows in the Rift")
local es = source("src/shared/LangEs.luau")
check(has(es, '["EXPANSION COMING SOON"]') and has(es, '["NEW GROUND OPENS IN A FUTURE UPDATE"]'), "No Spanish for the dome")

print(string.format("PASS: %d edge dome checks (where it stands, its panels, how much shows, the message, wired in)", checks))
