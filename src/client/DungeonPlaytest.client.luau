-- Owner-only test controls, folded into a small DEV button in the bottom-right
-- corner: dungeon tests (F7 / F8 work any time), leaving a test, and the
-- loadout and gem rerolls. Authorization is independently checked on every
-- server request.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local request = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Request")
local player = Players.LocalPlayer
-- Permissions can arrive after this script starts; never infer authorization locally.
while player:GetAttribute("CanTestDungeon") == nil do
	player:GetAttributeChangedSignal("CanTestDungeon"):Wait()
end
if player:GetAttribute("CanTestDungeon") ~= true then
	return
end
local gui = Instance.new("ScreenGui")
gui.Name = "DungeonPlaytest"
gui:SetAttribute("NoTranslate", true) -- (test tools stay in English)
gui.ResetOnSpawn = false
gui.DisplayOrder = 120
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(object: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = object
end

-- The DEV button, in the strip the dashboard keeps clear along the bottom.
local toggle = Instance.new("TextButton")
toggle.AnchorPoint = Vector2.new(1, 1)
toggle.Position = UDim2.new(1, -14, 1, -8)
toggle.Size = UDim2.fromOffset(74, 28)
toggle.BackgroundColor3 = Color3.fromRGB(39, 61, 79)
toggle.TextColor3 = Color3.fromRGB(255, 210, 126)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 12
toggle.Text = "DEV"
toggle.Parent = gui
corner(toggle, 6)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -14, 1, -42)
panel.Size = UDim2.fromOffset(300, 458)
panel.BackgroundColor3 = Color3.fromRGB(17, 25, 36)
panel.Visible = false
panel.Parent = gui
corner(panel, 8)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 210, 126)
stroke.Transparency = 0.6
stroke.Parent = panel

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 36)
status.Position = UDim2.fromOffset(6, 4)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 210, 126)
status.TextWrapped = true
status.TextSize = 12
status.Font = Enum.Font.GothamBold
status.Text = "DEV TOOLS · Onboarding is currently paused."
status.Parent = panel

