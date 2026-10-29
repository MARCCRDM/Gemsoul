--[[
	The bounty board out on the hall floor (Shared.Bounties.Board), where
	its inlay bands cross between the Hall of Fame and Brutus's booth: a
	freestanding screen on two lit pylons with a BOUNTIES lightbox and
	crossed blades on top, a glowing ring on the floor round it. Each face
	shows one bounty, WANTED: the boss itself, a big figure of its body
	(ReplicatedStorage.RiftPortraits) standing on a lit ledge out of the
	screen's left half, in its element's light; beside it its name, element,
	threat, what it pays, who to bring and where it was last seen, in a
	plain column; both change every Board.Period
	seconds, never to the same one (Bounties.boardAt), the same for
	everyone (the server's clock). Its prompt opens the bounty board (Client.
	RiftClient, "Bounty").

	Built by each player's client like the Kennel's pen (the Shelter's
	server-built parts are at their budget), only while you're in the
	Outpost and near the Shelter.

	  BountyBoard.mount(at)   the Shelter's frame (once)
	  BountyBoard.show(on)    shows or hides it
	  BountyBoard.step(dt)    turns its faces when their bounty changes
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounties = require(Shared:WaitForChild("Bounties"))
local BossLoot = require(Shared:WaitForChild("BossLoot"))
local GemConfig = require(Shared:WaitForChild("GemConfig"))
local Lang = require(Shared:WaitForChild("Lang"))
local RiftRun = require(Shared:WaitForChild("RiftRun"))

local BountyBoard = {}
BountyBoard.Reach = 260 -- studs from the board: past this it's put away

-- The look: the hall's dark steel and bounty amber, WANTED in red.
local DARK = Color3.fromRGB(34, 36, 44)
local STEEL = Color3.fromRGB(70, 74, 82)
local AMBER = Color3.fromRGB(240, 178, 48)
local RED = Color3.fromRGB(226, 62, 48)
local INK = Color3.fromRGB(12, 13, 20)
local IVORY = Color3.fromRGB(240, 232, 214)
local FADED = Color3.fromRGB(150, 146, 160)
local THREAT_COLORS = { Color3.fromRGB(110, 220, 140), AMBER, Color3.fromRGB(255, 92, 72) }

local at: CFrame? = nil
local model: Folder? = nil
local wanted = false
local clock = 0
type Face = { Gui: SurfaceGui, Carrier: BasePart, Shown: string?, Figure: Model?, Missing: string?, Parts: { [string]: Instance } }
local faces: { Face } = {}

local function piece(parent: Instance, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanTouch, p.CanQuery = false, solid == true
	p.CastShadow = solid == true
	p.Size, p.CFrame, p.Color, p.Material = size, cframe, color, material
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A disc lying flat (a cylinder on its side), `height` thick.
local function disc(parent: Instance, cframe: CFrame, radius: number, height: number, color: Color3, material: Enum.Material, solid: boolean?): Part
	local p = piece(parent, cframe * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(height, radius * 2, radius * 2), color, material, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false
	l.Parent = parent
end

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local function text(parent: Instance, value: string, x: number, y: number, w: number, h: number, size: number, color: Color3, font: Enum.Font?, align: Enum.TextXAlignment?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or Enum.Font.GothamBlack,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
	}, parent)
end

-- A face's screen, laid out once (960 x 660): the left half is the boss's
-- stage (the figure stands in front of it, out of the screen, lit in its
-- element's colour rising from the floor), the right half says who it is:
-- its name, big; its element and threat; what it pays, whether to bring a
-- party, where it was last seen; and how to take it. Plain words in a
-- column, nothing more. A thin line along the foot runs down the time
-- left on this bounty.
local W, H = 960, 660
local SPLIT = 480
local function layout(carrier: BasePart): Face
	local gui = new("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(W, H),
		LightInfluence = 0,
		Brightness = 1.3,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, carrier)
	local parts: { [string]: Instance } = {}
	local back = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, gui)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(20, 20, 28), Color3.fromRGB(8, 9, 14)) }, back)
	-- The stage: its element's light rising from the floor behind the boss.
	parts.Wash = new("Frame", { Size = UDim2.fromOffset(SPLIT, H), BackgroundColor3 = AMBER, BorderSizePixel = 0 }, back)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.85), NumberSequenceKeypoint.new(1, 0.35) }),
	}, parts.Wash)
	text(back, Lang.translate("WANTED"), 34, 22, 300, 44, 34, RED)
	parts.Count = text(back, "", W - 230, 22, 200, 44, 24, FADED, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
	parts.Count:SetAttribute("NoTranslate", true)
	new("Frame", { Position = UDim2.fromOffset(SPLIT, 40), Size = UDim2.fromOffset(2, H - 80), BackgroundColor3 = IVORY, BackgroundTransparency = 0.88, BorderSizePixel = 0 }, back)
	-- Who it is.
	local x, cw = SPLIT + 36, W - SPLIT - 72
	parts.Name = text(back, "", x, 70, cw, 170, 70, IVORY)
	parts.Name.TextYAlignment = Enum.TextYAlignment.Bottom
	parts.Name.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = 70, MinTextSize = 30 }, parts.Name)
	parts.Name:SetAttribute("NoTranslate", true)
	parts.Kind = text(back, "", x, 250, cw, 40, 30, IVORY)
	parts.Kind.RichText = true
	parts.Kind:SetAttribute("NoTranslate", true)
	parts.Accent = new("Frame", { Position = UDim2.fromOffset(x, 306), Size = UDim2.fromOffset(84, 6), BackgroundColor3 = AMBER, BorderSizePixel = 0 }, back)
	-- What it pays, who to bring, where it was last seen: a label over each.
	local function row(y: number, label: string): TextLabel
		text(back, Lang.translate(label), x, y, cw, 26, 20, FADED, Enum.Font.GothamBold)
		return text(back, "", x, y + 24, cw, 34, 28, IVORY)
	end
	row(332, "REWARD").Text = Lang.translate("BOSS CACHE")
	parts.Party = row(394, "PARTY")
	parts.Seen = row(456, "LAST SEEN")
	-- How to take it.
	local key = new("Frame", { Position = UDim2.fromOffset(x, H - 126), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1 }, back)
	new("UIStroke", { Color = AMBER, Thickness = 3 }, key)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, key)
	text(key, "E", 0, 0, 52, 52, 30, AMBER, nil, Enum.TextXAlignment.Center):SetAttribute("NoTranslate", true)
	text(back, string.upper(Lang.translate("Take a bounty")), x + 70, H - 126, cw - 70, 52, 30, AMBER)
	-- The time left on this bounty, along the foot.
	local track = new("Frame", { Position = UDim2.fromOffset(0, H - 8), Size = UDim2.fromOffset(W, 8), BackgroundColor3 = Color3.fromRGB(30, 30, 40), BorderSizePixel = 0 }, back)
	parts.Fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = AMBER, BorderSizePixel = 0 }, track)
	-- (a flash over it all when its bounty changes)
	parts.Flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = IVORY, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10 }, gui)
	return { Gui = gui, Carrier = carrier, Shown = nil, Figure = nil, Missing = nil, Parts = parts }
