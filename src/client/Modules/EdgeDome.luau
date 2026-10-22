--[[
	Where the Outpost ends, for now: a force-field dome over the quarry's
	edge (Shared.Outpost.Edge, where the server's invisible walls stand),
	unseen from the middle, that shows itself as you come near. Its panels
	light up round where you're heading, brightest straight ahead and
	fading out a way off, and the closer you come the more of it shows.
	On it, at your eye height wherever you walk along it, the message
	EXPANSION COMING SOON flickers into view, cast on the field like a
	hologram (a split ghost of it drifting, a scan line rolling down).

	Each player's screen draws only its own patch of the dome (Columns by
	Rows panels, snapped to the dome's grid so they stay put as you walk:
	only the patch moves round with you), and nothing at all when you're
	further than Near from the edge. The words are in PlayerGui, so they're
	in the player's language (Translate).

	  EdgeDome.start()       once, from Lobby.client
	  EdgeDome.cell(column, row) -> CFrame, Vector3   a panel's place on the
	                         dome (from the quarry's middle) and its size
	  EdgeDome.column(angle) -> number   the grid column round the edge at
	                         `angle` (radians, from the quarry's middle)
	  EdgeDome.reveal(gap) -> 0..1   how much shows `gap` studs from the edge
	  EdgeDome.glow(distance, reveal) -> 0..1   how lit a panel is, `distance`
	                         studs from where you're looking at the dome
	  EdgeDome.facing(offset, eye) -> CFrame   the message's place on the
	                         dome for someone at `offset` from the middle
	  EdgeDome.board(gui)    fills a SurfaceGui with the message
	  EdgeDome.paint(gui, reveal, now)   lights it (its flicker, ghost, scan)
	  EdgeDome.Radius, Panel, Columns, Rows, Near, Full, Spread, Text, Line,
	  Message, Pixels
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Outpost = require(ReplicatedStorage.Shared.Outpost)

local EdgeDome = {}

EdgeDome.Radius = (Outpost.Edge or 474) - 1 -- (just inside the walls)
EdgeDome.Panel = 12 -- studs a side (round the edge and up it)
EdgeDome.Columns = 17 -- across your patch of it
EdgeDome.Rows = 11 -- up it
EdgeDome.Near = 170 -- studs from the edge: further, none of it shows
EdgeDome.Full = 40 -- this near, all of it does
EdgeDome.Spread = 70 -- studs round where you look that light up (at its fullest)
EdgeDome.Floor = 15 -- the outermost bench's top (OutpostWorld): the message hangs clear of it
EdgeDome.Text = "EXPANSION COMING SOON"
EdgeDome.Line = "NEW GROUND OPENS IN A FUTURE UPDATE"
EdgeDome.Color = Color3.fromRGB(96, 206, 255)
EdgeDome.Ghost = Color3.fromRGB(255, 92, 196)
EdgeDome.Every = 0.08 -- seconds between the panels' updates

-- Radians a panel spans: a whole number of them round the edge, so the
-- grid meets itself all the way round.
local STEP = math.pi * 2 / math.floor(math.pi * 2 * EdgeDome.Radius / EdgeDome.Panel + 0.5)

-- A frame at `at` looking along `look`, upright.
local function looking(at: Vector3, look: Vector3): CFrame
	local right = look:Cross(Vector3.new(0, 1, 0)).Unit
	return CFrame.fromMatrix(at, right, right:Cross(look).Unit, -look)
end

-- The grid column round the edge at `angle`.
function EdgeDome.column(angle: number): number
	return math.floor(angle / STEP)
end

-- Panel `column`, `row` (0 at the ground, up from there): its frame on the
-- dome, from the quarry's middle (facing it), and its size.
function EdgeDome.cell(column: number, row: number): (CFrame, Vector3)
	local theta = (column + 0.5) * STEP
	local phi = (row + 0.5) * STEP
	local r = EdgeDome.Radius
	local at = Vector3.new(math.cos(phi) * math.cos(theta), math.sin(phi), math.cos(phi) * math.sin(theta)) * r
	local frame = looking(at, -at.Unit)
	-- (A little wider and taller than its share, so the panels meet.)
	local width = r * math.cos(phi) * STEP * 1.04
	local height = r * STEP * 1.04
	return frame, Vector3.new(width, height, 0.3)
end

-- How much of it shows `gap` studs from the edge: none past Near, all of it
-- within Full, eased between.
function EdgeDome.reveal(gap: number): number
	local x = math.clamp((EdgeDome.Near - gap) / (EdgeDome.Near - EdgeDome.Full), 0, 1)
	return x * x * (3 - 2 * x)
end

-- How lit a panel `distance` studs from where you look at the dome is, at
-- `reveal`: full there, fading to none Spread out (a smaller patch further
-- off, the whole of Spread up close).
function EdgeDome.glow(distance: number, reveal: number): number
	if reveal <= 0 then
		return 0
	end
	local spread = EdgeDome.Spread * (0.45 + 0.55 * reveal)
	local x = math.clamp(1 - distance / spread, 0, 1)
	return reveal * x * x
end

-- Where the message hangs for someone at `offset` from the quarry's middle
-- with their eyes `eye` studs over its ground: on the dome, straight ahead
-- of them, facing in, at their eyes (never lower than clear of the benches
-- round the edge, Floor).
function EdgeDome.facing(offset: Vector3, eye: number): CFrame
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local out = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(1, 0, 0)
	local r = EdgeDome.Radius - 0.6
	local high = math.max(eye, EdgeDome.Floor + EdgeDome.Message.Y / 2 + 1)
	local phi = math.asin(math.clamp(high / r, 0, 0.9))
	local at = out * (r * math.cos(phi)) + Vector3.new(0, r * math.sin(phi), 0)
	-- (Upright, facing back in toward the middle.)
	return looking(at, -out)
end

-- The message -----------------------------------------------------------------------------------------

EdgeDome.Message = Vector2.new(68, 19) -- studs
EdgeDome.Pixels = 20 -- its pixels a stud

local function make(class: string, props, parent: Instance?)
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

-- Fills `gui` (a SurfaceGui Message studs at Pixels a stud) with the
-- message: its Title over a split Ghost of it, its Line under, two Rules
-- and a Scan line. All unseen till paint() lights them.
function EdgeDome.board(gui: SurfaceGui)
	local W = EdgeDome.Message.X * EdgeDome.Pixels
	local function words(name: string, text: string, y: number, h: number, font, color: Color3, z: number)
		return make("TextLabel", {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(40, y),
			Size = UDim2.fromOffset(W - 80, h),
			Font = font,
			Text = text,
			TextScaled = true,
			TextColor3 = color,
			TextStrokeColor3 = Color3.fromRGB(6, 18, 30),
			TextStrokeTransparency = 1,
			TextTransparency = 1,
			ZIndex = z,
		}, gui)
	end
	words("Ghost", EdgeDome.Text, 70, 150, Enum.Font.GothamBlack, EdgeDome.Ghost, 1)
	words("Title", EdgeDome.Text, 70, 150, Enum.Font.GothamBlack, Color3.fromRGB(226, 246, 255), 2)
	words("Line", EdgeDome.Line, 240, 56, Enum.Font.GothamBold, EdgeDome.Color, 2)
	for i, y in { 52, 314 } do
		make("Frame", {
			Name = "Rule" .. i,
			BackgroundColor3 = EdgeDome.Color,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(120, y),
			Size = UDim2.fromOffset(W - 240, 3),
		}, gui)
	end
	make("Frame", {
		Name = "Scan",
		BackgroundColor3 = Color3.fromRGB(200, 240, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(W, 6),
		ZIndex = 3,
	}, gui)
end

-- Lights `gui`'s message at `reveal` (0: unseen), as it looks at `now`
-- (seconds): flickering a little, its ghost drifting off to the side (a
-- jump now and then), the scan line rolling down.
function EdgeDome.paint(gui: SurfaceGui, reveal: number, now: number)
	local fade = 1 - reveal * (0.92 + 0.08 * math.sin(now * 9))
	local title = gui:FindFirstChild("Title") :: TextLabel
	title.TextTransparency = fade
	title.TextStrokeTransparency = 0.5 + 0.5 * fade
	local line = gui:FindFirstChild("Line") :: TextLabel
	line.TextTransparency = math.min(1, fade + 0.1)
	local glitch = (now % 2.6) < 0.08
	local drift = math.sin(now * 2.3) * 5 + (if glitch then 14 else 0)
	local ghost = gui:FindFirstChild("Ghost") :: TextLabel
	ghost.Position = UDim2.fromOffset(40 + drift, 70 + (if glitch then -3 else 0))
	ghost.TextTransparency = math.min(1, 0.55 + 0.45 * fade)
	for _, name in { "Rule1", "Rule2" } do
		(gui:FindFirstChild(name) :: Frame).BackgroundTransparency = math.min(1, 0.3 + 0.7 * fade)
	end
	local scan = gui:FindFirstChild("Scan") :: Frame
	scan.Position = UDim2.fromOffset(0, (now * 140) % (EdgeDome.Message.Y * EdgeDome.Pixels))
	scan.BackgroundTransparency = math.min(1, 0.8 + 0.2 * fade)
end

-- On screen -------------------------------------------------------------------------------------------

local player = Players.LocalPlayer

type Panel = { Part: BasePart, Column: number?, Row: number }

local folder: Folder
local panels: { Panel } = {}
local base: number? = nil -- the patch's first column
local board: Part
local gui: SurfaceGui
local shown = false

local function build()
	folder = make("Folder", { Name = "EdgeDome" })
	for row = 0, EdgeDome.Rows - 1 do
		for _ = 1, EdgeDome.Columns do
			local part = make("Part", {
				Name = "DomePanel",
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Material = Enum.Material.ForceField,
				Color = EdgeDome.Color,
				Transparency = 1,
				Size = Vector3.new(1, 1, 0.3),
			}, folder)
			table.insert(panels, { Part = part, Row = row })
		end
	end
	board = make("Part", {
		Name = "DomeMessage",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(EdgeDome.Message.X, EdgeDome.Message.Y, 0.2),
	}, folder)
	-- (In PlayerGui, so it's in the player's language.)
	gui = make("SurfaceGui", {
		Name = "EdgeDomeMessage",
		Adornee = board,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = EdgeDome.Pixels,
		LightInfluence = 0,
		Brightness = 2,
		ResetOnSpawn = false,
		Enabled = false,
	})
	EdgeDome.board(gui)
end

local function setShown(on: boolean)
	if shown == on then
		return
	end
	shown = on
	folder.Parent = if on then workspace else nil
	gui.Enabled = on
end

-- The patch round column `first`: each panel to its place (only when the
-- patch has moved on a column).
local function place(first: number, center: Vector3)
	if base == first then
		return
	end
	base = first
	local columns = EdgeDome.Columns
	for i, panel in panels do
		local column = first + (i - 1) % columns
		local frame, size = EdgeDome.cell(column, panel.Row)
		panel.Column = column
		panel.Part.Size = size
		panel.Part.CFrame = frame + center
	end
end

local function step(now: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local here = root ~= nil and player:GetAttribute("Outpost") == true and player:GetAttribute("RiftRun") == nil
	if not here then
		setShown(false)
		return
	end
	local center = Outpost.Location.Position
	local offset = (root :: BasePart).Position - center
	local gap = EdgeDome.Radius - Vector3.new(offset.X, 0, offset.Z).Magnitude
	local reveal = EdgeDome.reveal(gap)
	if reveal <= 0 then
		setShown(false)
		return
	end
	setShown(true)
	local angle = math.atan2(offset.Z, offset.X)
	place(EdgeDome.column(angle) - math.floor(EdgeDome.Columns / 2), center)
	-- Lit round where you look at it: straight ahead, at your eyes.
	local message = EdgeDome.facing(offset, math.max(0, offset.Y + 3))
	local look = message.Position + center
	for _, panel in panels do
		local lit = EdgeDome.glow((panel.Part.Position - look).Magnitude, reveal)
		-- (A slow shimmer through it, so it reads as a field.)
		local shimmer = 0.85 + 0.15 * math.sin(now * 1.7 + (panel.Column or 0) * 0.9 + panel.Row * 1.3)
		local transparency = if lit <= 0.01 then 1 else 1 - 0.9 * lit * shimmer
		if math.abs(panel.Part.Transparency - transparency) > 0.01 then
			panel.Part.Transparency = transparency
		end
	end
	board.CFrame = message + center
	EdgeDome.paint(gui, reveal, now)
end

local started = false
function EdgeDome.start()
	if started then
		return
	end
	started = true
	build()
	gui.Parent = player:WaitForChild("PlayerGui")
	local nextStep = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextStep then
			return
		end
		nextStep = now + (if shown then EdgeDome.Every else 0.5)
		step(now)
	end)
end

return EdgeDome
