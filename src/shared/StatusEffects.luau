--[[
	Buffs and debuffs, shown like an RPG's status bar: who is Burning,
	Slowed (Cryo), Frozen, Shocked, has their armor shredded, and so on.

	The server works out each fighter's active effects and writes them to
	one attribute, "Statuses", on the player or the enemy model:

	  "Burning:1234.50:0,Slowed:1233.10:30"   (id : ends at, server time : value)

	Clients decode it and draw the icons (see the combat HUD). Which gem does
	what:

	  Thermal    Burning (damage every second); a critical burn adds
	             Grievous Wounds (healing received -30%)
	  Cryo       Slowed; sometimes Frozen solid
	  Ion        chain arcs; sometimes Shocked (stunned)
	  Corrosive  Armor Shred; sometimes Vulnerable and Mortal Strike
	             (healing received -20%)
]]
local Status = {}

local GOLD = Color3.fromRGB(255, 196, 90)
local RED = Color3.fromRGB(220, 60, 60)
local THERMAL = Color3.fromRGB(238, 62, 54)
local CRYO = Color3.fromRGB(64, 150, 255)
local ION = Color3.fromRGB(255, 212, 40)
local CORROSIVE = Color3.fromRGB(70, 205, 90)
local BARRIER = Color3.fromRGB(150, 225, 255)

export type Effect = {
	Name: string,
	Tag: string?, -- the element or source, e.g. "Cryo"
	Icon: string,
	Color: Color3,
	Debuff: boolean,
	Text: string, -- %d is replaced with the value
	Order: number,
}

-- In display order: buffs first, then debuffs, most dangerous first.
Status.Catalog = {
	Shielded = {
		Name = "Shielded",
		Icon = "🛡",
		Color = BARRIER,
		Debuff = false,
		Text = "Absorbs the next %d damage.",
	},
	EnergySiphon = {
		Name = "Energy Siphon",
		Tag = "Resonance",
		Icon = "🔋",
		Color = GOLD,
		Debuff = false,
		Text = "Soaks up %d damage and turns it into Charge.",
	},
	CryoShield = {
		Name = "Cryo Shield",
		Tag = "Cryo",
		Icon = "💠",
		Color = CRYO,
		Debuff = false,
		Text = "A cryogenic barrier halves incoming damage.",
	},
	ResonanceEcho = {
		Name = "Resonance Echo",
		Tag = "Resonance",
		Icon = "〰",
		Color = GOLD,
		Debuff = false,
		Text = "Weapon strikes hit harder.",
	},
	Frozen = {
		Name = "Frozen",
		Tag = "Cryo",
		Icon = "🧊",
		Color = CRYO,
		Debuff = true,
		Text = "Frozen solid: can't move or act.",
	},
	Shocked = {
		Name = "Shocked",
		Tag = "Ion",
		Icon = "⚡",
		Color = ION,
		Debuff = true,
		Text = "Ion shock: can't move or act.",
	},
	Stunned = { Name = "Stunned", Icon = "💫", Color = GOLD, Debuff = true, Text = "Stunned: can't move or act." },
	Staggered = { Name = "Staggered", Icon = "💥", Color = GOLD, Debuff = true, Text = "Reeling: can't move or act." },
	GuardBroken = { Name = "Guard Broken", Icon = "💔", Color = RED, Debuff = true, Text = "Can't raise a guard." },
	Burning = {
		Name = "Burning",
		Tag = "Thermal",
		Icon = "🔥",
		Color = THERMAL,
		Debuff = true,
		Text = "Takes Thermal damage every second.",
	},
	Bleeding = {
		Name = "Bleeding",
		Icon = "🩸",
		Color = RED,
		Debuff = true,
		Text = "Takes damage every half second.",
	},
	BurningWard = {
		Name = "Burning Ward",
		Tag = "Thermal",
		Icon = "🔥",
		Color = THERMAL,
		Debuff = false,
		Text = "A barrier that sets anyone who hits you alight.",
	},
	StaticShell = {
		Name = "Static Shell",
		Tag = "Ion",
		Icon = "⚡",
		Color = ION,
		Debuff = false,
		Text = "A barrier that shocks anyone who hits you.",
	},
	RiposteStance = {
		Name = "Riposte Stance",
		Icon = "🤺",
		Color = GOLD,
		Debuff = false,
		Text = "Braced: the next blow is turned aside and answered.",
	},
	Silenced = {
		Name = "Interrupted",
		Icon = "🔇",
		Color = RED,
		Debuff = true,
		Text = "Surges locked.",
	},
	Blinded = {
		Name = "Blinded",
		Tag = "Thermal",
		Icon = "🌞",
		Color = THERMAL,
		Debuff = true,
		Text = "%d%% of attacks miss.",
	},
	Slowed = { Name = "Slowed", Tag = "Cryo", Icon = "❄", Color = CRYO, Debuff = true, Text = "Moves %d%% slower." },
	ArmorShred = {
		Name = "Armor Shred",
		Tag = "Corrosive",
		Icon = "🧪",
		Color = CORROSIVE,
		Debuff = true,
		Text = "Armor reduced by %d%%.",
	},
	Vulnerable = {
		Name = "Vulnerable",
		Tag = "Corrosive",
		Icon = "🎯",
		Color = CORROSIVE,
		Debuff = true,
		Text = "Takes %d%% more damage.",
	},
	Exposed = { Name = "Exposed", Icon = "⚠", Color = GOLD, Debuff = true, Text = "Takes %d%% more damage." },
	Weakened = {
		Name = "Weakened",
		Tag = "Corrosive",
		Icon = "🥀",
		Color = CORROSIVE,
		Debuff = true,
		Text = "Deals %d%% less damage.",
	},
	GrievousWounds = {
		Name = "Grievous Wounds",
		Tag = "Thermal",
		Icon = "🚫",
		Color = THERMAL,
		Debuff = true,
		Text = "Healing received -30%.",
	},
	MortalStrike = {
		Name = "Mortal Strike",
		Tag = "Corrosive",
		Icon = "☠",
		Color = CORROSIVE,
		Debuff = true,
		Text = "Healing received -20%.",
	},
}
-- The Q / E / R triad's buffs and debuffs (TriadServer).
local function entry(name, tag, icon, color, debuff, text)
	return { Name = name, Tag = tag, Icon = icon, Color = color, Debuff = debuff, Text = text }