end

-- The boss on a face: a figure of its body (ReplicatedStorage.RiftPortraits,
-- Server.RiftServer's portraitOf) standing big on a lit ledge out of the
-- screen's left half, turned a little to look out, a lamp over it. (A real
-- figure, not a ViewportFrame: those don't draw on a board out in the
-- world.) It may still be on its way from the server: put in when it comes.
local STAGE = { X = 2.4, Y = -0.1, W = 4.2, H = 5.5 } -- (studs, on the face: the stage's middle and room)
local function bounds(model: Model, pivot: CFrame): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in model:GetDescendants() do
		-- (only what's seen: a big see-through hitbox would shrink it to nothing)
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			local half = part.Size / 2
			for _, c in { Vector3.new(-1, -1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(1, 1, 1) } do
				local p = pivot:PointToObjectSpace(part.CFrame:PointToWorldSpace(half * c))
				lo, hi = lo:Min(p), hi:Max(p)
			end
		end
	end
	return lo, hi
end
local warned: { [string]: boolean } = {}
local function portrait(face: Face, id: string, tint: Color3?)
	if face.Figure then
		face.Figure:Destroy()
		face.Figure = nil
	end
	local folder = ReplicatedStorage:FindFirstChild("RiftPortraits")
	local source = folder and folder:FindFirstChild(id)
	if not (source and source:IsA("Model")) then
		-- (said once, so a boss that never comes shows up in the output)
		if not warned[id] then
			warned[id] = true
			warn("[BountyBoard] waiting for the portrait of", id)
		end
		face.Missing = id
		return
	end
	local body = source:Clone() :: Model?
	if not body then
		face.Missing = id
		return
	end
	face.Missing = nil
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	local lo, hi = bounds(body, body:GetPivot())
	local size = hi - lo
	if size.Y <= 0 or size.Y ~= size.Y then
		body:Destroy()
		return
	end
	local fit = math.min(STAGE.H / size.Y, STAGE.W / math.max(size.X, size.Z, 0.1))
	body:ScaleTo(body:GetScale() * fit)
	lo, hi = lo * fit, hi * fit
	size = hi - lo
	-- On a ledge out of the face (its front is the carrier's -Z), its back
	-- clear of the screen, its feet on the ledge at the stage's foot.
	local carrier = face.Carrier
	local depth = 0.3 + size.Z / 2
	local foot = carrier.CFrame * CFrame.new(STAGE.X, STAGE.Y - STAGE.H / 2 - 0.1, -depth)
	local look = carrier.CFrame.Rotation * CFrame.Angles(0, math.rad(-16), 0)
	local center = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	body:PivotTo(CFrame.new(foot.Position) * look * CFrame.new(-center))
	local ledge = piece(body, foot * CFrame.new(0, -0.09, 0), Vector3.new(STAGE.W + 0.4, 0.18, size.Z + 0.6), DARK, Enum.Material.Metal)
	ledge.Name = "Ledge"
	piece(body, foot * CFrame.new(0, -0.09, -(size.Z + 0.6) / 2), Vector3.new(STAGE.W + 0.42, 0.2, 0.06), tint or AMBER, Enum.Material.Neon).Name = "LedgeEdge"
	light(ledge, tint or AMBER, 7, 1.4)
	-- (a lamp over it, so it reads from across the hall)
	local lamp = piece(body, foot * CFrame.new(0, STAGE.H + 0.8, -0.4), Vector3.new(0.2, 0.2, 0.2), DARK, Enum.Material.Metal)
	lamp.Name, lamp.Transparency = "Lamp", 1
	local spot = Instance.new("SpotLight")
	spot.Face, spot.Angle, spot.Range, spot.Brightness = Enum.NormalId.Bottom, 70, 10, 2.4
	spot.Color, spot.Shadows = Color3.fromRGB(255, 240, 220), false
	spot.Parent = lamp
	body.Name = "Figure"
	body.Parent = carrier.Parent
	face.Figure = body
end

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- `entry` (a Bounties.entries() entry, number `index` of `total`) on `face`.
local function draw(face: Face, entry, index: number, total: number)
	local p = face.Parts
	local boss = entry.Boss
	local tint = GemConfig.ElementColors[entry.Element] or AMBER
	local threat = BossLoot.threat(boss)
	local group = threat >= RiftRun.GroupThreat
	local color = THREAT_COLORS[math.clamp(threat - 1, 1, 3)] or AMBER;
	(p.Count :: TextLabel).Text = string.format("%02d / %02d", index, total);
	(p.Name :: TextLabel).Text = string.upper(boss.Name or "?");
	(p.Wash :: Frame).BackgroundColor3 = tint;
	(p.Accent :: Frame).BackgroundColor3 = tint;
	(p.Fill :: Frame).BackgroundColor3 = tint;
	(p.Kind :: TextLabel).Text = string.format(
		'<font color="%s">%s</font>   <font color="%s">%s</font>',
		hex(tint),
		Lang.translate(string.upper(GemConfig.elementName(entry.Element) or entry.Element or "")),
		hex(color),
		Lang.translate("THREAT " .. BossLoot.numeral(threat))
	);
	(p.Party :: TextLabel).Text = Lang.translate(if group then "BRING A PARTY" else "SOLO OR PARTY");
	(p.Party :: TextLabel).TextColor3 = if group then RED else Color3.fromRGB(110, 220, 140);
	(p.Seen :: TextLabel).Text = string.upper(entry.Biome or "")
	portrait(face, tostring(boss.Id), tint)
	-- (the flash: a blink of light over the new one)
	local flash = p.Flash :: Frame
	flash.BackgroundTransparency = 0.25
	TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

-- The board, built once in the Shelter's frame.
local function build(frame: CFrame): Folder
	local made = Instance.new("Folder")
	made.Name = "BountyBoard"
	local b = frame * CFrame.new(Bounties.Board.Spot)
	-- The ring on the floor round it, and the plinth.
	disc(made, b * CFrame.new(0, 0.06, 0), 5.8, 0.04, AMBER, Enum.Material.Neon).Transparency = 0.15
	disc(made, b * CFrame.new(0, 0.07, 0), 5.5, 0.05, Color3.fromRGB(30, 30, 38), Enum.Material.Slate)
	disc(made, b * CFrame.new(0, 0.45, 0), 3.2, 0.9, DARK, Enum.Material.Metal, true)
	disc(made, b * CFrame.new(0, 0.92, 0), 3.3, 0.08, AMBER, Enum.Material.Metal)
	disc(made, b * CFrame.new(0, 0.97, 0), 2.9, 0.04, AMBER, Enum.Material.Neon).Transparency = 0.3
	disc(made, b * CFrame.new(0, 0.98, 0), 2.55, 0.05, DARK, Enum.Material.Metal)
	-- The pylons: dark steel, an amber slit up each side, a red cap.
	for _, s in { -1, 1 } do
		local foot = b * CFrame.new(s * 5.6, 0, 0)
		piece(made, foot * CFrame.new(0, 0.3, 0), Vector3.new(2, 0.6, 2), DARK, Enum.Material.Metal, true)
		piece(made, foot * CFrame.new(0, 6.8, 0), Vector3.new(1.1, 13, 1.1), DARK, Enum.Material.Metal, true)
		for _, side in { -1, 1 } do
			piece(made, foot * CFrame.new(0, 6.8, side * 0.57), Vector3.new(0.28, 11, 0.06), AMBER, Enum.Material.Neon)
		end
		piece(made, foot * CFrame.new(s * 0.57, 6.8, 0), Vector3.new(0.06, 11, 0.28), AMBER, Enum.Material.Neon)
		local cap = piece(made, foot * CFrame.new(0, 13.45, 0), Vector3.new(1.4, 0.3, 1.4), RED, Enum.Material.Neon)
		light(cap, Color3.fromRGB(255, 120, 90), 8, 0.6)
		piece(made, foot * CFrame.new(-s * 0.55, 7.6, 0), Vector3.new(0.8, 1.4, 0.7), STEEL, Enum.Material.Metal)
	end
	-- The screen: a dark housing, amber edges, a face each way.
	piece(made, b * CFrame.new(0, 7.6, 0), Vector3.new(10.2, 7.2, 1), DARK, Enum.Material.Metal, true)
	for _, y in { -3.62, 3.62 } do
		piece(made, b * CFrame.new(0, 7.6 + y, 0), Vector3.new(10.4, 0.18, 1.08), AMBER, Enum.Material.Metal)
	end
	for _, x in { -5.12, 5.12 } do
		piece(made, b * CFrame.new(x, 7.6, 0), Vector3.new(0.18, 7.4, 1.08), AMBER, Enum.Material.Metal)
	end
	for i, side in { 1, -1 } do
		-- (each face turned to look out its own side)
		local carrier = piece(
			made,
			b * CFrame.new(0, 7.6, side * 0.53) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			Vector3.new(9.6, 6.6, 0.05),
			INK,
			Enum.Material.SmoothPlastic
		)
		carrier.Name = if i == 1 then "FaceFront" else "FaceBack"
		light(carrier, Color3.fromRGB(255, 214, 170), 14, 0.7)
		faces[i] = layout(carrier)
	end
	-- The lightbox on top, BOUNTIES each way, the crossed blades over it.
	piece(made, b * CFrame.new(0, 12.3, 0), Vector3.new(7.6, 1.9, 1), DARK, Enum.Material.Metal)
	for _, x in { -2.8, 2.8 } do
		piece(made, b * CFrame.new(x, 11.5, 0), Vector3.new(0.4, 0.6, 0.4), STEEL, Enum.Material.Metal)
	end
	for _, side in { 1, -1 } do
		local lit = piece(
			made,
			b * CFrame.new(0, 12.3, side * 0.53) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			Vector3.new(7, 1.4, 0.05),
			IVORY,
			Enum.Material.SmoothPlastic
		)
		local gui = new("SurfaceGui", { Face = Enum.NormalId.Front, CanvasSize = Vector2.new(700, 140), LightInfluence = 0, Brightness = 1.2 }, lit)
		new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = IVORY, BorderSizePixel = 0 }, gui)
		local word = text(gui, Lang.translate("BOUNTIES"), 0, 0, 700, 140, 96, INK, nil, Enum.TextXAlignment.Center)
		word.ZIndex = 2
		new("Frame", { Position = UDim2.fromOffset(0, 126), Size = UDim2.fromOffset(700, 14), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 2 }, gui)
	end
	local crest = b * CFrame.new(0, 14.6, 0)
	local medal = piece(made, crest * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.3, 2, 2), AMBER, Enum.Material.Metal)
	medal.Shape = Enum.PartType.Cylinder
	for _, s in { -1, 1 } do
		piece(made, crest * CFrame.Angles(0, 0, math.rad(s * 38)), Vector3.new(0.32, 4.4, 0.16), STEEL, Enum.Material.Metal)
		piece(made, crest * CFrame.new(s * 1.3, -1.6, 0) * CFrame.Angles(0, 0, math.rad(s * 38)), Vector3.new(0.9, 0.24, 0.2), DARK, Enum.Material.Metal)
	end
	-- Its prompt: the bounty board, from here.
	local anchor = piece(made, b * CFrame.new(0, 2.6, 0), Vector3.new(1, 1, 1), DARK, Enum.Material.SmoothPlastic)
	anchor.Transparency, anchor.Name = 1, "BountyPrompt"
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take a bounty"
	prompt.ObjectText = "Bounty Board"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function()
		require(script.Parent.RiftClient).openGate("Bounty", anchor.Position)
	end)
	prompt.Parent = anchor
	return made
