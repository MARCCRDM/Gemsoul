--[[
	CosmeticView: a skin, suit or pickaxe as it really looks, in 3D, for the
	Shop and the Wardrobe.

	The server dresses a mannequin once per cosmetic and keeps the parts in
	ReplicatedStorage.CosmeticPreviews[<id>] (Equipment.cosmeticPreview).
	CosmeticView.attach puts that model in a ViewportFrame over a drawn
	placeholder, asking the server for any it hasn't built yet (in batches),
	and fills in the moment the model arrives. Big views turn slowly.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local GemClient = require(script.Parent.GemClient)

local CosmeticView = {}

local asked: { [string]: boolean } = {}
local pending: { string } = {}
local flushing = false

-- Asks for every id requested this frame in one go.
local function request(id: string)
	if asked[id] then
		return
	end
	asked[id] = true
	table.insert(pending, id)
	if flushing then
		return
	end
	flushing = true
	task.defer(function()
		local batch = pending
		pending = {}
		flushing = false
		local result = GemClient.request("CosmeticPreviews", batch)
		if not result.Ok then
			-- Let a later tile ask again.
			for _, id in batch do
				asked[id] = nil
			end
		end
	end)
end

local function frame(view: ViewportFrame, source: Instance, kind: string, spin: boolean): RBXScriptConnection?
	local world = Instance.new("WorldModel")
	local model = Instance.new("Model")
	for _, part in source:GetChildren() do
		if part:IsA("BasePart") then
			part:Clone().Parent = model
		end
	end
	model.Parent = world
	world.Parent = view
	local box, size = model:GetBoundingBox()
	local center = box.Position
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	-- From the front, turned a little: a suit faces you, and a blade shows
	-- its flat (it's built across the miner's front). A pickaxe is seen
	-- side on, head and spike in profile (Equipment builds it so).
	local yaw = if kind == "Suit" then math.rad(200) elseif kind == "Pick" then math.rad(215) else math.rad(195)
	local pitch = math.rad(if kind == "Suit" then 8 elseif kind == "Pick" then 10 else 4)
	local reach = if kind == "Suit" then 1.8 elseif kind == "Pick" then 1.55 else 2.0
	local distance = math.max(size.X, size.Y, size.Z) * reach + 0.3
	local function place(angle: number)
		local offset =
			Vector3.new(math.sin(angle) * math.cos(pitch), math.sin(pitch), math.cos(angle) * math.cos(pitch))
		camera.CFrame = CFrame.lookAt(center + offset * distance, center)
	end
	place(yaw)
	if not spin then
		return nil
	end
	local started = os.clock()
	return RunService.RenderStepped:Connect(function()
		place(yaw + math.sin((os.clock() - started) * 0.6) * 0.55)
	end)
end

-- Puts cosmetic `id` in 3D over `root` (filling it); the drawn art already in
-- `root` stays as the placeholder until the model is ready. Returns false
-- for cosmetics that have no 3D look (trims, backs, titles).
function CosmeticView.attach(root: GuiObject, id: string, spin: boolean?): boolean
	local cosmetic = Cosmetics.get(id)
	if not cosmetic or not Cosmetics.isMinerKind(cosmetic.Kind) then
		return false
	end
	local view = Instance.new("ViewportFrame")
	view.Name = "CosmeticView"
	view:SetAttribute("Cosmetic", id)
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = Color3.fromRGB(150, 156, 172)
	view.LightColor = Color3.fromRGB(255, 246, 232)
	view.LightDirection = Vector3.new(-0.4, -1, -0.6)
	view.ZIndex = root.ZIndex + 5
	view.Visible = false
	view.Parent = root
	local connections: { RBXScriptConnection } = {}
	local function cleanup()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
	local filled = false
	local function fill(source: Instance?)
		if filled or not source or not view.Parent then
			return
		end
		filled = true
		cleanup()
		local turning = frame(view, source, cosmetic.Kind, spin == true)
		if turning then
			table.insert(connections, turning)
		end
		-- Swap the drawn placeholder for the real thing.
		for _, child in root:GetChildren() do
			if child ~= view and child:IsA("GuiObject") then
				child.Visible = false
			end
		end
		view.Visible = true
	end
	-- Its parts can replicate after the folder itself: wait for all of them
	-- (the server counts them in its Parts attribute) before framing it.
	local function whenWhole(folder: Instance)
		local function check()
			local parts = folder:GetAttribute("Parts")
			if #folder:GetChildren() >= (if type(parts) == "number" then parts else 1) then
				fill(folder)
			end
		end
		table.insert(connections, folder.ChildAdded:Connect(check))
		table.insert(connections, folder:GetAttributeChangedSignal("Parts"):Connect(check))
		check()
	end
	local function watch(store: Instance)
		local ready = store:FindFirstChild(id)
		if ready then
			whenWhole(ready)
			return
		end
		table.insert(
			connections,
			store.ChildAdded:Connect(function(child)
				if child.Name == id then
					whenWhole(child)
				end
			end)
		)
		request(id)
	end
	local store = ReplicatedStorage:FindFirstChild("CosmeticPreviews")
	if store then
		watch(store)
	else
		table.insert(
			connections,
			ReplicatedStorage.ChildAdded:Connect(function(child)
				if child.Name == "CosmeticPreviews" then
					watch(child)
				end
			end)
		)
		request(id)
	end
	view.Destroying:Connect(cleanup)
	return true
end

return CosmeticView
