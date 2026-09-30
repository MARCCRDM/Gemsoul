--[[
	Classes, gear and abilities. Shared by the server (which saves choices,
	builds gear on characters and runs combat) and the client (screens, HUD).

	Stats are on a 1-5 scale: Health, Power, Defense, Speed. A class sets the
	base; its weapon and armor shift them (+1 / -1).

	Each class has:
	  * 4 weapons. A weapon sets your basic attack (click) and has a passive.
	  * 3 armors, each with a passive.
	  * 6 abilities: equip any 3 on Q / E / R. Plus an ultimate on F.
	  * a resource that abilities spend: Rage, Mana, Focus or Resolve.
	Specs and their talent nodes are listed for the upcoming talent tree.

	Ability and attack numbers are read by the server's combat code; see
	shared/Combat.luau for how damage, resources and effects work.
]]

export type Stats = { Health: number, Power: number, Defense: number, Speed: number }
-- Basic attack: "Melee" swings hit every enemy in a cone in front of you;
-- "Shot" fires at the aimed point and hits the first enemy in the way.
export type Attack = {
	Kind: "Melee" | "Shot",
	Damage: number,
	Range: number,
	Rate: number, -- seconds between attacks
	Arc: number?, -- melee cone width in degrees
	Combo: number?, -- melee: every Nth swing is a finisher (x1.6 damage)
}
-- A passive changes how gear plays. Effect keys are handled by Combat.
export type Passive = { Name: string, Text: string, Effect: { [string]: any } }
export type Gear = {
	Id: string,
	Name: string,
	Style: string,
	Description: string,
	Look: string, -- how Equipment draws it
	Mods: { [string]: number },
	Attack: Attack?, -- weapons
	Passive: Passive,
}
export type Ability = {
	Id: string,
	Name: string,
	Description: string,
	Kind: string, -- see Combat.luau: Cone, Nova, Dash, Bolt, Buff, Zone
	Cooldown: number,
	Cost: number?, -- resource spent
	Gain: number?, -- resource gained
	Ultimate: boolean?,
	[string]: any, -- the kind's own numbers
}
export type SpecAbility = { Name: string, Description: string }
export type Spec = { Name: string, Style: string, Nodes: { string }, Signature: SpecAbility }
export type Class = {
	Id: string,
	Name: string,
	Role: string,
	Tagline: string,
	Color: Color3,
	ResourceId: string,
	Resource: string,
	ArmorWeight: string,
	Difficulty: number,
	Stats: Stats,
	Abilities: { Ability }, -- six; any three go on Q / E / R
	Ultimate: Ability,
	Weapons: { Gear },
	Armors: { Gear },
	Specs: { Spec },
}

local Crafting = require(script.Parent.Crafting)
local GemConfig = require(script.Parent.GemConfig)

local Classes = {}

Classes.StatNames = { "Health", "Power", "Defense", "Speed" }
Classes.Order = { "Warrior", "Wizard", "Archer", "Tank" }
Classes.AbilityKeys = { "Q", "E", "R" }
Classes.UltimateKey = "F"

-- Armor passives, one per style.
local BASTION = { Name = "Bastion", Text = "Take 12% less damage.", Effect = { TakenMult = 0.88 } }
local ATTUNED = { Name = "Attuned", Text = "Abilities recharge 10% faster.", Effect = { CooldownMult = 0.9 } }
local FLEET = { Name = "Fleet", Text = "+2 walk speed.", Effect = { SpeedAdd = 2 } }

