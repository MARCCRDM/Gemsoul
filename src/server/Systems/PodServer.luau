--[[
	Personal pods (Shared.Pods): a pad on the settlement (Server.World.
	OutpostWorld builds them) kept for everyone in the server from the moment
	they join, next to a friend's if a friend is here. The first time they
	come into the Outpost their pod lands on it with them inside: down from
	orbit on its thrusters, a burst of dust on touchdown, then it deploys
	(landing legs, solar wings out, the antenna up, the doors open, the stair
	folds out, the display stall rises) and they walk down the steps. Their
	client films it (Client.PodArrival) from the PodLanding attribute: the
	server time the descent starts. It lifts off when they leave the server.

	Where you start in the Outpost, and come back to (a respawn, a duel, the
	Rift), is the foot of its stair: the player's PodSpawn attribute (a
	CFrame), read by OutpostServer, ArenaSessions, RiftServer and the
	client's loading cover. PodIndex says which pad is theirs.

	  PodServer.start(site)    site: OutpostServer.site() (its Pads)
	  PodServer.land(player) -> boolean   lands their pod with them in it
	                           (false: it's down already, or there's none)
	  PodServer.spawnFor(player) -> CFrame?
	  PodServer.restyle(player)   their pod and yard again, in their style now

	Its style (Shared.PodStyle: the hull's colour, its glow, the showcase's
	kaiju, the yard's decor) comes from PodServer.styleOf(player), the pieces
	they own from PodServer.ownedOf(player) and the showcase's kaiju from
	PodServer.kaijuOf(player, id) (Main: the profile). MY POD (Client.PodUI)
	opens from a prompt on its door, its owner's only, once they've walked
	out of it.

	The pod roll: on its first landing ever, PodServer.rollFor(player) (Main)
	rolls a piece (PodStyle.roll), unlocks it and puts it on; on the way down
	the hull and glow flick through the catalogue, slower and slower, and
	settle on it at touchdown. Every landing after (nil from rollFor) comes
	down in the style they've kept, no flicks. The player's PodRoll attribute says what it was
	("Kind|Id|Rarity|New": Client.PodArrival shows it).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Pods = require(ReplicatedStorage.Shared.Pods)
local PodStyle = require(ReplicatedStorage.Shared.PodStyle)

local PodServer = {}
-- (Main wires these to the profile: its Pod, and its kaiju by id)
PodServer.styleOf = function(_player: Player): any
	return nil
end
PodServer.kaijuOf = function(_player: Player, _id: string): any
	return nil
end
PodServer.ownedOf = function(_player: Player): any
	return nil -- (nil: nothing's checked)
end
PodServer.rollFor = function(_player: Player): any
	return nil -- (the piece rolled: { Kind, Id, Rarity, Name, New })
end
local function styleFor(player: Player)
	return PodStyle.clean(PodServer.styleOf(player), function(id)
		return PodServer.kaijuOf(player, id) ~= nil
	end, PodServer.ownedOf(player))
end

local STEEL = Color3.fromRGB(128, 134, 146)
local DARK = Color3.fromRGB(58, 62, 72)

local pads = {} -- { { Index, Tier, CFrame, Model } }
local byIndex = {}
local taken: { [number]: Player | true } = {} -- (true: a pod still lifting off)
-- Each player's pad, and their pod once it's landed (Entry: its motion).
local podOf: { [Player]: { Index: number, Pad: any, Model: Model?, Entry: any } } = {}
-- Pods on the move: { Model, Rest, Kind ("Land" | "Deploy" | "Lift"), T, ... }
local moving = {}
local rng = Random.new()
local anchor: Vector3? = nil -- (the Shelter: new pods land nearest it)
local scrapped = setmetatable({}, { __mode = "k" }) -- (pods gone for good)

-- A pod gone for good: its pad free again (unless someone has it already).
local function scrap(model: Model, index: number)
	if not scrapped[model] then
		scrapped[model] = true
		model:Destroy()
	end
	if taken[index] == true then
		taken[index] = nil
	end
end
local function standing(model: Model): boolean
	return not scrapped[model] and model.Parent ~= nil
end

local function part(parent, cframe: CFrame, size: Vector3, color: Color3, material, shape: string?)
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	if shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	end
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CFrame, p.Size, p.Color = cframe, size, color
	p.Material = material or Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local UP = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder standing up)

-- Its style on the pod `model` (and its yard `stall`): the hull's colour
-- and material, the glow on the beacon, trim, name and yard lights. A Prism
-- glow is white here; each client runs it round the rainbow (Client.
-- PodShowcase).
local function paint(model: Instance?, style)
	if not model then
		return
	end
	local hull, glow = PodStyle.hull(style), PodStyle.glow(style)
	local roof, frame = PodStyle.roof(style) or hull, PodStyle.frame(style) or DARK
	local ok, found = pcall(function()
		return (Enum.Material :: any)[PodStyle.hullMaterial(style)]
	end)
	local material = if ok and found then found else Enum.Material.SmoothPlastic
	local entry = PodStyle.find("Glow", style and style.Glow)
	model:SetAttribute("Prism", if entry and entry.Prism then true else nil)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local kind = p:GetAttribute("Paint")
			if kind == "Hull" then
				p.Color, p.Material = hull, material
			elseif kind == "Roof" then
				-- (a two-tone roof keeps a plain finish; one the hull's colour takes the hull's)
				p.Color, p.Material = roof, if PodStyle.roof(style) then Enum.Material.SmoothPlastic else material
			elseif kind == "Frame" then
				p.Color, p.Material = frame, Enum.Material.Metal
			elseif kind == "Glow" then
				p.Color = glow
				local light = p:FindFirstChildOfClass("PointLight")
				if light then
					light.Color = glow
				end
			end
		elseif p:IsA("TextLabel") and p.Parent and p.Parent.Name == "Nameplate" then
			p.TextColor3 = glow:Lerp(Color3.new(1, 1, 1), 0.55)
		end
	end
end
PodServer.paint = paint

-- The pod, built standing on `pad` (its door toward the middle): a white
-- habitat module with a rounded roof, warm-lit double doors and windows,
-- an antenna with a beacon in the owner's colour, a stair down to the pad
-- and blue thrusters under it (lit only in flight). Its display stall
-- stands beside it once it's down (`display`).
local WHITE = Color3.fromRGB(226, 228, 232)
local WARM = Color3.fromRGB(255, 196, 96)
local JET = Color3.fromRGB(120, 190, 255)
local CYAN = Color3.fromRGB(110, 220, 255)
local SOLAR = Color3.fromRGB(38, 54, 96)
local function build(player: Player, pad): (Model, { any })
	local f = pad.CFrame
	local style = styleFor(player)
	local color = PodStyle.glow(style)
	local hullColor = WHITE -- (painted in its style once built: `paint`)
	-- (drawn at Pods.Scale: these are the sizes before it)
	local K = Pods.Scale
	local function F(x, y, z)
		return f * CFrame.new(x * K, y * K, z * K)
	end
	local function V(x, y, z)
		return Vector3.new(x * K, y * K, z * K)
	end
	local w, d, base = Pods.Width / K, Pods.Hull * 2 / K, Pods.Base / K
	local model = Instance.new("Model")
	model.Name = "Pod"
	-- What moves as it deploys, each built where it ends up (open): `delta`
	-- (studs, in the pod's frame) back to where it's stowed, the share of
	-- the deploy it moves in (`from`, `to`), and its phase ("Legs" on the
	-- way down, "Deploy" on the pad).
	local moves = {}
	local function stow(p: BasePart, phase: string, delta: Vector3, from: number, to: number)
		table.insert(moves, { Part = p, Phase = phase, Delta = delta, From = from, To = to })
		return p
	end
	-- the skirt it stands on (up off the pad on its legs), the body and its rounded roof
	local skirt = part(model, F(0, base * 0.65, 0), V(w - 1, base * 0.7, d - 0.6), DARK, Enum.Material.Metal)
	skirt.CanCollide, skirt.CanQuery = true, true
	local body = part(model, F(0, base + 2.3, 0), V(w, 4.6, d), hullColor, Enum.Material.SmoothPlastic)
	body.Name = "Hull"
	body.CanCollide, body.CanQuery = true, true
	model.PrimaryPart = body
	local roofY = base + 4.6
	part(model, F(0, roofY + 0.7, 0), V(w, 1.4, d - 2.8), hullColor, Enum.Material.SmoothPlastic):SetAttribute("Paint", "Roof")
	for _, side in { -1, 1 } do
		-- (a cylinder lies along X: the roof's rounded edges)
		part(model, F(0, roofY, side * (d / 2 - 1.4)), V(w, 2.8, 2.8), hullColor, Enum.Material.SmoothPlastic, "Cylinder"):SetAttribute("Paint", "Roof")
		-- dark end panels and a trim band round the bottom
		part(model, F(side * (w / 2 + 0.05), base + 2.6, 0), V(0.3, 5, d - 1), DARK, Enum.Material.Metal)
	end
	part(model, F(0, base + 0.35, 0), V(w + 0.2, 0.5, d + 0.2), DARK, Enum.Material.Metal)
	-- its glow: a trim line round the hull over the band
	part(model, F(0, base + 0.68, 0), V(w + 0.24, 0.14, d + 0.24), color, Enum.Material.Neon).Name = "Trim"
	-- the front: double doors and two windows, lit warm
	local front = -d / 2
	part(model, F(0, base + 2.1, front - 0.1), V(3.8, 4.1, 0.3), DARK, Enum.Material.Metal)
	local door = part(model, F(0, base + 2, front - 0.2), V(3.1, 3.7, 0.2), WARM, Enum.Material.Neon)
	door.Name = "Door"
	-- (its two leaves slide apart as it deploys)
	for _, side in { -1, 1 } do
		local leaf = part(model, F(side * (0.78 + 1.3), base + 2, front - 0.4), V(1.55, 3.7, 0.15), hullColor, Enum.Material.SmoothPlastic)
		leaf.Name = "DoorLeaf"
		stow(leaf, "Deploy", V(-side * 1.3, 0, 0), 0.22, 0.5)
	end
	for _, side in { -1, 1 } do
		part(model, F(side * 3.9, base + 2.7, front - 0.1), V(1.9, 1.8, 0.3), DARK, Enum.Material.Metal)
		part(model, F(side * 3.9, base + 2.7, front - 0.2), V(1.5, 1.4, 0.2), WARM, Enum.Material.Neon)
	end
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = WARM, 14, 0.9
	glow.Parent = door
	-- the roof: a vent box and the antenna with its beacon
	part(model, F(0, roofY + 1.7, 1.2), V(2, 0.6, 1.6), STEEL, Enum.Material.Metal)
	local mast = part(model, F(1.4, roofY + 2.5, -0.6), V(0.3, 2.2, 0.3), DARK, Enum.Material.Metal)
	stow(mast, "Deploy", V(0, -1.8, 0), 0.05, 0.35)
	local beacon = part(model, F(1.4, roofY + 3.9, -0.6), V(0.8, 0.8, 0.8), color, Enum.Material.Neon)
	beacon.Name = "Beacon"
	stow(beacon, "Deploy", V(0, -1.8, 0), 0.05, 0.35)
	-- the solar wings: folded flat on the roof, swung out over the ends
	for _, side in { -1, 1 } do
		local wing = part(model, F(side * (w / 2 + 1.5), roofY + 1.5, 0), V(3, 0.18, d - 3.4), SOLAR, Enum.Material.SmoothPlastic)
		wing.Name = "Wing"
		table.insert(moves, {
			Part = wing,
			Phase = "Deploy",
			Hinge = F(side * (w / 2), roofY + 1.5, 0),
			Arm = CFrame.new(-side * 1.5 * K, 0, 0),
			Side = side,
			From = 0.1,
			To = 0.5,
		})
		part(model, F(side * (w / 2 - 0.05), roofY + 1.5, 0), V(0.3, 0.3, d - 3), DARK, Enum.Material.Metal)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, 16, 1.2
	light.Parent = beacon
	-- the stair down from the doors to the pad
	local steps = 4
	local run = Pods.Ramp / K / steps
	for i = 1, steps do
		local top = base * (1 - (i - 1) / steps)
		local step = part(
			model,
			F(0, top / 2, front - (i - 0.5) * run),
			V(3.6, top, run),
			STEEL,
			Enum.Material.DiamondPlate
		)
		step.Name = if i == 1 then "Ramp" else "Step"
		step.CanCollide, step.CanQuery = true, true
		stow(step, "Deploy", V(0, 0, i * run), 0.45 + (i - 1) * 0.07, 0.75 + (i - 1) * 0.07)
	end
	for _, side in { -1, 1 } do
		local from = (F(side * 1.9, base + 1.2, front - 0.2)).Position
		local to = (F(side * 1.9, 1.2, front - Pods.Ramp / K)).Position
		local rail = part(model, CFrame.lookAt((from + to) / 2, to), Vector3.new(0.15 * K, 0.15 * K, (to - from).Magnitude), DARK, Enum.Material.Metal)
		stow(rail, "Deploy", V(0, 0, Pods.Ramp / K), 0.6, 0.98)
	end
	-- the landing legs, out of the skirt on the way down
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local at = F(x * (w / 2 - 1.3), base * 0.45, z * (d / 2 - 1))
			local leg = part(model, at, V(0.7, base * 0.9, 0.7), STEEL, Enum.Material.Metal)
			leg.Name = "Leg"
			stow(leg, "Legs", V(0, base * 0.55, 0), 0, 1)
			local foot = part(model, at * CFrame.new(0, -base * 0.42 * K, 0), V(1.5, 0.25, 1.5), DARK, Enum.Material.Metal)
			stow(foot, "Legs", V(0, base * 0.55, 0), 0, 1)
		end
	end
	-- the thrusters, lit only on the way down or up
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local jet = part(model, F(x * (w / 2 - 1.6), -1.1, z * (d / 2 - 1.4)), V(0.9, 2.2, 0.9), JET, Enum.Material.Neon)
			jet.Name = "Thruster"
			jet.Transparency = 1
		end
	end
	-- whose it is (sized in studs: small from afar)
	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.new(7, 0, 1.1, 0)
	plate.StudsOffsetWorldSpace = V(0, 4.6 + 1.2, 0)
	plate.MaxDistance = 90
	plate.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55)
	label.TextStrokeColor3 = Color3.fromRGB(20, 22, 30)
	label.TextStrokeTransparency = 0.3
	label.Text = player.DisplayName
	label.Parent = plate
	plate.Parent = body
	-- the roar on the way down
	local roar = Instance.new("Sound")
	roar.Name = "Thrust"
	roar.SoundId = "rbxasset://sounds/action_falling.mp3"
	roar.Volume, roar.RollOffMaxDistance = 0.7, 260
	roar.Parent = body
	-- (what its style colours: the hull, its roof, its frame and its glow)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Paint") == nil then
			if p.Color == hullColor and p.Material == Enum.Material.SmoothPlastic then
				p:SetAttribute("Paint", "Hull")
			elseif p.Name == "Beacon" or p.Name == "Trim" then
				p:SetAttribute("Paint", "Glow")
			elseif p.Color == DARK and p.Material == Enum.Material.Metal and p.Name ~= "Skirt" then
				p:SetAttribute("Paint", "Frame")
			end
		end
	end
	-- (its body solid to the camera: Roblox's pulls in in front of it, never
	-- through it)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Size.Magnitude > 6 and p.Transparency < 0.5 then
			p.CanQuery = true
		end
	end
	model:SetAttribute("OwnerId", player.UserId)
	paint(model, style)
	model.Parent = pad.Model
	return model, moves
end

-- MY POD, on its door (its owner's: the client hides it from the rest),
-- once it's open and they've walked out of it.
local function prompt(model: Model, owner: Player)
	local door = model:FindFirstChild("Door")
	if not door or door:FindFirstChild("PodPrompt") then
		return
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "PodPrompt"
	p.ActionText, p.ObjectText = "Customize", "MY POD"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p:SetAttribute("PromptKind", "Pod")
	p:SetAttribute("OwnerId", owner.UserId)
	p.Parent = door
end

-- The display stall beside the pod, once it's down: posts, an awning lit
-- warm underneath, a counter (where the owner's favourite things will go)
-- and a couple of crates.
local WOOD = Color3.fromRGB(120, 86, 58)
-- The front yard's pieces (Shared.PodStyle.Decor), each at `at` (on the
-- pad, facing out toward the middle), in the pod's glow `glow`.
local DECOR = {}
function DECOR.Lamps(m, at: CFrame, glow: Color3)
	for _, dx in { -1.3, 1.3 } do
		part(m, at * CFrame.new(dx, 2, 0), Vector3.new(0.35, 4, 0.35), DARK, Enum.Material.Metal)
		local cap = part(m, at * CFrame.new(dx, 4.2, 0), Vector3.new(0.9, 0.5, 0.9), glow, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = glow, 10, 0.8
		light.Parent = cap
	end
end
function DECOR.Planter(m, at: CFrame, glow: Color3)
	part(m, at * CFrame.new(0, 0.6, 0), Vector3.new(3, 1.2, 1.8), DARK, Enum.Material.Metal)
	for i, spec in { { -0.8, 2.6, 0.2 }, { 0.3, 3.4, -0.25 }, { 0.95, 2.2, 0.35 } } do
		part(m, at * CFrame.new(spec[1], 1.2 + spec[2] / 2, 0) * CFrame.Angles(0, i, spec[3]), Vector3.new(0.6, spec[2], 0.6), glow, Enum.Material.Neon)
	end
end
function DECOR.Flag(m, at: CFrame, glow: Color3)
	part(m, at * CFrame.new(0, 3.6, 0), Vector3.new(0.25, 7.2, 0.25), STEEL, Enum.Material.Metal)
	part(m, at * CFrame.new(0, 7.3, 0), Vector3.new(0.45, 0.45, 0.45), glow, Enum.Material.Neon, "Ball")
	part(m, at * CFrame.new(1.1, 6, 0), Vector3.new(2, 2.4, 0.08), glow, Enum.Material.Fabric)
end
function DECOR.Crates(m, at: CFrame, _glow: Color3)
	part(m, at * CFrame.new(-0.6, 0.8, 0), Vector3.new(1.6, 1.6, 1.6), WOOD, Enum.Material.WoodPlanks)
	part(m, at * CFrame.new(-0.4, 2.2, 0.1) * CFrame.Angles(0, 0.4, 0), Vector3.new(1.2, 1.2, 1.2), WOOD, Enum.Material.WoodPlanks)
	part(m, at * CFrame.new(1.1, 0.8, 0) * UP, Vector3.new(1.6, 1.2, 1.2), Color3.fromRGB(128, 76, 50), Enum.Material.CorrodedMetal, "Cylinder")
end
function DECOR.Drill(m, at: CFrame, glow: Color3)
	part(m, at * CFrame.new(0, 0.5, 0), Vector3.new(2.2, 1, 2.2), DARK, Enum.Material.Metal)
	part(m, at * CFrame.new(0, 2.4, 0), Vector3.new(0.4, 3, 0.4), Color3.fromRGB(240, 178, 48), Enum.Material.Metal)
	part(m, at * CFrame.new(0, 3.9, 0) * UP, Vector3.new(1.4, 1, 1), STEEL, Enum.Material.Metal, "Cylinder")
	part(m, at * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(180)), Vector3.new(0.6, 1.2, 0.6), glow, Enum.Material.Neon)
end
function DECOR.Scope(m, at: CFrame, _glow: Color3)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		part(m, at * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.2, 0.7) * CFrame.Angles(math.rad(-20), 0, 0), Vector3.new(0.18, 2.6, 0.18), DARK, Enum.Material.Metal)
	end
	part(m, at * CFrame.new(0, 2.8, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.Angles(0, math.rad(90), 0) * UP * CFrame.Angles(0, 0, math.rad(-90)),
		Vector3.new(2.6, 0.6, 0.6), STEEL, Enum.Material.Metal, "Cylinder")
end

function DECOR.Spire(m, at: CFrame, glow: Color3)
	part(m, at * CFrame.new(0, 0.4, 0), Vector3.new(2.4, 0.8, 2.4), DARK, Enum.Material.Metal)
	-- (a tall crystal and two small ones leaning off it, lit from inside)
	local core = part(m, at * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(0.9, 5.2, 0.9), glow, Enum.Material.Neon)
	part(m, at * CFrame.new(0, 6.3, 0) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(45), 0, 0), Vector3.new(0.64, 0.64, 0.64), glow, Enum.Material.Neon)
	for _, spec in { { -0.75, 1.9, 0.35 }, { 0.8, 1.5, -0.4 } } do
		part(m, at * CFrame.new(spec[1], 0.8 + spec[2] / 2, 0) * CFrame.Angles(0, 0.6, spec[3]), Vector3.new(0.5, spec[2], 0.5), glow, Enum.Material.Glass)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = glow, 14, 1.1
	light.Parent = core
end
function DECOR.Bench(m, at: CFrame, _glow: Color3)
	for _, dx in { -1.1, 1.1 } do
		part(m, at * CFrame.new(dx, 0.5, 0), Vector3.new(0.3, 1, 1), DARK, Enum.Material.Metal)
		part(m, at * CFrame.new(dx, 1.4, 0.45), Vector3.new(0.25, 1.6, 0.25), DARK, Enum.Material.Metal)
	end
	part(m, at * CFrame.new(0, 1.05, 0), Vector3.new(3, 0.2, 1.1), WOOD, Enum.Material.WoodPlanks)
	part(m, at * CFrame.new(0, 1.9, 0.5) * CFrame.Angles(math.rad(-12), 0, 0), Vector3.new(3, 0.6, 0.15), WOOD, Enum.Material.WoodPlanks)
end
function DECOR.Dish(m, at: CFrame, glow: Color3)
	part(m, at * CFrame.new(0, 0.3, 0), Vector3.new(1.6, 0.6, 1.6), DARK, Enum.Material.Metal)
	part(m, at * CFrame.new(0, 1.6, 0), Vector3.new(0.35, 2.4, 0.35), STEEL, Enum.Material.Metal)
	local tilt = at * CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(-40), 0, 0)
	part(m, tilt * UP, Vector3.new(0.25, 3, 3), Color3.fromRGB(224, 228, 236), Enum.Material.SmoothPlastic, "Cylinder")
	part(m, tilt * CFrame.new(0, 0.9, 0), Vector3.new(0.12, 1.6, 0.12), STEEL, Enum.Material.Metal)
	part(m, tilt * CFrame.new(0, 1.75, 0), Vector3.new(0.35, 0.35, 0.35), glow, Enum.Material.Neon, "Ball")
end
function DECOR.Cart(m, at: CFrame, glow: Color3)
	local rust = Color3.fromRGB(128, 76, 50)
	part(m, at * CFrame.new(0, 1.2, 0), Vector3.new(2.6, 1.2, 1.6), rust, Enum.Material.CorrodedMetal)
	part(m, at * CFrame.new(0, 1.85, 0), Vector3.new(2.8, 0.15, 1.8), DARK, Enum.Material.Metal)
	for _, dx in { -0.85, 0.85 } do
		for _, dz in { -0.85, 0.85 } do
			part(m, at * CFrame.new(dx, 0.45, dz), Vector3.new(0.25, 0.9, 0.9), DARK, Enum.Material.Metal, "Cylinder")
		end
	end
	-- (heaped with gems: the glow's and a few of the elements')
	local colors = { glow, Color3.fromRGB(255, 92, 60), Color3.fromRGB(90, 170, 255), Color3.fromRGB(255, 214, 50), glow }
	for i, spec in { { -0.8, 0.2, 0.3 }, { -0.2, -0.3, 0.9 }, { 0.4, 0.25, 0.5 }, { 0.9, -0.2, 1.2 }, { 0.05, 0.1, 1.6 } } do
		part(m, at * CFrame.new(spec[1], 2.1, spec[2]) * CFrame.Angles(spec[3], spec[3] * 2, 0.4), Vector3.new(0.55, 0.55, 0.55), colors[i], Enum.Material.Neon)
	end
end
function DECOR.Holo(m, at: CFrame, glow: Color3)
	part(m, at * CFrame.new(0, 0.3, 0), Vector3.new(1.4, 0.6, 1.4), DARK, Enum.Material.Metal)
	part(m, at * CFrame.new(0, 0.62, 0), Vector3.new(1, 0.06, 1), glow, Enum.Material.Neon)
	local panel = part(m, at * CFrame.new(0, 2.6, 0), Vector3.new(2.8, 1.8, 0.05), glow, Enum.Material.Glass)
	panel.Transparency = 0.6
	for _, edge in { { 0, 0.92, 2.8, 0.08 }, { 0, -0.92, 2.8, 0.08 }, { -1.4, 0, 0.08, 1.9 }, { 1.4, 0, 0.08, 1.9 } } do
		part(m, at * CFrame.new(edge[1], 2.6 + edge[2], 0), Vector3.new(edge[3], edge[4], 0.08), glow, Enum.Material.Neon)
	end
	-- (a gem drawn on it)
	part(m, at * CFrame.new(0, 2.6, -0.04) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.6, 0.6, 0.04), glow, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		local beam = part(m, at * CFrame.new(side * 0.45, 1.5, 0) * CFrame.Angles(0, 0, side * 0.35), Vector3.new(0.05, 1.8, 0.05), glow, Enum.Material.Neon)
		beam.Transparency = 0.5
	end
end
function DECOR.Meteor(m, at: CFrame, glow: Color3)
	-- a crater ring, the rock half sunk in it, lit cracks across it
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		part(m, at * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.2, 1.6) * CFrame.Angles(math.rad(-20), 0, 0), Vector3.new(1.1, 0.4, 0.6), DARK, Enum.Material.Slate)
	end
	local rock = part(m, at * CFrame.new(0, 1, 0), Vector3.new(2.4, 2.4, 2.4), Color3.fromRGB(46, 42, 48), Enum.Material.Basalt, "Ball")
	for i, spec in { { 0.2, 0.3 }, { 1.4, -0.4 }, { 2.6, 0.5 }, { 4, -0.2 }, { 5.2, 0.35 } } do
		part(m, at * CFrame.new(0, 1.05, 0) * CFrame.Angles(spec[2], spec[1], 0) * CFrame.new(0, 0, -1.18), Vector3.new(0.14, 1.4 + (i % 2) * 0.4, 0.06), glow, Enum.Material.Neon)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = glow, 12, 1.2
	light.Parent = rock
end
local GOLD = Color3.fromRGB(255, 196, 72)
function DECOR.Statue(m, at: CFrame, glow: Color3)
	-- a golden kaiju rearing up on a plinth, its eyes in the pod's glow
	part(m, at * CFrame.new(0, 0.5, 0), Vector3.new(2.6, 1, 2.2), DARK, Enum.Material.Metal)
	part(m, at * CFrame.new(0, 1.05, 0), Vector3.new(2.8, 0.1, 2.4), GOLD, Enum.Material.Metal)
	local body = at * CFrame.new(0, 2.6, 0.2) * CFrame.Angles(math.rad(-18), 0, 0)
	part(m, body, Vector3.new(1.5, 2.4, 1.3), GOLD, Enum.Material.Metal)
	part(m, body * CFrame.new(0, 1.6, -0.35), Vector3.new(1.2, 1, 1.4), GOLD, Enum.Material.Metal) -- head
	part(m, body * CFrame.new(0, 1.4, -1.2), Vector3.new(0.8, 0.5, 0.7), GOLD, Enum.Material.Metal) -- snout
	for _, side in { -1, 1 } do
		part(m, body * CFrame.new(side * 0.35, 1.8, -1.06), Vector3.new(0.2, 0.2, 0.08), glow, Enum.Material.Neon) -- eye
		part(m, body * CFrame.new(side * 0.4, 2.3, -0.1) * CFrame.Angles(math.rad(-30), 0, side * 0.3), Vector3.new(0.22, 0.8, 0.22), GOLD, Enum.Material.Metal) -- horn
		part(m, at * CFrame.new(side * 0.55, 1.6, 0.4), Vector3.new(0.55, 1.1, 0.7), GOLD, Enum.Material.Metal) -- leg
		part(m, body * CFrame.new(side * 0.95, 0.4, -0.5) * CFrame.Angles(math.rad(-50), 0, side * 0.4), Vector3.new(0.35, 1.2, 0.35), GOLD, Enum.Material.Metal) -- claw
	end
	part(m, at * CFrame.new(0, 1.6, 1.4) * CFrame.Angles(math.rad(60), 0, 0), Vector3.new(0.5, 1.8, 0.5), GOLD, Enum.Material.Metal) -- tail
end

local function display(pad, style): Model
	local f = pad.CFrame
	local K = Pods.Scale
	local function F(x, y, z)
		return f * CFrame.new(x * K, y * K, z * K)
	end
	local function V(x, y, z)
		return Vector3.new(x * K, y * K, z * K)
	end
	local stall = Instance.new("Model")
	stall.Name = "Display"
	local x, z = Pods.Width / K / 2 + 1.7, 0.8
	local counter = part(stall, F(x, 0.6, z - 1), V(2.8, 1.2, 2), WOOD, Enum.Material.WoodPlanks)
	counter.Name = "Counter"
	counter.CanCollide, counter.CanQuery = true, true
	part(stall, F(x, 1.25, z - 1), V(3, 0.1, 2.2), DARK, Enum.Material.Metal)
	for _, dx in { -1.4, 1.4 } do
		part(stall, F(x + dx, 1.8, z - 2.2), V(0.25, 3.6, 0.25), DARK, Enum.Material.Metal)
		part(stall, F(x + dx, 1.8, z + 0.4), V(0.25, 3.6, 0.25), DARK, Enum.Material.Metal)
	end
	part(stall, F(x, 3.7, z - 0.9) * CFrame.Angles(math.rad(-12), 0, 0), V(3.6, 0.25, 3.4), DARK, Enum.Material.Metal)
	local strip = part(stall, F(x, 3.4, z - 2.4), V(3.4, 0.18, 0.18), WARM, Enum.Material.Neon)
	local lamp = Instance.new("PointLight")
	lamp.Color, lamp.Range, lamp.Brightness = WARM, 10, 0.8
	lamp.Parent = strip
	part(stall, F(x + 0.2, 0.5, z + 1.4), V(1, 1, 1), WOOD, Enum.Material.WoodPlanks)
	part(stall, F(x - 1, 0.4, z + 1.6) * CFrame.Angles(0, math.rad(20), 0), V(0.8, 0.8, 0.8), WOOD, Enum.Material.WoodPlanks)
	local cyan = part(stall, F(x - 1, 1.55, z - 1.5), V(0.35, 0.5, 0.35), CYAN, Enum.Material.Neon)
	cyan.Name = "Lantern"
	-- The yard: the showcase's pedestal (its kaiju is each client's to build,
	-- Client.PodShowcase, from the Showcase attributes) and a decor spot each
	-- side of the stair.
	style = style or PodStyle.default()
	local glow = PodStyle.glow(style)
	local slots = PodStyle.Slots
	local plinthAt = f * CFrame.new(slots.Showcase.X, 0, slots.Showcase.Z)
	local plinth = part(stall, plinthAt * CFrame.new(0, 0.7, 0), Vector3.new(2.6, 1.4, 2.6), DARK, Enum.Material.Metal)
	plinth.Name = "Showcase"
	plinth.CanCollide = true
	part(stall, plinthAt * CFrame.new(0, 1.43, 0) * UP, Vector3.new(0.06, 2.4, 2.4), glow, Enum.Material.Neon, "Cylinder").Name = "ShowcaseGlow"
	local holo = Instance.new("PointLight")
	holo.Color, holo.Range, holo.Brightness = glow, 9, 0.7
	holo.Parent = plinth
	for _, slot in { "Left", "Right" } do
		local spot = slots[slot]
		local build = DECOR[style[slot]]
		if build then
			local piece = Instance.new("Model")
			piece.Name = "Decor" .. slot
			build(piece, f * CFrame.new(spot.X, 0, spot.Z), glow)
			piece.Parent = stall
		end
	end
	-- (what its glow colours: Client.PodShowcase runs a Prism glow round)
	for _, p in stall:GetDescendants() do
		if p:IsA("BasePart") and p.Color == glow and p.Material == Enum.Material.Neon then
			p:SetAttribute("Paint", "Glow")
		end
	end
	local entry = PodStyle.find("Glow", style.Glow)
	stall:SetAttribute("Prism", if entry and entry.Prism then true else nil)
	stall.Parent = pad.Model
	return stall
