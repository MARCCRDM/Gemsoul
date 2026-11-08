--[[
	The combat basics as a live demo (Client BasicsScreen plays it, a line
	at a time): two real fighters on a small stage in a viewport, a miner in
	starter gear and round 1's rival in its outfit (Server.Duelist builds
	them: the "BasicsDemo" request, a store in your PlayerGui), acting out
	what the narrator says, in step with the voice:

	  BasicsAttack     a swing, a three-hit combo, then a held heavy blow
	                   that staggers the rival
	  BasicsBlock      the guard raised and held; the rival's swing blocked
	                   (a cyan spark), then one blocked just as it lands: a
	                   PERFECT BLOCK (gold), the rival staggered
	  BasicsAbilities  Q, E and R lit one by one, the charge bar full; a bolt
	                   (charge spent) and a blast that floors the rival

	They're posed by the game's own fight poses (Shared.RivalPose: the same
	slashes, heavy blows, guards, casts and flinches as in a real fight),
	laid out from their joints every frame (anchored in the viewport). Over
	the stage: the topic and its number, the control being pressed (a key
	cap that dips as it's pressed, HOLD as it's held), what landed (HIT,
	x2, x3 COMBO...), and for abilities the Q/E/R gems and the charge bar.

	  BasicsDemo.fighters(timeout) -> (hero, foe)?   the server's fighters
	  BasicsDemo.new(stage: GuiObject, hero, foe, touch) -> demo
	  demo.show(name, index, total)   a line begins
	  demo.step(name, t)              each frame: `t` seconds into the line
	  demo.destroy()
	  BasicsDemo.Scripts              what each line acts out, and when
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RivalPose = require(ReplicatedStorage.Shared.RivalPose)
local GemClient = require(script.Parent.GemClient)
local UiKit = require(script.Parent.UiKit)
local CombatSound = require(script.Parent.CombatSound)
local UiSound = require(script.Parent.UiSound)

local BasicsDemo = {}

local GOLD = Color3.fromRGB(255, 202, 91)
local CYAN = Color3.fromRGB(110, 220, 255)
local INK = Color3.fromRGB(8, 10, 16)
local TEXT = Color3.fromRGB(240, 244, 250)
local CHARGE = Color3.fromRGB(70, 150, 255)
local GEMS = { Q = Color3.fromRGB(255, 120, 60), E = Color3.fromRGB(90, 200, 255), R = Color3.fromRGB(190, 120, 255) }

-- What each line acts out (seconds into the line, the narrator's cues:
-- Client.Narration). Hero / Foe: their actions in turn (RivalPose's
-- ActionKind, its wind-up's start and the moment it lands, the side);
-- Guard: when the hero's guard is up; FoeHurt: when the rival flinches;
-- Blocked: when the hero's shield takes a blow; Pops: what shows over the
-- rival, when; Presses: the control pressed (Hold: let go then); Shots /
-- Rings: a bolt flying to the rival, a blast's ring out over the floor;
-- Gems: when Q, E and R light; Spend: charge spent, when, how much. A
-- cast's Element: what's heard as it's thrown (and lands: Shots / Rings
-- by their gem's, GEM_ELEMENTS).
BasicsDemo.Scripts = {
	-- The narrator's welcome, before the basics: the fighters squared up, the
	-- hero's arms thrown wide in greeting.
	TrainingBegins = {
		Title = "WELCOME, MINER",
		Hero = { { "Buff", 0.5, 0.9 } },
		Foe = {},
	},
	BasicsAttack = {
		Title = "ATTACK",
		Hero = {
			{ "Slash", 2.7, 2.92, 1 },
			{ "Slash", 5.4, 5.6, 1 },
			{ "Slash", 5.92, 6.12, -1 },
			{ "Slash", 6.44, 6.64, 1 },
			{ "Charge", 8.25, 9.15 },
			{ "Heavy", 9.15, 9.32 },
		},
		Foe = { { "Stagger", 9.32, 9.5 } },
		FoeHurt = { 2.92, 5.6, 6.12, 6.64, 9.32 },
		Pops = { { 2.92, "HIT" }, { 5.6, "x1" }, { 6.12, "x2" }, { 6.64, "x3 COMBO" }, { 9.32, "HEAVY BLOW", GOLD } },
		Presses = { { 2.7, "Attack" }, { 5.4, "Attack" }, { 5.92, "Attack" }, { 6.44, "Attack" }, { 8.25, "Attack", 9.15 } },
	},
	BasicsBlock = {
		Title = "BLOCK",
		Hero = {},
		Foe = {
			{ "Slash", 4.55, 5.35, 1 },
			{ "Slash", 7.0, 7.65, -1 },
			{ "Stagger", 7.75, 7.95 },
		},
		Guard = { { 1.9, 3.7 }, { 5.0, 5.8 }, { 7.5, 8.1 } },
		Blocked = { 5.35, 7.65 },
		Pops = { { 2.2, "GUARD UP", CYAN }, { 5.35, "BLOCKED", CYAN }, { 7.65, "PERFECT BLOCK", GOLD } },
		Presses = { { 1.9, "Block", 3.7 }, { 5.0, "Block", 5.8 }, { 7.5, "Block", 8.1 } },
		Sparks = { { 5.35, CYAN }, { 7.65, GOLD } },
	},
	BasicsAbilities = {
		Title = "ABILITIES",
		Hero = {
			{ "Bolt", 6.2, 6.6, Element = "Fire" },
			{ "Nova", 8.7, 9.15, Element = "Frost" },
		},
		Foe = { { "Stagger", 9.45, 9.65 } },
		FoeHurt = { 6.95 },
		Gems = { Q = 2.5, E = 3.3, R = 4.1 },
		Spend = { { 6.6, 0.34 }, { 9.15, 0.34 } },
		Shots = { { 6.6, 6.95, "Q" } },
		Rings = { { 9.15, 9.75, "E" } },
		Pops = { { 6.95, "BOLT", GEMS.Q }, { 9.45, "BLAST", GEMS.E } },
		Presses = { { 6.2, "Q" }, { 8.7, "E" } },
	},
}

local KEYS = {
	Desk = { Attack = "CLICK", Block = "R-CLICK", Q = "Q", E = "E", R = "R" },
	Touch = { Attack = "ATTACK", Block = "BLOCK", Q = "Q", E = "E", R = "R" },
}
-- What's heard (Client CombatSound and UiSound, the fight's own sounds):
-- flat, not placed (the stage is a picture, not a place), and a little
-- under the narrator. An action as it starts, by RivalPose's kind; the
-- gems' elements for a cast and its landing.
local HEARD = 0.7
local ACTION_SOUNDS = { Slash = "Swing", Heavy = "HeavySwing", Charge = "Charge", Stagger = "Stun", Nova = "NovaWarn" }
local GEM_ELEMENTS = { Q = "Fire", E = "Frost" }
local function hear(name: string?)
	if name then
		pcall(CombatSound.play, name, nil, { Volume = HEARD })
	end
end
local function hearElement(kind: string, element: string?)
	if element then
		pcall(CombatSound.element, kind, element, nil, { Volume = HEARD })
	end
end
local function click(name: string)
	pcall(UiSound.play, name)
end

-- The server's fighters (asked for, then waited on), or nil.
function BasicsDemo.fighters(timeout: number): (Model?, Model?)
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local deadline = os.clock() + timeout
	local askAgain = 0
	while os.clock() < deadline do
		local store = gui:FindFirstChild("BasicsDemo")
		local hero = store and store:FindFirstChild("Hero")
		local foe = store and store:FindFirstChild("Foe")
		if
			hero
			and foe
			and hero:FindFirstChild("HumanoidRootPart")
			and foe:FindFirstChild("HumanoidRootPart")
			and hero:FindFirstChildOfClass("Humanoid")
			and foe:FindFirstChildOfClass("Humanoid")
		then
			return hero :: Model, foe :: Model
		end
		if os.clock() >= askAgain then
			askAgain = os.clock() + 3
			task.spawn(function()
				pcall(GemClient.request, "BasicsDemo")
			end)
		end
		task.wait(0.2)
	end
	return nil, nil
end

local function new(class: string, props, parent: Instance?)
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	i.Parent = parent
	return i
end

-- A viewport has one light and no bounce: dark metal goes near black in
-- it. Dark parts (not the glowing ones) are lifted toward a steel grey,
-- the darker the more.
BasicsDemo.Steel = Color3.fromRGB(150, 160, 182)
BasicsDemo.Lift = 0.45
local function brighten(part: BasePart)
	if part.Material == Enum.Material.Neon or part.Transparency >= 1 then
		return
	end
	local c = part.Color
	local bright = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	if bright < 0.45 then
		part.Color = c:Lerp(BasicsDemo.Steel, BasicsDemo.Lift * (1 - bright / 0.45))
	end
end

-- A fighter in the viewport: a copy, every part anchored, its links
-- (joints and welds) remembered, so it can be laid out from its joints.
local function fighter(source: Model, world: Instance, at: CFrame)
	local model = source:Clone()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	-- (feet on the floor: the hip height and half the root under it)
	local lift = (humanoid.HipHeight > 0 and humanoid.HipHeight or 1.9) + root.Size.Y / 2
	local welds = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			brighten(d)
		elseif d:IsA("WeldConstraint") and d.Part0 and d.Part1 then
			table.insert(welds, { d.Part0, d.Part1, d.Part0.CFrame:ToObjectSpace(d.Part1.CFrame) })
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	-- (the root put on its spot, the rest laid out from it: solve)
	root.CFrame = at * CFrame.new(0, lift, 0)
	model.Parent = world
	return { Model = model, Root = root, Welds = welds, Home = root.CFrame }
end

-- Lays its parts out from the root through its joints (as posed) and welds.
-- (Parts are told apart by BasicsDemo._key: themselves in game; tests swap
-- it, as their stand-in instances aren't one object per part.)
BasicsDemo._key = function(part: Instance): any
	return part
end
local function solve(f)
	local key = BasicsDemo._key
	local links = {}
	local function link(a, b, offset)
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
			local ka, kb = key(a), key(b)
			links[ka] = links[ka] or {}
			links[kb] = links[kb] or {}
			table.insert(links[ka], { b, offset })
			table.insert(links[kb], { a, offset:Inverse() })
		end
	end
	for _, d in f.Model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("Weld") then
			link(d.Part0, d.Part1, d.C0 * d.C1:Inverse())
		elseif d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			link(d.Attachment0.Parent, d.Attachment1.Parent, d.Attachment0.CFrame * d.Attachment1.CFrame:Inverse())
		end
	end
	for _, w in f.Welds do
		link(w[1], w[2], w[3])
	end
	local seen = { [key(f.Root)] = true }
	local stack = { f.Root }
	while #stack > 0 do
		local part = table.remove(stack)
		for _, l in links[key(part)] or {} do
			local k = key(l[1])
			if not seen[k] then
				seen[k] = true
				l[1].CFrame = part.CFrame * l[2]
				table.insert(stack, l[1])
			end
		end
	end
end

-- Sets its fight attributes for `t` from the line's script.
local function act(model: Model, actions, t: number, offset: number)
	local current = nil
	for _, a in actions or {} do
		if t >= a[2] - 0.001 then
			current = a
		end
	end
	if current then
		model:SetAttribute("ActionKind", current[1])
		model:SetAttribute("ActionStart", current[2] + offset)
		model:SetAttribute("ActionAt", current[3] + offset)
		model:SetAttribute("ActionSide", current[4] or 1)
	else
		model:SetAttribute("ActionKind", nil)
		model:SetAttribute("ActionStart", nil)
		model:SetAttribute("ActionAt", nil)
	end
end
local function latest(list, t: number): number?
	local found = nil
	for _, at in list or {} do
		if t >= at then
			found = at
		end
	end
	return found
end

function BasicsDemo.new(stage: GuiObject, heroSource: Model, foeSource: Model, touch: boolean)
	local keys = if touch then KEYS.Touch else KEYS.Desk
	local view = new("ViewportFrame", {
		Name = "Demo",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(14, 17, 27),
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(205, 208, 222), -- (bright: the frontier armour is dark metal)
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = 2,
	}, stage)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(70, 82, 116), Color3.fromRGB(22, 26, 40)),
	}, view)
	UiKit.round(view, 6)
	local world = new("WorldModel", {}, view)
	local camera = new("Camera", { FieldOfView = 30 }, view)
	view.CurrentCamera = camera
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 4.6, 20), Vector3.new(0, 2.6, 0))
	-- The stage: a dark floor, a lit ring round it, a faint grid.
	local function piece(cf: CFrame, size: Vector3, color: Color3, material, shape)
		local p = new("Part", {
			Anchored = true,
			CanCollide = false,
			Size = size,
			CFrame = cf,
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Shape = shape or Enum.PartType.Block,
		}, world)
		return p
	end
	local flat = CFrame.Angles(0, 0, math.rad(90))
	piece(CFrame.new(0, -0.25, 0) * flat, Vector3.new(0.5, 22, 22), Color3.fromRGB(58, 64, 84), nil, Enum.PartType.Cylinder)
	piece(CFrame.new(0, 0.01, 0) * flat, Vector3.new(0.02, 18.6, 18.6), CYAN, Enum.Material.Neon, Enum.PartType.Cylinder)
	piece(CFrame.new(0, 0.02, 0) * flat, Vector3.new(0.03, 18, 18), Color3.fromRGB(70, 77, 100), nil, Enum.PartType.Cylinder)
	piece(CFrame.new(0, 0.03, 0) * flat, Vector3.new(0.04, 2.4, 2.4), Color3.fromRGB(104, 112, 138), nil, Enum.PartType.Cylinder)

	local hero = fighter(heroSource, world, CFrame.lookAt(Vector3.new(-4.2, 0, 0), Vector3.new(4.2, 0, 0)))
	local foe = fighter(foeSource, world, CFrame.lookAt(Vector3.new(4.2, 0, 0), Vector3.new(-4.2, 0, 0)))
	solve(hero)
	solve(foe)

	-- Effects in the viewport: flashes, the bolt, the blast's ring.
	local fx = {}
	local function flash(at: Vector3, color: Color3, size: number)
		local ball = piece(CFrame.new(at), Vector3.one * size * 0.4, color, Enum.Material.Neon, Enum.PartType.Ball)
		ball.Transparency = 0.1
		table.insert(fx, { Part = ball, Born = os.clock(), Life = 0.35, Grow = size })
	end

	-- Over the stage: the topic, its number, the control, what landed.
	local overlay = new("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, stage)
	local function label(props)
		props.BackgroundTransparency = props.BackgroundTransparency or 1
		props.Font = props.Font or Enum.Font.GothamBlack
		props.TextScaled = true
		props.ZIndex = 6
		return new("TextLabel", props, overlay)
	end
	local title = label({ Position = UDim2.fromScale(0.04, 0.05), Size = UDim2.fromScale(0.5, 0.13), TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
	local number = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.96, 0.06), Size = UDim2.fromScale(0.2, 0.09), TextColor3 = Color3.fromRGB(150, 165, 190), TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
	local pop = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.68, 0.24), Size = UDim2.fromScale(0.4, 0.12), TextColor3 = TEXT, Text = "", TextStrokeTransparency = 0.4 })
	local popScale = new("UIScale", {}, pop)
	-- the key cap
	local cap = new("Frame", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.2, 0.15),
		BackgroundColor3 = Color3.fromRGB(28, 32, 46),
		ZIndex = 6,
		Visible = false,
	}, overlay)
	UiKit.round(cap, 8)
	local capEdge = new("UIStroke", { Color = Color3.fromRGB(90, 100, 130), Thickness = 2 }, cap)
	local capText = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = TEXT,
		ZIndex = 7,
		Text = "",
	}, cap)
	new("UIPadding", { PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0), PaddingLeft = UDim.new(0.1, 0), PaddingRight = UDim.new(0.1, 0) }, capText)
	local capFill = new("Frame", { BackgroundColor3 = GOLD, BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 6 }, cap)
	UiKit.round(capFill, 8)
	local capHint = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.79), Size = UDim2.fromScale(0.3, 0.06), TextColor3 = GOLD, Text = "", Visible = false })
	-- the abilities' gems and charge bar
	local gemRow = new("Frame", { Position = UDim2.fromScale(0.04, 0.78), Size = UDim2.fromScale(0.3, 0.16), BackgroundTransparency = 1, ZIndex = 6, Visible = false }, overlay)
	local gemSlots = {}
	for i, key in { "Q", "E", "R" } do
		local slot = new("Frame", {
			Position = UDim2.fromScale((i - 1) * 0.34, 0),
			Size = UDim2.fromScale(0.3, 1),
			BackgroundColor3 = Color3.fromRGB(28, 32, 46),
			ZIndex = 6,
		}, gemRow)
		new("UIAspectRatioConstraint", { AspectRatio = 1 }, slot)
		UiKit.round(slot, 100)
		local ring = new("UIStroke", { Color = GEMS[key], Thickness = 2, Transparency = 0.7 }, slot)
		local letter = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.fromRGB(110, 118, 140), Text = key, ZIndex = 7 }, slot)
		new("UIPadding", { PaddingTop = UDim.new(0.22, 0), PaddingBottom = UDim.new(0.22, 0) }, letter)
		gemSlots[key] = { Slot = slot, Ring = ring, Letter = letter, Scale = new("UIScale", {}, slot) }
	end
	local bar = new("Frame", { Position = UDim2.fromScale(0.36, 0.86), Size = UDim2.fromScale(0.3, 0.035), BackgroundColor3 = Color3.fromRGB(28, 32, 46), BorderSizePixel = 0, ZIndex = 6, Visible = false }, overlay)
	UiKit.round(bar, 4)
	local barFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = CHARGE, BorderSizePixel = 0, ZIndex = 7 }, bar)
	UiKit.round(barFill, 4)
	local barLabel = label({ Position = UDim2.fromScale(0.36, 0.79), Size = UDim2.fromScale(0.3, 0.055), TextColor3 = CHARGE, TextXAlignment = Enum.TextXAlignment.Left, Text = "CHARGE", Visible = false })

	local demo = {}
	local line = nil -- { Name, Offset, Shown = { pops, presses, sparks... } }
	local lastClock = os.clock()

	function demo.show(name: string, index: number, total: number)
		local spec = BasicsDemo.Scripts[name] or {}
		line = { Name = name, Script = spec, Offset = os.clock(), Fired = {} }
		title.Text = spec.Title or ""
		number.Text = if index > 0 then string.format("%02d/%02d", index, total) else ""
		pop.Text = ""
		cap.Visible, capHint.Visible = false, false
		local abilities = spec.Gems ~= nil
		gemRow.Visible, bar.Visible, barLabel.Visible = abilities, abilities, abilities
		for _, slot in gemSlots do
			slot.Ring.Transparency, slot.Letter.TextColor3 = 0.7, Color3.fromRGB(110, 118, 140)
			slot.Slot.BackgroundColor3 = Color3.fromRGB(28, 32, 46)
		end
		barFill.Size = UDim2.fromScale(0, 1)
		for _, f in { hero, foe } do
			for _, attr in { "ActionKind", "ActionStart", "ActionAt", "GuardUntil", "HurtAt", "BlockedAt" } do
				f.Model:SetAttribute(attr, nil)
			end
		end
	end

	-- Fires once per line: `key` the moment `at` passes.
	local function once(key: string, t: number, at: number): boolean
		if line and t >= at and not line.Fired[key] then
			line.Fired[key] = true
			return true
		end
		return false
	end

	function demo.step(name: string, t: number)
		if not line or line.Name ~= name then
			return
		end
		local s = line.Script
		local now = line.Offset + t
		local clock = os.clock()
		local dt = math.clamp(clock - lastClock, 0, 0.1)
		lastClock = clock
		-- the fighters
		act(hero.Model, s.Hero, t, line.Offset)
		act(foe.Model, s.Foe, t, line.Offset)
		local guardUntil = nil
		for _, g in s.Guard or {} do
			if t >= g[1] and t < g[2] then
				guardUntil = g[2] + line.Offset
			end
		end
		hero.Model:SetAttribute("GuardUntil", guardUntil)
		local hurt = latest(s.FoeHurt, t)
		foe.Model:SetAttribute("HurtAt", if hurt then hurt + line.Offset else nil)
		foe.Model:SetAttribute("HurtSide", 1)
		local blocked = latest(s.Blocked, t)
		hero.Model:SetAttribute("BlockedAt", if blocked then blocked + line.Offset else nil)
		-- what's heard: each action as it starts (a cast's element with it),
		-- each blow as it lands (a heavy's heavier, a combo's third rings),
		-- the shield taking a blow (a perfect block rings), each key pressed
		for who, list in { Hero = s.Hero or {}, Foe = s.Foe or {} } do
			for i, a in list do
				if once(who .. "Sound" .. i, t, a[2]) then
					hear(ACTION_SOUNDS[a[1]])
					hearElement("Cast", a.Element)
				end
			end
		end
		for i, at in s.FoeHurt or {} do
			if once("hurtSound" .. i, t, at) then
				local heavy, combo = false, false
				for _, a in s.Hero or {} do
					if a[1] == "Heavy" and math.abs(a[3] - at) < 0.01 then
						heavy = true
					end
				end
				for _, p in s.Pops or {} do
					if math.abs(p[1] - at) < 0.01 and string.find(p[2], "COMBO", 1, true) then
						combo = true
					end
				end
				hear(if heavy then "HeavyHit" else "Hit")
				if combo then
					hear("Combo")
				end
			end
		end
		for i, at in s.Blocked or {} do
			if once("blockSound" .. i, t, at) then
				local perfect = false
				for _, p in s.Pops or {} do
					if math.abs(p[1] - at) < 0.01 and string.find(p[2], "PERFECT", 1, true) then
						perfect = true
					end
				end
				hear(if perfect then "Parry" else "Block")
			end
		end
		for i, p in s.Presses or {} do
			if once("pressSound" .. i, t, p[1]) then
				click("Click")
			end
		end
		local heroHead = hero.Model:FindFirstChild("Head") :: BasePart?
		local foeHead = foe.Model:FindFirstChild("Head") :: BasePart?
		pcall(RivalPose.update, hero.Model, dt, now, now, false, nil, foeHead and foeHead.CFrame.Position)
		pcall(RivalPose.update, foe.Model, dt, now, now, false, nil, heroHead and heroHead.CFrame.Position)
		solve(hero)
		solve(foe)
		local foeChest = foe.Root.CFrame.Position + Vector3.new(-0.4, 0.6, 0)
		local heroHand = (hero.Model:FindFirstChild("RightHand") :: BasePart?)
		local heroFront = hero.Root.CFrame.Position + Vector3.new(1.2, 0.6, 0)
		-- what landed
		for i, p in s.Pops or {} do
			if once("pop" .. i, t, p[1]) then
				pop.Text, pop.TextColor3 = p[2], p[3] or TEXT
				popScale.Scale = 1.5
				TweenService:Create(popScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				if not s.Sparks and not s.Shots then
					flash(foeChest, p[3] or Color3.fromRGB(255, 240, 210), if p[3] then 3.2 else 2)
				end
			end
		end
		for i, sp in s.Sparks or {} do
			if once("spark" .. i, t, sp[1]) then
				flash(heroFront, sp[2], 2.6)
			end
		end
		-- the control: shown from its first press, dipping as it's pressed
		local press, holding = nil, false
		for _, p in s.Presses or {} do
			if t >= p[1] - 0.25 then
				press = p
				holding = p[3] ~= nil and t >= p[1] and t < p[3]
			end
		end
		if press then
			cap.Visible = true
			capText.Text = keys[press[2]] or press[2]
			local since = t - press[1]
			local down = holding or (since >= 0 and since < 0.16)
			cap.Position = UDim2.fromScale(0.5, if down then 0.965 else 0.95)
			cap.BackgroundColor3 = if down then Color3.fromRGB(70, 60, 30) else Color3.fromRGB(28, 32, 46)
			capEdge.Color = if down then GOLD else Color3.fromRGB(90, 100, 130)
			capHint.Visible = press[3] ~= nil
			capHint.Text = if press[3] then "HOLD" else ""
			capFill.Size = UDim2.fromScale(if holding then math.clamp((t - press[1]) / (press[3] - press[1]), 0, 1) else 0, 1)
		end
		-- abilities: the gems light, the charge fills and is spent
		if s.Gems then
			local full = math.clamp((t - 1.9) / 0.6, 0, 1)
			for _, sp in s.Spend or {} do
				if t >= sp[1] then
					full -= sp[2]
				end
			end
			barFill.Size = UDim2.fromScale(math.max(0, full), 1)
			for key, at in s.Gems do
				local slot = gemSlots[key]
				if once("gem" .. key, t, at) then
					click("Enchant")
					slot.Ring.Transparency = 0
					slot.Letter.TextColor3 = TEXT
					slot.Slot.BackgroundColor3 = GEMS[key]:Lerp(INK, 0.55)
					slot.Scale.Scale = 1.35
					TweenService:Create(slot.Scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
				end
			end
			for i, p in s.Presses or {} do
				local slot = gemSlots[p[2]]
				if slot and once("cast" .. i, t, p[1]) then
					slot.Scale.Scale = 1.3
					TweenService:Create(slot.Scale, TweenInfo.new(0.35), { Scale = 1 }):Play()
				end
			end
		end
		-- the bolt in flight, the blast's ring
		for i, shot in s.Shots or {} do
			if t >= shot[1] and t < shot[2] then
				local k = (t - shot[1]) / (shot[2] - shot[1])
				local from = if heroHand then heroHand.CFrame.Position else heroFront
				if not line.Fired["shot" .. i] then
					line.Fired["shot" .. i] = piece(CFrame.new(from), Vector3.one * 0.9, GEMS[shot[3]], Enum.Material.Neon, Enum.PartType.Ball)
					hear("Bolt")
				end
				local ball = line.Fired["shot" .. i]
				if typeof(ball) == "Instance" then
					ball.CFrame = CFrame.new(from:Lerp(foeChest, k))
				end
			elseif t >= shot[2] and typeof(line.Fired["shot" .. i]) == "Instance" then
				line.Fired["shot" .. i]:Destroy()
				line.Fired["shot" .. i] = true
				flash(foeChest, GEMS[shot[3]], 3.4)
				hearElement("Impact", GEM_ELEMENTS[shot[3]])
			end
		end
		for i, ring in s.Rings or {} do
			if t >= ring[1] and t < ring[2] + 0.3 then
				if not line.Fired["ring" .. i] then
					line.Fired["ring" .. i] = piece(CFrame.new(hero.Root.CFrame.Position.X, 0.1, 0) * flat, Vector3.new(0.1, 1, 1), GEMS[ring[3]], Enum.Material.Neon, Enum.PartType.Cylinder)
					hear("Blast")
					hearElement("Impact", GEM_ELEMENTS[ring[3]])
				end
				local disc = line.Fired["ring" .. i]
				if typeof(disc) == "Instance" then
					local k = math.clamp((t - ring[1]) / (ring[2] - ring[1]), 0, 1)
					local size = 1 + k * 15
					disc.Size = Vector3.new(0.1, size, size)
					disc.Transparency = 0.15 + 0.85 * math.max(0, (t - ring[2]) / 0.3)
				end
			elseif t >= ring[2] + 0.3 and typeof(line.Fired["ring" .. i]) == "Instance" then
				line.Fired["ring" .. i]:Destroy()
				line.Fired["ring" .. i] = true
			end
		end
		-- flashes fade and grow
		for i = #fx, 1, -1 do
			local f = fx[i]
			local k = (clock - f.Born) / f.Life
			if k >= 1 then
				f.Part:Destroy()
				table.remove(fx, i)
			else
				f.Part.Size = Vector3.one * f.Grow * (0.4 + 0.6 * k)
				f.Part.Transparency = 0.1 + 0.9 * k
			end
		end
	end

	function demo.destroy()
		view:Destroy()
		overlay:Destroy()
	end

	return demo
end

return BasicsDemo
