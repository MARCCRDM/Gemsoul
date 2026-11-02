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
panel.Size = UDim2.fromOffset(300, 562)
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
		fit.Scale = if height > 0 then math.clamp((height - 70) / 562, 0.4, 1) else 1
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

-- NEW INTRO: DUNGEON: the new intro from its dungeon, on this account (its
-- two 1v1s counted won): the kaiju roll if owed, the pod drop, the Breach
-- and the Nest, their roll cards, then the lobby. The whole new intro from
-- its start: PLAY AS A NEW PLAYER.
local firstDungeon = Instance.new("TextButton")
firstDungeon.Name = "FirstDungeon"
firstDungeon.Size = UDim2.fromOffset(288, 30)
firstDungeon.Position = UDim2.fromOffset(6, 84)
firstDungeon.BackgroundColor3 = Color3.fromRGB(206, 112, 40)
firstDungeon.TextColor3 = Color3.fromRGB(255, 244, 226)
firstDungeon.Font = Enum.Font.GothamBold
firstDungeon.TextSize = 12
firstDungeon.Text = "NEW INTRO: DUNGEON"
firstDungeon.Parent = panel
corner(firstDungeon, 5)
firstDungeon.Activated:Connect(function()
	if busy then
		return
	end
	panel.Visible = false
	toggle.Text = arrow(false)
	busy = true
	task.spawn(function()
		local ok, problem = pcall(function()
			-- (the new intro at its dungeon on this account: Server.IntroRoundsServer's DevIntroDungeon)
			local set = request:InvokeServer("DevIntroDungeon")
			if not (set and set.Ok) then
				status.Text = if set then set.Message else "Couldn't set up the new intro."
				return
			end
			local message = require(script.Parent.Modules.FirstDungeonUI).play()
			status.Text = message or "New intro: into the dungeon."
		end)
		if not ok then
			status.Text = "First dungeon failed: " .. tostring(problem)
		end
		busy = false
	end)
end)

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
	b.Position = UDim2.fromOffset(if i == 2 then 153 else 6, if i <= 2 then 120 else 120 + (i - 2) * 32)
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
versionCaption.Position = UDim2.fromOffset(6, 332)
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
	b.Position = UDim2.fromOffset(104 + (version - 1) * 98, 332)
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
abilityCaption.Position = UDim2.fromOffset(6, 364)
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
	b.Position = UDim2.fromOffset(104 + (i - 1) * 98, 364)
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
cacheCaption.Position = UDim2.fromOffset(6, 396)
cacheCaption.Text = "ARENA CACHE"
cacheCaption.Parent = panel
for i, wins in { 10, 20, 30, 40, 50 } do
	local b = Instance.new("TextButton")
	b.Name = "StreakCache" .. wins
	b.Size = UDim2.fromOffset(34, 26)
	b.Position = UDim2.fromOffset(104 + (i - 1) * 38, 396)
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
bossCaption.Position = UDim2.fromOffset(6, 428)
bossCaption.Text = "BOSS CACHE"
bossCaption.Parent = panel
for threat, numeral in { "I", "II", "III" } do
	local b = Instance.new("TextButton")
	b.Name = "BossCache" .. threat
	b.Size = UDim2.fromOffset(60, 26)
	b.Position = UDim2.fromOffset(104 + (threat - 1) * 64, 428)
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
languageCaption.Position = UDim2.fromOffset(6, 460)
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
	b.Position = UDim2.fromOffset(104 + (i - 1) * 98, 460)
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

-- KAIJU ROLL: the starter roll as a test, rolled from every kind
-- (Modules/KaijuRoll.preview): see it with all the kaiju in it. Nothing is
-- claimed or saved; START just closes it.
local rollCaption = versionCaption:Clone()
rollCaption.Position = UDim2.fromOffset(6, 492)
rollCaption.Text = "KAIJU ROLL"
rollCaption.Parent = panel
local rollButton = Instance.new("TextButton")
rollButton.Name = "KaijuRollPreview"
rollButton.Size = UDim2.fromOffset(190, 26)
rollButton.Position = UDim2.fromOffset(104, 492)
rollButton.BackgroundColor3 = Color3.fromRGB(30, 84, 64)
rollButton.TextColor3 = Color3.fromRGB(150, 255, 200)
rollButton.Font = Enum.Font.GothamBold
rollButton.TextSize = 12
rollButton.Text = "ROLL WITH ALL KAIJU"
rollButton.Parent = panel
corner(rollButton, 5)
rollButton.Activated:Connect(function()
	panel.Visible = false
	task.spawn(require(script.Parent.Modules.KaijuRoll).preview)
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
poseLine.Position = UDim2.fromOffset(6, 278)
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

-- WATCH (Owners only: Server.DevSpectate checks it): the camera behind
-- another player in this server, third person, to see what they do. PREV /
-- NEXT go through who's here, STOP brings the camera back. A line at the
-- top says who and where they are.
do
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromOffset(96, 26)
	caption.Position = UDim2.fromOffset(6, 528)
	caption.BackgroundTransparency = 1
	caption.TextColor3 = Color3.fromRGB(255, 210, 126)
	caption.Font = Enum.Font.GothamBold
	caption.TextSize = 12
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.Text = "WATCH"
	caption.Parent = panel
	local banner = Instance.new("TextLabel")
	banner.Name = "Watching"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 6)
	banner.Size = UDim2.fromOffset(520, 30)
	banner.BackgroundColor3 = Color3.fromRGB(17, 25, 36)
	banner.BackgroundTransparency = 0.15
	banner.TextColor3 = Color3.fromRGB(255, 210, 126)
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 13
	banner.Visible = false
	banner.Parent = gui
	corner(banner, 6)

	local target: Player? = nil
	local saved = nil
	local function others(): { Player }
		local list = {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				table.insert(list, other)
			end
		end
		table.sort(list, function(a, b)
			return a.UserId < b.UserId
		end)
		return list
	end
	-- Where they are and what's up, from what the server puts on them.
	local function doing(other: Player): string
		local bits = {}
		local session = other:GetAttribute("CombatSession")
		if other:GetAttribute("MatchId") then
			table.insert(bits, "in a match")
		elseif other:GetAttribute("DungeonId") then
			table.insert(bits, "in a dungeon, room " .. tostring(other:GetAttribute("DungeonRoom") or 1))
		elseif session then
			table.insert(bits, "in the Arena (" .. tostring(session) .. ")")
		elseif other:GetAttribute("Outpost") then
			table.insert(bits, "in the Outpost")
		else
			table.insert(bits, "loading / menus")
		end
		if other:GetAttribute("IntroRounds") then
			table.insert(bits, "intro card up")
		end
		if other:GetAttribute("MenuOpen") then
			table.insert(bits, "menu open")
		end
		if other:GetAttribute("DuelQueue") then
			table.insert(bits, "searching " .. tostring(other:GetAttribute("DuelQueue")))
		end
		return table.concat(bits, " · ")
	end
	local camera = workspace.CurrentCamera
	local function stop()
		if not target then
			return
		end
		target = nil
		banner.Visible = false
		game:GetService("RunService"):UnbindFromRenderStep("DevWatch")
		pcall(function()
			request:InvokeServer("DevSpectate", nil)
		end)
		local own = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if own then
			camera.CameraSubject = own
		end
		if saved then
			player.CameraMode, player.CameraMaxZoomDistance, player.CameraMinZoomDistance = saved[1], saved[2], saved[3]
			saved = nil
		end
		status.Text = "Back to you."
	end
	local function watch(other: Player)
		local ok, result = pcall(function()
			return request:InvokeServer("DevSpectate", other.UserId)
		end)
		if not ok or not result or not result.Ok then
			status.Text = if ok and result then result.Message else "Couldn't watch them."
			return
		end
		saved = saved or { player.CameraMode, player.CameraMaxZoomDistance, player.CameraMinZoomDistance }
		target = other
		banner.Visible = true
		status.Text = result.Message
		-- (each frame: other scenes set the camera too; this one wins while watching)
		game:GetService("RunService"):BindToRenderStep("DevWatch", Enum.RenderPriority.Camera.Value - 2, function()
			if not target or not target.Parent then
				stop()
				return
			end
			local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				player.CameraMode = Enum.CameraMode.Classic
				player.CameraMaxZoomDistance = 45
				player.CameraMinZoomDistance = 6
				camera.CameraType = Enum.CameraType.Custom
				if camera.CameraSubject ~= humanoid then
					camera.CameraSubject = humanoid
				end
			end
		end)
	end
	local function step(by: number)
		local list = others()
		if #list == 0 then
			status.Text = "Nobody else is in this server."
			return
		end
		local at = target and table.find(list, target) or 0
		local nextOne = list[((at - 1 + by) % #list) + 1]
		if at == 0 and by < 0 then
			nextOne = list[#list]
		end
		watch(nextOne)
	end
	for i, item in { { "PREV", -1 }, { "NEXT", 1 }, { "STOP", 0 } } do
		local b = Instance.new("TextButton")
		b.Name = "Watch" .. item[1]
		b.Size = UDim2.fromOffset(60, 26)
		b.Position = UDim2.fromOffset(104 + (i - 1) * 64, 528)
		b.BackgroundColor3 = if item[2] == 0 then Color3.fromRGB(70, 46, 84) else Color3.fromRGB(39, 61, 79)
		b.TextColor3 = Color3.fromRGB(240, 245, 250)
		b.Font = Enum.Font.GothamBold
		b.TextSize = 12
		b.Text = item[1]
		b.Parent = panel
		corner(b, 5)
		b.Activated:Connect(function()
			if item[2] == 0 then
				stop()
			else
				step(item[2])
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			if target then
				banner.Text = string.format("WATCHING %s (@%s)  ·  %s", target.DisplayName, target.Name, doing(target))
			end
		end
	end)

	-- Health bars under the banner while watching: theirs, their kaiju's, and
	-- whoever they're fighting (their rival, the other side of their match,
	-- the creatures closest to them).
	local BAR_ROWS, NEAR = 9, 70
	local bars = Instance.new("Frame")
	bars.Name = "WatchHealth"
	bars.AnchorPoint = Vector2.new(0.5, 0)
	bars.Position = UDim2.new(0.5, 0, 0, 40)
	bars.Size = UDim2.fromOffset(360, 0)
	bars.AutomaticSize = Enum.AutomaticSize.Y
	bars.BackgroundColor3 = Color3.fromRGB(17, 25, 36)
	bars.BackgroundTransparency = 0.2
	bars.Visible = false
	bars.Parent = gui
	corner(bars, 6)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = bars
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bars
	local rows = {}
	for i = 1, BAR_ROWS do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 18)
		row.BackgroundTransparency = 1
		row.Visible = false
		row.Parent = bars
		local name = Instance.new("TextLabel")
		name.Name = "Who"
		name.Size = UDim2.new(0, 130, 1, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 12
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Parent = row
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Position = UDim2.fromOffset(136, 3)
		track.Size = UDim2.new(1, -136, 1, -6)
		track.BackgroundColor3 = Color3.fromRGB(40, 46, 58)
		track.Parent = row
		corner(track, 4)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = track
		corner(fill, 4)
		local amount = Instance.new("TextLabel")
		amount.Name = "Amount"
		amount.Size = UDim2.fromScale(1, 1)
		amount.BackgroundTransparency = 1
		amount.Font = Enum.Font.GothamBold
		amount.TextSize = 11
		amount.TextColor3 = Color3.new(1, 1, 1)
		amount.TextStrokeTransparency = 0.4
		amount.ZIndex = 3
		amount.Parent = track
		rows[i] = { Row = row, Name = name, Fill = fill, Amount = amount }
	end
	local SIDES = {
		You = { Color3.fromRGB(110, 230, 120), Color3.fromRGB(235, 245, 235) },
		Kaiju = { Color3.fromRGB(80, 200, 255), Color3.fromRGB(190, 230, 255) },
		Foe = { Color3.fromRGB(240, 80, 80), Color3.fromRGB(255, 200, 200) },
	}
	local function humanoidOf(model: Instance?): Humanoid?
		return if model then model:FindFirstChildOfClass("Humanoid") else nil
	end
	local function show(i: number, side: string, label: string, humanoid: Humanoid)
		local r = rows[i]
		local colors = SIDES[side]
		local max = math.max(humanoid.MaxHealth, 1)
		local hp = math.clamp(humanoid.Health, 0, max)
		r.Row.Visible = true
		r.Name.Text = label
		r.Name.TextColor3 = colors[2]
		r.Fill.BackgroundColor3 = colors[1]
		r.Fill.Size = UDim2.fromScale(hp / max, 1)
		r.Amount.Text = string.format("%d / %d", math.ceil(hp), math.floor(max))
	end
	-- Who's on the board, in order: them, their kaiju, then their foes.
	local function board(): { { any } }
		local out = {}
		local me = target :: Player
		local own = humanoidOf(me.Character)
		if own then
			table.insert(out, { "You", me.DisplayName, own })
		end
		local kaijuFolder = workspace:FindFirstChild("Kaiju")
		for _, model in if kaijuFolder then kaijuFolder:GetChildren() else {} do
			local h = humanoidOf(model)
			if h and model:GetAttribute("KaijuOwner") == me.UserId then
				table.insert(out, { "Kaiju", tostring(model:GetAttribute("KaijuName") or "Kaiju"), h })
			end
		end
		-- The other side of their match.
		local match = me:GetAttribute("MatchId")
		if match then
			for _, other in Players:GetPlayers() do
				local h = other ~= me and other:GetAttribute("MatchId") == match and humanoidOf(other.Character)
				if h then
					table.insert(out, { "Foe", other.DisplayName, h })
				end
			end
		end
		-- Their rival first, then the creatures closest to them.
		local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local enemies = workspace:FindFirstChild("Enemies")
		local near = {}
		for _, model in if enemies then enemies:GetChildren() else {} do
			local h = humanoidOf(model)
			local at = model:IsA("Model") and model.PrimaryPart
			if h and h.Health > 0 then
				local mine = model:GetAttribute("RivalOwner") == me.UserId
				local d = if root and at then (at.Position - root.Position).Magnitude else math.huge
				if mine or d <= NEAR then
					table.insert(near, { Model = model, H = h, Rank = if mine then -1 else d })
				end
			end
		end
		table.sort(near, function(a, b)
			return a.Rank < b.Rank
		end)
		for _, e in near do
			table.insert(out, { "Foe", tostring(e.Model:GetAttribute("CombatTitle") or e.Model.Name), e.H })
		end
		return out
	end
	local lastDrawn = 0
	game:GetService("RunService").Heartbeat:Connect(function()
		bars.Visible = target ~= nil and target.Parent ~= nil
		if not bars.Visible or os.clock() - lastDrawn < 0.1 then
			return
		end
		lastDrawn = os.clock()
		local shown = board()
		for i = 1, BAR_ROWS do
			local entry = shown[i]
			if entry then
				show(i, entry[1], entry[2], entry[3])
			else
				rows[i].Row.Visible = false
			end
		end
	end)
end