end
local STALL_SINK = 4.6 * Pods.Scale -- (how far under the pad it waits to rise)

-- The showcase's kaiju, for each client to build on its pedestal.
local function showcase(stall: Model, player: Player, style)
	local record = style and style.Showcase and PodServer.kaijuOf(player, style.Showcase)
	stall:SetAttribute("ShowcaseSpecies", if record then record.Species else nil)
	stall:SetAttribute("ShowcaseElement", if record then record.Element else nil)
	stall:SetAttribute("ShowcaseName", if record then (record.Name or record.Species) else nil)
	stall:SetAttribute("ShowcaseLevel", if record then record.Level else nil)
end

local function ease(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
-- Where a moving part is in the pod's frame (its rest on the pad), `e` of
-- the way from stowed (0) to out (1).
local function placeOf(entry, move, e: number): CFrame
	if move.Hinge then
		local angle = -move.Side * math.pi * 0.94 * e
		return move.HingeRel * CFrame.Angles(0, 0, angle) * move.Arm
	end
	return CFrame.new(move.Delta * (1 - e)) * move.Open
end
-- Every moving part of `phase` to `t` (0..1 of it), the pod `height` up.
local function pose(entry, phase: string, t: number, height: number)
	local at = CFrame.new(0, height, 0) * entry.Rest
	for _, move in entry.Moves do
		if move.Phase == phase then
			local e = ease((t - move.From) / math.max(0.01, move.To - move.From))
			move.Part.CFrame = at * placeOf(entry, move, e)
		end
	end
end

-- (the pod's pivot is its Hull, `Rest` where it stands on the pad)
local function setHeight(entry, height: number)
	if standing(entry.Model) and entry.Model.PrimaryPart then
		entry.Model:PivotTo(CFrame.new(0, height, 0) * entry.Rest) -- (world up: the hull stands turned)
	end
end
local function thruster(model: Model, on: boolean)
	for _, jet in model:GetChildren() do
		if jet.Name == "Thruster" then
			(jet :: BasePart).Transparency = if on then 0.15 else 1
		end
	end
	local roar = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Thrust")
	if roar then
		pcall(function()
			if on then
				(roar :: Sound):Play()
			else
				(roar :: Sound):Stop()
			end
		end)
	end
end
local function serverNow(): number
	local ok, t = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

-- The rider: held inside the hull while it comes down and opens up.
local function carry(entry, height: number)
	local player = entry.Rider
	if not player then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not player:GetAttribute("Outpost") then
		return
	end
	-- (taken off somewhere else meanwhile, the Rift or a fight: let go of
	-- them where they are, the cinematic over)
	if player:GetAttribute("RiftRun") or player:GetAttribute("CombatSession") or player:GetAttribute("MatchId") then
		entry.Rider = nil
		player:SetAttribute("PodLanding", nil)
		root.Anchored = false
		return
	end
	root.Anchored = true
	character:PivotTo(CFrame.new(0, height, 0) * entry.Rest * CFrame.new(0, -0.3 * Pods.Scale, 0.8 * Pods.Scale))
end
-- Out at the top of the stair, walking down it (the camera's theirs again).
local function release(entry)
	local player = entry.Rider
	entry.Rider = nil
	if not player then
		return
	end
	player:SetAttribute("PodLanding", nil)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root then
		return
	end
	root.Anchored = false
	if player:GetAttribute("Outpost") then
		local pad = entry.Pad
		character:PivotTo(pad * CFrame.new(0, Pods.Base + 3, -(Pods.Hull + 0.6)))
		root.AssemblyLinearVelocity = Vector3.zero
		if humanoid then
			humanoid:MoveTo(Pods.spawnAt(pad).Position)
		end
	end
end

-- A puff of moon dust round the pad as it touches down.
local function dust(pad: CFrame)
	local puff = Instance.new("Part")
	puff.Name = "TouchdownDust"
	puff.Anchored, puff.CanCollide, puff.CanTouch, puff.CanQuery = true, false, false, false
	puff.Transparency = 1
	puff.Size = Vector3.new(16, 1, 16)
	puff.CFrame = pad * CFrame.new(0, 0.5, 0)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(176, 178, 188))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 11) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.2, 2.2)
	smoke.Speed = NumberRange.new(14, 26)
	smoke.SpreadAngle = Vector2.new(90, 8)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Drag = 3
	smoke.Rate = 0
	smoke.Parent = puff
	local thud = Instance.new("Sound")
	thud.SoundId = "rbxasset://sounds/collide.wav"
	thud.Volume, thud.RollOffMaxDistance = 1, 200
	thud.Parent = puff
	puff.Parent = workspace
	pcall(function()
		smoke:Emit(60)
		thud:Play()
	end)
	task.delay(3, function()
		puff:Destroy()
	end)
