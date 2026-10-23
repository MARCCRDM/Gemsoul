-- A shared boxed lottery following the miner's head. No screen window or input lock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Roll = require(ReplicatedStorage.Shared.MiningRoll)
local GemArt = require(script.Parent.GemArt)

local Reveal = {}
local player = Players.LocalPlayer
local WHITE = Color3.fromRGB(239, 249, 255)
local GOLD = Color3.fromRGB(255, 206, 92)
local MUTED = Color3.fromRGB(152, 173, 194)
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
	text.TextColor3, text.TextStrokeColor3, text.TextStrokeTransparency = color, Color3.fromRGB(6, 13, 22), 0.8
	text.Font, text.TextScaled, text.TextWrapped = Enum.Font.GothamBold, true, true
	text.Position, text.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, height)
	text.Text = ""
	text.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize, limit.MinTextSize, limit.Parent = size, 10, text
	return text
end
local function billboard(anchor, name, offset, size)
	local board = Instance.new("BillboardGui")
	board.Name, board.Adornee, board.AlwaysOnTop = name, anchor, true
	board.LightInfluence, board.MaxDistance, board.Active = 0, Roll.Range, false
	board.Size, board.StudsOffsetWorldSpace = size, offset
	-- The whole card sits above its anchor, rather than half over the head.
	board.SizeOffset = Vector2.new(0, 0.5)
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
	if head then return head.Position + Vector3.new(0, head.Size.Y / 2 + 1.1, 0) end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then return root.Position + Vector3.new(0, 3.6, 0) end
	-- Streaming can temporarily hide the miner. Keep the last known head location.
	return previous or (packet.MinerPosition or packet.Position) + Vector3.new(0, 3.5, 0)
end
local function restoreNames(entry)
	if entry.NameAdded then entry.NameAdded:Disconnect(); entry.NameAdded = nil end
	for object, previous in entry.HiddenNames or {} do
		if object.Parent then
			if object:IsA("Humanoid") then
				if object.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None then object.DisplayDistanceType = previous end
			elseif not object.Enabled then object.Enabled = previous end
		end
	end
	entry.HiddenNames, entry.NameCharacter = {}, nil
end
local function hideNames(entry)
	local miner = Players:GetPlayerByUserId(entry.Packet.MinerId)
	local character = miner and miner.Character
	if character == entry.NameCharacter then return end
	restoreNames(entry)
	entry.NameCharacter = character
	if not character then return end
	local function hide(object)
		-- Reparenting a title can announce it again; keep its original state.
		if entry.HiddenNames[object] ~= nil then return end
		if object:IsA("Humanoid") then
			entry.HiddenNames[object] = object.DisplayDistanceType
			object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		elseif object:IsA("BillboardGui") and (object.Name == "CosmeticTitle" or object.Name == "PartyMarker" or object.Name == "Nameplate") then
			entry.HiddenNames[object] = object.Enabled
			object.Enabled = false
		end
	end
	for _, object in character:GetDescendants() do hide(object) end
	entry.NameAdded = character.DescendantAdded:Connect(hide)
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
	restoreNames(entry)
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
	-- Positional audio: observers hear nearby finds, not the whole server at full volume.
	sound(entry.Anchor, 0.9 + rank * 0.12, 0.16 + rank * 0.035)
