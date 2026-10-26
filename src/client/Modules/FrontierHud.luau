--[[
	The frontier on screen:

	  (No title card as you cross from one band or biome into another:
	  the ground, the light and the critters say where you are.)
	  the light    out in the biomes the screen's grade and the outdoor
	               light take on the biome's (Frontier.Biomes: Tint,
	               Ambient), blending across the spokes and in from the
	               core's edge (not in the Rift, which has its own).
	  (No noise ring or stirred-up meter: the screen stays the game's. The
	  critters coming are the sign.)
	  arrows       a rift coming for you (its Prey is you) that opens off
	               screen gets an arrow at the screen's edge, pointing at
	               it, till its critter is out.
	  Rift Charged a tag with the seconds left, after you helped clear a
	               wandering rift (RiftCharged: gems come luckier).
	  status tags  under it: ALONE (out past the core with no kaiju out:
	               FrontierAlone, the critters come harder), and while
	               you're hurt in the Outpost, where you'll mend: HEAL AT
	               THE SHELTER away from it (AtBase), MENDING while you do
	               (LobbyMend).
	  (No banner when a Rift Vein surfaces somewhere new: no big words
	  across the middle of the screen. Its tear and glow show where.)
	  sightings    the nearest wild kaiju within Sighting studs, off
	               screen, gets an arrow at the screen's edge with how far
	               it is (the vein guardian's in red), so you can find them.

	  FrontierHud.start()
	  FrontierHud.biomeLight(offset, tint, ambient, fog?) -> tint, ambient, fog
	      the grade, outdoor light and fog colour at `offset` from the
	      Outpost's middle, given the Outpost's own (pure)
	  FrontierHud.edge(size, point, margin) -> Vector2, angle   where an
	      arrow sits for a point off screen (pure)
	  FrontierHud.nearest(spots, from, reach) -> index?, studs   the nearest
	      of `spots` (Vector3s) within `reach` across the ground (pure)
	  FrontierHud.tags(alone, hurt, here, atBase, mending) -> { id }   which
	      status tags show (FrontierHud.Tags) (pure)
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Frontier = require(ReplicatedStorage.Shared.Frontier)
local Outpost = require(ReplicatedStorage.Shared.Outpost)

local FrontierHud = {}

FrontierHud.Sighting = 220 -- studs: how far off a wild kaiju gets an arrow
local WILD = Color3.fromRGB(255, 176, 70)

-- Where an arrow sits for `point` (a screen point, possibly off screen or
-- mirrored from behind the camera) on a screen of `size`, `margin` in from
-- its edge, and the angle it points (radians, 0 = right).
function FrontierHud.edge(size: Vector2, point: Vector2, margin: number): (Vector2, number)
	local middle = size / 2
	local d = point - middle
	if d.Magnitude < 1e-3 then
		d = Vector2.new(0, 1)
	end
	local halfW, halfH = math.max(1, middle.X - margin), math.max(1, middle.Y - margin)
	local scale = math.min(halfW / math.max(math.abs(d.X), 1e-3), halfH / math.max(math.abs(d.Y), 1e-3))
	return middle + d * scale, math.atan2(d.Y, d.X)
end

-- The grade's tint and the outdoor light at `offset` from the Outpost's
-- middle: `tint` and `ambient` (the Outpost's own) in the core, the
-- biomes' further out, blended across the spokes (Frontier.biomeMix).
function FrontierHud.biomeLight(offset: Vector3, tint: Color3, ambient: Color3, fog: Color3?): (Color3, Color3, Color3)
	local weights, inward = Frontier.biomeMix(offset)
	local t, a, f = { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }
	for i, biome in Frontier.Biomes do
		local w = weights[i]
		t[1], t[2], t[3] = t[1] + biome.Tint.R * w, t[2] + biome.Tint.G * w, t[3] + biome.Tint.B * w
		a[1], a[2], a[3] = a[1] + biome.Ambient.R * w, a[2] + biome.Ambient.G * w, a[3] + biome.Ambient.B * w
		f[1], f[2], f[3] = f[1] + biome.Fog.R * w, f[2] + biome.Fog.G * w, f[3] + biome.Fog.B * w
	end
	return tint:Lerp(Color3.new(t[1], t[2], t[3]), inward),
		ambient:Lerp(Color3.new(a[1], a[2], a[3]), inward),
		(fog or Color3.new(f[1], f[2], f[3])):Lerp(Color3.new(f[1], f[2], f[3]), inward)
end

-- The nearest of `spots` within `reach` of `from`, across the ground.
function FrontierHud.nearest(spots: { Vector3 }, from: Vector3, reach: number): (number?, number)
	local best, bestDistance = nil, reach
	for i, spot in spots do
		local distance = Vector2.new(spot.X - from.X, spot.Z - from.Z).Magnitude
		if distance <= bestDistance then
			best, bestDistance = i, distance
		end
	end
	return best, bestDistance
end

-- Out in the biomes, the light turns to theirs (a little each quarter
-- second, so it drifts rather than snaps), from the Outpost's own grade
-- (Scenes.OutpostFinish) and outdoor light (Scenes.spaceLighting's). Not in
-- the Rift, nor anywhere but the Outpost: their lighting is their own.
local OUTPOST_AMBIENT = Color3.fromRGB(150, 156, 176)
local function biomeLight(player: Player)
	local Lighting = game:GetService("Lighting")
	local ok, Scenes = pcall(require, script.Parent.Scenes)
	local tint = if ok and Scenes.OutpostFinish then Scenes.OutpostFinish.Grade.Tint else Color3.fromRGB(248, 250, 255)
	local haze = if ok and Scenes.OutpostFinish then Scenes.OutpostFinish.Fog.Color else Color3.fromRGB(86, 92, 110)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and player:GetAttribute("Outpost") == true and player:GetAttribute("RiftRun") == nil then
				local want, ambient, fog =
					FrontierHud.biomeLight(root.Position - Outpost.Location.Position, tint, OUTPOST_AMBIENT, haze)
				local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
				if grade then
					grade.TintColor = grade.TintColor:Lerp(want, 0.2)
				end
				Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(ambient, 0.2)
				local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
				if atmosphere then
					atmosphere.Color = atmosphere.Color:Lerp(fog, 0.2)
				end
			end
		end
	end)
end

-- The Rift Charged tag on the right while it lasts (RiftCharged: gems come
-- luckier). (The noise ring and the stirred-up meter are off the HUD: the
-- critters coming say it well enough.)
local function chargedTag(player: Player, gui: ScreenGui)
	local charged = Instance.new("TextLabel")
	charged.Name = "RiftCharged"
	charged.BackgroundColor3 = Color3.fromRGB(40, 16, 64)
	charged.BackgroundTransparency = 0.2
	charged.AnchorPoint = Vector2.new(1, 0.5)
	charged.Position = UDim2.new(1, -18, 0.5, 30)
	charged.Size = UDim2.fromOffset(132, 18)
	charged.Font = Enum.Font.GothamBlack
	charged.TextSize = 11
	charged.TextColor3 = Frontier.RiftColor:Lerp(Color3.new(1, 1, 1), 0.35)
	charged.Visible = false
	charged.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = charged

	local function refresh()
		local ends = player:GetAttribute("RiftCharged")
		local left = if type(ends) == "number" then ends - workspace:GetServerTimeNow() else 0
		charged.Visible = left > 0
		if left > 0 then
			charged.Text = string.format("RIFT CHARGED · %ds", math.ceil(left))
		end
	end
	player:GetAttributeChangedSignal("RiftCharged"):Connect(refresh)
	refresh()
	-- (The seconds tick down.)
	task.spawn(function()
		while true do
			task.wait(1)
			if charged.Visible then
				refresh()
			end
		end
	end)
end

-- Tags under it, on the right: out there alone (FrontierAlone), and while
-- hurt in the Outpost, that only the Shelter mends you (AtBase, LobbyMend).
FrontierHud.Tags = {
	Alone = { Text = "ALONE · NO KAIJU WITH YOU", Color = Color3.fromRGB(255, 96, 96), Back = Color3.fromRGB(70, 14, 18) },
	Heal = { Text = "HURT · HEAL AT THE SHELTER", Color = Color3.fromRGB(255, 214, 140), Back = Color3.fromRGB(56, 36, 10) },
	Mending = { Text = "MENDING AT THE SHELTER", Color = Color3.fromRGB(140, 255, 170), Back = Color3.fromRGB(12, 50, 26) },
}

-- Which tags show (pure): `alone` out there with no kaiju; `hurt` below
-- full health; `here` in the Outpost (not away in the Rift); `atBase`,
-- `mending` as HealthRegen has them.
function FrontierHud.tags(alone: boolean, hurt: boolean, here: boolean, atBase: boolean, mending: boolean): { string }
	local list = {}
	if alone then
		table.insert(list, "Alone")
	end
	if mending then
		table.insert(list, "Mending")
	elseif here and hurt and not atBase then
		table.insert(list, "Heal")
	end
	return list
end

local function statusTags(player: Player, gui: ScreenGui)
	local column = Instance.new("Frame")
	column.Name = "FrontierTags"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(1, 0)
	column.Position = UDim2.new(1, -18, 0.5, 42)
	column.Size = UDim2.fromOffset(200, 60)
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = column
	local labels: { [string]: TextLabel } = {}
	for i, id in { "Alone", "Heal", "Mending" } do
		local tag = FrontierHud.Tags[id]
		local label = Instance.new("TextLabel")
		label.Name = id
		label.LayoutOrder = i
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.fromOffset(0, 18)
		label.BackgroundColor3 = tag.Back
		label.BackgroundTransparency = 0.15
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 11
		label.TextColor3 = tag.Color
		label.Text = tag.Text
		label.Visible = false
		label.Parent = column
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = label
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = tag.Color
		stroke.Transparency = 0.55
		stroke.Parent = label
		labels[id] = label
	end

	local humanoid: Humanoid? = nil
	local function refresh()
		local hurt = humanoid ~= nil and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth - 0.5
		local here = player:GetAttribute("Outpost") == true and player:GetAttribute("RiftRun") == nil
		local shown = {}
		for _, id in
			FrontierHud.tags(
				player:GetAttribute("FrontierAlone") == true,
				hurt,
				here,
				player:GetAttribute("AtBase") == true,
				player:GetAttribute("LobbyMend") == true
			)
		do
			shown[id] = true
		end
		for id, label in labels do
			label.Visible = shown[id] == true
		end
	end
	for _, name in { "FrontierAlone", "AtBase", "LobbyMend", "Outpost", "RiftRun" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	local healthWatch: RBXScriptConnection? = nil
	local function watch(character: Model)
		if healthWatch then
			healthWatch:Disconnect()
		end
		humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			healthWatch = humanoid.HealthChanged:Connect(refresh)
		end
		refresh()
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
	refresh()
end

-- Arrows at the screen's edge for rifts coming for you, off screen.
local function arrows(player: Player, gui: ScreenGui)
	local watched: { [BasePart]: TextLabel } = {}
	local stepping: RBXScriptConnection? = nil
	local function arrow(): TextLabel
		local text = Instance.new("TextLabel")
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Size = UDim2.fromOffset(34, 34)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextSize = 28
		text.Text = "➤"
		text.TextColor3 = Frontier.RiftColor:Lerp(Color3.new(1, 1, 1), 0.2)
		text.TextStrokeTransparency = 0.3
		text.Visible = false
		text.Parent = gui
		return text
	end
	local function step()
		local camera = workspace.CurrentCamera
		local now = workspace:GetServerTimeNow()
		for anchor, label in watched do
			local done = not anchor.Parent or now > (anchor:GetAttribute("HopAt") or 0) + 1.5
			if done or not camera then
				label:Destroy()
				watched[anchor] = nil
				continue
			end
			-- (This screen sits below Roblox's top bar: its points are the
			-- viewport's, less the bar.)
			local point, onScreen = camera:WorldToViewportPoint(anchor.Position)
			local inset = GuiService:GetGuiInset()
			local size = camera.ViewportSize - Vector2.new(0, inset.Y)
			local y = point.Y - inset.Y
			local inside = onScreen and point.X >= 0 and y >= 0 and point.X <= size.X and y <= size.Y
			label.Visible = not inside
			if not inside then
				local flat = Vector2.new(point.X, y)
				if point.Z < 0 then
					flat = size - flat -- (behind the camera: mirrored)
				end
				local at, angle = FrontierHud.edge(size, flat, 40)
				label.Position = UDim2.fromOffset(at.X, at.Y)
				label.Rotation = math.deg(angle)
			end
		end
		if next(watched) == nil and stepping then
			stepping:Disconnect()
			stepping = nil
		end
	end
	local function track(anchor: Instance)
		-- (Its attributes arrive with it; a critter slipping back has no Prey.)
		if not anchor:IsA("BasePart") or anchor:GetAttribute("Dormant") then
			return
		end
		if anchor:GetAttribute("Prey") ~= player.UserId or watched[anchor] or not anchor.Parent then
			return
		end
		watched[anchor] = arrow()
		if not stepping then
			stepping = RunService.RenderStepped:Connect(step)
		end
	end
	task.spawn(function()
		local rifts = workspace:WaitForChild("Rifts", 120)
		if not rifts then
			return
		end
		rifts.ChildAdded:Connect(track)
	end)
end

-- An arrow at the screen's edge toward the nearest wild kaiju off screen
-- (within Sighting studs, in the Outpost, not in a fight), with how far.
local function sightings(player: Player, gui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(70, 46)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local arrow = Instance.new("TextLabel")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.32)
	arrow.Size = UDim2.fromOffset(26, 26)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextSize = 22
	arrow.Text = "➤"
	arrow.TextStrokeTransparency = 0.3
	arrow.Parent = holder
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.62)
	label.Size = UDim2.fromOffset(90, 14)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextStrokeTransparency = 0.35
	label.Parent = holder
	local target: BasePart? = nil
	local guard = false
	local scanIn = 0
	RunService.RenderStepped:Connect(function(dt)
		scanIn -= dt
		local character = player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local busy = player:GetAttribute("Outpost") ~= true or player:GetAttribute("CombatSession") ~= nil
		if scanIn <= 0 then
			scanIn = 0.25
			target = nil
			local enemies = workspace:FindFirstChild("Enemies")
			if me and not busy and enemies then
				local spots, parts = {}, {}
				for _, model in enemies:GetChildren() do
					local root = model:GetAttribute("KaijuWild") and (model :: Model).PrimaryPart
					if root then
						table.insert(spots, root.Position)
						table.insert(parts, root)
					end
				end
				local index = FrontierHud.nearest(spots, me.Position, FrontierHud.Sighting)
				target = if index then parts[index] else nil
				guard = target ~= nil and (target.Parent :: Instance):GetAttribute("KaijuGuardian") == true
			end
		end
		local camera = workspace.CurrentCamera
		if not target or not target.Parent or not me or busy or not camera then
			holder.Visible = false
			return
		end
		local point, onScreen = camera:WorldToViewportPoint(target.Position)
		local inset = GuiService:GetGuiInset()
		local size = camera.ViewportSize - Vector2.new(0, inset.Y)
		local y = point.Y - inset.Y
		local inside = onScreen and point.X >= 0 and y >= 0 and point.X <= size.X and y <= size.Y
		holder.Visible = not inside
		if inside then
			return
		end
		local flat = Vector2.new(point.X, y)
		if point.Z < 0 then
			flat = size - flat -- (behind the camera: mirrored)
		end
		local at, angle = FrontierHud.edge(size, flat, 64)
		holder.Position = UDim2.fromOffset(at.X, at.Y)
		arrow.Rotation = math.deg(angle)
		local color = if guard then Frontier.Bands.Guarded.Color else WILD
		arrow.TextColor3, label.TextColor3 = color, color
		local studs = Vector2.new(target.Position.X - me.Position.X, target.Position.Z - me.Position.Z).Magnitude
		label.Text = string.format("%s %d", if guard then "GUARDIAN" else "KAIJU", math.floor(studs + 0.5))
	end)
end

function FrontierHud.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "FrontierBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")
	biomeLight(player)
	chargedTag(player, gui)
	statusTags(player, gui)
	arrows(player, gui)
	sightings(player, gui)
end

return FrontierHud
