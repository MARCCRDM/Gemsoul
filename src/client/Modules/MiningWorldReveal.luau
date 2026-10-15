-- A shared lottery floating over the mined rock. No screen window or input lock.
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
	board.Parent = anchor
	return board
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
	local ring = part(entry.Root, "DiscoveryRing", entry.Packet.Position + Vector3.new(0, 0.2, 0))
	ring.Shape, ring.Material, ring.Color = Enum.PartType.Cylinder, Enum.Material.Neon, entry.Color
	ring.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	entry.Ring = ring
	if rank >= 3 then
		local beam = part(entry.Root, "RarityBeacon", entry.Packet.Position)
		beam.Shape, beam.Material, beam.Color = Enum.PartType.Cylinder, Enum.Material.Neon, entry.Color
		local height = 6 + rank * 2
		beam.Size = Vector3.new(height, 0.15 + rank * 0.05, 0.15 + rank * 0.05)
		beam.CFrame = CFrame.new(entry.Packet.Position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
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
	entry.Light.Color, entry.Light.Brightness = entry.Color, 0.5 + Roll.rank(packet) * 0.35
	if gem then
		local model, radius = GemArt.model(gem, true)
		entry.Winner = prepare(model, radius)
		entry.Winner.Name, entry.Winner.Parent = "AwardedGem", entry.Root
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
	if packet.Coins and packet.Coins > 0 then table.insert(rewards, "+" .. packet.Coins .. " coins") end
	if packet.Gear then table.insert(rewards, tostring(packet.Gear)) end
	entry.Extras.Text = table.concat(rewards, "  ·  ")
	-- A delayed observer sees the result without replaying an old explosion.
	if elapsed - Roll.Duration < 0.7 then burst(entry) end
end
local function step()
	if not canWatch() then Reveal.close(); return end
	local now, camera = workspace:GetServerTimeNow(), workspace.CurrentCamera
	for id, expiry in seen do if expiry < now then seen[id] = nil end end
	for id, entry in active do
		local sample = Roll.sample(entry.Packet, now)
		if sample.Done or not entry.Root.Parent or not near(entry.Packet.Position) then
			destroy(entry); active[id] = nil
			continue
		end
		local t, center = sample.Elapsed, entry.Packet.Position + Vector3.new(0, 3.5, 0)
		entry.Anchor.Position = center
		if sample.Landed then
			if not entry.Landed then showResult(entry, t) end
			if entry.Winner then
				entry.Winner:PivotTo(CFrame.new(center + Vector3.new(0, 0.3 + math.sin(t * 2.3) * 0.2, 0)) * GemArt.pose(entry.Packet.Gem, t * 1.3))
			end
			local revealAge = t - Roll.Duration
			if entry.Ring then
				local diameter = 2 + math.min(revealAge, 1.2) * (5 + Roll.rank(entry.Packet))
				entry.Ring.Size = Vector3.new(0.06, diameter, diameter)
				entry.Ring.Transparency = math.clamp(revealAge / 1.2, 0.15, 1)
			end
			if entry.Beam then entry.Beam.Transparency = math.clamp(0.5 + revealAge / 3, 0.5, 1) end
		else
			local index = math.floor(sample.Position + 0.5)
			local right = camera and camera.CFrame.RightVector or Vector3.new(1, 0, 0)
			for i = -1, 1 do
				local at = index + i
				local cell, tier = entry.Cells[i + 2], entry.Sequence[at] or "Common"
				if cell.Index ~= at then
					if cell.Model then cell.Model:Destroy(); cell.Model = nil end
					cell.Index = at
					if at == Roll.Target and entry.Packet.Gem then
						local model, radius = GemArt.model(entry.Packet.Gem, false)
						cell.Model = prepare(model, radius)
					elseif tier ~= "Empty" then cell.Model = template(tier):Clone() end
					if cell.Model then cell.Model.Parent = entry.Root end
				end
				if cell.Model then
					local offset = at - sample.Position
					cell.Model:PivotTo(CFrame.new(center + right * (offset * 2.8) + Vector3.new(0, -math.abs(offset) * 0.4, 0)) * CFrame.Angles(0.15, t * 2, 0.12))
				end
			end
			if entry.Index ~= index then
				entry.Index = index
				local tier = entry.Sequence[index] or "Common"
				entry.Heading.Text = "ROLLING  ·  " .. string.upper(GemConfig.TierLabels[tier] or "STONE")
				entry.Heading.TextColor3 = GemConfig.TierColors[tier] or WHITE
				entry.Light.Color = entry.Heading.TextColor3
				if near(entry.Packet.Position) then sound(entry.Anchor, 2.2 - sample.Position / Roll.Target * 0.6, 0.045) end
			end
		end
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
	if type(packet) ~= "table" or not canWatch() or not near(packet.Position) then return end
	local now = workspace:GetServerTimeNow()
	if seen[packet.Id] or Roll.sample(packet, now).Done then return end
	seen[packet.Id] = packet.StartedAt + Roll.lifetime(packet)
	local count, oldest = 0, nil
	for _, entry in active do
		count += 1
		if not oldest or entry.Packet.StartedAt < oldest.Packet.StartedAt then oldest = entry end
	end
	if count >= Roll.MaxActive and oldest then destroy(oldest); active[oldest.Packet.Id] = nil end
	if not folder then folder = Instance.new("Folder"); folder.Name = "MiningDiscoveries"; folder.Parent = workspace end
	local root = Instance.new("Model")
	root.Name, root.Parent = "MiningRoll_" .. packet.Id, folder
	local anchor = part(root, "RollAnchor", packet.Position + Vector3.new(0, 3.5, 0))
	local upper = billboard(anchor, "MinerLabel", Vector3.new(0, 2.2, 0), UDim2.new(11, 0, 0.7, 0))
	local miner = label(upper, 0, 1, 14, WHITE)
	miner.Text = packet.MinerName .. "  ·  " .. packet.NodeName
	local board = billboard(anchor, "Discovery", Vector3.new(0, -2.25, 0), UDim2.new(12, 0, 2.3, 0))
	local heading, detail = label(board, 0, 0.32, 23, WHITE), label(board, 0.34, 0.2, 15, WHITE)
	local stats, extras = label(board, 0.56, 0.2, 13, WHITE), label(board, 0.79, 0.2, 12, GOLD)
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color, light.Parent = 10, 0.6, WHITE, anchor
	active[packet.Id] = { Packet = packet, Sequence = Roll.sequence(packet), Root = root, Anchor = anchor, Light = light,
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
