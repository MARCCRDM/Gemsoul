--[[
	The full-screen crate opening. Light rays spin behind the crate, it
	shakes harder and harder, a white flash, then the prize pops out with its
	name, rarity and odds while sparkles fly. Opening several shows the rest
	as a row of cards underneath.

	CrateReveal.play(crate, results)   results from the "OpenCrate" request
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local IronUi = require(script.Parent.IronUi)
local ShopArt = require(script.Parent.ShopArt)

local player = Players.LocalPlayer
local new = IronUi.new
local P = IronUi.Colors

local CrateReveal = {}

local RARITY_NAMES = { Common = "Common", Uncommon = "Uncommon", Rare = "Rare", UltraRare = "Ultra Rare" }

local function tween(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function rarityColor(rarity: string): Color3
	return GemConfig.TierColors[rarity] or Color3.fromRGB(230, 230, 230)
end

local function resultName(result): string
	local cosmetic = result.Cosmetic and Cosmetics.get(result.Cosmetic)
	if cosmetic then
		return cosmetic.Name
	end
	return (result.Lines and result.Lines[1]) or "A prize"
end

-- A spinning fan of light rays behind the centre.
local function rays(parent: Instance, color: Color3): Frame
	local fan = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(0, 0),
	}, parent)
	for i = 0, 15 do
		local ray = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(if i % 2 == 0 then 34 else 18, 900),
			Rotation = i * 22.5,
			BackgroundColor3 = if i % 3 == 0 then Color3.new(1, 1, 1) else color,
			BorderSizePixel = 0,
		}, fan)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.55, 0.55),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
		}, ray)
	end
	return fan
end

local function circle(parent: Instance, size: number, color: Color3, transparency: number): Frame
	local c = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
	}, parent)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = c
	return c
end

local function sparkles(parent: Instance, color: Color3)
	for i = 1, 14 do
		local star = new("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(30, 30),
			Text = if i % 2 == 0 then "✦" else "✧",
			TextSize = math.random(18, 34),
			TextColor3 = if i % 3 == 0 then Color3.new(1, 1, 1) else color,
			Font = IronUi.Chunky,
			Rotation = math.random(0, 90),
		}, parent)
		local angle = math.random() * math.pi * 2
		local distance = math.random(140, 300)
		tween(star, 0.9, {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.45, math.sin(angle) * distance),
			TextTransparency = 1,
			Rotation = star.Rotation + 180,
		})
		task.delay(0.95, function()
			star:Destroy()
		end)
	end
end