Classes.List = {
	Warrior = {
		Id = "Warrior",
		Name = "Warrior",
		Role = "Melee damage",
		Tagline = "Charge in, hit hard, never back down.",
		Color = Color3.fromRGB(255, 90, 60),
		ResourceId = "Rage",
		Resource = "Rage: builds as you hit and get hit, fades out of combat",
		ArmorWeight = "Heavy",
		Difficulty = 1,
		Stats = { Health = 4, Power = 4, Defense = 3, Speed = 2 },
		Abilities = {
			{
				Id = "Cleave",
				Name = "Cleave",
				Description = "A wide swing that hits every enemy in front of you.",
				Kind = "Cone",
				Damage = 22,
				Range = 9,
				Arc = 150,
				Cost = 20,
				Cooldown = 4,
			},
			{
				Id = "Charge",
				Name = "Charge",
				Description = "Dash forward, stunning enemies where you land. Builds Rage.",
				Kind = "Dash",
				Distance = 22,
				Damage = 12,
				Radius = 7,
				Stun = 1,
				Gain = 20,
				Cooldown = 10,
			},
			{
				Id = "BattleCry",
				Name = "Battle Cry",
				Description = "Deal 30% more damage for 8 seconds and gain a burst of Rage.",
				Kind = "Buff",
				Duration = 8,
				DamageMult = 1.3,
				Gain = 30,
				Cooldown = 20,
			},
			{
				Id = "Whirlwind",
				Name = "Whirlwind",
				Description = "Spin with your weapon out, hitting everything around you.",
				Kind = "Nova",
				Damage = 28,
				Radius = 10,
				Cost = 35,
				Cooldown = 8,
			},
			{
				Id = "Execute",
				Name = "Execute",
				Description = "A heavy blow that deals triple damage to enemies below 30% health.",
				Kind = "Cone",
				Damage = 30,
				Range = 8,
				Arc = 70,
				ExecuteBelow = 0.3,
				ExecuteMult = 3,
				Cost = 30,
				Cooldown = 6,
			},
			{
				Id = "IronWill",
				Name = "Iron Will",
				Description = "Take 40% less damage for 5 seconds and heal 15% of your health.",
				Kind = "Buff",
				Duration = 5,
				TakenMult = 0.6,
				Heal = 0.15,
				Cooldown = 25,
			},
		},
		Ultimate = {
			Id = "Rampage",
			Name = "Rampage",
			Description = "For 10 seconds: 50% more damage, 40% faster attacks. Heals 20% of your health.",
			Kind = "Buff",
			Duration = 10,
			DamageMult = 1.5,
			RateMult = 0.6,
			Heal = 0.2,
			Ultimate = true,
			Cooldown = 60,
		},
		Weapons = {
			{
				Id = "Longsword",
				Name = "Iron Longsword",
				Style = "Balanced",
				Description = "A reliable blade for every fight. A three-swing combo.",
				Look = "Sword",
				Mods = {},
				Attack = { Kind = "Melee", Damage = 14, Range = 7, Arc = 100, Rate = 0.55, Combo = 3 },
				Passive = { Name = "Keen Edge", Text = "+10% critical hit chance.", Effect = { CritAdd = 0.1 } },
			},
			{
				Id = "Greataxe",
				Name = "Iron Greataxe",
				Style = "Heavy hitter",
				Description = "Slow, brutal swings that cleave through crowds.",
				Look = "Greataxe",
				Mods = { Power = 1, Speed = -1 },
				Attack = { Kind = "Melee", Damage = 24, Range = 8, Arc = 140, Rate = 0.95, Combo = 2 },
				Passive = {
					Name = "Armor Breaker",
					Text = "Hits make enemies take 8% more damage for 5s (stacks 3 times).",
					Effect = { Sunder = 0.08 },
				},
			},
			{
				Id = "TwinBlades",
				Name = "Iron Twin Blades",
				Style = "Swift",
				Description = "A blade in each hand for a storm of quick cuts.",
				Look = "TwinBlades",
				Mods = { Speed = 1, Power = -1 },
				Attack = { Kind = "Melee", Damage = 8, Range = 6, Arc = 90, Rate = 0.32, Combo = 4 },
				Passive = {
					Name = "Lacerate",
					Text = "Hits make enemies bleed for 30% more damage over 3s.",
					Effect = { Bleed = 0.3 },
				},
			},
			{
				Id = "Spear",
				Name = "Iron Spear",
				Style = "Reach",
				Description = "Keep them at a distance with long, straight thrusts.",
				Look = "Spear",
				Mods = { Speed = 1, Defense = -1 },
				Attack = { Kind = "Melee", Damage = 13, Range = 11, Arc = 35, Rate = 0.6, Combo = 3 },
				Passive = {
					Name = "Impale",
					Text = "Thrusts reach 11 studs and hit every enemy in the line.",
					Effect = {},
				},
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
				Passive = BASTION,
			},
			{
				Id = "IronScale",
				Name = "Iron Scale",
				Style = "Balanced",
				Description = "Overlapping scales: solid protection that still moves.",
				Look = "Scale",
				Mods = {},
				Passive = ATTUNED,
			},
			{
				Id = "IronChain",
				Name = "Iron Chainmail",
				Style = "Agile",
				Description = "Light links for warriors who never stand still.",
				Look = "Chain",
				Mods = { Speed = 1, Defense = -1 },
				Passive = FLEET,
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
		ResourceId = "Mana",
		Resource = "Mana: spent on spells, refills steadily",
		ArmorWeight = "Light",
		Difficulty = 3,
		Stats = { Health = 1, Power = 4, Defense = 1, Speed = 3 },
		Abilities = {
			{
				Id = "ArcaneBolt",
				Name = "Arcane Bolt",
				Description = "A fast bolt of pure magic.",
				Kind = "Bolt",
				Damage = 26,
				Range = 60,
				Cost = 12,
				Cooldown = 1.5,
			},
			{
				Id = "Blink",
				Name = "Blink",
				Description = "Teleport forward in a flash.",
				Kind = "Dash",
				Distance = 24,
				Teleport = true,
				Cost = 15,
				Cooldown = 8,
			},
			{
				Id = "ManaShield",
				Name = "Mana Shield",
				Description = "A barrier that absorbs 60 damage for 8 seconds.",
				Kind = "Buff",
				Duration = 8,
				Shield = 60,
				Cost = 25,
				Cooldown = 18,
			},
			{
				Id = "FrostNova",
				Name = "Frost Nova",
				Description = "Blast of cold around you that slows enemies by 50% for 3 seconds.",
				Kind = "Nova",
				Damage = 12,
				Radius = 11,
				Slow = 0.5,
				SlowTime = 3,
				Cost = 20,
				Cooldown = 12,
			},
			{
				Id = "Fireball",
				Name = "Fireball",
				Description = "A slow ball of fire that explodes and burns everything nearby.",
				Kind = "Bolt",
				Damage = 30,
				Range = 55,
				Splash = 8,
				Burn = 0.5,
				Cost = 25,
				Cooldown = 6,
			},
			{
				Id = "ChainLightning",
				Name = "Chain Lightning",
				Description = "A bolt that jumps to three more enemies.",
				Kind = "Bolt",
				Damage = 20,
				Range = 55,
				Chain = 3,
				Cost = 22,
				Cooldown = 7,
			},
		},
		Ultimate = {
			Id = "Meteor",
			Name = "Meteor",
			Description = "Call down a meteor on the aimed spot: huge damage and a 1.5s stun.",
			Kind = "Nova",
			AtTarget = true,
			TargetRange = 60,
			Damage = 90,
			Radius = 14,
			Stun = 1.5,
			Delay = 0.8,
			Ultimate = true,
			Cooldown = 60,
		},
		Weapons = {
			{
				Id = "ArcStaff",
				Name = "Arc Staff",
				Style = "Power",
				Description = "A tall staff that channels devastating bolts.",
				Look = "Staff",
				Mods = { Power = 1, Speed = -1 },
				Attack = { Kind = "Shot", Damage = 20, Range = 55, Rate = 0.9 },
				Passive = {
					Name = "Blast",
					Text = "Bolts explode, hitting enemies within 6 studs for half damage.",
					Effect = { Splash = 6 },
				},
			},
			{
				Id = "WandTome",
				Name = "Wand and Tome",
				Style = "Quick casting",
				Description = "Rapid bolts from a wand, backed by a spellbook.",
				Look = "WandTome",
				Mods = { Speed = 1, Power = -1 },
				Attack = { Kind = "Shot", Damage = 9, Range = 45, Rate = 0.35 },
				Passive = { Name = "Arcane Flow", Text = "Each hit restores 3 Mana.", Effect = { ResourceOnHit = 3 } },
			},
			{
				Id = "CrystalOrb",
				Name = "Crystal Orb",
				Style = "Protective",
				Description = "A floating orb that hardens your wards.",
				Look = "Orb",
				Mods = { Defense = 1, Power = -1 },
				Attack = { Kind = "Shot", Damage = 12, Range = 40, Rate = 0.6 },
				Passive = {
					Name = "Crystal Ward",
					Text = "Every 8 seconds, gain a shield that absorbs 25 damage.",
					Effect = { Ward = 25 },
				},
			},
			{
				Id = "StormScepter",
				Name = "Storm Scepter",
				Style = "Chaining",
				Description = "Crackling bolts that leap between enemies.",
				Look = "Scepter",
				Mods = { Speed = 1, Defense = -1 },
				Attack = { Kind = "Shot", Damage = 11, Range = 45, Rate = 0.55 },
				Passive = {
					Name = "Arc Lightning",
					Text = "Bolts jump to a second enemy for 60% damage.",
					Effect = { Chain = 0.6 },
				},
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
				Passive = ATTUNED,
			},
			{
				Id = "WardedRobes",
				Name = "Warded Robes",
				Style = "Defensive",
				Description = "Robes stitched with protective runes.",
				Look = "WardedRobe",
				Mods = { Defense = 1, Speed = -1 },
				Passive = BASTION,
			},
			{
				Id = "WindwalkerWraps",
				Name = "Windwalker Wraps",
				Style = "Agile",
				Description = "Light wraps for a caster always on the move.",
				Look = "Wraps",
				Mods = { Speed = 1, Defense = -1 },
				Passive = FLEET,
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
		ResourceId = "Focus",
		Resource = "Focus: spent on shots and tricks, refills quickly",
		ArmorWeight = "Medium",
		Difficulty = 2,
		Stats = { Health = 2, Power = 3, Defense = 2, Speed = 4 },
		Abilities = {
			{
				Id = "PowerShot",
				Name = "Power Shot",
				Description = "A heavy arrow that pierces every enemy in a line.",
				Kind = "Bolt",
				Damage = 34,
				Range = 90,
				Pierce = true,
				Cost = 25,
				Cooldown = 5,
			},
			{
				Id = "EvasiveRoll",
				Name = "Evasive Roll",
				Description = "Roll backward out of danger and regain Focus.",
				Kind = "Dash",
				Distance = 16,
				Backward = true,
				Gain = 15,
				Cooldown = 7,
			},
			{
				Id = "Volley",
				Name = "Volley",
				Description = "Rain arrows on the aimed spot for 4 seconds.",
				Kind = "Zone",
				AtTarget = true,
				TargetRange = 70,
				Radius = 10,
				Duration = 4,
				Tick = 8,
				Cost = 35,
				Cooldown = 12,
			},
			{
				Id = "SnareTrap",
				Name = "Snare Trap",
				Description = "A trap at the aimed spot that roots enemies inside for 5 seconds.",
				Kind = "Zone",
				AtTarget = true,
				TargetRange = 40,
				Radius = 7,
				Duration = 5,
				Tick = 3,
				Slow = 1,
				SlowTime = 1,
				Cost = 20,
				Cooldown = 14,
			},
			{
				Id = "PoisonArrow",
				Name = "Poison Arrow",
				Description = "An arrow that poisons for heavy damage over 5 seconds.",
				Kind = "Bolt",
				Damage = 12,
				Range = 80,
				Poison = 3,
				Cost = 15,
				Cooldown = 6,
			},
			{
				Id = "RapidFire",
				Name = "Rapid Fire",
				Description = "Attack 50% faster for 6 seconds.",
				Kind = "Buff",
				Duration = 6,
				RateMult = 0.5,
				Cost = 30,
				Cooldown = 18,
			},
		},
		Ultimate = {
			Id = "RainOfArrows",
			Name = "Rain of Arrows",
			Description = "A storm of arrows over a wide area for 6 seconds.",
			Kind = "Zone",
			AtTarget = true,
			TargetRange = 80,
			Radius = 16,
			Duration = 6,
			Tick = 14,
			Ultimate = true,
			Cooldown = 60,
		},
		Weapons = {
			{
				Id = "Longbow",
				Name = "Hunter's Longbow",
				Style = "Long range",
				Description = "Powerful shots from very far away.",
				Look = "Longbow",
				Mods = { Power = 1, Speed = -1 },
				Attack = { Kind = "Shot", Damage = 18, Range = 90, Rate = 0.8 },
				Passive = {
					Name = "Steady Aim",
					Text = "+30% damage to enemies more than 30 studs away.",
					Effect = { FarBonus = 0.3 },
				},
			},
			{
				Id = "Shortbow",
				Name = "Shortbow",
				Style = "Rapid fire",
				Description = "Loose arrows as fast as you can draw.",
				Look = "Shortbow",
				Mods = { Speed = 1, Power = -1 },
				Attack = { Kind = "Shot", Damage = 8, Range = 60, Rate = 0.3 },
				Passive = { Name = "Quick Draw", Text = "Each hit restores 2 Focus.", Effect = { ResourceOnHit = 2 } },
			},
			{
				Id = "Crossbow",
				Name = "Iron Crossbow",
				Style = "Armor piercing",
				Description = "Slow to reload, but every bolt punches through.",
				Look = "Crossbow",
				Mods = { Power = 1, Speed = -1 },
				Attack = { Kind = "Shot", Damage = 22, Range = 70, Rate = 1 },
				Passive = {
					Name = "Punch Through",
					Text = "Bolts pierce every enemy in a line.",
					Effect = { Pierce = true },
				},
			},
			{
				Id = "ThrowingKnives",
				Name = "Throwing Knives",
				Style = "Close quarters",
				Description = "A bandolier of knives for fast, bloody work up close.",
				Look = "Knives",
				Mods = { Power = 1, Defense = -1 },
				Attack = { Kind = "Shot", Damage = 7, Range = 30, Rate = 0.28 },
				Passive = {
					Name = "Serrated",
					Text = "Hits make enemies bleed for 40% more damage over 3s.",
					Effect = { Bleed = 0.4 },
				},
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
				Passive = ATTUNED,
			},
			{
				Id = "StuddedLeather",
				Name = "Studded Leather",
				Style = "Defensive",
				Description = "Leather reinforced with iron studs.",
				Look = "StuddedLeather",
				Mods = { Defense = 1, Speed = -1 },
				Passive = BASTION,
			},
			{
				Id = "ShadowLeather",
				Name = "Shadow Leather",
				Style = "Agile",
				Description = "Dark, silent leather for moving unseen.",
				Look = "ShadowLeather",
				Mods = { Speed = 1, Defense = -1 },
				Passive = FLEET,
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
		ResourceId = "Resolve",
		Resource = "Resolve: builds as you take and deal hits, fades out of combat",
		ArmorWeight = "Fortified",
		Difficulty = 1,
		Stats = { Health = 5, Power = 2, Defense = 4, Speed = 1 },
		Abilities = {
			{
				Id = "ShieldBash",
				Name = "Shield Bash",
				Description = "Stun the enemy in front of you and make it attack you. Builds Resolve.",
				Kind = "Cone",
				Damage = 14,
				Range = 7,
				Arc = 70,
				Stun = 1.5,
				Taunt = 4,
				Gain = 15,
				Cooldown = 6,
			},
			{
				Id = "ChallengeRoar",
				Name = "Challenge Roar",
				Description = "Every enemy nearby turns to attack you. Builds Resolve.",
				Kind = "Nova",
				Damage = 0,
				Radius = 16,
				Taunt = 6,
				Gain = 25,
				Cooldown = 12,
			},
			{
				Id = "Bulwark",
				Name = "Bulwark",
				Description = "Take 50% less damage for 5 seconds.",
				Kind = "Buff",
				Duration = 5,
				TakenMult = 0.5,
				Cost = 30,
				Cooldown = 15,
			},
			{
				Id = "GroundSlam",
				Name = "Ground Slam",
				Description = "Slam the ground, hurting and slowing enemies around you by 40%.",
				Kind = "Nova",
				Damage = 20,
				Radius = 10,
				Slow = 0.4,
				SlowTime = 3,
				Cost = 20,
				Cooldown = 8,
			},
			{
				Id = "GuardianCharge",
				Name = "Guardian Charge",
				Description = "Dash forward and knock enemies where you land off their feet.",
				Kind = "Dash",
				Distance = 18,
				Damage = 10,
				Radius = 7,
				Stun = 0.8,
				Taunt = 3,
				Cooldown = 12,
			},
			{
				Id = "SecondWind",
				Name = "Second Wind",
				Description = "Heal 30% of your health.",
				Kind = "Buff",
				Duration = 0,
				Heal = 0.3,
				Cost = 40,
				Cooldown = 30,
			},
		},
		Ultimate = {
			Id = "Fortress",
			Name = "Fortress",
			Description = "For 8 seconds take 70% less damage; every nearby enemy is taunted. Heals 20%.",
			Kind = "Buff",
			Duration = 8,
			TakenMult = 0.3,
			Heal = 0.2,
			TauntRadius = 18,
			Taunt = 8,
			Ultimate = true,
			Cooldown = 60,
		},
		Weapons = {
			{
				Id = "SwordShield",
				Name = "Sword and Shield",
				Style = "Balanced",
				Description = "The classic guard: strike and block.",
				Look = "SwordShield",
				Mods = {},
				Attack = { Kind = "Melee", Damage = 11, Range = 7, Arc = 100, Rate = 0.6, Combo = 3 },
				Passive = { Name = "Shield Wall", Text = "Take 15% less damage.", Effect = { TakenMult = 0.85 } },
			},
			{
				Id = "MaceTower",
				Name = "Mace and Tower Shield",
				Style = "Immovable",
				Description = "A shield as tall as you are.",
				Look = "MaceShield",
				Mods = { Defense = 1, Speed = -1 },
				Attack = { Kind = "Melee", Damage = 12, Range = 6.5, Arc = 90, Rate = 0.75, Combo = 3 },
				Passive = { Name = "Tower Guard", Text = "Take 25% less damage.", Effect = { TakenMult = 0.75 } },
			},
			{
				Id = "Warhammer",
				Name = "Iron Warhammer",
				Style = "Offensive",
				Description = "Give up the shield to hit back hard.",
				Look = "Warhammer",
				Mods = { Power = 1, Defense = -1 },
				Attack = { Kind = "Melee", Damage = 22, Range = 8, Arc = 120, Rate = 1, Combo = 2 },
				Passive = {
					Name = "Concussive",
					Text = "Combo finishers stun enemies for 1 second.",
					Effect = { FinisherStun = 1 },
				},
			},
			{
				Id = "Halberd",
				Name = "Iron Halberd",
				Style = "Control",
				Description = "Wide, sweeping arcs that hold a whole pack at bay.",
				Look = "Halberd",
				Mods = { Power = 1, Speed = -1 },
				Attack = { Kind = "Melee", Damage = 15, Range = 10, Arc = 160, Rate = 0.8, Combo = 3 },
				Passive = {
					Name = "Hook",
					Text = "Hits slow enemies by 25% for 2 seconds.",
					Effect = { SlowOnHit = 0.25 },
				},
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
				Passive = ATTUNED,
			},
			{
				Id = "TowerPlate",
				Name = "Tower Plate",
				Style = "Defensive",
				Description = "The thickest armor in the kingdom.",
				Look = "TowerPlate",
				Mods = { Defense = 1, Speed = -1 },
				Passive = BASTION,
			},
			{
				Id = "VanguardPlate",
				Name = "Vanguard Plate",
				Style = "Agile",
				Description = "Lighter plate for tanks who lead the charge.",
				Look = "Vanguard",
				Mods = { Speed = 1, Defense = -1 },
				Passive = FLEET,
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

function Classes.ability(classId: any, abilityId: any): Ability?
	local class = Classes.get(classId)
	if not class then
		return nil
	end
	if class.Ultimate.Id == abilityId then
		return class.Ultimate
	end
	for _, ability in class.Abilities do
		if ability.Id == abilityId then
			return ability
		end
	end
	return nil
end

-- The three abilities on Q / E / R: the saved picks if they're valid,
-- otherwise the class's first three.
function Classes.loadout(classId: any, picks: { any }?): { Ability }
	local class = Classes.get(classId)
	if not class then
		return {}
	end
	local chosen, seen = {}, {}
	for i = 1, 3 do
		local id = picks and picks[i]
		local ability = Classes.ability(classId, id)
		if ability and not ability.Ultimate and not seen[id] then
			chosen[i] = ability
			seen[id] = true
		end
	end
	-- Fill gaps with the first abilities not already chosen.
	for i = 1, 3 do
		if not chosen[i] then
			for _, ability in class.Abilities do
				if not seen[ability.Id] then
					chosen[i] = ability
					seen[ability.Id] = true
					break
				end
			end
		end
	end
	return chosen
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

-- Ratings for the character screen: each 1-5 stat point is worth 20, gear
-- quality adds to that, and socketed gems add their bonuses on top.
-- Element is the gem that gives the largest bonus, for colouring it.
export type Rating = { Base: number, Bonus: number, Element: string? }
function Classes.ratings(loadout: { [string]: any }): { [string]: Rating }
	local stats = Classes.stats(loadout.Class, loadout.Weapon, loadout.Armor)
	local ratings = {}
	for _, name in Classes.StatNames do
		ratings[name] = { Base = stats[name] * 20, Bonus = 0 }
	end
	-- Better-made gear (Fine, Superior, Masterwork) raises the base.
	for kind, key in { Weapons = "Weapon", Armors = "Armor" } do
		for stat, amount in Crafting.qualityBonus(kind, loadout[key .. "Quality"]) do
			ratings[stat].Base += amount
		end
	end
	for _, slot in { "Weapon", "Armor" } do
		local gem = loadout[slot .. "Gem"]
		if gem then
			for stat, amount in GemConfig.statBonuses(gem, slot) do
				local rating = ratings[stat]
				if amount > rating.Bonus then
					rating.Element = gem.Element
				end
				rating.Bonus += amount
			end
		end
	end
	return ratings
end

-- What ratings do to the avatar (16 speed and 100 health at ratings of 40
-- and 67, the Roblox defaults).
function Classes.walkSpeed(speedRating: number): number
	return math.clamp(12 + speedRating * 0.1, 12, 28)
end

function Classes.maxHealth(healthRating: number): number
	return math.floor(60 + healthRating * 0.6)
end

return Classes
