--[[
	Ability icons: a painted icon for every Rig Maneuver and Gem Surge, cut
	from one sprite sheet (assets/images/ability_icons.png, painted by
	tools/make_ability_icons.py; AbilityIconAtlas says where each one sits).

	Upload the sheet once (Creator Hub, Images) and put its id in ImageId.
	Until then the sockets keep their plain text glyph.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tech = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatTechnology"))
local Atlas = require(script.Parent.AbilityIconAtlas)

local Icons = {}

-- Roblox id of the uploaded sheet (the number from rbxassetid://12345). 0 = not uploaded yet.
Icons.ImageId = 88825646209723

local byName = {}
for id, definition in Tech.Catalog do
	byName[definition.Name] = id
end

-- The catalog id for a definition, an id, or a display name.
function Icons.idOf(definition: any): string?
	if type(definition) == "string" then
		return if Atlas.Index[definition] then definition else byName[definition]
	elseif type(definition) == "table" then
		if definition.Id and Atlas.Index[definition.Id] then
			return definition.Id
		end
		return byName[definition.Name]
	end
	return nil
end

local function cornerOf(target: Instance): UDim?
	for _, holder in { target, target.Parent } do
		local corner = holder and holder:FindFirstChildOfClass("UICorner")
		if corner then
			return corner.CornerRadius
		end
	end
	return nil
end

-- Paints the ability's icon over `target`, filling it, and clears its text
-- glyph. With nothing to show (no ability, or the sheet isn't uploaded yet)
-- the art is removed and the text glyph stays. Returns whether art is shown.
function Icons.apply(target: GuiObject, definition: any, _color: Color3?): boolean
	if Icons.ImageId == 0 then
		return false
	end
	local art = target:FindFirstChild("AbilityArt") :: ImageLabel?
	local id = Icons.idOf(definition)
	local index = id and Atlas.Index[id]
	if index == nil then
		if art then
			art:Destroy()
		end
		return false
	end
	if target:IsA("TextLabel") or target:IsA("TextButton") then
		(target :: TextLabel).Text = ""
	end
	if not art then
		local made = Instance.new("ImageLabel")
		made.Name = "AbilityArt"
		made.BackgroundTransparency = 1
		made.AnchorPoint = Vector2.new(0.5, 0.5)
		made.Position = UDim2.fromScale(0.5, 0.5)
		made.Size = UDim2.fromScale(1, 1)
		made.ZIndex = target.ZIndex
		made.Image = "rbxassetid://" .. Icons.ImageId
		made.ImageRectSize = Vector2.new(Atlas.Cell, Atlas.Cell)
		local radius = cornerOf(target)
		if radius then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = radius
			corner.Parent = made
		end
		made.Parent = target
		art = made
	end
	local column = index % Atlas.Columns
	local row = index // Atlas.Columns
	art.ImageRectOffset = Vector2.new(column * Atlas.Cell, row * Atlas.Cell)
	return true
end

-- Greys an icon out (locked or unaffordable) or brings it back.
function Icons.dim(target: GuiObject, dimmed: boolean)
	if Icons.ImageId == 0 then
		return
	end
	local art = target:FindFirstChild("AbilityArt") :: ImageLabel?
	if art then
		art.ImageColor3 = if dimmed then Color3.fromRGB(110, 110, 120) else Color3.new(1, 1, 1)
	end
end

return Icons
