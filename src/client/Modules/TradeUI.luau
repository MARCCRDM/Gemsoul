-- Equipment trade desk. Both players see item rolls and attached gems before confirming.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Classes = require(ReplicatedStorage.Shared.Classes)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local TradeUI = {}
local window = IronUi.window("EquipmentTrade", 10, 900, 620, "⇄")
window.Title.Text = "EQUIPMENT EXCHANGE"
window.Subtitle.Text = "Trade one item for another in the same slot. Enchantments travel with equipment."
local body = IronUi.new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(24, 90),
	Size = UDim2.new(1, -48, 1, -110),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 5,
}, window.Panel)
UiKit.list(body, 8)
local state, target, selected = nil, nil, nil
local slot = "Weapon"
local busy, elapsed, lastKey = false, 0, ""
local draw
local function line(value, height)
	local t = IronUi.text(body, value, 15, IronUi.Colors.Text)
	t.Size = UDim2.new(1, -12, 0, height or 26)
	t.TextWrapped = true
	return t
end
local function button(value, primary, callback)
	local b = IronUi.button(body, value, primary, callback)
	b.Size = UDim2.new(1, -12, 0, 38)
end
local function key(s)
	return if s
		then s.Id .. tostring(s.Right and s.Right.Id) .. tostring(s.Revision) .. tostring(s.Saving) .. tostring(
			s.OwnConfirmed
		) .. tostring(s.PartnerConfirmed)
		else "none"
end
local function request(action, ...)
	if busy then
		return
	end
	busy = true
	local result = GemClient.request(action, ...)
	busy = false
	if result.Message ~= "" then
		UiKit.toast(result.Message)
	end
	if result.Ok then
		state = result.Trade
		lastKey = key(state)
	end
	draw()
end
local function describe(item)
	if not item then
		return "Waiting for the other item."
	end
	local profile = GemClient.Profile
	local gear = Classes.gear(profile.Character.Class, Slots.Definitions[item.Slot].Kind, item.Id)
	local roll = item.Roll
	local rarity = if roll then GearRolls.Rarities[roll.Rarity].Name else "Common"
	local parts = { (if gear then gear.Name else item.Id) .. " | " .. rarity .. " | Quality " .. item.Quality }
	for _, stat in { "Health", "Power", "Defense", "Speed" } do
		if roll and roll.Stats[stat] then
			table.insert(parts, "+" .. roll.Stats[stat] .. " " .. stat)
		end
	end
	table.insert(
		parts,
		if item.Gem
			then "Enchantment: " .. GemConfig.displayName(item.Gem) .. " (cut " .. item.Gem.Cut .. ")"
			else "Empty gem socket"
	)
	return table.concat(parts, "  •  ")
end
local function ownedChoices(which, callback)
	local profile = GemClient.Profile
	local kind = Slots.Definitions[which].Kind
	local class = Classes.get(profile.Character.Class)
	for _, gear in class[kind] do
		if profile.Owned[kind][gear.Id] then
			local id = gear.Id
			button(gear.Name .. (if selected == id then "  [SELECTED]" else ""), selected == id, function()
				callback(id)
			end)
		end
	end
end
draw = function()
	IronUi.clear(body)
	if not GemClient.Profile then
		line("Loading equipment...")
		return
	end
	if state then
		if state.Saving then
			line("Saving the exchange... Equipment actions will resume after confirmation.", 60)
			return
		end
		line("Trading with " .. state.Partner .. " • " .. Slots.Definitions[state.Slot].Label)
		line("YOU GIVE: " .. describe(if state.Initiator then state.Left else state.Right), 84)
		line("YOU RECEIVE: " .. describe(if state.Initiator then state.Right else state.Left), 84)
		line(
			"Your confirmation: "
				.. (if state.OwnConfirmed then "READY" else "PENDING")
				.. " • Partner: "
				.. (if state.PartnerConfirmed then "READY" else "PENDING")
		)
		if not state.Initiator and not state.OwnConfirmed then
			line("Choose your counteroffer (changing it clears both confirmations):")
			ownedChoices(state.Slot, function(id)
				request("TradeCounter", state.Id, id)
			end)
		end
		if state.Right and not state.OwnConfirmed then
			button("CONFIRM THESE TWO ITEMS", true, function()
				request("TradeConfirm", state.Id, state.Revision)
			end)
		end
		button("CANCEL TRADE", false, function()
			request("TradeCancel", state.Id)
		end)
		return
	end
	line("Choose another player in this server:")
	local count = 0
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer then
			count += 1
			button(
				p.DisplayName .. " (@" .. p.Name .. ")" .. (if target == p.UserId then "  [SELECTED]" else ""),
				target == p.UserId,
				function()
					target = p.UserId
					draw()
				end
			)
		end
	end
	if count == 0 then
		line("No other players are here. Join a multiplayer server to trade.", 44)
	end
	line("Choose a slot:")
	local tabs = IronUi.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 38) }, body)
	UiKit.list(tabs, 6, true)
	for _, name in Slots.Order do
		local b = IronUi.button(tabs, Slots.Definitions[name].Label, slot == name, function()
			slot = name
			selected = nil
			draw()
		end)
		b.Size = UDim2.fromOffset(128, 38)
	end
	ownedChoices(slot, function(id)
		selected = id
		draw()
	end)
	line("One item per model is supported. A trade cannot add a model the recipient already owns.", 44)
	if target and selected then
		button("SEND EQUIPMENT OFFER", true, function()
			request("TradeOffer", target, slot, selected)
		end)
	end
end
function TradeUI.open()
	window.Gui.Enabled = true
	window.Fit()
	request("TradeState")
end
local function close()
	window.Gui.Enabled = false
end
window.Close.Activated:Connect(close)
window.Shade.Activated:Connect(close)
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1.5 or busy or not window.Gui.Enabled then
		return
	end
	elapsed = 0
	task.spawn(function()
		busy = true
		local result = GemClient.request("TradeState")
		busy = false
		if result.Ok then
			state = result.Trade
			if key(state) ~= lastKey then
				lastKey = key(state)
				draw()
			end
		end
	end)
end)
GemClient.Changed:Connect(function()
	if window.Gui.Enabled and not busy then
		draw()
	end
end)
return TradeUI