end
local triadEffects = {
	Empowered = entry("Empowered", nil, "⚔", GOLD, false, "Your next %d swings carry your sword's element."),
	Overheated = entry("Thermal Burst", "Thermal", "🔥", THERMAL, false, "Deals %d%% more damage."),
	EmberGuard = entry("Ember Guard", "Thermal", "🛡", THERMAL, false, "Guard up: blocked hits burn back."),
	FireWall = entry("Fire Wall", "Thermal", "🧱", THERMAL, false, "A wall of fire stops bolts in front of you."),
	FrozenWall = entry("Frozen Wall", "Cryo", "🧊", CRYO, false, "Every frontal hit stops on the ice."),
	-- The showcase defenses.
	RingOfFire = entry("Ring of Fire", "Thermal", "⭕", THERMAL, false, "Whoever crosses your ring of flame burns and is thrown back."),
	IcePillar = entry("Ice Pillar", "Cryo", "🗻", CRYO, false, "Up on the ice: out of reach of swords."),
	TeslaFence = entry("Tesla Fence", "Ion", "⚡", ION, false, "Your fence stops bolts and stuns whoever crosses."),
	HoloDecoy = entry("Hologram Decoy", "Ion", "👤", ION, false, "Your decoy bursts when a foe gets close."),
	SporeWall = entry("Spore Wall", "Corrosive", "🌫", CORROSIVE, false, "Your fog wall stops bolts and poisons whoever walks through."),
	AcidSlick = entry("Acid Slick", "Corrosive", "💧", CORROSIVE, false, "Foes on your slick slide, slowed and corroded."),
	PhoenixMantle = entry("Phoenix Mantle", "Thermal", "🕊", THERMAL, false, "A fall under 20% health becomes a rebirth."),
	Regrowth = entry("Regrowth", nil, "✚", CORROSIVE, false, "Healing over time."),
	IceArmor = entry("Ice Armor", "Cryo", "🧊", CRYO, false, "Takes %d%% less damage."),
	ColdResolve = entry("Cold Resolve", "Cryo", "❄", CRYO, false, "+%d%% resistance to every element."),
	FrostRiposte = entry("Frost Riposte", "Cryo", "🤺", CRYO, false, "A timed block freezes the attacker."),
	StaticCatch = entry("Static Catch", "Ion", "⚡", ION, false, "Wider parry; a parry stuns and steals Charge."),
	Deflector = entry("Deflector Field", "Ion", "🔰", ION, false, "Bolts bounce back at whoever threw them."),
	Grounded = entry("Grounded", "Ion", "⏚", ION, false, "Immune to stun, slow and freeze."),
	Purged = entry("Purge Shell", "Corrosive", "🫧", CORROSIVE, false, "Immune to new debuffs."),
	CorrosionAura = entry("Corrosion Aura", "Corrosive", "☣", CORROSIVE, false, "Nearby enemies lose Stamina and defense."),
	ToxicMantle = entry("Toxic Mantle", "Corrosive", "🦂", CORROSIVE, false, "Melee attackers are poisoned for %d%% of their hit."),
	Untargetable = entry("Untargetable", nil, "👻", GOLD, false, "Nothing can touch you."),
	Poisoned = entry("Poisoned", "Corrosive", "☠", CORROSIVE, true, "Takes damage every second."),
	Chilled = entry("Chilled", "Cryo", "❄", CRYO, true, "%d of 3 Chill: at 3 you freeze."),
	Branded = entry("Branded", "Ion", "🎯", ION, true, "Hits on you arc and steal Charge."),
	Rooted = entry("Rooted", "Cryo", "🌱", CRYO, true, "Held in place."),
}
for id, effect in triadEffects do
	(Status.Catalog :: any)[id] = effect
