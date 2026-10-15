-- A shared boxed lottery following the miner's head. No screen window or input lock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Roll = require(ReplicatedStorage.Shared.MiningRoll)
local GemArt = require(script.Parent.GemArt)

local Reveal = {}
local player = Players.LocalPlayer
local WHITE = Color3.fromRGB(239, 249, 255)
local GOLD = Color3.fromRGB(255, 206, 92)
local active, templates, seen = {}, {}, {}
local connection, folder = nil, nil
local started = false
local playerGui = player:WaitForChild("PlayerGui")

local function part(parent, name, at)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = name, true, false, false, false, false
	p.Size, p.CFrame, p.Transparency = Vector3.new(0.1, 0.1, 0.1), CFrame.new(at), 1
	p.Parent = parent
	return p
end
local function label(parent, y, height, size, color)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency, text.RichText = 1, false
	text.TextColor3, text.TextStrokeColor3, text.TextStrokeTransparency = color, Color3.fromRGB(6, 13, 22), 0.25
	text.Font, text.TextScaled, text.TextWrapped = Enum.Font.GothamBold, true, true
	text.Position, text.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, height)
	text.Text = ""
	text.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize, limit.MinTextSize, limit.Parent = size, 8, text
	return text
end
local function billboard(anchor, name, offset, size)
	local board = Instance.new("BillboardGui")
	board.Name, board.Adornee, board.AlwaysOnTop = name, anchor, false
	board.LightInfluence, board.MaxDistance, board.Active = 0, Roll.Range, false
	board.Size, board.StudsOffsetWorldSpace = size, offset
	board.Parent = playerGui
	return board
end
local function frame(parent, name, position, size, color, transparency)
	local box = Instance.new("Frame")
	box.Name, box.Position, box.Size = name, position, size
	box.BorderSizePixel, box.BackgroundColor3, box.BackgroundTransparency = 0, color, transparency or 0
	box.Active, box.Parent = false, parent
	return box
