--[[
	A gem raid's critters on screen (Shared.Frontier.Raid; the server's
	KaijuWilds and FrontierServer send these through CombatFx):

	  giggle(position, kind)   a snatcher's evil giggle ("Giggle") or its
	                           cackle ("Cackle", landing a trip, grabbing a
	                           gem): heard where it is (CombatSound), with
	                           "hee hee!" bobbing up over it
	  recovered(from, to, color?, gem?)   a snatched gem dropped: the stone
	                           itself (its look: GemArt) pops out of its
	                           snatcher at `from` and arcs back to whoever it
	                           was taken from at `to`, "GOT IT BACK!"
	  start()                  the stone a snatcher's running off with, held
	                           over its head: the very gem it took, built
	                           from what's on its model (CarriedGem*:
	                           KaijuWilds), turning slowly in its own light

	Words in the world aren't seen by client/Translate, so they're
	translated here (Shared.Lang).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Lang = require(ReplicatedStorage.Shared.Lang)
local CombatSound = require(script.Parent.CombatSound)
local GemArt = require(script.Parent.GemArt)

local CritterFx = {}

CritterFx.Laughs = {
	Giggle = { Text = "hee hee!", Color = Color3.fromRGB(190, 255, 120), Size = 18 },
	Cackle = { Text = "NYEH HEH HEH!", Color = Color3.fromRGB(215, 120, 255), Size = 22 },
}
CritterFx.Back = { Text = "GOT IT BACK!", Color = Color3.fromRGB(255, 214, 90), Size = 20 }
CritterFx.MaxWords = 6 -- on screen at once (a swarm giggling is one din)
CritterFx.Flight = 0.55 -- seconds a dropped gem takes to fly back
CritterFx.Held = { Scale = 0.9, Above = 1.1, Spin = 1.6 } -- a carried stone: its size, how high over the head, turns a second

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "CritterFx"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

