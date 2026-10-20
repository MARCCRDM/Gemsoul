--[[
	The Store's displays: what the Saga Shelter's Store sells, out on stands
	round its counter, drawn by each player's own client (the server sends
	no parts). Each is the real thing: the Shop's own 3D preview of it
	(ReplicatedStorage.CosmeticPreviews, Server Equipment.cosmeticPreview),
	so a stand looks just as the cosmetic does when worn.

	  the wall     a lit back wall behind the counter: three helmets on the
	               top shelf, three weapon skins hung under them
	  the picks    three pickaxes turning on plinths between the counter and
	               the wall
	  the suits    two mannequins on turntables either side of the counter,
	               each wearing a suit

	Every Every seconds each stand moves on to the next of its kind that
	the Store sells (by the server's clock: everyone sees the same), so over
	a few minutes every suit, helmet, weapon skin and pickaxe on sale comes
	round. A plate under each names it and its price. The next turn's
	previews are asked for ahead of time; a stand keeps what it shows until
	the next one has arrived whole.

	None of it collides, casts a shadow or can be clicked (CanQuery: a
	click in the Outpost swings at a rock). It is only there while you're
	in the Outpost and within Reach of the Store.

	  StoreDisplays.mount(at)   builds the stands for the Shelter at `at` (once)
	  StoreDisplays.show(on)    shows or hides them (hidden, nothing runs)
	  StoreDisplays.step(dt)    moves them on and turns them (20 times a second at most)

	Pure, and tested without Roblox (tests/store_displays_cases.luau):
	  StoreDisplays.Stands                every stand, in the Shelter's frame
	  StoreDisplays.onSale(kind) -> { id }   what the Store sells of a kind
	                                      (Shared.Cosmetics.ofKind's order)
	  StoreDisplays.showing(stand, t) -> id   what a stand shows at server time t
	  StoreDisplays.fit(cframes, sizes, stand) -> (rest, scale)   a preview's
	                                      parts as offsets from the stand's foot:
	                                      standing on it, facing the hall, its
	                                      kind's height
	  StoreDisplays.build(at) -> Displays   the stands, empty
	  StoreDisplays.dress(displays, i, id, source)   puts a preview (a folder of
	                                      parts) on stand i
	  StoreDisplays.pose(displays, t)     turns the turning ones
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local LiveLooks = require(script.Parent:WaitForChild("LiveLooks"))

local StoreDisplays = {}

StoreDisplays.Every = 40 -- seconds each stand shows a thing
StoreDisplays.Middle = Vector3.new(-70, 0.86, 6) -- the Store, in the Shelter's frame
StoreDisplays.Reach = 200 -- studs from the Store: past this it's put away
StoreDisplays.TurnReach = 90 -- ...and past this the turning ones keep still

local V = Vector3.new
local FLOOR = 0.86
-- Saga Outfitters' colour (the Store's: Server OutpostWorld's STATION.Store),
-- a marking on the prices, never a light.
local BRAND = Color3.fromRGB(122, 150, 214)
local DARK = Color3.fromRGB(30, 32, 42)
local STEEL = Color3.fromRGB(150, 158, 170)
local WARM = Color3.fromRGB(255, 238, 214) -- the shop's display lighting

-- Standing at `from`, turned to face `toward` (level), then `turn` more.
local function facing(from: Vector3, toward: Vector3, turn: number?): CFrame
	return CFrame.new(from) * CFrame.Angles(0, math.atan2(-(toward.X - from.X), -(toward.Z - from.Z)) + (turn or 0), 0)
end

-- Every stand: its kind and which of that kind's stands it is (Slot of
-- Slots), its foot (At: where the bottom of the thing stands, facing the
-- hall, east; or, Hung, where its middle hangs), how tall its kind is
-- shown (Height: nil keeps a suit life size), whether its back is to the
-- wall (Back), how fast it turns (Turn, radians a second), and its price
-- plate.
export type Stand = {
	Kind: string,
	Slot: number,
	Slots: number,
	At: CFrame,
	Height: number?,
	Back: boolean?,
	Hung: boolean?,
	Turn: number?,
	Plate: CFrame,
	PlateSize: Vector3,
}
StoreDisplays.Stands = {} :: { Stand }
local WALL = -83.4 -- the face of the lit back wall
local ROWS = { 0.5, 6, 11.5 } -- the wall's three columns, and the picks' plinths
do
	local hall = V(1, 0, 0)
	local function add(spec)
		local foot, plate = spec.Foot, spec.PlateAt
		table.insert(StoreDisplays.Stands, {
			Kind = spec.Kind,
			Slot = spec.Slot,
			Slots = spec.Slots,
			At = facing(foot, foot + hall, spec.Yaw) * CFrame.Angles(0, 0, spec.Roll or 0),
			Height = spec.Height,
			Back = spec.Back,
			Hung = spec.Hung,
			Turn = spec.Turn,
			Plate = facing(plate, plate + hall),
			PlateSize = spec.PlateSize,
		})
	end
	for k, z in ROWS do
		-- Helmets on the top shelf, turned to show their shape; weapon
		-- skins hung across the wall under them, on the slant.
		add({
			Kind = "Helmet",
			Slot = k,
			Slots = 3,
			Foot = V(WALL + 0.95, 11.32, z),
			Height = 2.5,
			Back = true,
			Yaw = math.rad(28),
			PlateAt = V(WALL + 3.05, 10.85, z),
			PlateSize = V(2.6, 0.5, 0.08),
		})
		add({
			Kind = "Skin",
			Slot = k,
			Slots = 3,
			Foot = V(WALL + 0.12, 8.85, z),
			Height = 4.2,
			Back = true,
			Hung = true,
			Roll = math.rad(-38),
			PlateAt = V(WALL + 0.12, 6.4, z),
			PlateSize = V(2.6, 0.55, 0.08),
		})
	end
	-- Pickaxes on plinths between the counter and the wall (where the orbs
	-- stood), turning, the head in profile as they come round.
	for k, z in ROWS do
		add({
			Kind = "Pick",
			Slot = k,
			Slots = 3,
			Foot = V(-76, FLOOR + 2.6, z),
			Height = 3.4,
			Turn = 0.5,
			PlateAt = V(-74.68, FLOOR + 1.5, z),
			PlateSize = V(1.9, 0.55, 0.08),
		})
	end
	-- The suits, life size on turntables either side of the counter, out
	-- in the hall.
	for k, z in { -8, 20 } do
		add({
			Kind = "Suit",
			Slot = k,
			Slots = 2,
			Foot = V(-62, FLOOR + 0.7, z),
			Height = nil,
			Turn = 0.35,
			PlateAt = V(-58.6, FLOOR + 1.3, z),
			PlateSize = V(2.8, 0.75, 0.1),
		})
	end
end

-- What the Store sells of a kind (not the exclusives), in its own order.
function StoreDisplays.onSale(kind: string): { string }
	local ids = {}
	for _, id in Cosmetics.ofKind(kind) do
		local cosmetic = Cosmetics.get(id)
		if cosmetic and cosmetic.Robux and not cosmetic.Exclusive then
			table.insert(ids, id)
		end
	end
	return ids
end

-- What a stand shows at server time t: each turn, the stands of a kind
-- move on together to the next ones on sale, never two showing the same.
function StoreDisplays.showing(stand: Stand, t: number): string?
	local list = StoreDisplays.onSale(stand.Kind)
	if #list == 0 then
		return nil
	end
	local turn = math.floor(t / StoreDisplays.Every)
	return list[(turn * stand.Slots + stand.Slot - 1) % #list + 1]
end

-- A preview's parts (CFrames in the mannequin's frame, which faces -Z) as
-- offsets from the stand's foot: the bottom of the whole thing on it (or,
-- hung, its middle at it), its middle over it (or the middle of its back
-- against it), at the kind's height
-- (a suit kept life size, but never over 6.5 studs). Returns the offsets
-- and the scale.
function StoreDisplays.fit(cframes: { CFrame }, sizes: { Vector3 }, stand: Stand): ({ CFrame }, number)
	local low, high = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for i, cf in cframes do
		local half = sizes[i] / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = cf * V(half.X * sx, half.Y * sy, half.Z * sz)
					low = V(math.min(low.X, p.X), math.min(low.Y, p.Y), math.min(low.Z, p.Z))
					high = V(math.max(high.X, p.X), math.max(high.Y, p.Y), math.max(high.Z, p.Z))
				end
			end
		end
	end
	local tall = math.max(high.Y - low.Y, 0.05)
	local scale = if stand.Height then math.clamp(stand.Height / tall, 0.5, 2.2) else math.min(1, 6.5 / tall)
	-- (Its back is +Z: the mannequin faces -Z.)
	local foot = V(
		(low.X + high.X) / 2,
		if stand.Hung then (low.Y + high.Y) / 2 else low.Y,
		if stand.Back then high.Z else (low.Z + high.Z) / 2
	)
	local rest = {}
	for i, cf in cframes do
		rest[i] = CFrame.fromMatrix((cf.Position - foot) * scale, cf.RightVector, cf.UpVector, -cf.LookVector)
	end
	return rest, scale
end

-- A part that's only there to be seen.
local function part(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: string?
): BasePart
	local p = Instance.new("Part")
	if shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

export type Shown = {
	Spec: Stand,
	Holder: Model,
	Id: string?,
	Parts: { BasePart },
	Rest: { CFrame },
	Name: TextLabel,
	Price: TextLabel,
}
export type Displays = { Model: Model, At: CFrame, Stands: { Shown } }

-- The stands, empty: the lit wall and its shelf, the plinths, the
-- turntables and a price plate for each.
function StoreDisplays.build(at: CFrame): Displays
	local model = Instance.new("Model")
	model.Name = "StoreDisplays"
	local function put(cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?, shape: string?)
		return part(model, at * cframe, size, color, material, shape)
	end
	-- The back wall: a dark panel in a steel frame, washed with warm light.
	local panel = put(CFrame.new(WALL - 0.15, 8.6, 6), V(0.3, 11, 19), DARK, Enum.Material.Metal)
	panel.Name = "DisplayWall"
	local wash = Instance.new("SurfaceLight")
	wash.Face = Enum.NormalId.Right
	wash.Color = WARM
	wash.Range = 10
	wash.Brightness = 1
	wash.Angle = 120
	wash.Parent = panel
	for _, y in { 3.1, 14.1 } do
		put(CFrame.new(WALL, y, 6), V(0.3, 0.3, 19.2), STEEL, Enum.Material.Metal)
	end
	for _, z in { -3.5, 15.5 } do
		put(CFrame.new(WALL, 8.6, z), V(0.3, 11.2, 0.3), STEEL, Enum.Material.Metal)
	end
	-- The helmets' shelf, and a steel rail over each weapon skin's plate.
	put(CFrame.new(WALL + 1.5, 11.2, 6), V(3, 0.24, 17.4), STEEL, Enum.Material.Metal)
	for _, z in ROWS do
		put(CFrame.new(WALL + 0.1, 6.86, z), V(0.16, 0.12, 2.4), STEEL, Enum.Material.Metal)
	end
	-- The picks' plinths, a steel collar round each near its top.
	for _, z in ROWS do
		put(
			CFrame.new(-76, FLOOR + 1.3, z) * CFrame.Angles(0, 0, math.rad(90)),
			V(2.6, 2.4, 2.4),
			STEEL,
			Enum.Material.Metal,
			"Cylinder"
		)
		put(
			CFrame.new(-76, FLOOR + 2.3, z) * CFrame.Angles(0, 0, math.rad(90)),
			V(0.16, 2.56, 2.56),
			DARK,
			Enum.Material.Metal,
			"Cylinder"
		)
	end
	-- The suits' turntables, a steel rim round each, lit warm.
	for _, z in { -8, 20 } do
		put(
			CFrame.new(-62, FLOOR + 0.35, z) * CFrame.Angles(0, 0, math.rad(90)),
			V(0.7, 4.6, 4.6),
			DARK,
			Enum.Material.Metal,
			"Cylinder"
		)
		local rim = put(
			CFrame.new(-62, FLOOR + 0.06, z) * CFrame.Angles(0, 0, math.rad(90)),
			V(0.12, 5, 5),
			STEEL,
			Enum.Material.Metal,
			"Cylinder"
		)
		local glow = Instance.new("PointLight")
		glow.Color = WARM
		glow.Range = 9
		glow.Brightness = 0.6
		glow.Parent = rim
		-- (its plate on a short post in front)
		put(CFrame.new(-58.6, FLOOR + 0.5, z), V(0.24, 1, 0.24), STEEL, Enum.Material.Metal)
	end
	local stands = {}
	for i, spec in StoreDisplays.Stands do
		local holder = Instance.new("Model")
		holder.Name = spec.Kind .. "Stand" .. spec.Slot
		holder.Parent = model
		local plate = part(holder, at * spec.Plate, spec.PlateSize, DARK, Enum.Material.Metal)
		plate.Name = "Plate"
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(spec.PlateSize.X * 60, spec.PlateSize.Y * 60)
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		gui.Parent = plate
		local lines = {}
		for k, line in
			{
				{ 0, 0.6, Enum.Font.GothamBold, Color3.fromRGB(236, 234, 228) },
				{ 0.58, 0.42, Enum.Font.GothamBold, BRAND },
			}
		do
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.Position = UDim2.fromScale(0.04, line[1])
			text.Size = UDim2.fromScale(0.92, line[2])
			text.TextScaled = true
			text.Font = line[3]
			text.TextColor3 = line[4]
			text.Text = ""
			text.Parent = gui
			lines[k] = text
		end
		stands[i] = { Spec = spec, Holder = holder, Id = nil, Parts = {}, Rest = {}, Name = lines[1], Price = lines[2] }
	end
	return { Model = model, At = at, Stands = stands }
end

local live = false -- (in the game: the copies' animated looks move, LiveLooks)

-- Puts cosmetic `id` on stand i, from its preview (a folder of parts in the
-- mannequin's frame), in place of whatever was there.
function StoreDisplays.dress(displays: Displays, i: number, id: string, source: Instance)
	local shown = displays.Stands[i]
	for _, p in shown.Parts do
		p:Destroy()
	end
	local parts, cframes, sizes = {}, {}, {}
	for _, child in source:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
			table.insert(cframes, child.CFrame)
			table.insert(sizes, child.Size)
		end
	end
	local rest, scale = StoreDisplays.fit(cframes, sizes, shown.Spec)
	shown.Parts, shown.Rest = {}, rest
	local pivot = displays.At * shown.Spec.At
	for k, original in parts do
		local copy = original:Clone()
		copy.Anchored = true
		copy.CanCollide, copy.CanTouch, copy.CanQuery = false, false, false
		copy.CastShadow = false
		copy.Size = sizes[k] * scale
		copy.CFrame = pivot * rest[k]
		copy.Parent = shown.Holder
		shown.Parts[k] = copy
	end
	shown.Id = id
	local cosmetic = Cosmetics.get(id)
	shown.Name.Text = if cosmetic then string.upper(cosmetic.Name) else id
	shown.Price.Text = if cosmetic and cosmetic.Robux then string.format("R$ %d", cosmetic.Robux) else ""
	if live then
		LiveLooks.watch(shown.Holder)
	end
end

-- Moves every part to its place in the game in one bulk move.
local bulkMove = (function()
	local ok, space = pcall(function()
		return game:GetService("Workspace")
	end)
	if ok and space and (space :: any).BulkMoveTo then
		return function(parts, cframes)
			space:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	return function(parts, cframes)
		for i, p in parts do
			p.CFrame = cframes[i]
		end
	end
end)()

-- Turns the turning ones to where they are at server time t (each its own
-- way round, so they don't turn in step).
function StoreDisplays.pose(displays: Displays, t: number)
	local parts, cframes = {}, {}
	for i, shown in displays.Stands do
		local turn = shown.Spec.Turn
		if turn and #shown.Parts > 0 then
			local pivot = displays.At * shown.Spec.At * CFrame.Angles(0, t * turn + i * 1.7, 0)
			for k, p in shown.Parts do
				table.insert(parts, p)
				table.insert(cframes, pivot * shown.Rest[k])
			end
		end
	end
	bulkMove(parts, cframes)
end

-- In the game: built once, shown while you're in the Outpost and near the
-- Store.
local displays: Displays? = nil
local wanted = false
local clock = 0
local asked: { [string]: boolean } = {}
local lastAsk = -math.huge

local function previews(): Instance?
	return ReplicatedStorage:FindFirstChild("CosmeticPreviews")
end

-- A preview whose parts have all arrived (the server counts them in its
-- Parts attribute), or nil.
local function whole(id: string): Instance?
	local store = previews()
	local folder = store and store:FindFirstChild(id)
	if not folder then
		return nil
	end
	local parts = folder:GetAttribute("Parts")
	return if #folder:GetChildren() >= (if type(parts) == "number" then parts else 1) then folder else nil
end

-- Asks the server for the previews of this turn and the next that
-- haven't been built yet (in one go; at most every few seconds).
local function ask(now: number)
	if now - lastAsk < 5 then
		return
	end
	lastAsk = now
	local store = previews()
	local missing = {}
	for _, t in { now, now + StoreDisplays.Every } do
		for _, spec in StoreDisplays.Stands do
			local id = StoreDisplays.showing(spec, t)
			if id and not asked[id] and not (store and store:FindFirstChild(id)) then
				asked[id] = true
				table.insert(missing, id)
			end
		end
	end
	if #missing == 0 then
		return
	end
	task.spawn(function()
		local GemClient = require(script.Parent:WaitForChild("GemClient"))
		local result = GemClient.request("CosmeticPreviews", missing)
		if not result.Ok then
			-- (Let a later turn ask again.)
			for _, id in missing do
				asked[id] = nil
			end
		end
	end)
end

function StoreDisplays.mount(at: CFrame)
	if displays then
		return
	end
	live = true
	displays = StoreDisplays.build(at)
end

local function distance(): number
	local camera = workspace.CurrentCamera
	if not (displays and camera) then
		return math.huge
	end
	return (camera.CFrame.Position - (displays.At * StoreDisplays.Middle)).Magnitude
end

function StoreDisplays.show(on: boolean)
	wanted = on
	if not displays then
		return
	end
	local parent = if on and distance() < StoreDisplays.Reach then workspace else nil
	if displays.Model.Parent ~= parent then
		displays.Model.Parent = parent
	end
end

function StoreDisplays.step(dt: number)
	if not (displays and wanted) then
		return
	end
	clock += dt
	if clock < 1 / 20 then
		return
	end
	clock = 0
	StoreDisplays.show(wanted)
	if not displays.Model.Parent then
		return
	end
	local now = workspace:GetServerTimeNow()
	ask(now)
	-- (One stand a step, so a turn's new things don't all arrive in one frame.)
	for i, shown in displays.Stands do
		local id = StoreDisplays.showing(shown.Spec, now)
		local source = if id and id ~= shown.Id then whole(id) else nil
		if id and source then
			StoreDisplays.dress(displays, i, id, source)
			break
		end
	end
	if distance() < StoreDisplays.TurnReach then
		StoreDisplays.pose(displays, now)
	end
end

return StoreDisplays