end

-- Down on the pad: dust, the stall waiting under it, then it deploys.
local function touchdown(entry)
	entry.Flip = nil
	paint(entry.Model, entry.Style) -- (the roll settles)
	setHeight(entry, 0)
	pose(entry, "Legs", 1, 0)
	thruster(entry.Model, false)
	dust(entry.Pad)
	if not entry.Display and entry.PadInfo then
		local stall = display(entry.PadInfo, entry.Style)
		entry.Display = stall
		if entry.Rider then
			showcase(stall, entry.Rider, entry.Style)
		end
		entry.StallRest = {}
		for _, p in stall:GetDescendants() do
			if p:IsA("BasePart") then
				entry.StallRest[p] = p.CFrame
				p.CFrame = CFrame.new(0, -STALL_SINK, 0) * p.CFrame
			end
		end
	end
	entry.Kind, entry.T = "Deploy", 0
end
-- Open: everything out, the rider out, the stall up.
local function deployed(entry)
	pose(entry, "Deploy", 1, 0)
	for p, rest in entry.StallRest or {} do
		p.CFrame = rest
	end
	entry.Model:SetAttribute("Landed", true)
	release(entry)
	if entry.Owner and entry.Owner.Parent then
		prompt(entry.Model, entry.Owner)
	end
end