local function anchorAt(position: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.1
	part.CFrame = CFrame.new(position)
	part.Parent = fxFolder()
	return part
end

local words = 0
-- Words bobbing up and fading at `position`.
function CritterFx.words(position: Vector3, spec): boolean
	if words >= CritterFx.MaxWords then
		return false
	end
	words += 1
	local anchor = anchorAt(position)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(190, 34)
	board.AlwaysOnTop = true
	board.MaxDistance = 90
	board.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = Lang.translate(spec.Text)
	label.TextSize = spec.Size
	label.TextColor3 = spec.Color
	label.TextStrokeColor3 = Color3.fromRGB(30, 10, 40)
	label.TextStrokeTransparency = 0.15
	label.Rotation = math.random(-12, 12)
	label.Parent = board
	TweenService:Create(board, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(math.random() * 2 - 1, 3.2, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.15, function()
		words -= 1
		anchor:Destroy()
	end)
	return true
end

function CritterFx.giggle(position: Vector3, kind: string?)
	if typeof(position) ~= "Vector3" then
		return
	end
	local laugh = CritterFx.Laughs[kind or "Giggle"] or CritterFx.Laughs.Giggle
	CombatSound.play(if kind == "Cackle" then "Cackle" else "Giggle", position)
	CritterFx.words(position, laugh)
end

-- The stone itself, as GemArt draws it (scaled), lit in its colour: a
-- model with its parts posed from `pivot` (moveTo puts it anywhere).
type Stone = { Model: Model, Parts: { BasePart }, Rest: { CFrame }, Scale: number }
function CritterFx.stone(gem, scale: number): Stone?
	if type(gem) ~= "table" or type(gem.Element) ~= "string" or not GemConfig.Shades[gem.Element] then
		return nil
	end
	local look = {
		Id = tostring(gem.Id or "gem"),
		Element = gem.Element,
		Tier = gem.Tier or "Common",
		Size = tonumber(gem.Size) or 5,
		Clarity = tonumber(gem.Clarity) or 5,
		Cut = tonumber(gem.Cut),
	}
	local ok, model = pcall(GemArt.model, look, false)
	if not ok or not model then
		return nil
	end
	local parts, rest = {}, {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
			part.CastShadow = false
			part.Size *= scale
			table.insert(parts, part)
			local cf = part.CFrame
			table.insert(rest, CFrame.fromMatrix(cf.Position * scale, cf.RightVector, cf.UpVector, -cf.LookVector))
		end
	end
	local glow = Instance.new("PointLight")
	glow.Color = GemConfig.ElementColors[gem.Element] or Color3.new(1, 1, 1)
	glow.Brightness, glow.Range, glow.Shadows = 2.2, 9, false
	glow.Parent = parts[1]
	return { Model = model, Parts = parts, Rest = rest, Scale = scale }
end

-- A stone's parts posed round `at`.
function CritterFx.place(stone: Stone, at: CFrame)
	for i, part in stone.Parts do
		part.CFrame = at * stone.Rest[i]
	end
end

function CritterFx.recovered(from: Vector3, to: Vector3, color: Color3?, gem: any?)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return
	end
	-- The stone itself if we know it; a plain glowing one if not.
	local real = CritterFx.stone(gem, 0.8)
	local stone: BasePart? = nil
	if real then
		real.Model.Parent = fxFolder()
	else
		stone = anchorAt(from)
		local plain = stone :: BasePart
		plain.Transparency = 0
		plain.Material = Enum.Material.Neon
		plain.Color = if typeof(color) == "Color3" then color else Color3.fromRGB(120, 230, 255)
		plain.Size = Vector3.one * 0.9
	end
	CombatSound.play("Combo", from)
	local start = from + Vector3.new(0, 2, 0)
	local finish = to + Vector3.new(0, 1.5, 0)
	local began = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local p = math.clamp((os.clock() - began) / CritterFx.Flight, 0, 1)
		local at = CFrame.new(start:Lerp(finish, p) + Vector3.new(0, math.sin(p * math.pi) * 6, 0))
			* CFrame.Angles(p * 9, p * 6, math.rad(45))
		if real then
			CritterFx.place(real, at)
		elseif stone then
			stone.CFrame = at
		end
		if p >= 1 then
			connection:Disconnect()
			if real then
				real.Model:Destroy()
			elseif stone then
				stone:Destroy()
			end
			CombatSound.play("Heal", to)
			CritterFx.words(to + Vector3.new(0, 2.5, 0), CritterFx.Back)
		end
	end)
end

-- What a snatcher carries, from its model (KaijuWilds' CarriedGem*).
function CritterFx.carriedGem(model: Instance): any?
	local id = model:GetAttribute("CarriedGemId")
	local element = model:GetAttribute("CarriedGemElement")
	if type(id) ~= "string" or type(element) ~= "string" then
		return nil
	end
	return {
		Id = id,
		Element = element,
		Tier = model:GetAttribute("CarryingGem"),
		Size = model:GetAttribute("CarriedGemSize"),
		Clarity = model:GetAttribute("CarriedGemClarity"),
		Cut = model:GetAttribute("CarriedGemCut"),
	}
end

-- The stones over snatchers' heads: built when one picks a gem up, posed
-- every frame over its head (turning slowly), gone when it lets go.
local held: { [Model]: { Stone: Stone, Id: string, Top: number } } = {}
local started = false
function CritterFx.start()
	if started then
		return
	end
	started = true
	local nextScan = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + 0.25
			-- Picked up, put down, or gone.
			local enemies = workspace:FindFirstChild("Enemies")
			for _, model in if enemies then enemies:GetChildren() else {} do
				if model:IsA("Model") then
					local gem = CritterFx.carriedGem(model)
					local entry = held[model]
					if gem and (not entry or entry.Id ~= gem.Id) then
						if entry then
							entry.Stone.Model:Destroy()
						end
						local stone = CritterFx.stone(gem, CritterFx.Held.Scale)
						if stone then
							local top = 2
							local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
							pcall(function()
								local box, size = model:GetBoundingBox()
								top = box.Position.Y + size.Y / 2 - (root :: BasePart).CFrame.Position.Y
							end)
							stone.Model.Parent = fxFolder()
							held[model] = { Stone = stone, Id = gem.Id, Top = top }
						end
					elseif not gem and entry then
						entry.Stone.Model:Destroy()
						held[model] = nil
					end
				end
			end
			for model, entry in held do
				if not model.Parent then
					entry.Stone.Model:Destroy()
					held[model] = nil
				end
			end
		end
		-- Over each one's head, turning.
		for model, entry in held do
			local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if root and root:IsA("BasePart") then
				local p = root.CFrame.Position + Vector3.new(0, entry.Top + CritterFx.Held.Above, 0)
				CritterFx.place(entry.Stone, CFrame.new(p) * CFrame.Angles(0, now * CritterFx.Held.Spin, 0))
			end
		end
	end)
end

CritterFx._held = held

return CritterFx
