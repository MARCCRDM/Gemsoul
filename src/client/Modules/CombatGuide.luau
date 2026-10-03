-- Grounded combat guide: universal actions, exosuit techniques and socket-powered surges.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Classes = require(ReplicatedStorage.Shared.Classes)
local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local Actions = require(ReplicatedStorage.Shared.CombatActions)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
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
		"Stamina powers every swing, your guard, dodges and Rig Maneuvers (1 / 2 / 3); it refills once you ease off · Charge powers the gems in your Surge Array (Q / E / R)."
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
			string.format("ATTACK · LMB / Shift+LMB Off-hand / Touch · %d Stamina", Actions.swingCost(weapon, false)),
			string.format(
				"%.0f%% weapon damage · %.2fs recovery. Alternate sides for up to +20%% combo damage; a miss or block resets the combo. Out of Stamina you still swing, winded (%.0f%% damage).",
				rules.BasicDamage * 100,
				rules.BasicCooldown,
				Actions.Stamina.WindedDamage * 100
			),
		},
		{
			string.format("HEAVY · Hold then Release on Gold · %d Stamina", Actions.swingCost(weapon, true)),
			string.format(
				"%.0f%% PvE / %.0f%% PvP damage · %.2fs recovery · breaks sustained guard. Gold release guarantees a critical; overholding reduces damage. +%.0f%% heavy critical chance. Without the Stamina for it, it comes out as a light swing.",
				rules.HeavyDamage * 100,
				rules.HeavyPvPDamage * 100,
				rules.HeavyCooldown,
				rules.HeavyCrit * 100
			),
		},
		{
			"HOP · Tap Space · 8 Stamina",
			string.format(
				"A quick %.2g-stud sidestep · %.2gs cooldown · %.2gs PvE / %.2gs PvP immunity. Step out of a bolt or a blast ring.",
				Actions.Base.Hop.Distance,
				Actions.Base.Hop.Cooldown,
				Actions.Base.Hop.Invincible,
				Actions.Base.Hop.PvPInvincible
			),
		},
		{
			"ROLL · Double-tap Space · 15 Stamina",
			string.format(
				"%.2g studs · %.2fs cooldown · %.2gs PvE / %.2gs PvP immunity. Time it as the enemy's cast bar fills.",
				rules.DodgeDistance,
				rules.DodgeCooldown,
				rules.Invincible,
				rules.PvPInvincible
			),
		},
		{
			string.format("BLOCK · Hold RMB / Block Button · %d Stamina/s", Actions.Stamina.GuardDrain),
			string.format(
				"%.0f%% PvE / %.0f%% PvP reduction · %.0f° frontal coverage. Each blow you block costs Stamina (half its damage, at least %d); a blow you can't pay for breaks your guard. First 0.3s can parry a melee quick attack for free; high block refreshes every 1.5s. Cannot attack while blocking.%s",
				rules.BlockReduction * 100,
				rules.BlockPvPReduction * 100,
				rules.BlockArc,
				Actions.Stamina.BlockMin,
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
	local function card(titleText, color, description)
		local frame = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.new(1, -12, 0, 70) }, body)
		UiKit.round(frame, 8)
		local title = text(frame, titleText, 13, color, IronUi.Bold)
		title.Position, title.Size = UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 22)
		local line = text(frame, description, 12, P.Text)
		line.Position, line.Size = UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 34)
		line.TextWrapped = true
	end
	local function heading(value, color)
		local label = text(body, value, 14, color, IronUi.Bold)
		label.Size = UDim2.new(1, -12, 0, 26)
	end
	-- Rig Maneuvers: learned in the Augment Tree, put on keys 1-3 in the Loadout.
	heading("RIG MANEUVERS · STAMINA · KEYS 1 / 2 / 3", Tech.Resources.Stamina.Color)
	local equipped = loadout.Maneuvers or Tech.DefaultManeuvers
	for _, id in Tech.Order.RigManeuvers do
		local definition = Tree.techStats(profile, id)
		local learned = Tree.isLearned(profile, id)
		local key = table.find(equipped, id)
		card(
			string.format(
				"%s %s · %d Stamina%s",
				definition.Icon,
				definition.Name,
				math.floor(definition.Cost + 0.5),
				if key and learned then " · KEY " .. key else ""
			),
			if learned and key then P.Gold else P.Dim,
			definition.Description
				.. (
					if not learned
						then " Unlock this node in your Augment Tree (K)."
						elseif not key then " Put it on key 1, 2 or 3 in the Loadout (L)."
						else ""
				)
		)
	end
	-- Gem Surges: the gem in each Surge Array socket decides the ability.
	heading("GEM SURGES · CHARGE · Q / E / R", Tech.Resources.Charge.Color)
	local amps = Tree.effects(profile)
	for _, key in { "Q", "E", "R" } do
		local gem = Tech.surgeGem(loadout, key)
		local definition = gem and Tech.surgeStats(gem, amps)
		if definition then
			card(
				string.format(
					"%s %s · %s · Tier %d · Rank %d · %g Charge%s",
					key,
					definition.Icon,
					definition.Name,
					definition.Tier,
					definition.Rank,
					math.floor(definition.Cost * 10 + 0.5) / 10,
					if definition.PerSecond then "/s" else ""
				),
				GemConfig.ElementColors[gem.Element] or P.Gold,
				definition.Description
			)
		else
			card(
				key .. " · Empty socket",
				P.Dim,
				"Socket a cut gem in the Surge Array (L). Its element and surge tier pick the ability; Size, Clarity and Cut set damage, duration and critical chance."
			)
		end
	end
	for _, element in GemConfig.Elements do
		local names = {}
		for tier, id in Tech.Surges[element] do
			table.insert(names, string.format("T%d %s", tier, Tech.Catalog[id].Name))
		end
		local line = text(
			body,
			string.upper(GemConfig.elementName(element)) .. " · " .. table.concat(names, " · "),
			12,
			GemConfig.ElementColors[element]
		)
		line.Size, line.TextWrapped = UDim2.new(1, -12, 0, 18), true
	end
	local resonance = {}
	for tier, id in Tech.Resonance do
		table.insert(resonance, string.format("T%d %s", tier, Tech.Catalog[id].Name))
	end
	table.sort(resonance)
	local resonanceLine =
		text(body, "RESONANCE (any element) · " .. table.concat(resonance, " · "), 12, Tech.Resources.Charge.Color)
	resonanceLine.Size, resonanceLine.TextWrapped = UDim2.new(1, -12, 0, 18), true
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
