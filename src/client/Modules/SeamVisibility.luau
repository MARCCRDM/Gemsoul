--[[
	Skin seams and glowing edges are SelectionBoxes (tagged SkinSeam by the
	server, Equipment.outline). Roblox draws a SelectionBox even round a part
	that is hidden, so without this the outlines of your own suit filled the
	first-person view (your helmet and chest plates are hidden round the
	camera, their outlines weren't), and a staged or stowed piece left its
	outline floating in the air. Each box shows only while its part does.
	Purely local.

	Seams can be alive, too: a box with a SeamFx attribute (set from its
	skin's palette, Cosmetics) is recoloured every frame while it shows,
	between its SeamA (the seam colour, set on every box) and SeamB (the
	glow):
	  Pulse    breathes, bright to dim and back
	  Shift    swings from one colour to the other
	  Flicker  crackles like a live wire: the glow, with sharp flashes
	  Rainbow  runs through every hue

	  SeamVisibility.shows(box)  pure: whether the box's part is showing
	  SeamVisibility.fxColor(fx, a, b, t, seed)  pure: an animated seam's colour
	  SeamVisibility.start()
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)

local SeamVisibility = {}

function SeamVisibility.shows(box: SelectionBox): boolean
	local part = box.Adornee
	return part ~= nil and part:IsA("BasePart") and part.Transparency < 0.99 and part.LocalTransparencyModifier < 0.99
end

local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)

type Fx = { Fx: string, A: Color3, B: Color3, Seed: number }

-- The colour of an animated seam at time `t` (seconds). `seed` staggers
-- boxes a little, so a suit's seams don't all flash in lockstep.
function SeamVisibility.fxColor(fx: string, a: Color3, b: Color3, t: number, seed: number): Color3
	if fx == "Pulse" then
		local k = 0.5 + 0.5 * math.sin(t * math.pi * 2 / 1.8)
		return a:Lerp(BLACK, 0.5 * (1 - k)):Lerp(WHITE, 0.15 * k)
	elseif fx == "Shift" then
		return a:Lerp(b, 0.5 + 0.5 * math.sin(t * math.pi * 2 / 2.6 + seed * 0.4))
	elseif fx == "Flicker" then
		local n = math.noise(t * 9, seed * 7.3, 0.5)
		if n > 0.32 then
			return b:Lerp(WHITE, 0.5) -- a flash
		end
		return a:Lerp(BLACK, math.clamp(-n, 0, 0.4))
	elseif fx == "Rainbow" then
		local _, s, v = a:ToHSV()
		return Color3.fromHSV((t * 0.18 + seed * 0.03) % 1, math.max(s, 0.65), math.max(v, 0.9))
	end
	return a
end

function SeamVisibility.start()
	local boxes: { [SelectionBox]: boolean } = {}
	-- Animated boxes, read once (and again only when a restyle changes them).
	local effects: { [SelectionBox]: Fx } = {}
	local links: { [SelectionBox]: RBXScriptConnection } = {}
	local count = 0
	local function read(box: SelectionBox)
		local fx, a, b = box:GetAttribute("SeamFx"), box:GetAttribute("SeamA"), box:GetAttribute("SeamB")
		if typeof(fx) == "string" and typeof(a) == "Color3" then
			count += 1
			effects[box] = { Fx = fx, A = a, B = if typeof(b) == "Color3" then b else a, Seed = count % 17 }
		elseif effects[box] then
			-- Restyled to a still seam: back to its own colour (SeamA).
			effects[box] = nil
			if typeof(a) == "Color3" then
				box.Color3 = a
			end
		end
	end
	local function add(instance: Instance)
		if instance:IsA("SelectionBox") and not boxes[instance] then
			boxes[instance] = true
			read(instance)
			links[instance] = instance.AttributeChanged:Connect(function()
				read(instance)
			end)
		end
	end
	for _, instance in CollectionService:GetTagged(Tags.SkinSeam) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.SkinSeam):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.SkinSeam):Connect(function(instance)
		local box = instance :: SelectionBox
		boxes[box], effects[box] = nil, nil
		if links[box] then
			links[box]:Disconnect()
			links[box] = nil
		end
	end)
	-- Just after the camera (and the first-person view, which hides your own
	-- parts at Camera + 3), so a box never shows for a frame round the camera.
	RunService:BindToRenderStep("SkinSeams", Enum.RenderPriority.Camera.Value + 4, function()
		local t = os.clock()
		for box in boxes do
			local shows = SeamVisibility.shows(box)
			if box.Visible ~= shows then
				box.Visible = shows
			end
			local effect = shows and effects[box]
			if effect then
				box.Color3 = SeamVisibility.fxColor(effect.Fx, effect.A, effect.B, t, effect.Seed)
			end
		end
	end)
end

return SeamVisibility