end

function BountyBoard.mount(frame: CFrame)
	if at then
		return
	end
	at = frame
	model = build(frame)
end

local function near(): boolean
	local camera = workspace.CurrentCamera
	if not (at and camera) then
		return false
	end
	local spot = at * CFrame.new(Bounties.Board.Spot)
	return (camera.CFrame.Position - spot.Position).Magnitude < BountyBoard.Reach
end

function BountyBoard.show(on: boolean)
	wanted = on
	if not model then
		return
	end
	local parent = if on and near() then workspace else nil
	if model.Parent ~= parent then
		model.Parent = parent
	end
end

-- What the faces show now: a new bounty drawn when its turn comes, the
-- time-left bar filled, a portrait put in once it's come from the server.
function BountyBoard.refresh(now: number)
	local front, back, share = Bounties.boardAt(now)
	if not front then
		return
	end
	local list = Bounties.entries()
	for i, entry in { front, back } do
		local face = faces[i]
		if not face then
			continue
		end
		local id = tostring(entry.Boss.Id)
		if face.Shown ~= id then
			face.Shown = id
			local index = 1
			for n, e in list do
				if e.Boss.Id == entry.Boss.Id then
					index = n
				end
			end
			draw(face, entry, index, #list)
		elseif face.Missing then
			portrait(face, id, GemConfig.ElementColors[entry.Element])
		end
		local fill = face.Parts.Fill :: Frame
		fill.Size = UDim2.fromScale(1 - share, 1)
	end
end

function BountyBoard.step(dt: number)
	if not (model and wanted) then
		return
	end
	clock += dt
	if clock < 0.2 then
		return
	end
	clock = 0
	BountyBoard.show(wanted)
	if model.Parent then
		BountyBoard.refresh(workspace:GetServerTimeNow())
	end
end

-- (for its tests and renders: the board as built)
function BountyBoard._built(): Folder?
	return model
end

return BountyBoard
