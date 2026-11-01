--[[
	SETTINGS: a ⚙ in the top bar, just past Roblox's own buttons, opens a small
	window:

	  MUSIC            [ ON ]   ━━━━━━●━━━  80%
	  SOUND EFFECTS    [ ON ]   ━━━━━━━━━●  100%

	Each row's switch turns it off or on; its slider sets how loud. They take
	effect at once (Client.Music's sound group, UiSound and CombatSound) and
	are saved with your profile (Server.SettingsServer), so they follow you
	to any server or device.

	  SettingsUI.start()   once (Lobby.client)
	  SettingsUI.open()
	  SettingsUI.apply(settings)   puts settings into effect (Shared.GameSettings)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local GameSettings = require(ReplicatedStorage.Shared.GameSettings)
local Lang = require(ReplicatedStorage.Shared.Lang)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local SettingsUI = {}

local P = IronUi.Colors
local new = IronUi.new
local W, H = 440, 250
local COMBAT_BASE = 0.85 -- (CombatSound's own level, at 100%)

local current = GameSettings.clean(nil)
local window = nil
local rows = {}
local saveAt = 0

-- Puts `settings` into effect at once.
function SettingsUI.apply(settings)
	current = GameSettings.clean(settings)
	pcall(function()
		require(script.Parent.Music).setVolume(GameSettings.music(current))
	end)
	local effects = GameSettings.effects(current)
	pcall(function()
		require(script.Parent.UiSound).Volume = effects
		local menu = SoundService:FindFirstChild("MenuSounds")
		if menu then
			menu.Volume = effects
		end
	end)
	pcall(function()
		require(script.Parent.CombatSound).Volume = COMBAT_BASE * effects
		local combat = SoundService:FindFirstChild("CombatSounds")
		if combat then
			combat.Volume = COMBAT_BASE * effects
		end
	end)
	for _, row in rows do
		row.draw()
	end
end

-- Saved a moment after the last change (a slider dragged is one save).
local function save()
	saveAt = os.clock() + 0.8
	local mine = saveAt
	task.delay(0.85, function()
		if mine == saveAt then
			GemClient.request("SaveSettings", current)
		end
	end)
end

local function change(key: string, value: any)
	local nextSettings = table.clone(current)
	nextSettings[key] = value
	SettingsUI.apply(nextSettings)
	save()
end

-- One row: its name, an ON/OFF switch, a slider.
local function row(parent: Instance, y: number, label: string, onKey: string, levelKey: string)
	local name = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, y),
		Size = UDim2.fromOffset(150, 34),
		Font = IronUi.Heading,
		TextSize = 15,
		TextColor3 = P.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Lang.translate(label),
	}, parent)
	local switch = new("TextButton", {
		Position = UDim2.fromOffset(176, y + 2),
		Size = UDim2.fromOffset(64, 30),
		Font = IronUi.Heading,
		TextSize = 13,
		AutoButtonColor = true,
	}, parent)
	UiKit.round(switch, 15)
	switch:SetAttribute("UiSound", "Click")
	local track = new("Frame", {
		Position = UDim2.fromOffset(256, y + 14),
		Size = UDim2.fromOffset(116, 6),
		BackgroundColor3 = Color3.fromRGB(44, 52, 76),
	}, parent)
	UiKit.round(track, 3)
	local fill = new("Frame", { BackgroundColor3 = P.Gold, Size = UDim2.fromScale(1, 1) }, track)
	UiKit.round(fill, 3)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = P.Text,
	}, track)
	UiKit.round(knob, 9)
	local value = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(378, y),
		Size = UDim2.fromOffset(46, 34),
		Font = IronUi.Bold,
		TextSize = 13,
		TextColor3 = P.Dim,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, parent)
	-- A bigger target than the track, for thumbs.
	local hit = new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(248, y - 4),
		Size = UDim2.fromOffset(132, 42),
		ZIndex = 3,
	}, parent)
	local function draw()
		local on, level = current[onKey], current[levelKey]
		switch.Text = Lang.translate(if on then "ON" else "OFF")
		switch.BackgroundColor3 = if on then P.Gold else Color3.fromRGB(44, 52, 76)
		switch.TextColor3 = if on then Color3.fromRGB(26, 18, 6) else P.Dim
		fill.Size = UDim2.fromScale(level, 1)
		knob.Position = UDim2.fromScale(level, 0.5)
		fill.BackgroundColor3 = if on then P.Gold else P.Dim
		value.Text = math.floor(level * 100 + 0.5) .. "%"
		name.TextColor3 = if on then P.Text else P.Dim
	end
	switch.Activated:Connect(function()
		change(onKey, not current[onKey])
	end)
	local dragging = false
	local function setFrom(x: number)
		local a, w = track.AbsolutePosition.X, track.AbsoluteSize.X
		if w > 0 then
			local level = math.clamp((x - a) / w, 0, 1)
			if not current[onKey] and level > 0 then
				current[onKey] = true -- (turning it up turns it on)
			end
			change(levelKey, level)
		end
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(rows, { draw = draw })
	draw()
end

local function build()
	local w = IronUi.window("Settings", 14, W, H, "⚙", P.Gold)
	w.Title.Text = Lang.translate("SETTINGS")
	w.Subtitle.Text = Lang.translate("Saved with your profile")
	w.Close.Activated:Connect(function()
		w.Gui.Enabled = false
	end)
	w.Shade.Activated:Connect(function()
		w.Gui.Enabled = false
	end)
	row(w.Panel, 96, "MUSIC", "MusicOn", "Music")
	row(w.Panel, 150, "SOUND EFFECTS", "EffectsOn", "Effects")
	window = w
	return w
end

function SettingsUI.open()
	local w = window or build()
	for _, r in rows do
		r.draw()
	end
	w.Gui.Enabled = true
end

-- The ⚙ in the top bar, just past Roblox's own buttons (UiKit.topbar).
local function gear()
	local gui = UiKit.gui("SettingsButton", 8)
	gui.IgnoreGuiInset = true
	local button = new("TextButton", {
		Name = "Settings",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.35,
		Text = "⚙",
		Font = IronUi.Heading,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true,
	}, gui)
	UiKit.round(button, 20)
	button:SetAttribute("UiSound", "Open")
	local function place()
		local screen = gui.AbsoluteSize
		local top, left = UiKit.topbar(screen.X)
		left -= UiKit.topbarLeftReserved() -- (Roblox's buttons' own edge)
		local size = math.clamp(top - 16, 32, 44)
		button.Size = UDim2.fromOffset(size, size)
		button.TextSize = math.floor(size * 0.55)
		button.Position = UDim2.fromOffset(left + 8, top / 2)
		-- (and everything laid out round Roblox's buttons keeps clear of it)
		UiKit.reserveTopbarLeft(size + 8)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	UiKit.onTopbar(place)
	place()
	button.Activated:Connect(SettingsUI.open)
end

local started = false
function SettingsUI.start()
	if started then
		return
	end
	started = true
	gear()
	-- Your saved settings, as soon as your profile's in (and again if they
	-- change on another of your screens).
	local applied = nil
	local function fromProfile()
		local saved = GemClient.Profile and GemClient.Profile.Settings
		local key = if type(saved) == "table" then table.concat({ tostring(saved.Music), tostring(saved.MusicOn), tostring(saved.Effects), tostring(saved.EffectsOn) }, "/") else "none"
		if key ~= applied and os.clock() > saveAt then
			applied = key
			SettingsUI.apply(saved)
		end
	end
	GemClient.Changed:Connect(fromProfile)
	fromProfile()
end

return SettingsUI