-- The roll on the way down: a random hull and glow from the catalogue, the
-- next sooner at first and slower as it nears the pad (Pods.flickAfter).
local function shuffle(entry)
	local hulls, glows = PodStyle.Hulls, PodStyle.Glows
	local look = {
		Hull = hulls[rng:NextInteger(1, #hulls)].Id,
		Glow = glows[rng:NextInteger(1, #glows)].Id,
	}
	-- (never what it'll land as: the settle reads as a change)
	if look.Hull == entry.Style.Hull and look.Glow == entry.Style.Glow then
		look.Hull = hulls[(table.find(hulls, PodStyle.find("Hull", look.Hull)) or 0) % #hulls + 1].Id
	end
	paint(entry.Model, look)
	local next = entry.T + Pods.flickAfter(entry.T)
	entry.Flip = if next < Pods.Landing.Fall - 0.15 then next else nil
end

-- One step of everything on the move (RunService.Heartbeat).
function PodServer._step(dt: number)
	local landing = Pods.Landing
	for i = #moving, 1, -1 do
		local entry = moving[i]
		entry.T += dt
		if not standing(entry.Model) then
			table.remove(moving, i)
		elseif entry.Kind == "Land" then
			if entry.T >= landing.Fall then
				touchdown(entry)
				carry(entry, 0)
			else
				local height = if entry.T < 0 then landing.Height else Pods.altitude(entry.T)
				setHeight(entry, height)
				if entry.Flip and entry.T >= entry.Flip then
					shuffle(entry)
				end
				pose(entry, "Legs", (entry.T - (landing.Fall - 1.1)) / 1, height)
				pose(entry, "Deploy", 0, height)
				carry(entry, height)
			end
		elseif entry.Kind == "Deploy" then
			local t = entry.T / landing.Deploy
			if t >= 1 then
				table.remove(moving, i)
				deployed(entry)
			else
				pose(entry, "Deploy", t, 0)
				for p, rest in entry.StallRest or {} do
					p.CFrame = CFrame.new(0, -STALL_SINK * (1 - ease((t - 0.5) / 0.5)), 0) * rest
				end
				carry(entry, 0)
			end
		else
			if entry.T >= landing.LiftOff then
				table.remove(moving, i)
				scrap(entry.Model, entry.Index)
			else
				setHeight(entry, entry.From + Pods.lift(entry.T))
			end
		end
	end
end

local function friendIds(player: Player): { [number]: boolean }
	local ids = {}
	pcall(function()
		local pages = Players:GetFriendsAsync(player.UserId)
		for _ = 1, 4 do
			for _, friend in pages:GetCurrentPage() do
				ids[friend.Id] = true
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	return ids
end

-- Joined: a pad kept for them (next to a friend's if they can).
local function reserve(player: Player)
	if podOf[player] or #pads == 0 then
		return
	end
	local friends = friendIds(player)
	if not player.Parent then
		return -- (left while we asked)
	end
	local near = {}
	for other, pod in podOf do
		if friends[other.UserId] then
			table.insert(near, pod.Index)
		end
	end
	local index = Pods.choose(pads, taken, near, rng, anchor)
	if not index or podOf[player] then
		return -- (every pad taken: the Shelter's spawn it is)
	end
	local pad = byIndex[index]
	taken[index] = player
	podOf[player] = { Index = index, Pad = pad }
	player:SetAttribute("PodIndex", index)
	player:SetAttribute("PodSpawn", Pods.spawnAt(pad.CFrame))
end

-- In the Outpost the first time: their pod comes down with them inside.
function PodServer.land(player: Player): boolean
	local pod = podOf[player]
	if not pod or pod.Model then
		return false
	end
	local landing = Pods.Landing
	-- (the roll, its first landing only: a piece unlocked and on, before
	-- it's built in that style; after that it lands as it's kept)
	local ok, piece = pcall(PodServer.rollFor, player)
	local rolled = ok and type(piece) == "table"
	if rolled then
		player:SetAttribute("PodRoll", string.format("%s|%s|%s|%s", piece.Kind, piece.Id, piece.Rarity, if piece.New then "1" else "0"))
	else
		player:SetAttribute("PodRoll", nil)
	end
	local model, moves = build(player, pod.Pad)
	local rest = model:GetPivot()
	for _, move in moves do
		local rel = rest:Inverse() * move.Part.CFrame
		move.Open = rel
		if move.Hinge then
			move.HingeRel = rest:Inverse() * move.Hinge
		end
	end
	local entry = {
		Model = model,
		Rest = rest,
		Pad = pod.Pad.CFrame,
		PadInfo = pod.Pad,
		Moves = moves,
		Kind = "Land",
		T = -landing.Lead,
		Index = pod.Index,
		Rider = player,
		Owner = player,
		Style = styleFor(player),
		Flip = if rolled then -landing.Lead else nil, -- (the flicks: a roll's only)
	}
	pod.Model, pod.Entry = model, entry
	setHeight(entry, landing.Height)
	pose(entry, "Legs", 0, landing.Height)
	pose(entry, "Deploy", 0, landing.Height)
	thruster(model, true)
	table.insert(moving, entry)
	player:SetAttribute("PodLanding", serverNow() + landing.Lead)
	carry(entry, landing.Height)
	-- Down and open by now whatever happens.
	task.delay(landing.Lead + landing.Fall + landing.Deploy + 2, function()
		local i = table.find(moving, entry)
		if i then
			table.remove(moving, i)
		end
		local still = podOf[player]
		if still and still.Entry == entry and standing(model) and not model:GetAttribute("Landed") then
			if entry.Kind == "Land" then
				touchdown(entry)
			end
			deployed(entry)
		end
	end)
	return true
end

local function depart(player: Player)
	local pod = podOf[player]
	podOf[player] = nil
	if not pod then
		return
	end
	if not pod.Model then
		taken[pod.Index] = nil -- (never landed: the pad's free now)
		return
	end
	taken[pod.Index] = true -- (free once it's gone)
	local entry = pod.Entry
	entry.PadInfo, entry.Rider = nil, nil -- (no stall going up after this)
	if entry.Display then
		entry.Display:Destroy() -- (packed up first)
		entry.Display = nil
	end
	local from = 0
	local i = table.find(moving, entry)
	if i then
		table.remove(moving, i)
		from = if entry.Kind == "Land" then (if entry.T < 0 then Pods.Landing.Height else Pods.altitude(entry.T)) else 0
	end
	-- (folded up, and away)
	setHeight(entry, from)
	pose(entry, "Deploy", 0, from)
	local lift = { Model = pod.Model, Rest = entry.Rest, Kind = "Lift", T = 0, From = from, Index = pod.Index }
	thruster(pod.Model, true)
	table.insert(moving, lift)
	task.delay(Pods.Landing.LiftOff + 2, function()
		scrap(pod.Model, pod.Index)
	end)
end

-- Their style again (MY POD: Client.PodUI): the hull and glow recoloured,
-- the yard rebuilt (once it's up), the showcase's kaiju.
function PodServer.restyle(player: Player)
	local pod = podOf[player]
	if not pod or not pod.Model or not standing(pod.Model) then
		return
	end
	local entry = pod.Entry
	local style = styleFor(player)
	entry.Style = style
	if not entry.Flip then
		paint(pod.Model, style) -- (still rolling on the way down: it settles on this)
	end
	if entry.Display and pod.Model:GetAttribute("Landed") then
		entry.Display:Destroy()
		entry.Display = display(entry.PadInfo, style)
		entry.StallRest = nil
		showcase(entry.Display, player, style)
	end
end

function PodServer.spawnFor(player: Player): CFrame?
	local at = player:GetAttribute("PodSpawn")
	return if typeof(at) == "CFrame" then at else nil
end

function PodServer.start(site)
	if not site or not site.Pads then
		return
	end
	pads = site.Pads
	anchor = if site.Spawn then site.Spawn.Position else nil
	for _, pad in pads do
		byIndex[pad.Index] = pad
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(reserve, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(reserve, player)
	end
	Players.PlayerRemoving:Connect(depart)
	RunService.Heartbeat:Connect(PodServer._step)
end

-- For tests.
PodServer._reserve, PodServer._depart = reserve, depart
PodServer._podOf, PodServer._taken = podOf, taken

return PodServer