end
local function edge(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = color, thickness, parent
	return stroke
end
local function aboveMiner(packet, previous)
	local miner = Players:GetPlayerByUserId(packet.MinerId)
	local character = miner and miner.Character
	local head = character and character:FindFirstChild("Head")
	if head then return head.Position + Vector3.new(0, head.Size.Y / 2 + 3, 0) end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then return root.Position + Vector3.new(0, 5.5, 0) end
	-- Streaming can temporarily hide the miner. Keep the last known head location.
	return previous or (packet.MinerPosition or packet.Position) + Vector3.new(0, 3.5, 0)
end
local function sound(anchor, pitch, volume)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	s.PlaybackSpeed, s.Volume = pitch, volume
	s.RollOffMinDistance, s.RollOffMaxDistance = 8, 75
	s.Parent = anchor
	s:Play()
	Debris:AddItem(s, 2)
end
local function prepare(model, radius)
	model:ScaleTo(1.05 / math.max(radius, 0.1))
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		end
	end
	return model
end
local function template(tier)
	if not templates[tier] then
		local rank = GemConfig.TierRank[tier] or 1
		local gem = { Id = "world-preview-" .. tier, Tier = tier, Element = GemConfig.Elements[(rank - 1) % #GemConfig.Elements + 1], Size = 6, Clarity = 7, Cut = 6 }
		local model, radius = GemArt.model(gem, false)
		templates[tier] = prepare(model, radius)
	end
	return templates[tier]
end
local function destroy(entry)
	entry.Board:Destroy()
	entry.Root:Destroy()
end
function Reveal.close()
	for _, entry in active do destroy(entry) end
	table.clear(active)
	for _, model in templates do model:Destroy() end
	table.clear(templates)
	if folder then folder:Destroy(); folder = nil end
	if connection then connection:Disconnect(); connection = nil end
end
local function canWatch()
	return player:GetAttribute("Outpost") == true and player:GetAttribute("CombatSession") == nil
end
local function near(position)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - position).Magnitude <= Roll.Range
end
local function burst(entry)
	local rank = Roll.rank(entry.Packet)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(entry.Color, WHITE)
	emitter.LightEmission, emitter.Rate = 0.85, 0
	emitter.Lifetime, emitter.Speed = NumberRange.new(0.5, 1.3), NumberRange.new(3, 5 + rank * 2)
	emitter.SpreadAngle, emitter.Drag = Vector2.new(180, 180), 3
	emitter.Size = NumberSequence.new(0.15 + rank * 0.07, 0)
	emitter.Transparency = NumberSequence.new(0.05, 1)
	emitter.Parent = entry.Anchor
	emitter:Emit(8 + rank * 10)
	local ring = part(entry.Root, "DiscoveryRing", entry.Center)
	ring.Shape, ring.Material, ring.Color = Enum.PartType.Cylinder, Enum.Material.Neon, entry.Color
	ring.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	entry.Ring = ring
	if rank >= 3 then
		local beam = part(entry.Root, "RarityBeacon", entry.Center)
		beam.Shape, beam.Material, beam.Color = Enum.PartType.Cylinder, Enum.Material.Neon, entry.Color
		local height = 2 + rank * 0.35
		beam.Size = Vector3.new(height, 0.15 + rank * 0.05, 0.15 + rank * 0.05)
		beam.CFrame = CFrame.new(entry.Center) * CFrame.Angles(0, 0, math.pi / 2)
		entry.Beam = beam
	end
	-- Positional audio: observers hear nearby finds, not the whole server at full volume.
	sound(entry.Anchor, 0.9 + rank * 0.12, 0.16 + rank * 0.035)
end
local function showResult(entry, elapsed)
	local packet, gem = entry.Packet, entry.Packet.Gem
	entry.Landed = true
	for _, cell in entry.Cells do if cell.Model then cell.Model:Destroy(); cell.Model = nil end end
	entry.Color = gem and GemConfig.TierColors[gem.Tier] or GOLD
	entry.Edge.Color, entry.SelectionEdge.Color, entry.Accent.BackgroundColor3 = entry.Color, entry.Color, entry.Color
	entry.Light.Color, entry.Light.Brightness = entry.Color, 0.5 + Roll.rank(packet) * 0.35
	if gem then
		local model, radius = GemArt.model(gem, true)
		entry.Winner = prepare(model, radius)
		entry.Winner.Name, entry.Winner.Parent = "AwardedGem", entry.Viewport
		entry.Heading.Text = string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier) .. "  ·  " .. GemConfig.shade(gem).Name
		entry.Heading.TextColor3 = entry.Color
		entry.Detail.Text = string.upper(GemConfig.elementName(gem.Element))
		entry.Detail.TextColor3 = GemConfig.ElementColors[gem.Element] or WHITE
		entry.Stats.Text = string.format("SIZE %d/10   ·   CLARITY %d/10   ·   %s", gem.Size, gem.Clarity, if gem.Cut then "CUT " .. gem.Cut .. "/10" else "UNCUT")
	else
		entry.Heading.Text = if packet.Full then "STONE POUCH FULL" else "ROCK MINED"
		entry.Detail.Text = if packet.Full then "No stone collected" else "No stone this time"
	end
	local rewards = {}
	if gem then table.insert(rewards, "VALUE ≈ " .. math.floor(GemConfig.value(gem)) .. " coins") end
	if packet.Coins and packet.Coins > 0 then table.insert(rewards, "+" .. packet.Coins .. " coins") end
	if packet.Gear then table.insert(rewards, tostring(packet.Gear)) end
	entry.Extras.Text = table.concat(rewards, "  ·  ")
	-- A delayed observer sees the result without replaying an old explosion.
	if elapsed - Roll.Duration < 0.7 then burst(entry) end
end
local function step()
	if not canWatch() then Reveal.close(); return end
	local now = workspace:GetServerTimeNow()
	for id, expiry in seen do if expiry < now then seen[id] = nil end end
	for id, entry in active do
		local sample = Roll.sample(entry.Packet, now)
		local center = aboveMiner(entry.Packet, entry.Center)
		if sample.Done or not entry.Root.Parent or not near(center) then
			destroy(entry); active[id] = nil
			continue
		end
		local t = sample.Elapsed
		entry.Center = center
		entry.Anchor.Position = center
		if sample.Landed then
			if not entry.Landed then showResult(entry, t) end
			if entry.Winner then
				entry.Winner:PivotTo(CFrame.new(0, math.sin(t * 2.3) * 0.1, 0) * GemArt.pose(entry.Packet.Gem, t * 1.3))
			end
			local revealAge = t - Roll.Duration
			if entry.Ring then
				local diameter = 2 + math.min(revealAge, 1.2) * (5 + Roll.rank(entry.Packet))
				entry.Ring.Size = Vector3.new(0.06, diameter, diameter)
				entry.Ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
				entry.Ring.Transparency = math.clamp(revealAge / 1.2, 0.15, 1)
			end
			if entry.Beam then
				entry.Beam.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
				entry.Beam.Transparency = math.clamp(0.5 + revealAge / 3, 0.5, 1)
			end
		else
			local index = math.floor(sample.Position + 0.5)
			for i = -1, 1 do
				local at = index + i
				-- Recycle three reel cells: only the incoming stone changes each tick.
				local cell, tier = entry.Cells[at % 3 + 1], entry.Sequence[at] or "Common"
				if cell.Index ~= at then
					if cell.Model then cell.Model:Destroy(); cell.Model = nil end
					cell.Index = at
					if at == Roll.Target and entry.Packet.Gem then
						local model, radius = GemArt.model(entry.Packet.Gem, false)
						cell.Model = prepare(model, radius)
					elseif tier ~= "Empty" then cell.Model = template(tier):Clone() end
					if cell.Model then cell.Model.Parent = entry.Viewport end
				end
				if cell.Model then
					local offset = at - sample.Position
					cell.Model:PivotTo(CFrame.new(offset * 2.8, -math.abs(offset) * 0.15, 0) * CFrame.Angles(0.15, t * 2, 0.12))
				end
			end
			if entry.Index ~= index then
				entry.Index = index
				local tier = entry.Sequence[index] or "Common"
				entry.Heading.Text = "ROLLING  ·  " .. string.upper(GemConfig.TierLabels[tier] or "STONE")
				entry.Heading.TextColor3 = GemConfig.TierColors[tier] or WHITE
				entry.Light.Color = entry.Heading.TextColor3
				entry.Edge.Color, entry.Accent.BackgroundColor3 = entry.Heading.TextColor3, entry.Heading.TextColor3
				if near(center) then sound(entry.Anchor, 2.2 - sample.Position / Roll.Target * 0.6, 0.045) end
			end
		end
		entry.Box.BackgroundTransparency = 0.08 + sample.Fade * 0.92
		entry.Well.BackgroundTransparency = 0.12 + sample.Fade * 0.88
		entry.Viewport.ImageTransparency = sample.Fade
		entry.Edge.Transparency, entry.SelectionEdge.Transparency = sample.Fade, 0.25 + sample.Fade * 0.75
		entry.Accent.BackgroundTransparency = sample.Fade
		for _, text in entry.Labels do
			text.TextTransparency, text.TextStrokeTransparency = sample.Fade, 0.25 + sample.Fade * 0.75
		end
		if entry.Winner and sample.Fade > 0 then
			for _, p in entry.Winner:GetDescendants() do
				if p:IsA("BasePart") then p.Transparency = math.max(p.Transparency, sample.Fade) end
			end
		end
		entry.Light.Brightness *= 1 - sample.Fade
	end
	if next(active) == nil then Reveal.close() end
end
function Reveal.receive(packet)
	if type(packet) ~= "table" or not canWatch() then return end
	local center = aboveMiner(packet)
	if not near(center) then return end
	local now = workspace:GetServerTimeNow()
	if seen[packet.Id] or Roll.sample(packet, now).Done then return end
	seen[packet.Id] = packet.StartedAt + Roll.lifetime(packet)
	local count, oldest = 0, nil
	for id, entry in active do
		-- One readable box per miner; repeated fast finds replace the prior display.
		if entry.Packet.MinerId == packet.MinerId then destroy(entry); active[id] = nil; continue end
		count += 1
		if not oldest or entry.Packet.StartedAt < oldest.Packet.StartedAt then oldest = entry end
	end
	if count >= Roll.MaxActive and oldest then destroy(oldest); active[oldest.Packet.Id] = nil end
	if not folder then folder = Instance.new("Folder"); folder.Name = "MiningDiscoveries"; folder.Parent = workspace end
	local root = Instance.new("Model")
	root.Name, root.Parent = "MiningRoll_" .. packet.Id, folder
	local anchor = part(root, "RollAnchor", center)
	local board = billboard(anchor, "Discovery", Vector3.zero, UDim2.new(8, 0, 5, 0))
	local box = frame(board, "MiningRollBox", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(8, 16, 27), 0.08)
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0.04, 0), box
	local border = edge(box, GOLD, 2)
	local accent = frame(box, "RarityAccent", UDim2.fromScale(0.04, 0.015), UDim2.fromScale(0.92, 0.012), GOLD)
	local miner = label(box, 0.04, 0.10, 14, WHITE)
	miner.Text = packet.MinerName .. "  ·  " .. packet.NodeName
	local heading = label(box, 0.15, 0.12, 22, WHITE)
	local well = frame(box, "ReelWindow", UDim2.fromScale(0.04, 0.29), UDim2.fromScale(0.92, 0.39), Color3.fromRGB(17, 30, 45), 0.12)
	well.ClipsDescendants = true
	local viewport = Instance.new("ViewportFrame")
	viewport.Name, viewport.BackgroundTransparency, viewport.Size = "GemReel", 1, UDim2.fromScale(1, 1)
	viewport.Active, viewport.Parent = false, well
	local camera = GemArt.setupViewport(viewport, 6)
	camera.FieldOfView = 35
	local selection = frame(well, "WinningSlot", UDim2.fromScale(0.36, 0.03), UDim2.fromScale(0.28, 0.94), GOLD, 1)
	local selectionEdge = edge(selection, GOLD, 1.5)
	local detail = label(box, 0.70, 0.09, 15, WHITE)
	local stats, extras = label(box, 0.81, 0.08, 13, WHITE), label(box, 0.90, 0.07, 12, GOLD)
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color, light.Parent = 10, 0.6, WHITE, anchor
	active[packet.Id] = { Packet = packet, Sequence = Roll.sequence(packet), Root = root, Anchor = anchor, Light = light,
		Board = board, Box = box, Edge = border, Accent = accent, Well = well, Viewport = viewport, SelectionEdge = selectionEdge, Center = center,
		Heading = heading, Detail = detail, Stats = stats, Extras = extras, Labels = {miner, heading, detail, stats, extras}, Cells = {{},{},{}} }
	if not connection then connection = RunService.RenderStepped:Connect(step) end
	step()
end
function Reveal.start()
	if started then return end
	started = true
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MiningRoll").OnClientEvent:Connect(Reveal.receive)
	for _, attribute in { "Outpost", "CombatSession" } do
		player:GetAttributeChangedSignal(attribute):Connect(function() if not canWatch() then Reveal.close() end end)
	end
end
return Reveal
