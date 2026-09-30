--[[
	The abilities screen [K]: your class's six abilities, and which three sit
	on Q / E / R. Click Q, E or R on a card to put that ability there (it
	swaps with whatever was in that slot). Also shows your ultimate [F], your
	weapon's attack and passive, and your armor's passive.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local P = IronUi.Colors
local BOLD = IronUi.Bold
local new, text, box, button, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.button, IronUi.clear

local WIDTH, HEIGHT = 980, 620
local KIND_LABELS = {
	Cone = "Frontal strike",
	Nova = "Area blast",
	Dash = "Movement",
	Bolt = "Projectile",
	Buff = "Self buff",
	Zone = "Ground area",
}

local AbilitiesUI = {}

local window = IronUi.window("Abilities", 9, WIDTH, HEIGHT, "⚔️")
local gui, panel = window.Gui, window.Panel
window.Title.Text = "ABILITIES"

local busy = false
local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 76),
	Size = UDim2.fromOffset(WIDTH - 48, HEIGHT - 100),
}, panel)

-- "Cone  |  4s cooldown  |  20 Rage"
function AbilitiesUI.summary(ability, resource: string): string
	local parts = { KIND_LABELS[ability.Kind] or ability.Kind, string.format("%gs cooldown", ability.Cooldown) }
	if ability.Cost and ability.Cost > 0 then
		table.insert(parts, string.format("%d %s", ability.Cost, resource))
	end
	if ability.Gain and ability.Gain > 0 then
		table.insert(parts, string.format("+%d %s", ability.Gain, resource))
	end
	return table.concat(parts, "  |  ")
end

function AbilitiesUI.attackSummary(attack): string
	if not attack then
		return ""
	end
	local parts = {
		if attack.Kind == "Melee" then "Melee" else "Ranged",
		string.format("%d damage", attack.Damage),
		string.format("every %.2gs", attack.Rate),
		string.format("%d stud reach", attack.Range),
	}
	if attack.Combo then
		table.insert(parts, string.format("%d-hit combo", attack.Combo))
	end
	return table.concat(parts, "  |  ")
end

local function setPicks(picks: { string })
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local result = GemClient.request("SetAbilities", picks)
		if not result.Ok then
			UiKit.toast(result.Message, P.Bad)
		end
		busy = false
		AbilitiesUI.refresh()
	end)
end

local function card(parent: Instance, ability, class, order: number, picks: { string }?)
	local slot = picks and table.find(picks, ability.Id)
	local c = box(parent, UDim2.new(), UDim2.new(), if slot then Color3.fromRGB(40, 34, 26) else P.Inset)
	c.LayoutOrder = order
	local stroke = c:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Color = if ability.Ultimate then P.Gold elseif slot then class.Color else P.Edge
	stroke.Thickness = if slot or ability.Ultimate then 2 else 1.5
	UiKit.pad(c, 10)
	local info = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, if picks then -34 else 0) }, c)
	UiKit.list(info, 3)
	text(info, ability.Name, 16, if ability.Ultimate then P.Gold else P.Text, BOLD)
	text(info, AbilitiesUI.summary(ability, class.ResourceId), 11, class.Color, BOLD)
	text(info, ability.Description, 12, P.Dim)
	if not picks then
		return
	end
	local row = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 30),
	}, c)
	UiKit.list(row, 6, true)
	for i, key in Classes.AbilityKeys do
		local b = button(row, key, slot == i, function()
			local newPicks = table.clone(picks)
			local from = table.find(newPicks, ability.Id)
			-- Put it in slot i; whatever was there moves to where this was.
			if from then
				newPicks[from] = newPicks[i]
			end
			newPicks[i] = ability.Id
			setPicks(newPicks)
		end)
		b.Size = UDim2.fromOffset(44, 30)
		b.AutomaticSize = Enum.AutomaticSize.None
	end
	if slot then
		local tag = text(row, "ON " .. Classes.AbilityKeys[slot], 11, class.Color, BOLD)
		tag.AutomaticSize = Enum.AutomaticSize.XY
		tag.Size = UDim2.fromOffset(0, 0)
	end
end

function AbilitiesUI.refresh()
	if not gui.Enabled then
		return
	end
	clear(body)
	local profile = GemClient.Profile
	local loadout = profile and profile.Character
	local class = loadout and Classes.get(loadout.Class)
	if not class then
		text(body, "Choose a class first.", 16, P.Dim)
		return
	end
	window.Subtitle.Text = string.format("%s  |  %s", class.Name, class.Resource)
	window.Subtitle.TextColor3 = class.Color
	local picks = {}
	for i, ability in Classes.loadout(class.Id, loadout.Abilities) do
		picks[i] = ability.Id
	end

	-- Six abilities, two columns.
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.64, 0, 1, 0) }, body)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 1 / 3, -8),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, ability in class.Abilities do
		card(grid, ability, class, i, picks)
	end

	-- Ultimate, weapon and armor.
	local side = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.64, 14, 0, 0),
		Size = UDim2.new(0.36, -14, 1, 0),
	}, body)
	UiKit.list(side, 10)
	local ultimate = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 150) }, side)
	new("UIGridLayout", { CellSize = UDim2.fromScale(1, 1) }, ultimate)
	card(ultimate, class.Ultimate, class, 1, nil)

	local weapon = Classes.weapon(class.Id, loadout.Weapon)
	local armor = Classes.armor(class.Id, loadout.Armor)
	local gear = box(side, UDim2.new(), UDim2.new(1, 0, 0, 0), P.Inset)
	gear.AutomaticSize = Enum.AutomaticSize.Y
	UiKit.pad(gear, 10)
	UiKit.list(gear, 3)
	if weapon then
		text(gear, "WEAPON: " .. weapon.Name, 13, P.Gold, BOLD)
		text(gear, AbilitiesUI.attackSummary(weapon.Attack), 11, class.Color, BOLD)
		text(gear, weapon.Passive.Name .. ": " .. weapon.Passive.Text, 12, P.Text)
	end
	if armor then
		text(gear, "ARMOR: " .. armor.Name, 13, P.Gold, BOLD)
		text(gear, armor.Passive.Name .. ": " .. armor.Passive.Text, 12, P.Text)
	end
	text(
		side,
		"Left click attacks (hold to keep swinging). Q, E and R cast your picks; F is your ultimate. Fight in the Arena or out the south gate.",
		12,
		P.Dim
	)
end

function AbilitiesUI.open()
	gui.Enabled = true
	window.Fit()
	AbilitiesUI.refresh()
end

function AbilitiesUI.close()
	gui.Enabled = false
	clear(body)
end

function AbilitiesUI.toggle()
	if gui.Enabled then
		AbilitiesUI.close()
	else
		AbilitiesUI.open()
	end
end

window.Close.Activated:Connect(AbilitiesUI.close)
window.Shade.Activated:Connect(AbilitiesUI.close)
GemClient.Changed:Connect(function()
	if gui.Enabled and not busy then
		AbilitiesUI.refresh()
	end
end)

return AbilitiesUI
