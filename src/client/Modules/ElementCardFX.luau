-- Pooled UI accents: never cover text and never allocate while animating.
local FX = {}
local colors = require(game:GetService("ReplicatedStorage").Shared.GemConfig).ElementColors

local function frame(parent, size)
	local item = Instance.new("Frame")
	item.BorderSizePixel = 0
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Size = size
	item.Active = false
	item.Parent = parent
	return item
end

function FX.create(card: GuiObject, gemWell: GuiObject)
	local particles = {}
	for index = 1, 7 do
		local parent = if index <= 3 then card else gemWell
		local dot = frame(parent, UDim2.fromOffset(3, 3))
		dot.ZIndex = 2
		dot.Visible = false
		local corner = Instance.new("UICorner")
		corner.Parent = dot
		local edge = Instance.new("UIStroke")
		edge.Thickness = 1
		edge.Parent = dot
		local spark = frame(dot, UDim2.fromOffset(1, 7))
		spark.Position = UDim2.fromScale(0.5, 0.5)
		spark.Visible = false
		particles[index] = { Dot = dot, Corner = corner, Edge = edge, Spark = spark }
	end
	local glow = Instance.new("UIStroke")
	glow.Thickness = 1.5
	glow.Transparency = 1
	local outline = frame(card, UDim2.new(1, -4, 1, -4))
	outline.Position = UDim2.fromScale(0.5, 0.5)
	outline.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = outline
	glow.Parent = outline
	return { Particles = particles, Glow = glow }
end

function FX.update(effect, element, time)
	local color = colors[element]
	local active = color ~= nil
	effect.Glow.Transparency = if active then 0.80 + math.sin(time * 1.5) * 0.07 else 1
	if active then effect.Glow.Color = color end
	for index, part in effect.Particles do
		part.Dot.Visible = active
		if not active then continue end
		local phase = (time * (if element == "Shock" then 0.65 else 0.22) + index * 0.173) % 1
		local fade = math.sin(phase * math.pi)
		local edge = index <= 3
		local x = if edge then (if index % 2 == 0 then 0.99 else 0.01) else 0.15 + (index - 4) * 0.23
		local y = 0.9 - phase * 0.75
		part.Dot.Position = UDim2.fromScale(x, y)
		part.Dot.BackgroundColor3, part.Edge.Color, part.Spark.BackgroundColor3 = color, color, color
		part.Dot.BackgroundTransparency = 1 - fade * 0.55
		part.Edge.Transparency = 1
		part.Spark.Visible = false
		part.Spark.Size = UDim2.fromOffset(1, 7)
		part.Dot.Rotation = 0
		part.Corner.CornerRadius = UDim.new(1, 0)
		part.Dot.Size = UDim2.fromOffset(2 + fade * 2, 3 + fade * 3)
		if element == "Frost" then
			part.Dot.Size = UDim2.fromOffset(6, 1)
			part.Spark.Visible = true
			part.Spark.BackgroundTransparency = 1 - fade * 0.5
			part.Dot.Rotation = 45
			part.Dot.Position = UDim2.fromScale(x, 0.25 + (index % 3) * 0.22)
		elseif element == "Shock" then
			part.Dot.Size = UDim2.fromOffset(2, 8)
			part.Dot.Rotation = 28
			part.Spark.Visible = true
			part.Spark.Size = UDim2.fromOffset(5, 1)
			part.Spark.BackgroundTransparency = 1 - fade * 0.65
		elseif element == "Poison" then
			local size = 3 + fade * 3
			part.Dot.Size = UDim2.fromOffset(size, size)
			part.Dot.BackgroundTransparency = 0.95
			part.Edge.Transparency = 1 - fade * 0.45
		end
	end
end

return FX
