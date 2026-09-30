--[[
	Classes, starter gear and abilities. Shared by the server (which saves
	choices and builds gear on characters) and the client (intro screens).

	Stats are on a 1-5 scale: Health, Power, Defense, Speed. A class sets the
	base; its weapon and armor shift them (+1 / -1).

	Specs and their talent nodes are listed for the upcoming talent tree
	(chosen at level 5); only the class, core abilities and gear are live now.
]]

export type Stats = { Health: number, Power: number, Defense: number, Speed: number }
export type Gear = {
	Id: string,
	Name: string,
	Style: string,
	Description: string,
	Look: string, -- how Equipment draws it
	Mods: { [string]: number },
}
export type Ability = { Name: string, Description: string }
export type Spec = { Name: string, Style: string, Nodes: { string }, Signature: Ability }
export type Class = {
	Id: string,
	Name: string,
	Role: string,
	Tagline: string,
	Color: Color3,
	Resource: string,
	ArmorWeight: string,
	Difficulty: number,
	Stats: Stats,
	Abilities: { Ability },
	Weapons: { Gear },
	Armors: { Gear },
	Specs: { Spec },
}

local Classes = {}

Classes.StatNames = { "Health", "Power", "Defense", "Speed" }

Classes.Order = { "Warrior", "Wizard", "Archer", "Tank" }

