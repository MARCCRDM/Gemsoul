-- Mining and enchanting only. Uses real Outpost rocks and their normal click/E/tap input.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GemArt = require(script.Parent.Modules.GemArt)
local Input = game:GetService("UserInputService")
local Tutorial = require(RS.Shared.Tutorial)
local ArmorSignatures = require(RS.Shared.ArmorSignatures)
local GemClient = require(script.Parent.Modules.GemClient)
local LobbyUI = require(script.Parent.Modules.LobbyUI)
local OutpostScene = require(script.Parent.Modules.OutpostScene)
local UiKit = require(script.Parent.Modules.UiKit)
local player = Players.LocalPlayer
if not Tutorial.Enabled then
	return
end
local function current()
	local p = GemClient.Profile
	return p and Tutorial.beat(p)
end
local function new(kind, props, parent)
	local o = Instance.new(kind)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local GOLD = Color3.fromRGB(255, 205, 95)
local function run()
	local runId = GemClient.Profile.Tutorial.Run
	local gui = new(
		"ScreenGui",
		{
			Name = "Tutorial",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			ClipToDeviceSafeArea = false,
			DisplayOrder = 60,
		},
		player.PlayerGui
	)
	-- Four non-interactive masks leave the highlighted target clickable.
	local masks = {}
	for i = 1, 4 do
		masks[i] = new(
			"Frame",
			{ BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Active = false },
			gui
		)
	end
	local frame = new("Frame", { BackgroundTransparency = 1, Visible = false }, gui)
	new("UIStroke", { Color = GOLD, Thickness = 3 }, frame)
	local card = new(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 52),
			Size = UDim2.fromOffset(480, 116),
			BackgroundColor3 = Color3.fromRGB(12, 18, 29),
			ZIndex = 3,
		},
		gui
	)
	UiKit.round(card, 12)
	local title = new(
		"TextLabel",
		{
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -28, 0, 32),
			BackgroundTransparency = 1,
			TextColor3 = GOLD,
			TextSize = 20,
			Font = Enum.Font.GothamBold,
			TextWrapped = true,
			ZIndex = 4,
		},
		card
	)
	local body = new(
		"TextLabel",
		{
			Position = UDim2.fromOffset(14, 46),
			Size = UDim2.new(1, -28, 0, 62),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(235, 242, 250),
			TextSize = 15,
			Font = Enum.Font.Gotham,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 4,
		},
		card
	)
	local nextButton = new(
		"TextButton",
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -28),
			Size = UDim2.fromOffset(220, 44),
			BackgroundColor3 = GOLD,
			Text = "GOT IT",
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			Visible = false,
			ZIndex = 5,
		},
		gui
	)
	UiKit.round(nextButton, 10)
	local skip = new(
		"TextButton",
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 12),
			Size = UDim2.fromOffset(90, 30),
			Text = "SKIP",
			TextSize = 14,
			BackgroundColor3 = Color3.fromRGB(25, 32, 44),
			TextColor3 = GOLD,
			ZIndex = 5,
		},
		gui
	)
	UiKit.round(skip, 8)
	local marker = new(
		"Highlight",
		{ FillColor = GOLD, FillTransparency = 0.7, OutlineColor = GOLD, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop },
		workspace
	)
	local pulse = TweenService:Create(
		marker,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ FillTransparency = 0.35 }
	)
	pulse:Play()
	local arrow = new(
		"TextLabel",
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(240, 40),
			BackgroundTransparency = 1,
			TextColor3 = GOLD,
			TextStrokeTransparency = 0.2,
			TextSize = 19,
			Font = Enum.Font.GothamBold,
			Visible = false,
			ZIndex = 2,
		},
		gui
	)
	-- Demonstration is cosmetic only; it never equips or consumes a gem.
	local sourceBox = new("Frame", { BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, gui)
	new("UIStroke", { Color = Color3.fromRGB(95, 225, 255), Thickness = 2 }, sourceBox)
	local ghost = new(
		"Frame",
		{ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(54, 54), BackgroundTransparency = 1, Visible = false, ZIndex = 7 },
		gui
	)
	local hand = new(
		"TextLabel",
		{
			Size = UDim2.fromOffset(130, 22),
			Position = UDim2.fromOffset(-38, 58),
			BackgroundTransparency = 1,
			Text = "HOLD → DRAG",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = GOLD,
			TextStrokeTransparency = 0.15,
			ZIndex = 8,
		},
		gui
	)
	hand.Visible = false
	local destination = new(
		"TextLabel",
		{
			Size = UDim2.fromOffset(200, 24),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(12, 18, 29),
			Text = "2  RELEASE HERE",
			TextColor3 = GOLD,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			Visible = false,
			ZIndex = 6,
		},
		gui
	)
	local progress = new(
		"TextLabel",
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 172),
			Size = UDim2.fromOffset(350, 24),
			BackgroundTransparency = 1,
			TextColor3 = GOLD,
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			ZIndex = 4,
		},
		gui
	)
	local reward = new(
		"TextLabel",
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 205),
			Size = UDim2.fromOffset(330, 48),
			BackgroundColor3 = Color3.fromRGB(17, 48, 43),
			TextColor3 = Color3.fromRGB(100, 255, 175),
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextWrapped = true,
			Visible = false,
			ZIndex = 5,
		},
		gui
	)
	UiKit.round(reward, 10)
	local lastMined = GemClient.Profile.Tutorial.Mined or 0
	local rewardUntil = 0
	local startPoint, endPoint, shownGem
	local demoAt = os.clock()
	local animation = RunService.RenderStepped:Connect(function()
		if not startPoint or not endPoint then
			ghost.Visible = false
			hand.Visible = false
			return
		end
		-- Pause the example during the player's actual drag.
		local dragging = Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or #Input:GetTouches() > 0
		local phase = (os.clock() - demoAt) % 3.2
		ghost.Visible = not dragging and phase < 2.7
		hand.Visible = ghost.Visible
		local t = math.clamp((phase - 0.5) / 1.5, 0, 1)
		t = t * t * (3 - 2 * t)
		local point = startPoint:Lerp(endPoint, t) + Vector2.new(0, -math.sin(t * math.pi) * 38)
		ghost.Position = UDim2.fromOffset(point.X, point.Y)
		hand.Position = UDim2.fromOffset(point.X - 65, point.Y + 30)
		hand.Text = if phase < 0.5 then "1  HOLD GEM" elseif t < 1 then "DRAG TO SOCKET" else "2  RELEASE"
	end)
	local function screenPosition(object)
		-- Match the source ScreenGui's origin, including device-safe insets.
		local source = object:FindFirstAncestorWhichIsA("ScreenGui")
		local origin = source and source.AbsolutePosition or Vector2.zero
		return object.AbsolutePosition + origin - gui.AbsolutePosition
	end
	local busy = false
	local function advance(id)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			GemClient.request("TutorialStep", id)
			busy = false
		end)
	end
	nextButton.Activated:Connect(function()
		local beat = current()
		if beat and beat.Id == "GemIntro" then
			advance(beat.Id)
		end
	end)
	skip.Activated:Connect(function()
		GemClient.request("TutorialSkip")
	end)
	local function rectangle(o, x, y, w, h)
		o.Position = UDim2.fromOffset(x, y)
		o.Size = UDim2.fromOffset(math.max(0, w), math.max(0, h))
	end
	local function spot(x, y, w, h)
		local size = gui.AbsoluteSize
		x = math.clamp(x, 0, size.X)
		y = math.clamp(y, 0, size.Y)
		w = math.min(w, size.X - x)
		h = math.min(h, size.Y - y)
		rectangle(masks[1], 0, 0, size.X, y)
		rectangle(masks[2], 0, y + h, size.X, size.Y - y - h)
		rectangle(masks[3], 0, y, x, h)
		rectangle(masks[4], x + w, y, size.X - x - w, h)
		rectangle(frame, x, y, w, h)
		frame.Visible = true
	end
	local lastSocket = nil
	local elapsed = 0
	local connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		local beat = current()
		if not beat or GemClient.Profile.Tutorial.Run ~= runId then
			return
		end
		local size = gui.AbsoluteSize
		startPoint, endPoint = nil, nil
		sourceBox.Visible = false
		destination.Visible = false
		local mined = GemClient.Profile.Tutorial.Mined or 0
		if mined > lastMined then
			reward.Text = ({
				"FIRST FIND! Thermal gem secured.",
				"NICE! Cryo gem secured. One more!",
				"THREE FOR THREE! Let's power up your gear.",
			})[mined] or "GEM FOUND!"
			reward.Visible = true
			rewardUntil = os.clock() + 2.5
			reward.BackgroundTransparency = 0
			TweenService:Create(reward, TweenInfo.new(2.5), { BackgroundTransparency = 0.35 }):Play()
			lastMined = mined
		end
		reward.Visible = os.clock() < rewardUntil
		progress.Text = if beat.Id == "Mine"
			then string.format("DISCOVER  •  %d / 3 GEMS", mined)
			elseif beat.Id == "GemIntro" or beat.Id == "OpenInventory" then "DISCOVER ✓    →    ENCHANT"
			else "ENCHANT  •  " .. ({
				SocketArmor = "1 / 3",
				SocketWeapon = "2 / 3",
				SocketShield = "3 / 3",
				CloseInventory = "COMPLETE",
			})[beat.Id]
		card.Size = UDim2.fromOffset(math.min(480, size.X - 32), 116)
		card.Position = UDim2.new(0.5, 0, 0, 52)
		title.Text = if Input.TouchEnabled then beat.Mobile or beat.Prompt else beat.Prompt
		body.Text = beat.Detail or ""
		nextButton.Visible = beat.Id == "GemIntro"
		marker.Adornee = nil
		arrow.Visible = false
		frame.Visible = false
		for _, m in masks do
			m.Visible = true
		end
		local target
		if beat.Id == "Mine" then
			title.Text = ({
				"Your first discovery is waiting!",
				"Great find! Let's get another.",
				"One more rock. You've got this!",
			})[mined + 1] or "Three gems secured!"
			body.Text =
				"Follow the gold pointer. Click, tap or press E for each pick swing. Break just THREE rocks to collect your starter gems."
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local best, dist = nil, math.huge
			for _, rock in CollectionService:GetTagged("OutpostNode") do
				local part = rock.PrimaryPart
				local owner = rock:GetAttribute("ClaimedBy")
				if root and part and (rock:GetAttribute("Hp") or 0) > 0 and (not owner or owner == player.UserId) then
					local d = (part.Position - root.Position).Magnitude
					if d < dist then
						best, dist = rock, d
					end
				end
			end
			if best then
				marker.Adornee = best
				local point, onScreen = workspace.CurrentCamera:WorldToViewportPoint(best.PrimaryPart.Position)
				arrow.Visible = true
				arrow.Position =
					UDim2.fromOffset(math.clamp(point.X, 120, size.X - 120), math.clamp(point.Y - 70, 185, size.Y - 70))
				arrow.Text = if onScreen
					then string.format("▼  MINE HERE · %d studs", dist)
					else "TURN TOWARD THE GLOWING ROCK"
				if onScreen then
					spot(point.X - 95, point.Y - 90, 190, 180)
				else
					spot(size.X * 0.15, size.Y * 0.25, size.X * 0.7, size.Y * 0.65)
				end
			else
				body.Text = "Looking for an available rock nearby…"
				for _, m in masks do
					m.Visible = false
				end
			end
		elseif beat.Id == "OpenInventory" then
			target = LobbyUI.tile("INVENTORY")
			if LobbyUI.dashboardOpen() then
				advance(beat.Id)
			end
		elseif beat.Id == "CloseInventory" then
			for _, o in player.PlayerGui:GetDescendants() do
				if o:IsA("GuiObject") and o:GetAttribute("TutorialSocket") == "CloseInventory" then
					target = o
					break
				end
			end
			if not LobbyUI.dashboardOpen() then
				advance(beat.Id)
			end
		elseif beat.Id ~= "GemIntro" then
			local slot = ({ SocketArmor = "Armor", SocketWeapon = "Weapon", SocketShield = "Shield" })[beat.Id]
			for _, o in player.PlayerGui:GetDescendants() do
				if o:IsA("GuiObject") and o:GetAttribute("TutorialSocket") == slot then
					target = o
					break
				end
			end
			if Tutorial.met(GemClient.Profile, beat.Id) then
				if lastSocket ~= beat.Id then
					lastSocket = beat.Id
					local c = GemClient.Profile.Character
					local kind = ArmorSignatures.Slots[slot]
					local roll = kind and c.GearRolls and c.GearRolls[kind] and c.GearRolls[kind][c[slot]]
					local name, effect = ArmorSignatures.describe(roll, c[slot .. "Gem"])
					if name ~= "" then
						UiKit.toast(name .. ": " .. effect, Color3.fromRGB(90, 245, 150))
					end
				end
				advance(beat.Id)
			end
		end
		if beat.Id ~= "Mine" then
			if not LobbyUI.dashboardOpen() and string.sub(beat.Id, 1, 6) == "Socket" then
				target = LobbyUI.tile("INVENTORY")
				title.Text = "Reopen Inventory to continue."
				body.Text = "Your gems are saved. Open Inventory, then follow the highlighted gem and socket."
			end
			if
				target
				and target.AbsoluteSize.X > 0
				and (LobbyUI.dashboardOpen() or beat.Id == "OpenInventory" or string.sub(beat.Id, 1, 6) == "Socket")
			then
				local p, s = screenPosition(target), target.AbsoluteSize
				local x, y, w, h = p.X - 8, p.Y - 8, s.X + 16, s.Y + 16
				local element = ({ SocketArmor = "Fire", SocketWeapon = "Frost", SocketShield = "Shock" })[beat.Id]
				if element and LobbyUI.dashboardOpen() then
					for _, o in player.PlayerGui:GetDescendants() do
						if
							o:IsA("GuiObject")
							and o:GetAttribute("TutorialGem") == element
							and (
								not GemClient.Profile.Tutorial.GemIds
								or o:GetAttribute("TutorialGemId") == GemClient.Profile.Tutorial.GemIds[element]
							)
						then
							local gp, gs = screenPosition(o), o.AbsoluteSize
							rectangle(sourceBox, gp.X - 4, gp.Y - 4, gs.X + 8, gs.Y + 8)
							sourceBox.Visible = true
							startPoint = gp + gs / 2
							endPoint = p + s / 2
							destination.Position = UDim2.fromOffset(endPoint.X, p.Y - 10)
							destination.Visible = true
							local id = o:GetAttribute("TutorialGemId")
							if shownGem ~= id then
								shownGem = id
								ghost:ClearAllChildren()
								demoAt = os.clock()
								for _, gem in GemClient.Profile.Gems do
									if gem.Id == id then
										GemArt.viewport(ghost, gem, true)
										break
									end
								end
							end
							body.Text =
								"1. Hold the glowing gem.  2. Drag it to the outlined equipment.  3. Release to enchant. Follow the moving example."
							local right, bottom = math.max(x + w, gp.X + gs.X + 8), math.max(y + h, gp.Y + gs.Y + 8)
							x, y = math.min(x, gp.X - 8), math.min(y, gp.Y - 8)
							w, h = right - x, bottom - y
							break
						end
					end
				end
				spot(x, y, w, h)
				rectangle(frame, p.X - 8, p.Y - 8, s.X + 16, s.Y + 16)
				-- Keep the explanation below the inventory's top controls.
				if p.Y < 180 then
					card.Position = UDim2.new(0.5, 0, 1, -140)
				end
			else
				spot(size.X * 0.2, size.Y * 0.35, size.X * 0.6, size.Y * 0.4)
			end
		end
	end)
	while current() and GemClient.Profile.Tutorial.Run == runId do
		task.wait(0.2)
	end
	connection:Disconnect()
	animation:Disconnect()
	pulse:Cancel()
	marker:Destroy()
	gui:Destroy()
	if not current() then
		UiKit.toast("Ready! Mine gems and enchant your gear.", GOLD)
	end
end
while true do
	while not current() do
		task.wait(0.25)
	end
	while not OutpostScene.isActive() do
		task.wait(0.25)
	end
	run()
end