-- Touch screens: the bottom-right corner is the thumb's (Combat's buttons).
-- So the DEV button goes up into Roblox's top bar strip, at its empty right
-- end, small, and its panel opens downward from there. That end is kept for
-- it (UiKit.reserveTopbar): windows that reach into the strip stop short of
-- it, so it never covers their close buttons.
if game:GetService("UserInputService").TouchEnabled then
	local UiKit = require(script.Parent.Modules.UiKit)
	gui.IgnoreGuiInset = true
	toggle.AnchorPoint, toggle.Position = Vector2.new(1, 0.5), UDim2.new(1, -14, 0, 29)
	toggle.Size = UDim2.fromOffset(56, 26)
	UiKit.reserveTopbar(14 + 56)
	-- (centred on the strip, in line with Roblox's own buttons)
	local function level()
		local top = UiKit.topbar(gui.AbsoluteSize.X)
		toggle.Position = UDim2.new(1, -14, 0, top / 2)
		panel.Position = UDim2.new(1, -14, 0, top + 4)
	end
	UiKit.onTopbar(level)
	toggle.TextSize = 11
	toggle.BackgroundTransparency = 0.25
	panel.AnchorPoint, panel.Position = Vector2.new(1, 0), UDim2.new(1, -14, 0, 62)
	-- A phone in landscape is shorter than the panel: shrink it to fit.
	local fit = Instance.new("UIScale")
	fit.Parent = panel
	local function shrink()
		local height = gui.AbsoluteSize.Y
		fit.Scale = if height > 0 then math.clamp((height - 70) / 394, 0.55, 1) else 1
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(shrink)
	shrink()
	level()
end
-- (Plain words: the arrow glyphs this used to show aren't in every phone's font.)
local function arrow(open: boolean): string
	return if open then "CLOSE" else "DEV"
end

toggle.Activated:Connect(function()
	panel.Visible = not panel.Visible
	toggle.Text = arrow(panel.Visible)
end)

local busy = false
local function run(action: string, ...)
	if busy then
		return
	end
	busy = true
	status.Text = "Loading..."
	local args = table.pack(...)
	local ok, result = pcall(function()
		return request:InvokeServer(action, table.unpack(args, 1, args.n))
	end)
	status.Text = if ok and result then result.Message else "Request failed. Finish the intro, then retry."
	if ok and result and result.Ok and action == "AdminRestartTutorial" then
		require(script.Parent.Modules.LobbyUI).closeDashboard()
		require(script.Parent.Modules.LobbyUI).closePicker()
		task.delay(0.35, function()
			require(script.Parent.Modules.OutpostScene).ensure(true)
		end)
		panel.Visible = false
		toggle.Text = arrow(false)
	end
	if ok and result and result.Ok and (action == "DevStreakCache" or action == "DevBossCache") then
		-- Out of the way, so the cache's roll plays in full view.
		panel.Visible = false
		toggle.Text = arrow(false)
		require(script.Parent.Modules.StreakRewards).show(result)
	end
	busy = false
end

-- Keep onboarding replay first and visually separate from destructive-looking rerolls.
local restart = Instance.new("TextButton")
restart.Name = "RestartIntroTutorial"
restart.Size = UDim2.fromOffset(288, 34)
restart.Position = UDim2.fromOffset(6, 44)
restart.BackgroundColor3 = Color3.fromRGB(255, 210, 126)
restart.TextColor3 = Color3.fromRGB(17, 25, 36)
restart.Font = Enum.Font.GothamBold
restart.TextSize = 12
restart.Text = if require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled then "RESTART INTRO / TUTORIAL" else "INTRO / TUTORIAL PAUSED"
restart.Active = require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled
restart.AutoButtonColor = restart.Active
restart.Parent = panel
corner(restart, 5)
restart.Activated:Connect(function()
	if require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled then
		run("AdminRestartTutorial")
	end
end)
-- With the fast start (Shared.FastStart) in place of the tutorial: play the
-- first join again as a brand-new player (your save is kept as a backup;
-- RESTORE SAVE puts it back). Each one has you rejoin.
if not restart.Active and require(game:GetService("ReplicatedStorage").Shared.FastStart).Enabled then
	restart.Text = "PLAY AS A NEW PLAYER"
	restart.Active, restart.AutoButtonColor = true, true
	restart.Size = UDim2.fromOffset(190, 34)
	local armed = 0
	restart.Activated:Connect(function()
		-- Tap twice: it swaps your save out and asks you to rejoin.
		if os.clock() > armed then
			armed = os.clock() + 4
			status.Text = "Tap again to reset to a new player. Your save is kept; RESTORE SAVE brings it back."
			return
		end
		armed = 0
		run("DevNewPlayer")
	end)
	local restore = Instance.new("TextButton")
	restore.Name = "RestoreSave"
	restore.Size = UDim2.fromOffset(92, 34)
	restore.Position = UDim2.fromOffset(202, 44)
	restore.BackgroundColor3 = Color3.fromRGB(39, 61, 79)
	restore.TextColor3 = Color3.fromRGB(240, 245, 250)
	restore.Font = Enum.Font.GothamBold
	restore.TextSize = 11
	restore.Text = "RESTORE SAVE"
	restore.Parent = panel
	corner(restore, 5)
	restore.Activated:Connect(function()
		run("DevRestoreSave")
	end)
end

local buttons = {
	{ "F7 / PATHWAY", "DungeonTest", "Full" },
	{ "F8 / TUNG TUNG", "DungeonTest", "Sahur" },
	{ "OPEN WORLD DUNGEON TEST", "DungeonTest", "OpenWorld" },
	{ "EXIT TEST", "ArenaLeave" },
	{ "REGENERATE LOADOUT", "AdminRegenerateEquipment" },
	{ "REROLL 3 GEMS", "AdminRegenerateGems" },
}
for i, item in buttons do
	local b = Instance.new("TextButton")
	local wide = i >= 3
	b.Size = UDim2.fromOffset(if wide then 288 else 141, 26)
	b.Position = UDim2.fromOffset(if i == 2 then 153 else 6, if i <= 2 then 84 else 84 + (i - 2) * 32)
	b.BackgroundColor3 = if i >= 5 then Color3.fromRGB(70, 46, 84) else Color3.fromRGB(39, 61, 79)
	b.TextColor3 = Color3.fromRGB(240, 245, 250)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = item[1]
	b.Parent = panel
	corner(b, 5)
	b.Activated:Connect(function()
		if item[3] then
			run(item[2], item[3])
		else
			run(item[2])
		end
	end)
end

-- INVENTORY V1 / V2: flips the dashboard between the redesign (the default,
-- Modules/InventoryV2) and the first Inventory (kept, Modules/InventoryScreen),
-- to test and compare. This session only.
local versionCaption = Instance.new("TextLabel")
versionCaption.Size = UDim2.fromOffset(96, 26)
versionCaption.Position = UDim2.fromOffset(6, 296)
versionCaption.BackgroundTransparency = 1
versionCaption.TextColor3 = Color3.fromRGB(255, 210, 126)
versionCaption.Font = Enum.Font.GothamBold
versionCaption.TextSize = 12
versionCaption.TextXAlignment = Enum.TextXAlignment.Left
versionCaption.Text = "INVENTORY"
versionCaption.Parent = panel
local versionButtons = {}
local function paintVersions()
	local current = require(script.Parent.Modules.InventoryV2).version(player)
	for version, b in versionButtons do
		local on = version == current
		b.BackgroundColor3 = if on then Color3.fromRGB(255, 210, 126) else Color3.fromRGB(39, 61, 79)
		b.TextColor3 = if on then Color3.fromRGB(17, 25, 36) else Color3.fromRGB(240, 245, 250)
	end
end
for version = 1, 2 do
	local b = Instance.new("TextButton")
	b.Name = "InventoryV" .. version
	b.Size = UDim2.fromOffset(92, 26)
	b.Position = UDim2.fromOffset(104 + (version - 1) * 98, 296)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = if version == 1 then "V1  OLD" else "V2  CURRENT"
	b.Parent = panel
	corner(b, 5)
	b.Activated:Connect(function()
		player:SetAttribute("InventoryVersion", version)
		paintVersions()
		status.Text = "Inventory " .. (if version == 1 then "v1 (old)" else "v2 (default)") .. ". Open INVENTORY to see it."
	end)
	versionButtons[version] = b
end
paintVersions()
player:GetAttributeChangedSignal("InventoryVersion"):Connect(paintVersions)

-- ABILITIES: the classic surge array (Q / E / R read the three surge
-- sockets) or the triad (Q the sword's gem, E the core gem, R the shield's).
-- Saved on your profile, so the server fights by the same rules.
local abilityCaption = versionCaption:Clone()
abilityCaption.Position = UDim2.fromOffset(6, 328)
abilityCaption.Text = "ABILITIES"
abilityCaption.Parent = panel
local abilityButtons = {}
local function paintAbilities(mode: string?)
	for id, b in abilityButtons do
		local on = id == mode
		b.BackgroundColor3 = if on then Color3.fromRGB(255, 210, 126) else Color3.fromRGB(39, 61, 79)
		b.TextColor3 = if on then Color3.fromRGB(17, 25, 36) else Color3.fromRGB(240, 245, 250)
	end
end
for i, mode in { "Classic", "Triad" } do
	local b = Instance.new("TextButton")
	b.Name = "Abilities" .. mode
	b.Size = UDim2.fromOffset(92, 26)
	b.Position = UDim2.fromOffset(104 + (i - 1) * 98, 328)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = if mode == "Classic" then "CLASSIC" else "Q·E·R TRIAD"
	b.Parent = panel
	corner(b, 5)
	b.Activated:Connect(function()
		run("DevAbilities", mode)
		paintAbilities(mode)
	end)
	abilityButtons[mode] = b
end
paintAbilities("Triad")

-- ARENA CACHE: roll a test Arena Cache for one of the first five streak
-- milestones (Shared.ArenaStreak) and open it, roll and all. Test caches
-- pay no coins or titles and their leftovers never reach the Market.
local cacheCaption = versionCaption:Clone()
cacheCaption.Position = UDim2.fromOffset(6, 360)
cacheCaption.Text = "ARENA CACHE"
cacheCaption.Parent = panel
for i, wins in { 10, 20, 30, 40, 50 } do
	local b = Instance.new("TextButton")
	b.Name = "StreakCache" .. wins
	b.Size = UDim2.fromOffset(34, 26)
	b.Position = UDim2.fromOffset(104 + (i - 1) * 38, 360)
	b.BackgroundColor3 = Color3.fromRGB(84, 64, 30)
	b.TextColor3 = Color3.fromRGB(255, 210, 126)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = tostring(wins)
	b.Parent = panel
	corner(b, 5)
	b.Activated:Connect(function()
		run("DevStreakCache", wins)
	end)
end

-- BOSS CACHE: a test boss cache (Shared.BossLoot) from a boss of threat I,
-- II or III, its gem and all, opened the same way.
local bossCaption = versionCaption:Clone()
bossCaption.Position = UDim2.fromOffset(6, 392)
bossCaption.Text = "BOSS CACHE"
bossCaption.Parent = panel
for threat, numeral in { "I", "II", "III" } do
	local b = Instance.new("TextButton")
	b.Name = "BossCache" .. threat
	b.Size = UDim2.fromOffset(60, 26)
	b.Position = UDim2.fromOffset(104 + (threat - 1) * 64, 392)
	b.BackgroundColor3 = Color3.fromRGB(92, 34, 30)
	b.TextColor3 = Color3.fromRGB(255, 176, 150)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = numeral
	b.Parent = panel
	corner(b, 5)
	b.Activated:Connect(function()
		run("DevBossCache", threat)
	end)
end

-- LANGUAGE: the game in English or Spanish (client/Translate), whatever
-- Roblox is set to. This session only.
local languageCaption = versionCaption:Clone()
languageCaption.Position = UDim2.fromOffset(6, 424)
languageCaption.Text = "LANGUAGE"
languageCaption.Parent = panel
local languageButtons = {}
local function paintLanguage()
	local current = require(game:GetService("ReplicatedStorage").Shared.Lang).language()
	for id, b in languageButtons do
		local on = id == current
		b.BackgroundColor3 = if on then Color3.fromRGB(255, 210, 126) else Color3.fromRGB(39, 61, 79)
		b.TextColor3 = if on then Color3.fromRGB(17, 25, 36) else Color3.fromRGB(240, 245, 250)
	end
end
for i, id in { "en", "es" } do
	local b = Instance.new("TextButton")
	b.Name = "Language" .. id
	b.Size = UDim2.fromOffset(92, 26)
	b.Position = UDim2.fromOffset(104 + (i - 1) * 98, 424)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = if id == "en" then "ENGLISH" else "ESPAÑOL"
	b.Parent = panel
	corner(b, 5)
	b.Activated:Connect(function()
		player:SetAttribute("Language", id)
		task.defer(paintLanguage)
	end)
	languageButtons[id] = b
end
paintLanguage()
player:GetAttributeChangedSignal("Language"):Connect(function()
	task.defer(paintLanguage)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.F7 then
		run("DungeonTest", "Full")
	elseif input.KeyCode == Enum.KeyCode.F8 then
		run("DungeonTest", "Sahur")
	end
end)

-- POSE CHECK: how the nearest other fighter's body is being posed on this
-- screen (Shared.RivalPose), to tell why a foe might not visibly swing or
-- guard: joints found (Motor6Ds), frames posed, resets (something else put a
-- bent joint back), the largest bend now and the action it's showing.
local RivalPose = require(game:GetService("ReplicatedStorage").Shared.RivalPose)
local poseLine = Instance.new("TextLabel")
poseLine.Size = UDim2.new(1, -12, 0, 46)
poseLine.Position = UDim2.fromOffset(6, 242)
poseLine.BackgroundTransparency = 1
poseLine.TextColor3 = Color3.fromRGB(160, 230, 255)
poseLine.TextWrapped = true
poseLine.TextXAlignment = Enum.TextXAlignment.Left
poseLine.TextSize = 11
poseLine.Font = Enum.Font.GothamMedium
poseLine.Text = "POSE CHECK: open near a fighter"
poseLine.Parent = panel

local function nearestFighter(): Model?
	local own = player.Character
	local eye = own and own:FindFirstChild("HumanoidRootPart")
	if not eye then
		return nil
	end
	local best, bestDistance = nil, 220
	local function consider(model)
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if model and model ~= own and root and root:IsA("BasePart") then
			local distance = (root.Position - eye.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	for _, other in Players:GetPlayers() do
		consider(other.Character)
	end
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		consider(model)
	end
	return best
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if panel.Visible then
			local model = nearestFighter()
			local info = model and RivalPose.inspect(model)
			poseLine.Text = if not model
				then "POSE CHECK: no fighter nearby"
				elseif not info then string.format(
					"POSE CHECK %s: NOT POSED (BodyPoses never reached it)",
					model.Name
				)
				else string.format(
					"POSE CHECK %s: %d joints (%s) · frames %d · resets %d · bend %.2f · %s",
					model.Name,
					info.Found,
					info.Kind,
					info.Updates,
					info.Resets,
					info.Bend,
					info.Action or "idle"
				)
		end
	end
end)