end
local function showResult(entry, elapsed)
	local packet, gem = entry.Packet, entry.Packet.Gem
	entry.Landed = true
	for _, cell in entry.Cells do if cell.Model then cell.Model:Destroy(); cell.Model = nil end end
	entry.Color = gem and GemConfig.TierColors[gem.Tier] or MUTED
	entry.Selection.Visible = false
	entry.Miner.Text = entry.Packet.MinerName .. "  ·  DISCOVERY"
	entry.Edge.Color, entry.SelectionEdge.Color, entry.Accent.BackgroundColor3 = entry.Color, entry.Color, entry.Color
	entry.Light.Color, entry.Light.Brightness = entry.Color, 0.5 + Roll.rank(packet) * 0.35
	if gem then
		local model, radius = GemArt.model(gem, true)
		entry.Winner = prepare(model, radius)
		entry.Winner.Name, entry.Winner.Parent = "AwardedGem", entry.Viewport
		entry.Well.Position, entry.Well.Size = UDim2.fromScale(0.045, 0.22), UDim2.fromScale(0.32, 0.50)
		entry.Camera.FieldOfView = 28
		entry.Rarity.Text = string.upper(GemConfig.TierLabels[gem.Tier] or gem.Tier)
		entry.Rarity.TextColor3 = entry.Color
		entry.Heading.Position, entry.Heading.Size = UDim2.fromScale(0.40, 0.34), UDim2.fromScale(0.55, 0.21)
		entry.Detail.Position, entry.Detail.Size = UDim2.fromScale(0.40, 0.57), UDim2.fromScale(0.55, 0.10)
		entry.Heading.Text = GemConfig.shade(gem).Name
		entry.Heading.TextColor3 = entry.Color
		entry.Detail.Text = string.upper(GemConfig.elementName(gem.Element))
		entry.Detail.TextColor3 = GemConfig.ElementColors[gem.Element] or WHITE
		entry.Stats.Text = string.format("SIZE %d/10   ·   CLARITY %d/10   ·   %s", gem.Size, gem.Clarity, if gem.Cut then "CUT " .. gem.Cut .. "/10" else "UNCUT")
	else
		-- Every rock pays a gem; only a full pouch (the server normally
		-- refuses that swing) lands here, as a short notice, never a blank reel.
		entry.Notice = true
		entry.Well.Visible, entry.Stats.Visible, entry.Rarity.Visible = false, false, false
		entry.Miner.Position, entry.Miner.Size = UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.90, 0.17)
		entry.Heading.Position, entry.Heading.Size = UDim2.fromScale(0.05, 0.29), UDim2.fromScale(0.90, 0.30)
		entry.Detail.Position, entry.Detail.Size = UDim2.fromScale(0.05, 0.63), UDim2.fromScale(0.90, 0.17)
		entry.Extras.Position, entry.Extras.Size = UDim2.fromScale(0.05, 0.82), UDim2.fromScale(0.90, 0.14)
		entry.Heading.Text = "ROCK MINED"
		entry.Heading.TextColor3 = WHITE
		entry.Detail.Text = if packet.Full then "GEM POUCH FULL" else ""
		entry.Detail.TextColor3 = MUTED
	end
	local rewards = {}
	if gem then table.insert(rewards, "VALUE ≈ " .. math.floor(GemConfig.value(gem)) .. " coins") end
	entry.Extras.Text = table.concat(rewards, "  ·  ")
	-- A delayed observer sees the result without replaying an old explosion.
	if gem and elapsed - Roll.Duration < 0.7 then burst(entry) end
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
		hideNames(entry)
		if sample.Landed then
			if not entry.Landed then showResult(entry, t) end
			if entry.Winner then
				entry.Winner:PivotTo(CFrame.new(0, math.sin(t * 2.3) * 0.1, 0) * GemArt.pose(entry.Packet.Gem, t * 1.3))
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
		local camera = workspace.CurrentCamera
		local screen = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local distance = if camera then (camera.CFrame.Position - center).Magnitude else 35
		local width, height = Roll.displaySize(screen, distance, UserInputService.TouchEnabled, entry.Notice)
		entry.Board.Size = UDim2.fromOffset(width, height)
		entry.Box.BackgroundTransparency = 0.03 + sample.Fade * 0.97
		entry.Well.BackgroundTransparency = 0.12 + sample.Fade * 0.88
		entry.Viewport.ImageTransparency = sample.Fade
		entry.Edge.Transparency, entry.SelectionEdge.Transparency = 0.35 + sample.Fade * 0.65, 0.5 + sample.Fade * 0.5
		entry.Accent.BackgroundTransparency = sample.Fade
		for _, text in entry.Labels do
			text.TextTransparency, text.TextStrokeTransparency = sample.Fade, 0.8 + sample.Fade * 0.2
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
	-- Your own finds are your loot card (MinerLoot), not a box over your head.
	if packet.MinerId == player.UserId then return end
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
	local board = billboard(anchor, "Discovery", Vector3.zero, UDim2.fromOffset(344, 206))
	local box = frame(board, "MiningRollBox", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), Color3.fromRGB(8, 16, 27), 0.08)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(25, 36, 49), Color3.fromRGB(7, 13, 22))
	gradient.Rotation, gradient.Parent = 90, box
	box.BackgroundColor3 = Color3.new(1, 1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0.04, 0), box
	local border = edge(box, MUTED, 1)
	local accent = frame(box, "RarityAccent", UDim2.fromScale(0.07, 0.025), UDim2.fromScale(0.86, 0.009), GOLD)
	local miner = label(box, 0.055, 0.105, 14, WHITE)
	miner.TextWrapped, miner.TextTruncate = false, Enum.TextTruncate.AtEnd
	miner.Position, miner.Size = UDim2.fromScale(0.04, 0.055), UDim2.fromScale(0.92, 0.105)
	miner:SetAttribute("NoTranslate", true)
	miner.Text = packet.MinerName .. "  ·  MINING"
	local heading = label(box, 0.18, 0.12, 22, WHITE)
	heading.Name = "ResultHeading"
	local rarity = label(box, 0.22, 0.09, 14, MUTED)
	rarity.Position, rarity.Size = UDim2.fromScale(0.40, 0.22), UDim2.fromScale(0.55, 0.09)
	local well = frame(box, "ReelWindow", UDim2.fromScale(0.045, 0.34), UDim2.fromScale(0.91, 0.43), Color3.fromRGB(17, 30, 45), 0.12)
	well.ClipsDescendants = true
	local viewport = Instance.new("ViewportFrame")
	viewport.Name, viewport.BackgroundTransparency, viewport.Size = "GemReel", 1, UDim2.fromScale(1, 1)
	viewport.Active, viewport.Parent = false, well
	local camera = GemArt.setupViewport(viewport, 6)
	camera.FieldOfView = 35
	local selection = frame(well, "WinningSlot", UDim2.fromScale(0.36, 0.05), UDim2.fromScale(0.28, 0.90), GOLD, 1)
	local selectionEdge = edge(selection, GOLD, 1.5)
	local detail = label(box, 0.83, 0.09, 14, MUTED)
	detail.Text = "Finding your stone..."
	local stats, extras = label(box, 0.76, 0.09, 12, WHITE), label(box, 0.88, 0.08, 13, GOLD)
	stats.Position, stats.Size = UDim2.fromScale(0.04, 0.76), UDim2.fromScale(0.92, 0.08)
	extras.Position, extras.Size = UDim2.fromScale(0.04, 0.88), UDim2.fromScale(0.92, 0.07)
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Color, light.Parent = 10, 0.6, WHITE, anchor
	active[packet.Id] = { Packet = packet, Sequence = Roll.sequence(packet), Root = root, Anchor = anchor, Light = light,
		Board = board, Box = box, Camera = camera, Selection = selection, Miner = miner, Rarity = rarity, Edge = border, Accent = accent, Well = well, Viewport = viewport, SelectionEdge = selectionEdge, Center = center,
		Heading = heading, Detail = detail, Stats = stats, Extras = extras, Labels = {miner, heading, rarity, detail, stats, extras}, Cells = {{},{},{}} }
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