end
Status.Order = {
	"Shielded",
	"EnergySiphon",
	"CryoShield",
	"ResonanceEcho",
	"BurningWard",
	"StaticShell",
	"RiposteStance",
	"PhoenixMantle",
	"FrozenWall",
	"FireWall",
	"RingOfFire",
	"IcePillar",
	"TeslaFence",
	"HoloDecoy",
	"SporeWall",
	"AcidSlick",
	"EmberGuard",
	"IceArmor",
	"ColdResolve",
	"Grounded",
	"Purged",
	"Deflector",
	"StaticCatch",
	"FrostRiposte",
	"ToxicMantle",
	"CorrosionAura",
	"Regrowth",
	"Overheated",
	"Empowered",
	"Untargetable",
	"Frozen",
	"Shocked",
	"Stunned",
	"Staggered",
	"GuardBroken",
	"Silenced",
	"Blinded",
	"Burning",
	"Poisoned",
	"Bleeding",
	"Rooted",
	"Chilled",
	"Branded",
	"Slowed",
	"ArmorShred",
	"Vulnerable",
	"Exposed",
	"Weakened",
	"GrievousWounds",
	"MortalStrike",
}
for i, id in Status.Order do
	(Status.Catalog :: any)[id].Order = i
end

export type Active = { Id: string, Ends: number, Value: number }

-- The name with its source, e.g. "Slowed (Cryo)".
function Status.label(id: string): string
	local effect = Status.Catalog[id]
	if not effect then
		return id
	end
	return if effect.Tag then string.format("%s (%s)", effect.Name, effect.Tag) else effect.Name
end

function Status.describe(id: string, value: number?): string
	local effect = Status.Catalog[id]
	if not effect then
		return ""
	end
	return if string.find(effect.Text, "%d", 1, true)
		then string.format(effect.Text, math.floor((value or 0) + 0.5))
		else effect.Text
end

-- A list of active effects -> the attribute string. Unknown or expired
-- effects are dropped; the strongest/longest of a repeated id is kept.
function Status.encode(list: { Active }, now: number): string
	local best: { [string]: Active } = {}
	for _, active in list do
		if Status.Catalog[active.Id] and active.Ends > now then
			local held = best[active.Id]
			if not held or active.Ends > held.Ends or (active.Value or 0) > (held.Value or 0) then
				best[active.Id] = {
					Id = active.Id,
					Ends = math.max(active.Ends, if held then held.Ends else 0),
					Value = math.max(active.Value or 0, if held then held.Value or 0 else 0),
				}
			end
		end
	end
	local parts = {}
	for _, id in Status.Order do
		local active = best[id]
		if active then
			-- Rounded so small clock jitter doesn't resend the attribute.
			table.insert(parts, string.format("%s:%.1f:%d", id, active.Ends, math.floor(active.Value + 0.5)))
		end
	end
	return table.concat(parts, ",")
end

function Status.decode(text: string?): { Active }
	local list = {}
	if type(text) ~= "string" then
		return list
	end
	for id, ends, value in string.gmatch(text, "(%w+):([%d%.]+):(%-?%d+)") do
		if Status.Catalog[id] then
			table.insert(list, { Id = id, Ends = tonumber(ends) :: number, Value = tonumber(value) :: number })
		end
	end
	return list
end

return Status
