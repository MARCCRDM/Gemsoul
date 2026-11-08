--[[
	A ranked league's crest (Shared.Leagues): the crest image cut from its
	sheet once that's uploaded (Leagues.Images.Sheet); until then a drawn
	stand-in, a diamond in the league's colour with its tier under it.

	  LeagueBadge.new(parent, size) -> badge   a square Frame, `size` px
	  badge:set(step)                          show this step (1-16), nil hides
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leagues = require(ReplicatedStorage.Shared.Leagues)

local LeagueBadge = {}
LeagueBadge.__index = LeagueBadge

local INK = Color3.fromRGB(8, 10, 16)

function LeagueBadge.new(parent: Instance, size: number)
	local holder = Instance.new("Frame")
	holder.Name = "LeagueBadge"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent
	local image = Instance.new("ImageLabel")
	image.Name = "Crest"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = holder
	-- (the stand-in: a diamond with an inner diamond, the tier under it)
	local drawn = Instance.new("Frame")
	drawn.Name = "Drawn"
	drawn.BackgroundTransparency = 1
	drawn.Size = UDim2.fromScale(1, 1)
	drawn.Parent = holder
	local outer = Instance.new("Frame")
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.Position = UDim2.fromScale(0.5, 0.44)
	outer.Size = UDim2.fromScale(0.58, 0.58)
	outer.Rotation = 45
	outer.BorderSizePixel = 0
	outer.Parent = drawn
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = outer
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.6, 0.6)
	inner.BackgroundColor3 = INK
	inner.BorderSizePixel = 0
	inner.Parent = outer
	local gem = Instance.new("Frame")
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromScale(0.5, 0.5)
	gem.BorderSizePixel = 0
	gem.Parent = inner
	local tier = Instance.new("TextLabel")
	tier.AnchorPoint = Vector2.new(0.5, 1)
	tier.Position = UDim2.fromScale(0.5, 1)
	tier.Size = UDim2.fromScale(0.7, 0.22)
	tier.BackgroundColor3 = INK
	tier.BorderSizePixel = 0
	tier.Font = Enum.Font.GothamBlack
	tier.TextScaled = true
	tier.TextColor3 = Color3.new(1, 1, 1)
	tier.Parent = drawn
	local self = setmetatable({
		Frame = holder,
		Image = image,
		Drawn = drawn,
		Outer = outer,
		Gem = gem,
		Tier = tier,
	}, LeagueBadge)
	return self
end

function LeagueBadge:set(step: number?)
	self.Frame.Visible = step ~= nil
	if not step then
		return
	end
	local info = Leagues.info(step)
	local sheet = Leagues.Images.Sheet
	if sheet and sheet ~= 0 then
		local offset, size = Leagues.crest(info.Step)
		self.Image.Image = "rbxassetid://" .. sheet
		self.Image.ImageRectOffset, self.Image.ImageRectSize = offset, size
		self.Image.Visible, self.Drawn.Visible = true, false
	else
		self.Image.Visible, self.Drawn.Visible = false, true
		self.Outer.BackgroundColor3 = info.Color
		self.Gem.BackgroundColor3 = info.Color:Lerp(Color3.new(1, 1, 1), 0.35)
		self.Tier.Visible = info.Tier ~= nil -- (Titan has no tiers)
		self.Tier.Text = info.Tier or ""
		self.Tier.TextColor3 = info.Color:Lerp(Color3.new(1, 1, 1), 0.5)
	end
end

return LeagueBadge
