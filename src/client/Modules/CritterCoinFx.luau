-- Server-paid rewards: local visual coins cannot grant currency or be stolen.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local CritterFx = require(script.Parent.CritterFx)

local CoinFx = {}
local active = 0
local gold = Color3.fromRGB(255, 200, 55)

-- Each coin lands with sparks; the final coin adds a short expanding pulse.
local function collect(at: Vector3, final: boolean)
	local flash = Instance.new("Part")
	flash.Name = "CoinCollect"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 0.3
	flash.Color = Color3.fromRGB(255, 230, 130)
	flash.Material = Enum.Material.Neon
	flash.Transparency = if final then 0.35 else 1
	flash.Anchored = true
	flash.CanCollide, flash.CanTouch, flash.CanQuery = false, false, false
	flash.CastShadow = false
	flash.CFrame = CFrame.new(at)
	flash.Parent = workspace
	Debris:AddItem(flash, 0.7)
	local attachment = Instance.new("Attachment")
	attachment.Parent = flash
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 250, 210), gold)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.2, 0.5)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.Drag = 7
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-120, 120)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new(0, 1)
	sparks.Parent = attachment
	sparks:Emit(if final then 12 else 5)
	if final then
		TweenService:Create(flash, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * 3.2,
			Transparency = 1,
		}):Play()
	end
end

function CoinFx.play(origin: Vector3, userId: number, amount: number)
	if typeof(origin) ~= "Vector3" or type(userId) ~= "number" or type(amount) ~= "number" then
		return
	end
	local camera = workspace.CurrentCamera
	if active >= 12 or not camera or (camera.CFrame.Position - origin).Magnitude > 160 then
		return
	end
	local recipient = Players:GetPlayerByUserId(userId)
	local root = recipient and recipient.Character and recipient.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local count = math.clamp(math.floor(amount), 0, 5)
	if count == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CritterCoinDrop"
	folder.Parent = workspace
	Debris:AddItem(folder, 3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(excluded, enemies)
	end
	params.FilterDescendantsInstances = excluded
	local coins = {}
	for i = 1, count do
		local angle = i / count * math.pi * 2
		local landing = origin + Vector3.new(math.cos(angle) * 1.6, 0, math.sin(angle) * 1.6)
		local hit = workspace:Raycast(landing + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
		landing = Vector3.new(landing.X, if hit then hit.Position.Y + 0.45 else origin.Y - 1.5, landing.Z)
		local coin = Instance.new("Part")
		coin.Name = "Coin"
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.18, 0.8, 0.8)
		coin.Material = Enum.Material.Metal
		coin.Color = gold
		coin.Anchored = true
		coin.CanCollide, coin.CanTouch, coin.CanQuery = false, false, false
		coin.CastShadow = false
		coin.CFrame = CFrame.new(origin)
		coin.Parent = folder
		local glow = Instance.new("PointLight")
		glow.Color, glow.Brightness, glow.Range = gold, 0.7, 3
		glow.Parent = coin
		table.insert(coins, { Part = coin, Landing = landing })
	end
	active += 1
	local began = os.clock()
	local connection
	local function finish()
		connection:Disconnect()
		folder:Destroy()
		active -= 1
	end
	connection = RunService.Heartbeat:Connect(function()
		if not folder.Parent or not root.Parent or recipient.Character ~= root.Parent then
			finish()
			return
		end
		local elapsed = os.clock() - began
		local target = root.Position + Vector3.new(0, 0.5, 0)
		for i, entry in coins do
			local t = math.max(0, elapsed - (i - 1) * 0.045)
			local position
			if t < 0.4 then
				local p = t / 0.4
				position = origin:Lerp(entry.Landing, p) + Vector3.new(0, math.sin(p * math.pi) * 2.4, 0)
			elseif t < 0.7 then
				position = entry.Landing + Vector3.new(0, math.sin((t - 0.4) / 0.3 * math.pi) * 0.85, 0)
			else
				local p = math.clamp((t - 0.7) / 0.45, 0, 1)
				position = entry.Landing:Lerp(target, p * p) + Vector3.new(0, math.sin(p * math.pi) * 1.2, 0)
				entry.Part.Transparency = if p >= 1 then 1 else 0
				if p >= 1 and not entry.Collected then
					entry.Collected = true
					local glow = entry.Part:FindFirstChildOfClass("PointLight")
					if glow then glow.Enabled = false end
					collect(target, i == count)
				end
			end
			entry.Part.CFrame = CFrame.new(position) * CFrame.Angles(0, t * 11 + i, math.rad(15))
		end
		if elapsed >= 1.15 + (count - 1) * 0.045 then
			if recipient == Players.LocalPlayer then
				CritterFx.words(
					target + Vector3.new(0, 2, 0),
					{ Text = "+" .. count .. " coins", Color = gold, Size = 19 }
				)
			end
			finish()
		end
	end)
end

return CoinFx