local function miniCard(parent: Instance, result, order: number)
	local color = rarityColor(result.Rarity)
	local card = ShopArt.rarityTile(parent, result.Rarity, 92)
	card.LayoutOrder = order
	local scale = new("UIScale", { Scale = 0 }, card)
	ShopArt.icon(card, result.Kind or "Cosmetic", result.Cosmetic, 56).Position = UDim2.fromScale(0.5, 0.42)
	local label = IronUi.text(card, resultName(result), 11, Color3.new(1, 1, 1), IronUi.Chunky)
	label.AnchorPoint = Vector2.new(0, 1)
	label.Position = UDim2.new(0, 4, 1, -4)
	label.Size = UDim2.new(1, -8, 0, 0)
	label.TextXAlignment = Enum.TextXAlignment.Center
	task.delay(0.08 * order, function()
		tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	return card, color
end

function CrateReveal.play(crate, results: { any })
	if #results == 0 then
		return
	end
	-- The best result gets the big reveal.
	local order = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4 }
	local best = results[1]
	for _, result in results do
		if (order[result.Rarity] or 0) > (order[best.Rarity] or 0) then
			best = result
		end
	end
	local color = rarityColor(best.Rarity)

	local gui = new("ScreenGui", {
		Name = "CrateReveal",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local backdrop = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(10, 6, 20),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, gui)
	tween(backdrop, 0.25, { BackgroundTransparency = 0.25 })

	local fan = rays(gui, crate.Color)
	local spin = RunService.RenderStepped:Connect(function(dt)
		fan.Rotation = (fan.Rotation + dt * 18) % 360
	end)
	local glowOuter = circle(gui, 520, crate.Color, 0.88)
	local glowInner = circle(gui, 320, Color3.new(1, 1, 1), 0.7)

	-- The crate shakes harder and harder...
	local art = ShopArt.crate(gui, 230, crate.Color)
	art.Position = UDim2.fromScale(0.5, 0.45)
	local artScale = new("UIScale", { Scale = 0.2 }, art)
	tween(artScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local skip = false
	backdrop.Activated:Connect(function()
		skip = true
	end)
	task.wait(0.35)
	local shakeTime = 1.4
	local started = os.clock()
	while os.clock() - started < shakeTime and not skip do
		local t = (os.clock() - started) / shakeTime
		art.Rotation = math.sin(os.clock() * (20 + t * 30)) * (3 + t * 12)
		artScale.Scale = 1 + t * 0.15 + math.sin(os.clock() * 30) * 0.02 * t
		glowInner.BackgroundTransparency = 0.7 - t * 0.35
		RunService.RenderStepped:Wait()
	end
	skip = false

	-- ...flash...
	local flash = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, gui)
	tween(flash, 0.12, { BackgroundTransparency = 0 })
	task.wait(0.12)
	art:Destroy()
	for _, ray in fan:GetChildren() do
		if ray:IsA("Frame") and ray.BackgroundColor3 ~= Color3.new(1, 1, 1) then
			ray.BackgroundColor3 = color
		end
	end
	glowOuter.BackgroundColor3 = color
	glowInner.BackgroundTransparency = 0.55
	tween(flash, 0.5, { BackgroundTransparency = 1 })

	-- ...and the prize pops out.
	local prize = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(200, 200),
	}, gui)
	ShopArt.icon(prize, best.Kind or "Cosmetic", best.Cosmetic, 190)
	local prizeScale = new("UIScale", { Scale = 0 }, prize)
	tween(prizeScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	sparkles(gui, color)
	-- A gentle bob afterwards.
	IronUi.animate(prize, function(t)
		prize.Position = UDim2.new(0.5, 0, 0.42, math.sin(t * 2.2) * 6)
	end)

	local info = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.42, 110),
		Size = UDim2.fromOffset(600, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, gui)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = info
	local name = IronUi.title(info, resultName(best), 40)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.LayoutOrder = 1
	local odds =
		IronUi.text(info, string.format("1/%s", tostring(best.Odds or 1)), 18, Color3.new(1, 1, 1), IronUi.Chunky)
	odds.TextXAlignment = Enum.TextXAlignment.Center
	odds.LayoutOrder = 2
	local rarity = IronUi.text(info, RARITY_NAMES[best.Rarity] or best.Rarity, 26, color, IronUi.Chunky)
	rarity.TextXAlignment = Enum.TextXAlignment.Center
	rarity.LayoutOrder = 3
	if best.Lines and #best.Lines > 1 then
		local extra = IronUi.text(info, table.concat(best.Lines, "  •  "), 14, P.Gold, IronUi.Chunky)
		extra.TextXAlignment = Enum.TextXAlignment.Center
		extra.LayoutOrder = 4
	end

	-- Everything else from a multi-open, in a row of cards.
	if #results > 1 then
		local row = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -90),
			Size = UDim2.fromOffset(0, 92),
			AutomaticSize = Enum.AutomaticSize.X,
		}, gui)
		local rowList = Instance.new("UIListLayout")
		rowList.FillDirection = Enum.FillDirection.Horizontal
		rowList.Padding = UDim.new(0, 8)
		rowList.SortOrder = Enum.SortOrder.LayoutOrder
		rowList.Parent = row
		for i, result in results do
			miniCard(row, result, i)
		end
	end

	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		spin:Disconnect()
		gui:Destroy()
	end
	local continue = IronUi.gemButton(gui, "CONTINUE", P.Emerald, finish)
	continue.AnchorPoint = Vector2.new(0.5, 1)
	continue.Position = UDim2.new(0.5, 0, 1, -30)
	backdrop.Activated:Connect(finish)
end

return CrateReveal
