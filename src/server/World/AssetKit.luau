--[[
	Imported art (ServerStorage.Assets): the Kenney Nature, Space and Space
	Station kits, imported in Studio. World builders ask for a model by name;
	when it's there they get a sized, anchored copy standing where they want
	it, and when it isn't (a test, a place without the kits) they get nil
	and build their own stand-in from parts.

	  AssetKit.has(name) -> boolean
	  AssetKit.pick(names, rng) -> string?          a random one that exists
	  AssetKit.place(parent, name, at, options) -> (Model?, Vector3?)
	      options: Height (studs, scales to it) or Width (the larger of X/Z)
	               or Scale; Yaw (radians); Collide (default false);
	               Sink (studs pushed into the ground, default 0);
	               Color (for parts that came in plain grey)
	      returns the model and its size after scaling
]]
local AssetKit = {}

local cached: Instance? = nil
local looked = false
local function assets(): Instance?
	if not looked then
		looked = true
		pcall(function()
			cached = (game :: any):GetService("ServerStorage"):FindFirstChild("Assets")
		end)
	end
	return cached
end

function AssetKit.has(name: string): boolean
	local folder = assets()
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

function AssetKit.pick(names: { string }, rng: Random): string?
	local found = {}
	for _, name in names do
		if AssetKit.has(name) then
			table.insert(found, name)
		end
	end
	if #found == 0 then
		return nil
	end
	return found[rng:NextInteger(1, #found)]
end

-- Kenney's FBX files can arrive without their colours (plain grey). Name
-- keywords on a part, or else the model's name, give it a sensible one.
local TINTS = {
	{ { "leaf", "leaves", "foliage", "grass", "bush", "plant", "moss" }, Color3.fromRGB(98, 160, 72) },
	{ { "pine", "cone" }, Color3.fromRGB(64, 128, 74) },
	{ { "fall" }, Color3.fromRGB(222, 140, 60) },
	{ { "wood", "bark", "trunk", "log", "stump", "plank" }, Color3.fromRGB(122, 86, 58) },
	{ { "dirt", "soil", "path" }, Color3.fromRGB(150, 112, 80) },
	{ { "flower_red", "mushroom_red" }, Color3.fromRGB(214, 70, 64) },
	{ { "flower_yellow" }, Color3.fromRGB(240, 206, 70) },
	{ { "flower_purple" }, Color3.fromRGB(160, 110, 220) },
	{ { "crystal" }, Color3.fromRGB(170, 120, 255) },
	{ { "stone", "rock", "cliff", "statue", "meteor" }, Color3.fromRGB(176, 164, 146) },
}
local function isPlain(part: BasePart): boolean
	local c = part.Color
	local grey = math.abs(c.R - c.G) < 0.03 and math.abs(c.G - c.B) < 0.03 and c.R > 0.55
	local textured = part:IsA("MeshPart") and (part :: MeshPart).TextureID ~= ""
	return grey and not textured and part:FindFirstChildOfClass("SurfaceAppearance") == nil
end
local function tintFor(name: string): Color3?
	local lower = string.lower(name)
	for _, entry in TINTS do
		for _, word in entry[1] do
			if string.find(lower, word, 1, true) then
				return entry[2]
			end
		end
	end
	return nil
end
local function tint(model: Instance, modelName: string)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and isPlain(part) then
			local color = tintFor(part.Name) or tintFor(modelName)
			if color then
				part.Color = color
			end
		end
	end
end

function AssetKit.place(parent: Instance, name: string, at: CFrame, options: { [string]: any }?): (Model?, Vector3?)
	local folder = assets()
	local source = folder and folder:FindFirstChild(name)
	if not source then
		return nil, nil
	end
	local opts = options or {}
	local model: Model
	if source:IsA("Model") then
		model = source:Clone()
	elseif source:IsA("BasePart") then
		model = Instance.new("Model")
		model.Name = name
		source:Clone().Parent = model
	else
		return nil, nil
	end
	local collide = opts.Collide == true
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = collide
			part.CanTouch = false
			part.CanQuery = collide
		end
	end
	if opts.Color then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and isPlain(part) then
				part.Color = opts.Color
			end
		end
	end
	tint(model, name)
	-- Scale to the size asked for.
	local _, size = model:GetBoundingBox()
	local scale = opts.Scale
	if not scale and opts.Height and size.Y > 0 then
		scale = opts.Height / size.Y
	elseif not scale and opts.Width and math.max(size.X, size.Z) > 0 then
		scale = opts.Width / math.max(size.X, size.Z)
	end
	if scale and math.abs(scale - 1) > 0.01 then
		pcall(function()
			model:ScaleTo(model:GetScale() * scale)
		end)
	end
	-- Stand it on `at`: turned, centred over it, its base on the ground.
	model:PivotTo(CFrame.new(at.Position) * (at - at.Position) * CFrame.Angles(0, opts.Yaw or 0, 0))
	local box, scaled = model:GetBoundingBox()
	local bottom = box.Position.Y - scaled.Y / 2
	local shift = Vector3.new(
		at.Position.X - box.Position.X,
		at.Position.Y - bottom - (opts.Sink or 0),
		at.Position.Z - box.Position.Z
	)
	model:PivotTo(model:GetPivot() + shift)
	model.Parent = parent
	return model, scaled
end

return AssetKit
