--[[
	The Q / E / R triad's look (client only, nothing replicates). Every move
	reads at a glance, for you and for whoever you fight:

	  cast(who, id, element, key)      the move's name over your head in its
	                                   key's colours, and a sigil at your feet:
	                                   a blade for Q, an orb for E, a hex for R
	  aura(who, id, element, kind, s)  what a move leaves on you while it lasts:
	                                   an empowered blade, a shield bubble, ice
	                                   armor, phoenix wings, a toxic shell...
	  wall(who, kind, cframe, w, s)    a wall of ice crystals or of flame
	  steal(from, to, resource, n)     Charge (blue) or Stamina (green) orbs
	                                   pulled from a victim into the thief
	  mark(root, s)                    Static Brand's crosshair on its target
	  shatter / root / breakBurst      freezes breaking, roots, shield bursts
	  phoenix(who, at)                 a rebirth in fire
	  trail / field / pylon            burning ground, ice, a thunder pylon
	  pillar / ring / decoy / slick    the showcase defenses: an Ice Pillar,
	                                   a Ring of Fire, a Hologram Decoy (and
	                                   decoyPop), an Acid Slick

	Built like the rest of the kit (CombatVfx): neon and glass parts, trails,
	particles and lights, tweened and cleaned up after themselves.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatFx = require(script.Parent.CombatFx)
local CombatSound = require(script.Parent.CombatSound)
local GemConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GemConfig"))
local CombatTechnology = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatTechnology"))

local TriadVfx = {}

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 214, 90)
local ICE = Color3.fromRGB(205, 238, 255)
local DEEP_ICE = Color3.fromRGB(110, 190, 255)
local HOT = Color3.fromRGB(255, 226, 140)
local EMBER = Color3.fromRGB(255, 110, 30)
local ACID = Color3.fromRGB(190, 255, 140)
local CHARGE = Color3.fromRGB(70, 150, 255)
local STAMINA = Color3.fromRGB(70, 215, 120)
-- The three keys' colours (the HUD and the inventory use the same).
TriadVfx.KeyColors = {
	Q = Color3.fromRGB(255, 138, 92),
	E = Color3.fromRGB(122, 196, 255),
	R = Color3.fromRGB(120, 230, 170),
}
TriadVfx.LaneNames = { Q = "OFFENSE", E = "ABILITY", R = "DEFENSE" }

local function colorOf(element: string?): Color3
	return GemConfig.ElementColors[element or ""] or GOLD
end

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "TriadVfx"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end
local function busy(): boolean
	return #fxFolder():GetChildren() > 420
end

local function part(size: Vector3, cframe: CFrame, color: Color3, transparency: number?, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = "Vfx"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.CFrame = cframe
	p.Parent = fxFolder()
	return p
end
local function glass(size: Vector3, cframe: CFrame, color: Color3, transparency: number?): Part
	local p = part(size, cframe, color, transparency or 0.2, nil, Enum.Material.Glass)
	p.Reflectance = 0.3
	return p
end
local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end
local function fade(p: BasePart, seconds: number, goal: { [string]: any }?, style: Enum.EasingStyle?)
	local target = goal or {}
	target.Transparency = 1
	tween(p, seconds, target, style)
	Debris:AddItem(p, seconds + 0.05)
end
local function disc(at: Vector3, diameter: number, color: Color3, transparency: number): Part
	return part(
		Vector3.new(0.08, diameter, diameter),
		CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		transparency,
		Enum.PartType.Cylinder
	)
end
local function ringAt(at: Vector3, diameter: number, color: Color3, transparency: number, seconds: number, grow: number)
	local r = disc(at, diameter, color, transparency)
	fade(r, seconds, { Size = Vector3.new(0.04, diameter * grow, diameter * grow) })
	return r
end
local function rootOf(who: any): BasePart?
	if typeof(who) == "Instance" then
		if who:IsA("BasePart") then
			return who
		end
		local character = if who:IsA("Player") then who.Character else who
		return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end
local function floorUnder(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = { fxFolder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), params)
	return if hit then hit.Position + Vector3.new(0, 0.05, 0) else at - Vector3.new(0, 2.9, 0)
end
local function light(parent: Instance, color: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = parent
	return l
end
local function emitter(parent: Instance, color: Color3, rate: number, opts: { [string]: any }?): ParticleEmitter
	local o = opts or {}
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.Texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color:Lerp(WHITE, 0.45), color)
	e.LightEmission = o.Light or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.Size or 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(o.Life or 0.5, (o.Life or 0.5) * 1.6)
	e.Speed = NumberRange.new(o.Speed or 1.5, (o.Speed or 1.5) * 2)
	e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
	e.Acceleration = o.Acceleration or Vector3.new(0, 2, 0)
	e.Rate = rate
	e.LockedToPart = o.Locked == true
	e.Parent = parent
	return e
end

-- Things that ride along with a body (auras, wings, marks): every frame
-- they're placed from the root, until they run out.
type Follower = { Root: BasePart, Parts: { { Part: BasePart, Offset: CFrame } }, Until: number, Born: number, Animate: ((Follower, number) -> ())?, Key: string? }
local followers: { Follower } = {}
local followConnection: RBXScriptConnection? = nil
local function step()
	local now = os.clock()
	for i = #followers, 1, -1 do
		local f = followers[i]
		if now >= f.Until or not f.Root.Parent then
			table.remove(followers, i)
			for _, entry in f.Parts do
				if entry.Part.Parent then
					fade(entry.Part, 0.3)
				end
			end
		else
			local base = f.Root.CFrame
			for _, entry in f.Parts do
				if entry.Part.Parent then
					entry.Part.CFrame = base * entry.Offset
				end
			end
			if f.Animate then
				f.Animate(f, now - f.Born)
			end
		end
	end
	if #followers == 0 and followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
end
local function follow(root: BasePart, seconds: number, key: string?, animate: ((Follower, number) -> ())?): Follower
	-- One of each kind per body: a new cast replaces the old.
	if key then
		for _, f in followers do
			if f.Root == root and f.Key == key then
				f.Until = 0
			end
		end
	end
	local f: Follower = { Root = root, Parts = {}, Until = os.clock() + seconds, Born = os.clock(), Animate = animate, Key = key }
	table.insert(followers, f)
	if not followConnection then
		followConnection = RunService.RenderStepped:Connect(step)
	end
	return f
end
local function hold(f: Follower, p: BasePart, offset: CFrame)
	table.insert(f.Parts, { Part = p, Offset = offset })
	p.CFrame = f.Root.CFrame * offset
end
local function stopFollow(root: BasePart, key: string)
	for _, f in followers do
		if f.Root == root and f.Key == key then
			f.Until = 0
		end
	end
end
TriadVfx._followers = followers

-- Cast -----------------------------------------------------------------------------

-- The move's name above the caster, in its key's colours: everyone reads
-- "R · FROZEN WALL" the moment it goes up.
local function nameplate(root: BasePart, key: string, name: string, color: Color3)
	local character = root.Parent
	local head = character and character:FindFirstChild("Head") or root
	local board = Instance.new("BillboardGui")
	board.Name = "TriadName"
	board.Size = UDim2.fromOffset(240, 34)
	board.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.MaxDistance = 140
	board.Adornee = head
	local keyColor = TriadVfx.KeyColors[key] or GOLD
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = board
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.Parent = holder
	local badge = Instance.new("TextLabel")
	badge.Size = UDim2.fromOffset(26, 26)
	badge.BackgroundColor3 = keyColor
	badge.Text = key
	badge.TextColor3 = Color3.fromRGB(14, 16, 22)
	badge.Font = Enum.Font.GothamBlack
	badge.TextSize = 16
	badge.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = badge
	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 26)
	label.BackgroundTransparency = 1
	label.Text = string.upper(name)
	label.TextColor3 = color:Lerp(WHITE, 0.55)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 17
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(8, 10, 14)
	label.Parent = holder
	board.Parent = head
	-- Pops in, rises and fades.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = holder
	tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.9, function()
		if board.Parent then
			tween(board, 0.5, { StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0) })
			tween(label, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween(badge, 0.5, { TextTransparency = 1, BackgroundTransparency = 1 })
		end
	end)
	Debris:AddItem(board, 1.5)