Classes.List = {
	Warrior = {
		Id = "Warrior",
		Name = "Warrior",
		Role = "Melee damage",
		Tagline = "Charge in, hit hard, never back down.",
		Color = Color3.fromRGB(255, 90, 60),
		Resource = "Rage: builds as you hit and get hit",
		ArmorWeight = "Heavy",
		Difficulty = 1,
		Stats = { Health = 4, Power = 4, Defense = 3, Speed = 2 },
		Abilities = {
			{ Name = "Cleave", Description = "A wide swing that hits every enemy in front of you." },
			{ Name = "Charge", Description = "Dash to an enemy and stun it briefly." },
			{ Name = "Battle Cry", Description = "More damage for 8 seconds and a burst of Rage." },
		},
		Weapons = {
			{
				Id = "Longsword",
				Name = "Iron Longsword",
				Style = "Balanced",
				Description = "A reliable blade for every fight.",
				Look = "Sword",
				Mods = {},
			},
			{
				Id = "Greataxe",
				Name = "Iron Greataxe",
				Style = "Heavy hitter",
				Description = "Slow, brutal swings that crush armor.",
				Look = "Greataxe",
				Mods = { Power = 1, Speed = -1 },
			},
			{
				Id = "TwinBlades",
				Name = "Iron Twin Blades",
				Style = "Swift",
				Description = "A blade in each hand for a storm of quick cuts.",
				Look = "TwinBlades",
				Mods = { Speed = 1, Power = -1 },
			},
		},
		Armors = {
			{
				Id = "IronPlate",
				Name = "Iron Plate",
				Style = "Defensive",
				Description = "Full plate. Shrugs off blows but slows you down.",
				Look = "Plate",
				Mods = { Defense = 1, Speed = -1 },
			},
			{
				Id = "IronScale",
				Name = "Iron Scale",
				Style = "Balanced",
				Description = "Overlapping scales: solid protection that still moves.",
				Look = "Scale",
				Mods = {},
			},
			{
				Id = "IronChain",
				Name = "Iron Chainmail",
				Style = "Agile",
				Description = "Light links for warriors who never stand still.",
				Look = "Chain",
				Mods = { Speed = 1, Defense = -1 },
			},
		},
		Specs = {
			{
				Name = "Berserker",
				Style = "All-out damage",
				Nodes = { "Bloodlust: heal from damage dealt", "Frenzy: attack speed builds up" },
				Signature = { Name = "Rampage", Description = "A furious five-hit flurry." },
			},
			{
				Name = "Blademaster",
				Style = "Precision and crits",
				Nodes = { "Deep Wounds: crits cause bleeding", "Keen Edge: more critical hits" },
				Signature = { Name = "Execute", Description = "A massive hit on enemies below 25% health." },
			},
			{
				Name = "Warlord",
				Style = "Leader and buffer",
				Nodes = { "Rally: nearby allies deal more damage", "Second Wind: heal when low" },
				Signature = {
					Name = "War Banner",
					Description = "Plant a banner that boosts allies' attack and defense.",
				},
			},
		},
	},

	Wizard = {
		Id = "Wizard",
		Name = "Wizard",
		Role = "Ranged magic",
		Tagline = "Bend the elements from a safe distance.",
		Color = Color3.fromRGB(150, 90, 255),
		Resource = "Mana: spent on spells, refills over time",
		ArmorWeight = "Light",
		Difficulty = 3,
		Stats = { Health = 1, Power = 4, Defense = 1, Speed = 3 },
		Abilities = {
			{ Name = "Arcane Bolt", Description = "A bolt of magic in the element of your socketed gem." },
			{ Name = "Blink", Description = "Teleport a short distance." },
			{ Name = "Mana Shield", Description = "Absorb damage with your mana instead of health." },
		},
		Weapons = {
			{
				Id = "ArcStaff",
				Name = "Arc Staff",
				Style = "Power",
				Description = "A tall staff that channels devastating spells.",
				Look = "Staff",
				Mods = { Power = 1, Speed = -1 },
			},
			{
				Id = "WandTome",
				Name = "Wand and Tome",
				Style = "Quick casting",
				Description = "Fast spells from a wand, backed by a spellbook.",
				Look = "WandTome",
				Mods = { Speed = 1, Power = -1 },
			},
			{
				Id = "CrystalOrb",
				Name = "Crystal Orb",
				Style = "Protective",
				Description = "A floating orb that hardens your wards.",
				Look = "Orb",
				Mods = { Defense = 1, Power = -1 },
			},
		},
		Armors = {
			{
				Id = "ApprenticeRobes",
				Name = "Apprentice Robes",
				Style = "Balanced",
				Description = "Simple, comfortable robes of the Arcanum.",
				Look = "Robe",
				Mods = {},
			},
			{
				Id = "WardedRobes",
				Name = "Warded Robes",
				Style = "Defensive",
				Description = "Robes stitched with protective runes.",
				Look = "WardedRobe",
				Mods = { Defense = 1, Speed = -1 },
			},
			{
				Id = "WindwalkerWraps",
				Name = "Windwalker Wraps",
				Style = "Agile",
				Description = "Light wraps for a caster always on the move.",
				Look = "Wraps",
				Mods = { Speed = 1, Defense = -1 },
			},
		},
		Specs = {
			{
				Name = "Evoker",
				Style = "Burst damage",
				Nodes = { "Overload: more spell power", "Chain Cast: bolts bounce to a second target" },
				Signature = { Name = "Meteor", Description = "Call down a meteor on an area." },
			},
			{
				Name = "Summoner",
				Style = "Pets",
				Nodes = { "Familiar: a crystal sprite fights beside you", "Soul Link: pet damage heals you" },
				Signature = { Name = "Crystal Golem", Description = "Summon a golem for 20 seconds." },
			},
			{
				Name = "Chronomancer",
				Style = "Control",
				Nodes = { "Slow Field: enemies in an area slow down", "Mirror Image: decoys draw attacks" },
				Signature = { Name = "Time Stop", Description = "Freeze enemies in an area for 3 seconds." },
			},
		},
	},

	Archer = {
		Id = "Archer",
		Name = "Archer",
		Role = "Ranged physical",
		Tagline = "Strike first, from where they can't reach you.",
		Color = Color3.fromRGB(90, 220, 120),
		Resource = "Focus: refills steadily over time",
		ArmorWeight = "Medium",
		Difficulty = 2,
		Stats = { Health = 2, Power = 3, Defense = 2, Speed = 4 },
		Abilities = {
			{ Name = "Power Shot", Description = "A charged arrow that pierces through enemies." },
			{ Name = "Evasive Roll", Description = "Roll backward out of danger." },
			{ Name = "Volley", Description = "Rain arrows down on an area." },
		},
		Weapons = {
			{
				Id = "Longbow",
				Name = "Hunter's Longbow",
				Style = "Long range",
				Description = "Powerful shots from very far away.",
				Look = "Longbow",
				Mods = { Power = 1, Speed = -1 },
			},
			{
				Id = "Shortbow",
				Name = "Shortbow",
				Style = "Rapid fire",
				Description = "Loose arrows as fast as you can draw.",
				Look = "Shortbow",
				Mods = { Speed = 1, Power = -1 },
			},
			{
				Id = "Crossbow",
				Name = "Iron Crossbow",
				Style = "Armor piercing",
				Description = "Slow to reload, but every bolt punches through.",
				Look = "Crossbow",
				Mods = { Power = 1, Speed = -1 },
			},
		},
		Armors = {
			{
				Id = "HuntersLeather",
				Name = "Hunter's Leather",
				Style = "Balanced",
				Description = "Supple leather for the long hunt.",
				Look = "Leather",
				Mods = {},
			},
			{
				Id = "StuddedLeather",
				Name = "Studded Leather",
				Style = "Defensive",
				Description = "Leather reinforced with iron studs.",
				Look = "StuddedLeather",
				Mods = { Defense = 1, Speed = -1 },
			},
			{
				Id = "ShadowLeather",
				Name = "Shadow Leather",
				Style = "Agile",
				Description = "Dark, silent leather for moving unseen.",
				Look = "ShadowLeather",
				Mods = { Speed = 1, Defense = -1 },
			},
		},
		Specs = {
			{
				Name = "Marksman",
				Style = "Sniper",
				Nodes = { "Steady Aim: more damage while standing still", "Headhunter: more critical hits" },
				Signature = { Name = "Deadeye", Description = "One devastating long-range shot." },
			},
			{
				Name = "Beastmaster",
				Style = "Pet",
				Nodes = { "Mech Hound: a robotic hunting dog", "Pack Bond: you and the hound share buffs" },
				Signature = { Name = "Stampede", Description = "A pack of hounds charges through enemies." },
			},
			{
				Name = "Trapper",
				Style = "Traps and poison",
				Nodes = { "Snare Trap: roots enemies in place", "Toxic Tips: arrows poison over time" },
				Signature = { Name = "Minefield", Description = "Throw three exploding traps." },
			},
		},
	},

	Tank = {
		Id = "Tank",
		Name = "Tank",
		Role = "Protector",
		Tagline = "Stand in front. Take the hits. Keep everyone alive.",
		Color = Color3.fromRGB(80, 170, 255),
		Resource = "Resolve: builds as you take damage",
		ArmorWeight = "Fortified",
		Difficulty = 1,
		Stats = { Health = 5, Power = 2, Defense = 4, Speed = 1 },
		Abilities = {
			{ Name = "Shield Bash", Description = "Stun an enemy and make it focus on you." },
			{ Name = "Challenge Roar", Description = "Every nearby enemy turns to attack you." },
			{ Name = "Bulwark", Description = "Take half damage for 5 seconds." },
		},
		Weapons = {
			{
				Id = "SwordShield",
				Name = "Sword and Shield",
				Style = "Balanced",
				Description = "The classic guard: strike and block.",
				Look = "SwordShield",
				Mods = {},
			},
			{
				Id = "MaceTower",
				Name = "Mace and Tower Shield",
				Style = "Immovable",
				Description = "A shield as tall as you are.",
				Look = "MaceShield",
				Mods = { Defense = 1, Speed = -1 },
			},
			{
				Id = "Warhammer",
				Name = "Iron Warhammer",
				Style = "Offensive",
				Description = "Give up the shield to hit back hard.",
				Look = "Warhammer",
				Mods = { Power = 1, Defense = -1 },
			},
		},
		Armors = {
			{
				Id = "IronBulwark",
				Name = "Iron Bulwark",
				Style = "Balanced",
				Description = "Heavy plate built to hold the line.",
				Look = "Bulwark",
				Mods = {},
			},
			{
				Id = "TowerPlate",
				Name = "Tower Plate",
				Style = "Defensive",
				Description = "The thickest armor in the kingdom.",
				Look = "TowerPlate",
				Mods = { Defense = 1, Speed = -1 },
			},
			{
				Id = "VanguardPlate",
				Name = "Vanguard Plate",
				Style = "Agile",
				Description = "Lighter plate for tanks who lead the charge.",
				Look = "Vanguard",
				Mods = { Speed = 1, Defense = -1 },
			},
		},
		Specs = {
			{
				Name = "Guardian",
				Style = "Pure defense",
				Nodes = { "Thick Skin: more defense", "Last Stand: survive one killing blow" },
				Signature = { Name = "Fortress", Description = "Become immovable and reflect damage." },
			},
			{
				Name = "Paladin",
				Style = "Holy support",
				Nodes = { "Healing Aura: heal nearby allies", "Blessed Strikes: your hits heal allies" },
				Signature = { Name = "Consecration", Description = "Holy ground that hurts enemies and heals allies." },
			},
			{
				Name = "Juggernaut",
				Style = "Offensive tank",
				Nodes = { "Momentum: moving builds speed and damage", "Crushing Blows: break enemy armor" },
				Signature = { Name = "Earthshatter", Description = "Slam the ground and knock enemies into the air." },
			},
		},
	},
} :: { [string]: Class }

function Classes.get(classId: any): Class?
	return if typeof(classId) == "string" then Classes.List[classId] else nil
end

local function find(list: { Gear }, id: any): Gear?
	for _, gear in list do
		if gear.Id == id then
			return gear
		end
	end
	return nil
end

function Classes.weapon(classId: any, weaponId: any): Gear?
	local class = Classes.get(classId)
	return class and find(class.Weapons, weaponId)
end

function Classes.armor(classId: any, armorId: any): Gear?
	local class = Classes.get(classId)
	return class and find(class.Armors, armorId)
end

-- Final 1-5 stats for a class with the given weapon and armor.
function Classes.stats(classId: string, weaponId: string?, armorId: string?): Stats
	local class = Classes.List[classId]
	local stats = table.clone(class.Stats)
	local function apply(gear: Gear?)
		if gear then
			for stat, change in gear.Mods do
				stats[stat] = math.clamp(stats[stat] + change, 1, 5)
			end
		end
	end
	apply(Classes.weapon(classId, weaponId))
	apply(Classes.armor(classId, armorId))
	return stats
end

return Classes
