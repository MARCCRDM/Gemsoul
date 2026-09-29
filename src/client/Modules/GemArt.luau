--[[
	Pictures of gems.

	GemArt.icon(parent, gem, size): a flat 2D icon for lists. Rough stones
	are a cluster of frosted crystal shards on a chunk of rock; cut stones
	are a bright faceted diamond. Every rough stone's cluster is shaped by
	its id, so no two look the same.

	GemArt.model(gem): a small 3D model for a ViewportFrame (the detail view).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)

local GemArt = {}

local PRISM = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 255, 90)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(80, 200, 255)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 80, 220)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 255, 90)),
})

-- A stable number from a gem id, so its random shape never changes.
local function seedOf(gem): number
	local seed = 7
	for i = 1, #gem.Id do
		seed = (seed * 31 + string.byte(gem.Id, i)) % 2147483647
	end
	return seed
end

local function darker(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, v * (1 - amount))
end

local function lighter(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s * (1 - amount * 0.6), math.min(1, v + amount))
end

-- Colours a GUI object with the gem's colour: solid, two-tone or prismatic.
local function paint(object: GuiObject, shade, rotation: number, shading: number)
	object.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	if shade.Prismatic then
		gradient.Color = PRISM
		TweenService:Create(gradient, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
			Rotation = rotation + 360,
		}):Play()
	elseif shade.Color2 then
		gradient.Color = ColorSequence.new(shade.Color, shade.Color2)
	else
		gradient.Color = ColorSequence.new(lighter(shade.Color, shading), darker(shade.Color, shading))
	end
	gradient.Parent = object
end

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

local function corner(object: GuiObject, scale: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = object
end

local function roughIcon(holder: Frame, gem, shade)
	local rng = Random.new(seedOf(gem))
	-- Chunk of host rock.
	local rock = frame(holder, {
		Position = UDim2.fromScale(0.5, 0.78),
		Size = UDim2.fromScale(0.86, 0.3),
		BackgroundColor3 = Color3.fromRGB(70, 66, 70),
		Rotation = rng:NextNumber(-6, 6),
		ZIndex = 1,
	})
	corner(rock, 0.4)
	local rockShade = Instance.new("UIGradient")
	rockShade.Color = ColorSequence.new(Color3.fromRGB(150, 146, 150), Color3.fromRGB(60, 56, 60))
	rockShade.Rotation = 90
	rockShade.Parent = rock

	-- Crystal shards growing out of the rock, tallest in the middle.
	local count = rng:NextInteger(3, 5)
	for i = 1, count do
		local t = (i - 0.5) / count
		local lean = (t - 0.5) * 70 + rng:NextNumber(-10, 10)
		local height = 0.62 - math.abs(t - 0.5) * 0.5 + rng:NextNumber(-0.06, 0.06)
		local width = rng:NextNumber(0.14, 0.2)
		local shard = frame(holder, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.24 + t * 0.52, 0.74),
			Size = UDim2.fromScale(width, height),
			Rotation = lean,
			ZIndex = 2,
		})
		corner(shard, 0.25)
		paint(shard, shade, 90 + lean, 0.35)
		-- A frosted highlight down one face of the shard.
		local face = frame(shard, {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0.12, 0.08),
			Size = UDim2.fromScale(0.3, 0.8),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.6,
			ZIndex = 3,
		})
		corner(face, 0.5)
	end
end

local function cutIcon(holder: Frame, gem, shade)
	local body = frame(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Rotation = 45,
		ZIndex = 2,
	})
	corner(body, 0.12)
	paint(body, shade, 0, 0.3)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.Parent = body
	-- The table facet and a crown facet catching the light.
	local tableFacet = frame(body, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		ZIndex = 3,
	})
	corner(tableFacet, 0.1)
	frame(body, {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0.08, 0.08),
		Size = UDim2.fromScale(0.3, 0.14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.35,
		ZIndex = 3,
	})
	-- A four-point twinkle on the upper facet; Gem Mint stones get a bigger one.
	local sparkle = if (gem.Cut or 0) >= 10 then 0.26 else 0.16
	for _, rotation in { 0, 90 } do
		local ray = frame(holder, {
			Position = UDim2.fromScale(0.66, 0.3),
			Size = UDim2.fromScale(sparkle, 0.03),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Rotation = rotation,
			ZIndex = 4,
		})
		corner(ray, 0.5)
		local taper = Instance.new("UIGradient")
		taper.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		taper.Parent = ray
	end