end

-- The key's sigil at your feet: a blade for Q, an orb for E, a hex for R.
local function sigil(root: BasePart, key: string, color: Color3, seconds: number)
	local floor = floorUnder(root.Position)
	local keyColor = TriadVfx.KeyColors[key] or GOLD
	ringAt(floor, 3, color, 0.2, 0.45, 2.6)
	ringAt(floor + Vector3.new(0, 0.02, 0), 2, keyColor, 0.35, 0.6, 3.4)
	local life = math.max(0.45, seconds + 0.2)
	if key == "Q" then
		-- Two blades crossing and spinning shut.
		for i, angle in { 45, -45 } do
			local blade = part(
				Vector3.new(0.18, 0.06, 4.2),
				CFrame.new(floor + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, math.rad(angle + 60), 0),
				if i == 1 then keyColor else color,
				0.15
			)
			tween(blade, life, { CFrame = CFrame.new(floor + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, math.rad(angle), 0) }, Enum.EasingStyle.Back)
			task.delay(life * 0.7, function()
				fade(blade, 0.25, { Size = Vector3.new(0.05, 0.02, 5.2) })
			end)
		end
	elseif key == "E" then
		-- An orb gathering at the chest.
		local orb = part(Vector3.one * 0.4, root.CFrame * CFrame.new(0, 0.6, -1.4), color:Lerp(WHITE, 0.4), 0, Enum.PartType.Ball)
		light(orb, color, 3, 10)
		tween(orb, life * 0.8, { Size = Vector3.one * 1.3 }, Enum.EasingStyle.Sine)
		task.delay(life * 0.8, function()
			fade(orb, 0.2, { Size = Vector3.one * 2.6 })
		end)
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local mote = part(Vector3.one * 0.18, CFrame.new(root.Position + Vector3.new(math.cos(a) * 3, 0.6, math.sin(a) * 3)), color, 0, Enum.PartType.Ball)
			fade(mote, life * 0.8, { CFrame = orb.CFrame, Size = Vector3.one * 0.05 }, Enum.EasingStyle.Sine)
		end
	else
		-- A hexagon of light rising around you.
		for i = 0, 5 do
			local a = i * math.pi / 3
			local side = part(
				Vector3.new(1.8, 0.08, 0.12),
				CFrame.new(floor + Vector3.new(math.cos(a) * 1.6, 0.06, math.sin(a) * 1.6)) * CFrame.Angles(0, -a + math.pi / 2, 0),
				keyColor,
				0.15
			)
			tween(side, life, {
				CFrame = side.CFrame + Vector3.new(0, 2.6, 0),
				Size = Vector3.new(1.8, 0.04, 0.06),
			}, Enum.EasingStyle.Sine)
			task.delay(life, function()
				fade(side, 0.25)
			end)
		end
	end
end

function TriadVfx.cast(who: Player, id: string?, element: string?, key: string?, castTime: number?)
	local root = rootOf(who)
	if not root then
		return
	end
	local color = colorOf(element)
	local move = id and CombatTechnology.Catalog[id]
	key = key or (move and move.Key) or "Q"
	nameplate(root, key, if move then move.Name else "?", color)
	sigil(root, key, color, castTime or 0.3)
	CombatSound.element("Cast", element, root.Position, { Volume = 0.7 })
	if key == "R" then
		CombatSound.play("Shield", root.Position, { Volume = 0.7, Pitch = 0.9 })
	end
end

-- Auras ------------------------------------------------------------------------------

local AURA = {}

-- An empowered blade: the sword hand burns, frosts or drips, with a light.
function AURA.Empower(root, color, seconds, element)
	local character = root.Parent
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	local anchorPart = (hand or root) :: BasePart
	local attachment = Instance.new("Attachment")
	attachment.Name = "TriadEmpower"
	attachment.Position = Vector3.new(0, -0.6, 0)
	attachment.Parent = anchorPart
	local spec = if element == "Fire"
		then { Texture = "rbxasset://textures/particles/fire_main.dds", Size = 0.7, Speed = 2, Acceleration = Vector3.new(0, 6, 0) }
		elseif element == "Frost" then { Size = 0.3, Speed = 0.6, Acceleration = Vector3.new(0, -2, 0) }
		elseif element == "Poison" then { Size = 0.35, Speed = 0.5, Acceleration = Vector3.new(0, -6, 0), Light = 0.4 }
		else { Size = 0.4, Speed = 3, Acceleration = Vector3.zero }
	emitter(attachment, color, 40, spec)
	light(attachment, color, 2.5, 9)
	Debris:AddItem(attachment, seconds)
	-- A rune ring turning round the hand.
	local f = follow(root, seconds, "Empower", function(f, t)
		for i, entry in f.Parts do
			entry.Offset = CFrame.new(1.25, -0.2, -0.6) * CFrame.Angles(0, t * 4 + i * math.pi, math.rad(90))
		end
	end)
	for i = 1, 2 do
		local ring = part(Vector3.new(0.06, 1.6, 1.6), root.CFrame, if i == 1 then color else WHITE, 0.25, Enum.PartType.Cylinder)
		hold(f, ring, CFrame.new(1.25, -0.2, -0.6))
	end
	-- Three sparks of the element circling the sword arm.
	local orbit = {}
	for i = 1, 3 do
		local mote = part(Vector3.one * 0.32, root.CFrame, color:Lerp(WHITE, 0.35), 0, Enum.PartType.Ball)
		light(mote, color, 1.2, 5)
		table.insert(orbit, mote)
		hold(f, mote, CFrame.new())
	end
	local spin = f.Animate
	f.Animate = function(self, t)
		if spin then
			spin(self, t)
		end
		for i, mote in orbit do
			local a = t * 7 + i * math.pi * 2 / 3
			for _, entry in self.Parts do
				if entry.Part == mote then
					entry.Offset = CFrame.new(1.25 + math.cos(a) * 0.7, -0.2 + math.sin(t * 3 + i) * 0.5, -0.6 + math.sin(a) * 0.7)
				end
			end
		end
	end
	CombatFx.flash(root.Position, color, 4, 12, 0.3)
end

-- A hex bubble that shimmers while it holds.
local function bubble(root, color, seconds, key, size, transparency)
	local f = follow(root, seconds, key, function(f, t)
		local shell = f.Parts[1]
		if shell then
			shell.Part.Transparency = transparency + 0.08 * math.sin(t * 6)
		end
	end)
	local shell = part(Vector3.one * size, root.CFrame, color, transparency, Enum.PartType.Ball, Enum.Material.ForceField)
	hold(f, shell, CFrame.new(0, 0.2, 0))
	local rim = part(Vector3.one * (size + 0.3), root.CFrame, color:Lerp(WHITE, 0.3), 0.85, Enum.PartType.Ball)
	hold(f, rim, CFrame.new(0, 0.2, 0))
	shell.Size = Vector3.one * 1
	tween(shell, 0.25, { Size = Vector3.one * size }, Enum.EasingStyle.Back)
	return f
end

function AURA.Shield(root, color, seconds)
	bubble(root, color, seconds, "Shield", 7.2, 0.45)
	CombatFx.burst(root.Position, color, "Sparks", 1)
end
function AURA.Refill(root, color)
	ringAt(floorUnder(root.Position), 4, color, 0.1, 0.4, 2)
	CombatFx.flash(root.Position, color, 4, 12, 0.25)
end
function AURA.Immune(root, _color, seconds)
	bubble(root, ACID, seconds, "Immune", 7.6, 0.25)
