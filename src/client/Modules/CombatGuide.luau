-- Grounded combat guide: universal actions, exosuit techniques and socket-powered surges.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Classes = require(ReplicatedStorage.Shared.Classes)
local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local Actions = require(ReplicatedStorage.Shared.CombatActions)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local AugmentTreeUI = require(script.Parent.AugmentTreeUI)
local GemClient = require(script.Parent.GemClient)
local ArenaScene = require(script.Parent.ArenaScene)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local CombatGuide = {}
local P = IronUi.Colors
local new, text, clear = IronUi.new, IronUi.text, IronUi.clear
local window = IronUi.window("Combat", 9, 980, 620, "⚔️")
window.Title.Text = "WARRIOR COMBAT"
local gui = window.Gui
local body = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Position = UDim2.fromOffset(24, 76),
	Size = UDim2.new(1, -48, 1, -100),
}, window.Panel)
function CombatGuide.refresh()
	if not gui.Enabled then
		return
	end
	clear(body)
	local profile = GemClient.Profile
	local loadout = profile and profile.Character
	if not loadout then
		return
	end
	window.Subtitle.Text =
		"Health · Stamina powers Rig Maneuvers · Charge powers socketed Gem Surges. Z/X cycle; R/F trigger."
	local weapon = Classes.weapon(loadout.Class, loadout.Weapon)
	local sets = Classes.setState(loadout)
	local effects = Classes.effects(loadout)
	local rules = Actions.resolve(
		sets.Counts,
		if weapon and weapon.Attack.Kind == "Melee" then "Sword" else "Pistol",
		1 - (effects.CooldownMult or 1)
	)
	UiKit.list(body, 10)
	local rows = {
		{
			"ATTACK · LMB / Q Left / E Right / Touch",
			string.format(
				"%.0f%% weapon damage · %.2fs recovery. Alternate sides for up to +20%% combo damage; a miss or block resets the combo.",
				rules.BasicDamage * 100,
				rules.BasicCooldown
			),
		},
		{
			"HEAVY · Hold then Release on Gold",
			string.format(
				"%.0f%% PvE / %.0f%% PvP damage · %.2fs recovery · breaks sustained guard. Gold release guarantees a critical; overholding reduces damage. +%.0f%% heavy critical chance.",
				rules.HeavyDamage * 100,
				rules.HeavyPvPDamage * 100,
				rules.HeavyCooldown,
				rules.HeavyCrit * 100
			),
		},
		{
			"DODGE · Space / Dodge Button · 15 Stamina",
			string.format(
				"%.2g studs · %.2fs cooldown · %.2gs PvE / %.2gs PvP immunity. Rolls in your movement direction.",
				rules.DodgeDistance,
				rules.DodgeCooldown,
				rules.Invincible,
				rules.PvPInvincible
			),
		},
		{
			"BLOCK · Hold RMB / Block Button",
			string.format(
				"%.0f%% PvE / %.0f%% PvP reduction · %.0f° frontal coverage. First 0.3s can parry a melee quick attack; high block refreshes every 1.5s. Cannot attack while blocking.%s",
				rules.BlockReduction * 100,
				rules.BlockPvPReduction * 100,
				rules.BlockArc,
				if rules.Deflect then " Deflects light projectiles." else ""
			),
		},
	}
	for _, row in rows do
		local card = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.new(1, 0, 0, 60) }, body)
		UiKit.round(card, 8)
		local title = text(card, row[1], 14, P.Gold, IronUi.Bold)
		title.Position = UDim2.fromOffset(12, 6)
		local description = text(card, row[2], 12, P.Text)
		description.Position = UDim2.fromOffset(12, 28)
		description.Size = UDim2.new(1, -24, 0, 28)
		description.TextWrapped = true
	end
	for _, group in { "RigManeuvers", "GemSurges" } do
		local heading = text(
			body,
			if group == "RigManeuvers" then "RIG MANEUVERS · STAMINA · R / Z" else "GEM SURGES · CHARGE · F / X",
			14,
			if group == "RigManeuvers" then Tech.Resources.Stamina.Color else Tech.Resources.Charge.Color,
			IronUi.Bold
		)
		heading.Size = UDim2.new(1, -12, 0, 26)
		for _, id in Tech.Order[group] do
			local definition = Tech.Catalog[id]
			local learned = Tree.isLearned(profile, id)
			local available = learned and (definition.Resource ~= "Charge" or Tech.hasGem(loadout, definition.Element))
			local card = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.new(1, -12, 0, 70) }, body)
			UiKit.round(card, 8)
			local title = text(
				card,
				string.format(
					"%s %s · %d %s%s",
					definition.Icon,
					definition.Name,
					definition.Cost,
					definition.Resource,
					if definition.PerSecond then "/s" else ""
				),
				13,
				if available then P.Gold else P.Dim,
				IronUi.Bold
			)
			title.Position, title.Size = UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 22)
			local description = text(
				card,
				definition.Description
					.. (
						if not learned
							then " Unlock this node in your Augment Tree (K)."
							elseif not available then " Socket a compatible gem to power this surge."
							else ""
					),
				12,
				P.Text
			)
			description.Position, description.Size = UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 34)
			description.TextWrapped = true
		end
	end
	local augments = text(
		body,
		"PASSIVE AUGMENTS · Your equipped gear applies these bonuses automatically.",
		13,
		P.Gold,
		IronUi.Bold
	)
	augments.Size, augments.TextWrapped = UDim2.new(1, -12, 0, 32), true
	for _, family in ArmorFamilies.Order do
		local line = text(
			body,
			string.format(
				"%s %d/6 · %d-piece bonus. %s",
				family,
				sets.Active[family].Count,
				sets.Active[family].Tier,
				ArmorFamilies.EnhancementText[family]
			),
			12,
			if (sets.Counts[family] or 0) >= 2 then P.Teal else P.Dim
		)
		line.Size = UDim2.new(1, 0, 0, 36)
		line.TextWrapped = true
	end
	local treeButton = IronUi.gemButton(body, "OPEN AUGMENT TREE · K", P.Gold, function()
		CombatGuide.close()
		AugmentTreeUI.open()
	end)
	treeButton.Size = UDim2.fromOffset(250, 36)
	local training = IronUi.gemButton(body, "TRAIN ON DUMMIES", P.Teal, function()
		CombatGuide.close()
		ArenaScene.enter(false)
	end)
	training.Size = UDim2.fromOffset(230, 36)
	local pvp = IronUi.gemButton(body, "ENTER PVP ARENA", P.Gold, function()
		CombatGuide.close()
		ArenaScene.enter(true)
	end)
	pvp.Size = UDim2.fromOffset(230, 36)
end
function CombatGuide.isOpen()
	return gui.Enabled
end
function CombatGuide.open()
	gui.Enabled = true
	window.Fit()
	CombatGuide.refresh()
end
function CombatGuide.close()
	gui.Enabled = false
	clear(body)
end
function CombatGuide.toggle()
	if gui.Enabled then
		CombatGuide.close()
	else
		CombatGuide.open()
	end
end
window.Close.Activated:Connect(CombatGuide.close)
window.Shade.Activated:Connect(CombatGuide.close)
GemClient.Changed:Connect(CombatGuide.refresh)
return CombatGuide