end

-- A square gem icon filling `size` pixels (or scale 1 if size is nil).
function GemArt.icon(parent: Instance, gem, size: number?): Frame
	local shade = GemConfig.shade(gem)
	local holder = Instance.new("Frame")
	holder.Name = "GemIcon"
	holder.BackgroundTransparency = 1
	holder.Size = if size then UDim2.fromOffset(size, size) else UDim2.fromScale(1, 1)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = holder
	holder.Parent = parent

	-- Soft glow behind the stone.
	local glow = frame(holder, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.95, 0.95),
		BackgroundColor3 = if shade.Prismatic then Color3.fromRGB(200, 120, 255) else shade.Color,
		BackgroundTransparency = 0.8,
		ZIndex = 0,
	})
	corner(glow, 0.5)

	if gem.Cut then
		cutIcon(holder, gem, shade)
	else
		roughIcon(holder, gem, shade)
	end
	return holder
end

local function part(
	model: Model,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	transparency: number?
)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.Parent = model
	return p
end

--[[
	A 3D model of the gem, centred near the origin and about 3 studs tall,
	scaled a little by the stone's size grade. Rough stones are a unique
	crystal cluster on rock; cut stones are a faceted gem with a glowing core.
]]
function GemArt.model(gem): Model
	local shade = GemConfig.shade(gem)
	local color = if shade.Prismatic then Color3.fromRGB(120, 255, 200) else shade.Color
	local model = Instance.new("Model")
	local scale = 0.8 + gem.Size * 0.04

	if gem.Cut then
		-- A cube balanced on its corner reads as a faceted gem as it spins.
		local tilt = CFrame.Angles(math.rad(45), 0, math.rad(35.26))
		part(model, Vector3.one * 2 * scale, CFrame.new(0, 1.3, 0) * tilt, color, Enum.Material.Glass, 0.15).Reflectance =
			0.25
		part(
			model,
			Vector3.one * 1.3 * scale,
			CFrame.new(0, 1.3, 0) * tilt * CFrame.Angles(0, math.rad(45), 0),
			lighter(color, 0.2),
			Enum.Material.Glass,
			0.35
		)
		part(model, Vector3.one * 0.6 * scale, CFrame.new(0, 1.3, 0) * tilt, color, Enum.Material.Neon)
		if shade.Color2 then
			part(model, Vector3.one * 0.9 * scale, CFrame.new(0, 1.3, 0), shade.Color2, Enum.Material.Neon, 0.3)
		end
	else
		local rng = Random.new(seedOf(gem))
		part(
			model,
			Vector3.new(2.6, 1, 2) * scale,
			CFrame.new(0, 0.1, 0) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, 6), 0),
			Color3.fromRGB(80, 76, 80),
			Enum.Material.Slate
		)
		local count = rng:NextInteger(4, 6)
		for i = 1, count do
			local angle = i / count * 2 * math.pi + rng:NextNumber(-0.4, 0.4)
			local lean = rng:NextNumber(10, 35)
			local height = rng:NextNumber(1.2, 2.4) * scale
			local width = rng:NextNumber(0.45, 0.7) * scale
			local base = CFrame.new(math.cos(angle) * 0.5 * scale, 0.5, math.sin(angle) * 0.4 * scale)
			local shardColor = if shade.Color2 and i % 2 == 0 then shade.Color2 else color
			part(
				model,
				Vector3.new(width, height, width),
				base
					* CFrame.Angles(0, -angle, 0)
					* CFrame.Angles(0, 0, math.rad(-lean))
					* CFrame.new(0, height / 2, 0)
					* CFrame.Angles(0, math.rad(45), 0),
				shardColor,
				Enum.Material.Glass,
				0.1
			)
		end
		-- The tallest centre shard, with a faint glow at its heart.
		part(
			model,
			Vector3.new(0.75, 2.8, 0.75) * scale,
			CFrame.new(0, 0.5 + 1.4 * scale, 0) * CFrame.Angles(0, math.rad(45), 0),
			color,
			Enum.Material.Glass,
			0.1
		)
		part(
			model,
			Vector3.new(0.3, 1.6, 0.3) * scale,
			CFrame.new(0, 0.5 + 1.2 * scale, 0),
			color,
			Enum.Material.Neon,
			0.4
		)
	end
	return model
end

return GemArt
