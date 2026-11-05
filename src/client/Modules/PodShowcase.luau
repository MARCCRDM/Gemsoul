--[[
	The kaiju on each pod's showcase pedestal (Server.PodServer sets the
	yard's Showcase attributes; Shared.PodStyle: the owner picks it in MY
	POD): this client builds each one near it, small enough to stand on the
	pedestal, turning slowly, its name and level over it. Built here, not on
	the server: the pods' parts are at their budget, as the Kennel's are
	(Client.KennelLife).

	  PodShowcase.step(dt)   each frame while you're in the Outpost
	  PodShowcase.clear()    all of them gone (you've left)
	  PodShowcase.fit(height, tall) -> scale   how much to scale a kaiju
	                         `height` tall to stand `tall`
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)

local PodShowcase = {}
PodShowcase.Reach = 180 -- studs: built within this of the camera
PodShowcase.Tall = 3.4 -- studs: how tall one stands on its pedestal
PodShowcase.Spin = 0.5 -- radians a second
PodShowcase.Every = 0.5 -- seconds between looks round for pods

local shown: { [Instance]: { Model: Model, Key: string, Offset: CFrame, Yaw: number } } = {}
local pads: Instance? = nil
local since = math.huge
local yaw = 0

function PodShowcase.fit(height: number, tall: number): number
	return if height > 0.01 then tall / height else 1
end

local function drop(yard: Instance)
	local entry = shown[yard]
	shown[yard] = nil
	if entry then
		entry.Model:Destroy()
	end
end

function PodShowcase.clear()
	for yard in shown do
		drop(yard)
	end
end

local function build(yard: Instance, species: string, element: string): any
	local ok, model = pcall(KaijuModels.build, species, element)
	if not ok or not model then
		return nil
	end
	local _, size = model:GetBoundingBox()
	pcall(KaijuModels.scale, model, PodShowcase.fit(size.Y, PodShowcase.Tall) * model:GetScale())
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
			p.CastShadow = false
		end
	end
	local box, scaled = model:GetBoundingBox()
	-- (from its pivot to the middle of its feet)
	local feet = model:GetPivot():ToObjectSpace(box * CFrame.new(0, -scaled.Y / 2, 0))
	local plate = Instance.new("BillboardGui")
	plate.Name = "ShowcaseName"
	plate.Size = UDim2.fromOffset(180, 26)
	plate.StudsOffsetWorldSpace = Vector3.new(0, scaled.Y + 1.2, 0)
	plate.MaxDistance = 70
	plate.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	local name, level = yard:GetAttribute("ShowcaseName"), yard:GetAttribute("ShowcaseLevel")
	label.Text = string.upper(tostring(name or species)) .. (if type(level) == "number" then "  ·  LV " .. level else "")
	label.Parent = plate
	plate.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	plate.Parent = model
	model.Parent = yard
	return { Model = model, Offset = feet:Inverse() }
end

function PodShowcase.step(dt: number)
	yaw = (yaw + dt * PodShowcase.Spin) % (math.pi * 2)
	since += dt
	if since >= PodShowcase.Every then
		since = 0
		if not pads or not pads.Parent then
			local settlement = workspace:FindFirstChild("Settlement", true)
			pads = settlement and settlement:FindFirstChild("Pads")
		end
		local camera = workspace.CurrentCamera
		local seen = {}
		for _, pad in if pads then pads:GetChildren() else {} do
			local yard = pad:FindFirstChild("Display")
			local stand = yard and yard:FindFirstChild("Showcase")
			local species, element = yard and yard:GetAttribute("ShowcaseSpecies"), yard and yard:GetAttribute("ShowcaseElement")
			if yard and stand and type(species) == "string" and camera
				and (stand.Position - camera.CFrame.Position).Magnitude < PodShowcase.Reach
			then
				seen[yard] = true
				local key = species .. "|" .. tostring(element) .. "|" .. tostring(yard:GetAttribute("ShowcaseName"))
				local entry = shown[yard]
				if not entry or entry.Key ~= key or not entry.Model.Parent then
					drop(yard)
					local made = build(yard, species, if type(element) == "string" then element else "Fire")
					if made then
						made.Key = key
						shown[yard] = made
					end
				end
			end
		end
		for yard in shown do
			if not seen[yard] then
				drop(yard)
			end
		end
	end
	-- (each on top of its pedestal, which rises out of the pad as the pod opens)
	for yard, entry in shown do
		local stand = yard:FindFirstChild("Showcase") :: BasePart?
		if stand and entry.Model.Parent then
			local top = stand.CFrame * CFrame.new(0, stand.Size.Y / 2, 0)
			entry.Model:PivotTo(CFrame.new(top.Position) * CFrame.Angles(0, yaw, 0) * entry.Offset)
		end
	end
end

return PodShowcase