end
function AURA.Deflect(root, _color, seconds)
	local f = bubble(root, GOLD, seconds, "Deflect", 9, 0.4)
	-- Hex panels orbiting the dome.
	local panels = {}
	for i = 1, 6 do
		local p = part(Vector3.new(1.6, 1.6, 0.06), root.CFrame, GOLD, 0.45)
		table.insert(panels, p)
		hold(f, p, CFrame.new())
	end
	local animate = f.Animate
	f.Animate = function(self, t)
		if animate then
			animate(self, t)
		end
		for i, p in panels do
			local a = t * 1.6 + i * math.pi / 3
			for _, entry in self.Parts do
				if entry.Part == p then
					entry.Offset = CFrame.new(math.cos(a) * 4.4, 0.6 + math.sin(t * 3 + i) * 0.6, math.sin(a) * 4.4)
						* CFrame.Angles(0, -a + math.pi / 2, 0)
				end
			end
		end
	end
end
function AURA.Guard(root, color, seconds)
	-- A disc of flame held before the shield.
	local f = follow(root, seconds, "Guard", function(f, t)
		local d = f.Parts[1]
		if d then
			d.Part.Transparency = 0.35 + 0.15 * math.sin(t * 18)
		end
	end)
	local face = part(Vector3.new(0.1, 4.2, 4.2), root.CFrame, color, 0.35, Enum.PartType.Cylinder)
	hold(f, face, CFrame.new(0, 0.6, -2.2) * CFrame.Angles(0, math.rad(90), 0))
	local core = part(Vector3.new(0.12, 2.4, 2.4), root.CFrame, HOT, 0.2, Enum.PartType.Cylinder)
	hold(f, core, CFrame.new(0, 0.6, -2.25) * CFrame.Angles(0, math.rad(90), 0))
	emitter(core, EMBER, 30, { Texture = "rbxasset://textures/particles/fire_main.dds", Size = 0.8, Acceleration = Vector3.new(0, 5, 0) })
end
function AURA.Boost(root, color, seconds)
	local f = follow(root, seconds, "Boost", function(f, t)
		for i, entry in f.Parts do
			entry.Offset = CFrame.new(0, -2.7 + (i - 1) * 0.15 + ((t * 1.3 + i * 0.5) % 1) * 3, 0) * CFrame.Angles(0, 0, math.rad(90))
			entry.Part.Transparency = 0.25 + ((t * 1.3 + i * 0.5) % 1) * 0.75
		end
	end)
	for _ = 1, 3 do
		hold(f, part(Vector3.new(0.05, 3.6, 3.6), root.CFrame, color, 0.4, Enum.PartType.Cylinder), CFrame.new())
	end
	CombatFx.burst(root.Position, color, "Embers", 1.2)
end
function AURA.Heal(root, _color, seconds)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, -2, 0)
	attachment.Parent = root
	emitter(attachment, STAMINA, 14, { Size = 0.3, Speed = 2, Spread = 40, Acceleration = Vector3.new(0, 3, 0), Life = 0.9 })
	light(attachment, STAMINA, 1.5, 8)
	Debris:AddItem(attachment, seconds)
	ringAt(floorUnder(root.Position), 3, STAMINA, 0.2, 0.6, 2.2)
end
function AURA.Phoenix(root, color, seconds)
	-- Wings of flame on the back, beating slowly.
	local f = follow(root, seconds, "Phoenix", function(f, t)
		local beat = math.sin(t * 3) * 0.25
		for i, entry in f.Parts do
			local side = if i % 2 == 1 then 1 else -1
			local tier = math.ceil(i / 2)
			entry.Offset = CFrame.new(side * (0.6 + tier * 0.75), 1.2 - tier * 0.3, 0.85)
				* CFrame.Angles(0, side * (0.25 + beat * 0.6), side * (0.55 - tier * 0.3 + beat))
			entry.Part.Transparency = 0.15 + tier * 0.15 + 0.1 * math.sin(t * 9 + i)
		end
	end)
	for tier = 1, 3 do
		for _ = 1, 2 do
			local feather = part(Vector3.new(3.2 - tier * 0.55, 0.75 - tier * 0.12, 0.08), root.CFrame, if tier == 1 then HOT else color, 0.2)
			hold(f, feather, CFrame.new())
		end
	end
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 1, 0.8)
	attachment.Parent = root
	emitter(attachment, EMBER, 18, { Texture = "rbxasset://textures/particles/fire_main.dds", Size = 0.5, Acceleration = Vector3.new(0, 4, 0) })
	Debris:AddItem(attachment, seconds)
end
function AURA.Armor(root, _color, seconds)
	-- Ice plates frozen over the body.
	local f = follow(root, seconds, "Armor")
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local plate = glass(Vector3.new(1.1, 1.8, 0.14), root.CFrame, ICE, 0.25)
		hold(f, plate, CFrame.new(math.cos(a) * 1.25, -0.2 + (i % 2) * 0.9, math.sin(a) * 1.25) * CFrame.Angles(0, -a + math.pi / 2, (i % 3 - 1) * 0.2))
	end
	CombatFx.burst(root.Position, ICE, "Frost", 1)
	CombatSound.play("Freeze", root.Position, { Volume = 0.6 })
end
function AURA.Resist(root, _color, seconds)
	-- A ring of the four elements turning round the waist.
	local elements = { "Fire", "Frost", "Shock", "Poison" }
	local f = follow(root, seconds, "Resist", function(f, t)
		for i, entry in f.Parts do
			local a = t * 2 + i * math.pi / 2
			entry.Offset = CFrame.new(math.cos(a) * 2, 0, math.sin(a) * 2)
		end
	end)
	for _, element in elements do
		local gem = part(Vector3.new(0.45, 0.7, 0.45), root.CFrame, colorOf(element), 0.05)
		light(gem, colorOf(element), 1, 5)
		hold(f, gem, CFrame.new())
	end
end
function AURA.Riposte(root, color, seconds)
	local f = follow(root, seconds, "Riposte", function(f, t)
		for i, entry in f.Parts do
			local a = t * 3 + i * math.pi * 2 / 3
			entry.Offset = CFrame.new(math.cos(a) * 1.8, 0.4, math.sin(a) * 1.8) * CFrame.Angles(0, -a, math.rad(70))
		end
	end)
	for _ = 1, 3 do
		hold(f, glass(Vector3.new(0.12, 1.6, 0.3), root.CFrame, ICE, 0.15), CFrame.new())
	end
	ringAt(floorUnder(root.Position), 3, color, 0.2, 0.5, 2)
end
function AURA.Catch(root, color, seconds)
	local character = root.Parent
	local hand = character and (character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm"))
	local attachment = Instance.new("Attachment")
	attachment.Parent = (hand or root) :: BasePart
	emitter(attachment, color, 35, { Size = 0.35, Speed = 4, Acceleration = Vector3.zero, Life = 0.2 })
	light(attachment, color, 3, 8)
	Debris:AddItem(attachment, seconds)
end
function AURA.Grounded(root, color, seconds)
	-- Four stakes driven into the ground round you, arcing to your feet.
	local floor = floorUnder(root.Position)
	for i = 1, 4 do
		local a = i * math.pi / 2 + math.pi / 4
		local base = floor + Vector3.new(math.cos(a) * 2.6, 0, math.sin(a) * 2.6)
		local stake = part(Vector3.new(0.25, 0.1, 0.25), CFrame.new(base), color, 0)
		tween(stake, 0.15, { Size = Vector3.new(0.25, 2.4, 0.25), CFrame = CFrame.new(base + Vector3.new(0, 1.2, 0)) }, Enum.EasingStyle.Back)
		task.delay(seconds, function()
			fade(stake, 0.3)
		end)
	end
	local ground = disc(floor, 6, color, 0.6)
	task.delay(seconds, function()
		fade(ground, 0.3)
	end)
end
function AURA.Corrosion(root, color, seconds)
	local f = follow(root, seconds, "Corrosion", function(f, t)
		local pool = f.Parts[1]
		if pool then
			pool.Part.Transparency = 0.72 + 0.08 * math.sin(t * 4)
		end
	end)
	local pool = part(Vector3.new(0.06, 12, 12), root.CFrame, color:Lerp(Color3.new(0, 0, 0), 0.35), 0.72, Enum.PartType.Cylinder)
	hold(f, pool, CFrame.new(0, -2.85, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, -2.6, 0)
	attachment.Parent = root
	emitter(attachment, ACID, 30, { Size = 0.4, Speed = 2, Spread = 80, Acceleration = Vector3.new(0, 2, 0), Light = 0.3 })
	Debris:AddItem(attachment, seconds)
end
function AURA.Mantle(root, color, seconds)
	-- A shell of toxic spines.
	local f = follow(root, seconds, "Mantle", function(f, t)
		for i, entry in f.Parts do
			local a = i / #f.Parts * math.pi * 2 + t * 0.6
			entry.Offset = CFrame.new(math.cos(a) * 1.6, -0.6 + (i % 3) * 0.9, math.sin(a) * 1.6)
				* CFrame.Angles(0, -a, math.rad(90 + 20 * math.sin(t * 5 + i)))
		end
	end)
	for _ = 1, 9 do
		hold(f, part(Vector3.new(0.14, 1.1, 0.14), root.CFrame, color, 0.1), CFrame.new())
	end
end
function AURA.EmpowerEnd(root)
	stopFollow(root, "Empower")
	for _, child in root.Parent and root.Parent:GetDescendants() or {} do
		if child:IsA("Attachment") and child.Name == "TriadEmpower" then
			child:Destroy()
		end
	end
end

function TriadVfx.aura(who: Player, _id: string?, element: string?, kind: string, seconds: number?)
	local root = rootOf(who)
	local handler = AURA[kind]
	if not root or not handler then
		return
	end
	handler(root, colorOf(element), seconds or 1, element)
end

-- Walls -------------------------------------------------------------------------------

function TriadVfx.wall(_who: Player, kind: string, frame: CFrame, width: number, seconds: number, element: string?)
	local floor = floorUnder(frame.Position)
	local facing = frame.LookVector * Vector3.new(1, 0, 1)
	if facing.Magnitude < 0.01 then
		facing = Vector3.new(0, 0, -1)
	end
	facing = facing.Unit
	local side = Vector3.new(-facing.Z, 0, facing.X)
	local pieces = math.max(4, math.floor(width / 1.4))
	local color = colorOf(element)
	if kind == "Ice" then
		CombatSound.play("Freeze", floor, { Volume = 1 })
		for i = 1, pieces do
			local along = (i - 0.5) / pieces - 0.5
			local height = 5.5 + math.sin(i * 1.7) * 1.2 + math.random() * 0.8
			local base = floor + side * along * width + facing * (math.random() - 0.5) * 0.6
			local crystal = glass(
				Vector3.new(width / pieces * 1.25, 0.2, 1.3),
				CFrame.lookAt(base, base + facing) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.25),
				if i % 3 == 0 then DEEP_ICE else ICE,
				0.12
			)
			task.delay(i * 0.025, function()
				tween(crystal, 0.22, {
					Size = Vector3.new(width / pieces * 1.25, height, 1.3),
					CFrame = crystal.CFrame + Vector3.new(0, height / 2, 0),
				}, Enum.EasingStyle.Back)
			end)
			-- A bright edge down the middle of each crystal.
			local edge = part(Vector3.new(0.08, 0.1, 0.08), crystal.CFrame, WHITE, 0.3)
			task.delay(i * 0.025, function()
				tween(edge, 0.22, { Size = Vector3.new(0.08, height * 0.9, 0.08), CFrame = crystal.CFrame + Vector3.new(0, height / 2, -0.66) }, Enum.EasingStyle.Back)
			end)
			task.delay(seconds, function()
				-- Shatter: chips fly, the crystals crumble down.
				fade(crystal, 0.35, { Size = Vector3.new(0.4, height * 0.4, 0.4), CFrame = crystal.CFrame - Vector3.new(0, height * 0.4, 0) })
				fade(edge, 0.2)
				if i % 2 == 0 then
					CombatFx.burst(base + Vector3.new(0, height / 2, 0), ICE, "Shards", 0.8)
				end
			end)
		end
		local mist = disc(floor + Vector3.new(0, 0.05, 0), width * 1.2, ICE, 0.7)
		task.delay(seconds, function()
			fade(mist, 0.5)
			CombatSound.play("GuardBreak", floor, { Volume = 0.5, Pitch = 1.3 })
		end)
		CombatFx.burst(floor + Vector3.new(0, 2, 0), ICE, "Frost", 1.6)
	elseif kind == "Tesla" then
		-- Tesla Fence: steel posts with crackling arcs strung between them.
		CombatSound.play("Zap", floor, { Volume = 1 })
		CombatSound.element("Impact", "Shock", floor, { Volume = 0.8 })
		local posts = math.max(3, math.floor(width / 2.5) + 1)
		local tops = {}
		for i = 1, posts do
			local along = (i - 1) / (posts - 1) - 0.5
			local base = floor + side * along * width
			local mast = part(Vector3.new(0.45, 0.2, 0.45), CFrame.new(base), Color3.fromRGB(70, 74, 92), 0, nil, Enum.Material.Metal)
			tween(mast, 0.2, { Size = Vector3.new(0.45, 4.6, 0.45), CFrame = CFrame.new(base + Vector3.new(0, 2.3, 0)) }, Enum.EasingStyle.Back)
			local coil = part(Vector3.one * 0.2, CFrame.new(base + Vector3.new(0, 4.8, 0)), color, 0.05, Enum.PartType.Ball)
			tween(coil, 0.25, { Size = Vector3.one * 0.9 }, Enum.EasingStyle.Back)
			if i % 2 == 1 then
				light(coil, color, 3, 12)
			end
			table.insert(tops, { Base = base, Mast = mast, Coil = coil })
		end
		-- The arcs: three strands between each pair of posts, re-drawn jagged
		-- every few frames so the fence crackles.
		local strands = {}
		for i = 1, posts - 1 do
			for _, height in { 1.2, 2.6, 4.2 } do
				local first = part(Vector3.new(0.1, 0.1, 1), CFrame.new(tops[i].Base), color:Lerp(WHITE, 0.5), 1)
				local second = part(Vector3.new(0.1, 0.1, 1), CFrame.new(tops[i].Base), color:Lerp(WHITE, 0.5), 1)
				table.insert(strands, { Parts = { first, second }, From = tops[i].Base, To = tops[i + 1].Base, Height = height })
			end
		end
		local ends = os.clock() + seconds
		local nextDraw = 0
		local connection
		connection = RunService.Heartbeat:Connect(function()
			local now = os.clock()
			if now >= ends then
				connection:Disconnect()
				return
			end
			if now < nextDraw then
				return
			end
			nextDraw = now + 0.05
			for _, strand in strands do
				local a = strand.From + Vector3.new(0, strand.Height + (math.random() - 0.5) * 0.5, 0)
				local b = strand.To + Vector3.new(0, strand.Height + (math.random() - 0.5) * 0.5, 0)
				local mid = (a + b) / 2 + Vector3.new(0, (math.random() - 0.5) * 0.8, 0) + facing * (math.random() - 0.5) * 0.5
				local flicker = if math.random() < 0.2 then 0.85 else 0.05
				for n, from in { a, mid } do
					local to = if n == 1 then mid else b
					local segment = strand.Parts[n]
					segment.Size = Vector3.new(0.09 + math.random() * 0.08, 0.09, (to - from).Magnitude)
					segment.CFrame = CFrame.lookAt((from + to) / 2, to)
					segment.Transparency = flicker
				end
			end
		end)
		local glow = disc(floor + Vector3.new(0, 0.04, 0), width, color, 0.75)
		glow.Size = Vector3.new(0.06, 1.6, width)
		glow.CFrame = CFrame.lookAt(floor, floor + side) * CFrame.Angles(0, math.rad(90), math.rad(90))
		CombatFx.burst(floor + Vector3.new(0, 2.5, 0), color, "Sparks", 1.5)
		task.delay(seconds, function()
			for _, strand in strands do
				fade(strand.Parts[1], 0.15)
				fade(strand.Parts[2], 0.15)
			end
			for _, top in tops do
				fade(top.Mast, 0.3, { Size = Vector3.new(0.45, 0.2, 0.45), CFrame = CFrame.new(top.Base) })
				fade(top.Coil, 0.25, { Size = Vector3.one * 1.6 })
			end
			fade(glow, 0.4)
			CombatSound.play("Zap", floor, { Volume = 0.5, Pitch = 0.8 })
		end)
	elseif kind == "Spore" then
		-- Spore Wall: a hedge of giant toadstools that breathes green spores.
		CombatSound.play("Corrode", floor, { Volume = 1 })
		CombatSound.element("Impact", "Poison", floor, { Volume = 0.8 })
		local caps = {}
		for i = 1, pieces do
			local along = (i - 0.5) / pieces - 0.5
			local base = floor + side * along * width + facing * (math.random() - 0.5) * 0.8
			local height = 4 + math.sin(i * 1.9) * 1.2 + math.random() * 0.9
			local girth = width / pieces * 0.6
			local stalk = part(Vector3.new(girth, 0.2, girth), CFrame.new(base), Color3.fromRGB(150, 176, 120), 0, nil, Enum.Material.SmoothPlastic)
			local capSize = Vector3.new(width / pieces * 2.1, 1.5, width / pieces * 2.1)
			local cap = part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(base + Vector3.new(0, 0.2, 0)), color, 0.05, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
			local glowCap = part(Vector3.new(0.2, 0.2, 0.2), cap.CFrame, ACID, 0.45, Enum.PartType.Ball)
			task.delay(i * 0.03, function()
				tween(stalk, 0.3, { Size = Vector3.new(girth, height, girth), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) }, Enum.EasingStyle.Back)
				tween(cap, 0.32, { Size = capSize, CFrame = CFrame.new(base + Vector3.new(0, height, 0)) }, Enum.EasingStyle.Back)
				tween(glowCap, 0.32, { Size = capSize * Vector3.new(0.8, 0.6, 0.8), CFrame = CFrame.new(base + Vector3.new(0, height - 0.15, 0)) }, Enum.EasingStyle.Back)
			end)
			if i % 2 == 1 and not busy() then
				local attachment = Instance.new("Attachment")
				attachment.Position = Vector3.new(0, 0, 0)
				attachment.Parent = glowCap
				emitter(attachment, ACID, 9, { Size = 0.45, Speed = 0.8, Acceleration = Vector3.new(0, -0.6, 0), Life = 1.6, Light = 0.4 })
			end
			-- They breathe.
			local pulse = TweenService:Create(glowCap, TweenInfo.new(0.6 + i % 3 * 0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.15 })
			task.delay(0.35, function()
				pulse:Play()
			end)
			table.insert(caps, { Stalk = stalk, Cap = cap, Glow = glowCap, Pulse = pulse, Base = base })
		end
		local fog = disc(floor + Vector3.new(0, 0.05, 0), width, ACID, 0.6)
		fog.Size = Vector3.new(0.06, 3, width * 1.1)
		fog.CFrame = CFrame.lookAt(floor, floor + side) * CFrame.Angles(0, math.rad(90), math.rad(90))
		CombatFx.burst(floor + Vector3.new(0, 1.5, 0), ACID, "Drips", 1.4)
		task.delay(seconds, function()
			for _, c in caps do
				c.Pulse:Cancel()
				fade(c.Stalk, 0.4, { Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(c.Base) })
				fade(c.Cap, 0.4, { Size = Vector3.new(0.3, 0.3, 0.3), CFrame = CFrame.new(c.Base + Vector3.new(0, 0.3, 0)) })
				fade(c.Glow, 0.3)
			end
			fade(fog, 0.6)
			CombatFx.burst(floor + Vector3.new(0, 2, 0), ACID, "Smoke", 1.2)
		end)
	else
		CombatSound.play("Burn", floor, { Volume = 1 })
		CombatSound.element("Impact", "Fire", floor, { Volume = 0.8 })
		for i = 1, pieces do
			local along = (i - 0.5) / pieces - 0.5
			local base = floor + side * along * width
			local height = 4.5 + math.sin(i * 2.1) * 0.8
			local column = part(Vector3.new(0.2, width / pieces * 1.1, width / pieces * 1.1), CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)), EMBER, 0.15, Enum.PartType.Cylinder)
			tween(column, 0.2, { Size = Vector3.new(height, width / pieces * 0.9, width / pieces * 0.9), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, Enum.EasingStyle.Back)
			local heart = part(Vector3.new(0.2, 0.5, 0.5), column.CFrame, HOT, 0.1, Enum.PartType.Cylinder)
			tween(heart, 0.2, { Size = Vector3.new(height * 0.6, 0.6, 0.6), CFrame = CFrame.new(base + Vector3.new(0, height * 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
			if i % 2 == 1 then
				local attachment = Instance.new("Attachment")
				attachment.Parent = heart
				emitter(attachment, color, 22, { Texture = "rbxasset://textures/particles/fire_main.dds", Size = 1.4, Acceleration = Vector3.new(0, 8, 0), Spread = 25, Life = 0.6 })
				light(attachment, EMBER, 2, 10)
			end
			-- Flicker while it burns.
			local flicker = TweenService:Create(column, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.4 })
			task.delay(0.2, function()
				flicker:Play()
			end)
			task.delay(seconds, function()
				flicker:Cancel()
				fade(column, 0.35, { Size = Vector3.new(0.2, width / pieces * 0.5, width / pieces * 0.5), CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)) })
				fade(heart, 0.3)
			end)
		end
		local scorch = disc(floor + Vector3.new(0, 0.04, 0), width, Color3.fromRGB(60, 20, 10), 0.4)
		scorch.Size = Vector3.new(0.06, 2.2, width)
		scorch.CFrame = CFrame.lookAt(floor, floor + side) * CFrame.Angles(0, math.rad(90), math.rad(90))
		task.delay(seconds, function()
			fade(scorch, 0.6)
		end)
	end
end

local WALL_HIT = {
	Ice = { ICE, "Shards", "Parry" },
	Fire = { EMBER, "Embers", "Burn" },
	Tesla = { GemConfig.ElementColors.Shock, "Sparks", "Zap" },
	Spore = { ACID, "Drips", "Corrode" },
}
function TriadVfx.wallHit(position: Vector3, kind: string)
	local look = WALL_HIT[kind] or WALL_HIT.Fire
	CombatFx.burst(position, look[1], look[2], 0.9)
	CombatFx.flash(position, look[1], 4, 10, 0.2)
	CombatSound.play(look[3], position, { Volume = 0.7 })
end

-- Steals, marks, breaks ----------------------------------------------------------------

function TriadVfx.steal(from: Vector3, to: Player?, resource: string, amount: number?)
	if busy() then
		return
	end
	local color = if resource == "Stamina" then STAMINA else CHARGE
	local target = to and rootOf(to)
	CombatSound.play("Zap", from, { Volume = 0.5, Pitch = if resource == "Stamina" then 0.8 else 1.3 })
	for i = 1, 5 do
		local orb = part(Vector3.one * 0.45, CFrame.new(from + Vector3.new(0, 1.5, 0)), color:Lerp(WHITE, 0.3), 0, Enum.PartType.Ball)
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.2, 0), Vector3.new(0, -0.2, 0)
		a0.Parent, a1.Parent = orb, orb
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(color)
		trail.Transparency = NumberSequence.new(0.1, 1)
		trail.Lifetime = 0.25
		trail.LightEmission = 1
		trail.Parent = orb
		local out = Vector3.new(math.cos(i * 1.3) * 2.5, 1.5 + (i % 3), math.sin(i * 1.3) * 2.5)
		tween(orb, 0.18, { CFrame = CFrame.new(from + out) }, Enum.EasingStyle.Quad)
		task.delay(0.18 + i * 0.03, function()
			if target and target.Parent then
				tween(orb, 0.28, { CFrame = target.CFrame, Size = Vector3.one * 0.15 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Debris:AddItem(orb, 0.3)
			else
				fade(orb, 0.3, { Size = Vector3.one * 0.05, CFrame = CFrame.new(from + out * 2) })
			end
		end)
	end
	if target then
		task.delay(0.5, function()
			if target.Parent then
				CombatFx.flash(target.Position, color, 3, 8, 0.2)
				ringAt(floorUnder(target.Position), 2, color, 0.2, 0.3, 2)
			end
		end)
	end
	-- What it took, floating up off the victim.
	if amount and amount > 0 then
		local anchorPart = part(Vector3.one * 0.1, CFrame.new(from + Vector3.new(0, 3, 0)), color, 1)
		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromOffset(160, 26)
		board.AlwaysOnTop = true
		board.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 16
		label.TextColor3 = color:Lerp(WHITE, 0.3)
		label.TextStrokeTransparency = 0.3
		label.Text = string.format("−%d %s", amount, string.upper(resource))
		label.Parent = board
		board.Parent = anchorPart
		tween(anchorPart, 0.9, { CFrame = anchorPart.CFrame + Vector3.new(0, 2.5, 0) })
		task.delay(0.5, function()
			tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end)
		Debris:AddItem(anchorPart, 1)
	end
end

function TriadVfx.mark(targetRoot: BasePart, seconds: number, element: string?)
	if typeof(targetRoot) ~= "Instance" or not targetRoot:IsA("BasePart") then
		return
	end
	local color = colorOf(element)
	local f = follow(targetRoot, seconds, "Mark", function(f, t)
		for i, entry in f.Parts do
			if i <= 4 then
				local a = t * 2 + i * math.pi / 2
				entry.Offset = CFrame.new(0, 4.4, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.5)
			else
				entry.Offset = CFrame.new(0, 4.2, 0) * CFrame.Angles(0, -t * 1.5, 0) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end)
	for _ = 1, 4 do
		hold(f, part(Vector3.new(0.18, 0.18, 0.9), targetRoot.CFrame, color, 0), CFrame.new())
	end
	local halo = part(Vector3.new(0.06, 2.8, 2.8), targetRoot.CFrame, color, 0.35, Enum.PartType.Cylinder)
	light(halo, color, 2, 8)
	hold(f, halo, CFrame.new())
	CombatSound.play("Zap", targetRoot.Position, { Volume = 0.6 })
end

function TriadVfx.shatter(position: Vector3, color: Color3)
	local element = GemConfig.elementOfColor(color)
	CombatFx.burst(position, color, if element == "Poison" then "Drips" else "Shards", 1.3)
	CombatFx.flash(position, color, 5, 14, 0.3)
	ringAt(floorUnder(position), 3, color, 0.1, 0.4, 3)
	for _ = 1, 8 do
		local out = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
		if out.Magnitude > 0.05 then
			local shard = if element == "Frost"
				then glass(Vector3.new(0.3, 0.7, 0.2), CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), ICE, 0.1)
				else part(Vector3.one * 0.3, CFrame.new(position), color, 0.05, Enum.PartType.Ball)
			fade(shard, 0.5, { CFrame = shard.CFrame + out.Unit * 4 - Vector3.new(0, 1, 0) })
		end
	end
	CombatSound.play(if element == "Frost" then "Freeze" else "Corrode", position, { Volume = 0.8 })
end

function TriadVfx.root(position: Vector3, seconds: number, element: string?)
	local floor = floorUnder(position)
	local color = colorOf(element)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local base = floor + Vector3.new(math.cos(a) * 1.3, 0, math.sin(a) * 1.3)
		local spike = glass(Vector3.new(0.3, 0.1, 0.3), CFrame.new(base) * CFrame.Angles(math.cos(a) * 0.4, 0, math.sin(a) * 0.4), ICE, 0.1)
		tween(spike, 0.12, { Size = Vector3.new(0.35, 2.4, 0.35), CFrame = spike.CFrame + Vector3.new(0, 1, 0) }, Enum.EasingStyle.Back)
		task.delay(seconds, function()
			fade(spike, 0.25, { Size = Vector3.new(0.1, 0.4, 0.1) })
		end)
	end
	ringAt(floor, 2, color, 0.2, seconds, 1.4)
end

function TriadVfx.breakBurst(position: Vector3, radius: number, element: string?)
	local color = colorOf(element)
	local floor = floorUnder(position)
	ringAt(floor, 2, color, 0.05, 0.45, radius)
	ringAt(floor + Vector3.new(0, 0.03, 0), 1, WHITE, 0.2, 0.3, radius * 1.2)
	CombatFx.burst(position, color, if element == "Frost" then "Shards" elseif element == "Fire" then "Embers" else "Sparks", 1.6)
	CombatFx.flash(position, color, 6, radius * 2.5, 0.35)
	CombatFx.shake(0.35, 0.25)
	CombatSound.play("Blast", position, { Volume = 0.9 })
end

function TriadVfx.phoenix(who: Player, position: Vector3)
	local root = rootOf(who)
	local floor = floorUnder(position)
	-- A pillar of fire, a ring and a flare: you rise again.
	local column = part(Vector3.new(1, 4, 4), CFrame.new(floor + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), EMBER, 0.1, Enum.PartType.Cylinder)
	tween(column, 0.35, { Size = Vector3.new(26, 2, 2), CFrame = CFrame.new(floor + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	task.delay(0.35, function()
		fade(column, 0.5, { Size = Vector3.new(30, 0.2, 0.2) })
	end)
	ringAt(floor, 4, HOT, 0, 0.6, 5)
	ringAt(floor + Vector3.new(0, 0.03, 0), 2, EMBER, 0.1, 0.8, 7)
	CombatFx.burst(position, EMBER, "Embers", 2.5)
	CombatFx.flash(position, HOT, 9, 30, 0.6)
	CombatFx.shake(0.6, 0.35)
	CombatSound.play("Heal", position, { Volume = 1 })
	CombatSound.play("Blast", position, { Volume = 0.8, Pitch = 1.2 })
	if root and who == Players.LocalPlayer then
		require(script.Parent.CombatVfx).screen("Crit", 0.4)
	end
	if root then
		AURA.Phoenix(root, EMBER, 1.2)
	end
end

function TriadVfx.trail(from: Vector3, to: Vector3, width: number, seconds: number, element: string?)
	local color = colorOf(element)
	local a, b = floorUnder(from), floorUnder(to)
	local line = (b - a) * Vector3.new(1, 0, 1)
	local length = math.max(2, line.Magnitude)
	local direction = if line.Magnitude > 0.1 then line.Unit else Vector3.new(0, 0, -1)
	local segments = math.max(3, math.floor(length / 2))
	for i = 1, segments do
		local at = a + direction * (i - 0.5) / segments * length
		local patch = part(Vector3.new(0.06, width, length / segments * 1.2), CFrame.lookAt(at, at + direction) * CFrame.Angles(0, 0, math.rad(90)), color, 0.4, nil, if element == "Frost" then Enum.Material.Glass else Enum.Material.Neon)
		patch.Size = Vector3.new(0.06, 0.2, length / segments * 1.2)
		task.delay(i * 0.03, function()
			tween(patch, 0.15, { Size = Vector3.new(0.06, width, length / segments * 1.2) })
		end)
		if i % 2 == 1 and not busy() then
			local attachment = Instance.new("Attachment")
			attachment.Parent = patch
			if element == "Fire" then
				emitter(attachment, color, 10, { Texture = "rbxasset://textures/particles/fire_main.dds", Size = 0.9, Acceleration = Vector3.new(0, 6, 0), Spread = 20 })
			elseif element == "Poison" then
				emitter(attachment, ACID, 8, { Size = 0.4, Speed = 1, Acceleration = Vector3.new(0, 2, 0), Light = 0.3 })
			else
				emitter(attachment, color, 8, { Size = 0.3, Speed = 2 })
			end
		end
		task.delay(seconds, function()
			fade(patch, 0.4)
		end)
	end
end

function TriadVfx.field(center: Vector3, radius: number, seconds: number, element: string?)
	local floor = floorUnder(center)
	local color = colorOf(element)
	local sheet = glass(Vector3.new(0.08, radius * 2, radius * 2), CFrame.new(floor) * CFrame.Angles(0, 0, math.rad(90)), ICE, 0.35)
	sheet.Shape = Enum.PartType.Cylinder
	sheet.Size = Vector3.new(0.08, 1, 1)
	tween(sheet, 0.25, { Size = Vector3.new(0.08, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	local rim = disc(floor + Vector3.new(0, 0.02, 0), radius * 2, color, 0.55)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local base = floor + Vector3.new(math.cos(a) * radius * 0.7, 0, math.sin(a) * radius * 0.7)
		local spike = glass(Vector3.new(0.3, 1.2, 0.3), CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.random() * 0.6 - 0.3, 0, math.random() * 0.6 - 0.3), ICE, 0.15)
		task.delay(seconds, function()
			fade(spike, 0.3)
		end)
	end
	CombatSound.play("Freeze", floor, { Volume = 0.7 })
	task.delay(seconds, function()
		fade(sheet, 0.5)
		fade(rim, 0.5)
	end)
end

function TriadVfx.pylon(center: Vector3, reach: number, seconds: number, element: string?)
	local floor = floorUnder(center)
	local color = colorOf(element)
	local mast = part(Vector3.new(0.6, 0.2, 0.6), CFrame.new(floor), Color3.fromRGB(70, 74, 92), 0, nil, Enum.Material.Metal)
	tween(mast, 0.25, { Size = Vector3.new(0.6, 5, 0.6), CFrame = CFrame.new(floor + Vector3.new(0, 2.5, 0)) }, Enum.EasingStyle.Back)
	local coil = part(Vector3.one * 1.4, CFrame.new(floor + Vector3.new(0, 5.2, 0)), color, 0.05, Enum.PartType.Ball)
	light(coil, color, 4, 16)
	local attachment = Instance.new("Attachment")
	attachment.Parent = coil
	emitter(attachment, color, 25, { Size = 0.3, Speed = 4, Acceleration = Vector3.zero, Life = 0.25 })
	local spin = TweenService:Create(coil, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = Vector3.one * 1.8 })
	spin:Play()
	local area = disc(floor + Vector3.new(0, 0.03, 0), reach * 2, color, 0.92)
	task.delay(seconds, function()
		spin:Cancel()
		fade(mast, 0.3)
		fade(coil, 0.3, { Size = Vector3.one * 3 })
		fade(area, 0.3)
	end)
	CombatSound.play("Zap", floor, { Volume = 0.8 })
end

function TriadVfx.deflect(from: Vector3, to: Vector3)
	local direction = to - from
	if direction.Magnitude < 0.1 then
		return
	end
	local beam = part(Vector3.new(0.12, 0.12, direction.Magnitude), CFrame.lookAt(from, to) * CFrame.new(0, 0, -direction.Magnitude / 2), GOLD, 0.1)
	fade(beam, 0.25, { Size = Vector3.new(0.03, 0.03, direction.Magnitude) })
	CombatFx.burst(from, GOLD, "Sparks", 0.8)
	CombatSound.play("Parry", from, { Volume = 0.7 })
end

function TriadVfx.empowerHit(position: Vector3, kind: string, final: number?)
	local color = if kind == "Burn" then EMBER elseif kind == "Chill" then ICE else ACID
	CombatFx.burst(position, color, if kind == "Burn" then "Embers" elseif kind == "Chill" then "Frost" else "Drips", if final == 1 then 1.4 else 0.8)
	if final == 1 then
		ringAt(floorUnder(position), 2.5, color, 0.1, 0.35, 2.5)
	end
end

-- The showcase defenses -------------------------------------------------------------

-- Ice Pillar: a column of ice bursts up under the caster (the server's
-- column is the collision; this is what you see), then shatters.
function TriadVfx.pillar(who: Player, floor: Vector3, height: number, seconds: number, element: string?)
	local color = colorOf(element)
	local column = glass(Vector3.new(4.5, 0.4, 4.5), CFrame.new(floor + Vector3.new(0, 0.2, 0)), ICE, 0.1)
	column.Material = Enum.Material.Ice
	tween(column, 0.18, { Size = Vector3.new(4.5, height, 4.5), CFrame = CFrame.new(floor + Vector3.new(0, height / 2, 0)) }, Enum.EasingStyle.Back)
	local core = part(Vector3.new(1.4, 0.4, 1.4), column.CFrame, WHITE, 0.55)
	tween(core, 0.18, { Size = Vector3.new(1.4, height * 0.95, 1.4), CFrame = CFrame.new(floor + Vector3.new(0, height / 2, 0)) }, Enum.EasingStyle.Back)
	light(core, DEEP_ICE, 3, 16)
	-- Crystals jut from its foot, and a frosted cap crowns it.
	local bits = { column, core }
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + math.random() * 0.4
		local base = floor + Vector3.new(math.cos(a) * 2.6, 0, math.sin(a) * 2.6)
		local tall = 1.8 + math.random() * 2.4
		local spike = glass(Vector3.new(0.9, 0.2, 0.9), CFrame.new(base) * CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5), if i % 2 == 0 then DEEP_ICE else ICE, 0.15)
		task.delay(0.05 + i * 0.02, function()
			tween(spike, 0.15, { Size = Vector3.new(0.9, tall, 0.9), CFrame = spike.CFrame * CFrame.new(0, tall / 2, 0) }, Enum.EasingStyle.Back)
		end)
		table.insert(bits, spike)
	end
	local cap = glass(Vector3.new(0.4, 5.2, 5.2), CFrame.new(floor + Vector3.new(0, height, 0)) * CFrame.Angles(0, 0, math.rad(90)), WHITE, 0.3)
	cap.Shape = Enum.PartType.Cylinder
	cap.Transparency = 1
	task.delay(0.18, function()
		cap.Transparency = 0.3
	end)
	table.insert(bits, cap)
	local frost = disc(floor + Vector3.new(0, 0.05, 0), 5, ICE, 0.8)
	tween(frost, 0.3, { Size = Vector3.new(0.08, 8, 8) })
	table.insert(bits, frost)
	CombatFx.burst(floor + Vector3.new(0, 1, 0), ICE, "Frost", 2)
	ringAt(floor, 4, color, 0.1, 0.45, 4)
	CombatSound.play("Freeze", floor, { Volume = 1 })
	CombatSound.play("Blast", floor, { Volume = 0.6, Pitch = 1.4 })
	if CombatFx.nearMe(floor, 30) then
		CombatFx.shake(0.4, 0.25)
	end
	task.delay(seconds, function()
		-- Shatter: chunks tumble off as it crumbles (the server's TriadBreak
		-- adds the burst).
		for n = 1, 10 do
			local at = floor + Vector3.new((math.random() - 0.5) * 4, math.random() * height, (math.random() - 0.5) * 4)
			local chunk = glass(Vector3.new(0.8, 1, 0.7), CFrame.new(at) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), if n % 2 == 0 then DEEP_ICE else ICE, 0.1)
			local out = (at - floor) * Vector3.new(1, 0, 1)
			out = if out.Magnitude > 0.1 then out.Unit else Vector3.new(1, 0, 0)
			fade(chunk, 0.6, { CFrame = CFrame.new(Vector3.new(at.X, floor.Y + 0.3, at.Z) + out * 3) * CFrame.Angles(math.random() * 6, 0, math.random() * 6) }, Enum.EasingStyle.Quad)
		end
		for _, bit in bits do
			fade(bit, 0.25, { Size = bit.Size * 0.6 })
		end
		CombatSound.play("GuardBreak", floor, { Volume = 0.8, Pitch = 1.2 })
	end)
end

-- Ring of Fire: a wheel of flame that turns around the caster as they move.
function TriadVfx.ring(who: Player, radius: number, seconds: number, element: string?)
	local root = rootOf(who)
	if not root then
		return
	end
	local color = colorOf(element)
	local count = math.clamp(math.floor(radius * 2.4), 12, 22)
	local flames = {}
	local f = follow(root, seconds, "RingOfFire", function(self, age)
		local spin = age * 1.4
		for i, entry in self.Parts do
			local flame = flames[i]
			if flame then
				local a = flame.Angle + spin
				local lick = flame.Height * (0.85 + 0.25 * math.sin(age * 9 + i * 1.7))
				entry.Offset = CFrame.new(math.cos(a) * radius, -2.9 + lick / 2, math.sin(a) * radius) * CFrame.Angles(0, 0, math.rad(90))
				if age > 0.2 then
					entry.Part.Size = Vector3.new(lick, flame.Width, flame.Width)
				end
			end
		end
	end)
	for i = 1, count do
		local a = i / count * math.pi * 2
		local height = 3 + (i % 3) * 0.6
		local width = 1.1 + (i % 2) * 0.3
		local flame = part(Vector3.new(0.2, width, width), root.CFrame, if i % 2 == 0 then EMBER else HOT, if i % 2 == 0 then 0.15 else 0.3, Enum.PartType.Cylinder)
		tween(flame, 0.2, { Size = Vector3.new(height, width, width) }, Enum.EasingStyle.Back)
		table.insert(flames, { Angle = a, Height = height, Width = width })
		hold(f, flame, CFrame.new(math.cos(a) * radius, -2.9, math.sin(a) * radius) * CFrame.Angles(0, 0, math.rad(90)))
		if i % 3 == 0 and not busy() then
			local attachment = Instance.new("Attachment")
			attachment.Parent = flame
			emitter(attachment, color, 16, { Texture = "rbxasset://textures/particles/fire_main.dds", Size = 1.2, Acceleration = Vector3.new(0, 9, 0), Spread = 20, Life = 0.5 })
			if i % 6 == 0 then
				light(attachment, EMBER, 2.5, 14)
			end
		end
	end
	-- A scorched band on the ground under the flames.
	local band = part(Vector3.new(0.06, radius * 2 + 1.6, radius * 2 + 1.6), root.CFrame, Color3.fromRGB(90, 30, 10), 0.55, Enum.PartType.Cylinder)
	table.insert(flames, false)
	hold(f, band, CFrame.new(0, -2.95, 0) * CFrame.Angles(0, 0, math.rad(90)))
	CombatFx.burst(root.Position - Vector3.new(0, 2, 0), EMBER, "Embers", 2)
	ringAt(floorUnder(root.Position), 2, HOT, 0, 0.35, radius)
	CombatSound.play("Burn", root.Position, { Volume = 1 })
	CombatSound.element("Cast", "Fire", root.Position, { Volume = 0.8 })
end

-- Hologram Decoy: a flickering copy of the caster, left where they stood.
local decoys: { [any]: { BasePart } } = {}
function TriadVfx.decoy(who: Player, center: Vector3, seconds: number, element: string?)
	local root = rootOf(who)
	local character = root and root.Parent
	if not root or not character then
		return
	end
	local color = colorOf(element)
	local turn = root.CFrame.Rotation
	local ghost = {}
	for _, piece in character:GetDescendants() do
		if #ghost >= 40 then
			break
		end
		if piece:IsA("BasePart") and piece ~= root and piece.Transparency < 0.9 then
			local relative = root.CFrame:ToObjectSpace(piece.CFrame)
			local copy = part(piece.Size, CFrame.new(center) * turn * relative, color:Lerp(Color3.fromRGB(120, 230, 255), 0.5), 0.25, nil, Enum.Material.ForceField)
			if piece:IsA("Part") then
				copy.Shape = piece.Shape
			end
			table.insert(ghost, copy)
		end
	end
	-- A scan line runs up and down it, and a projector ring glows at its feet.
	local floor = floorUnder(center)
	local scan = disc(floor + Vector3.new(0, 0.2, 0), 3.2, color, 0.35)
	TweenService:Create(scan, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = scan.CFrame + Vector3.new(0, 5.4, 0) }):Play()
	local pad = disc(floor + Vector3.new(0, 0.04, 0), 3.4, color, 0.3)
	light(pad, color, 2, 10)
	table.insert(ghost, scan)
	table.insert(ghost, pad)
	for _, copy in ghost do
		TweenService:Create(copy, TweenInfo.new(0.09, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), { Transparency = math.min(0.7, copy.Transparency + 0.2) }):Play()
	end
	decoys[who] = ghost
	CombatFx.burst(center, color, "Sparks", 1.2)
	CombatSound.play("Zap", center, { Volume = 0.8, Pitch = 1.3 })
	-- (If the pop never arrives, it fades out on its own.)
	task.delay(seconds + 1, function()
		if decoys[who] == ghost then
			decoys[who] = nil
			for _, copy in ghost do
				fade(copy, 0.3)
			end
		end
	end)
end

-- The decoy goes off: the copy blows apart in a lightning burst.
function TriadVfx.decoyPop(who: Player, center: Vector3, radius: number)
	local ghost = decoys[who]
	decoys[who] = nil
	for _, copy in ghost or {} do
		if copy.Parent then
			fade(copy, 0.2, { Size = copy.Size * 1.4 })
		end
	end
	local color = GemConfig.ElementColors.Shock
	TriadVfx.breakBurst(center, radius, "Shock")
	for _ = 1, 6 do
		local a = math.random() * math.pi * 2
		local reach = radius * (0.6 + math.random() * 0.4)
		local from = center
		for n = 1, 3 do
			local to = center + Vector3.new(math.cos(a) * reach * n / 3, (math.random() - 0.6) * 2, math.sin(a) * reach * n / 3)
			local length = (to - from).Magnitude
			if length > 0.1 then
				local bolt = part(Vector3.new(0.15, 0.15, length), CFrame.lookAt((from + to) / 2, to), color:Lerp(WHITE, 0.4), 0)
				fade(bolt, 0.25)
			end
			from = to
		end
	end
	CombatSound.play("Zap", center, { Volume = 1 })
end

-- Acid Slick: a bubbling pool of acid on the ground.
function TriadVfx.slick(center: Vector3, radius: number, seconds: number, element: string?)
	local floor = floorUnder(center)
	local color = colorOf(element)
	local pool = disc(floor + Vector3.new(0, 0.03, 0), 1, Color3.fromRGB(70, 120, 30), 0.15)
	pool.Material = Enum.Material.Glass
	pool.Reflectance = 0.35
	tween(pool, 0.3, { Size = Vector3.new(0.08, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	local sheen = disc(floor + Vector3.new(0, 0.06, 0), 1, ACID, 0.55)
	tween(sheen, 0.3, { Size = Vector3.new(0.06, radius * 1.7, radius * 1.7) }, Enum.EasingStyle.Back)
	-- Lobes round the edge, so it reads as a spill and not a circle.
	local pieces = { pool, sheen }
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + math.random() * 0.5
		local size = radius * (0.5 + math.random() * 0.3)
		local lobe = disc(floor + Vector3.new(math.cos(a) * radius * 0.75, 0.035, math.sin(a) * radius * 0.75), 0.5, color:Lerp(ACID, 0.5), 0.3)
		tween(lobe, 0.35, { Size = Vector3.new(0.07, size, size) }, Enum.EasingStyle.Back)
		table.insert(pieces, lobe)
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = sheen
	emitter(attachment, ACID, 12, { Size = 0.4, Speed = 0.6, Spread = 60, Acceleration = Vector3.new(0, 1.5, 0), Life = 0.8, Light = 0.3 })
	-- Bubbles swell and pop all over it.
	local ends = os.clock() + seconds
	task.spawn(function()
		while os.clock() < ends and pool.Parent do
			if not busy() then
				local a, d = math.random() * math.pi * 2, math.sqrt(math.random()) * radius * 0.9
				local at = floor + Vector3.new(math.cos(a) * d, 0.1, math.sin(a) * d)
				local bubble = part(Vector3.one * 0.2, CFrame.new(at), ACID, 0.3, Enum.PartType.Ball, Enum.Material.Glass)
				tween(bubble, 0.35, { Size = Vector3.one * (0.5 + math.random() * 0.6) })
				task.delay(0.35, function()
					fade(bubble, 0.1, { Size = Vector3.one * 1.2 })
				end)
			end
			task.wait(0.12)
		end
	end)
	CombatFx.burst(floor + Vector3.new(0, 0.5, 0), ACID, "Drips", 1.6)
	CombatSound.play("Corrode", floor, { Volume = 1 })
	CombatSound.element("Impact", "Poison", floor, { Volume = 0.7 })
	task.delay(seconds, function()
		for _, piece in pieces do
			fade(piece, 0.6)
		end
	end)
end

return TriadVfx
