local colorMt = { __index = {
	Lerp = function(self, _other, _amount)
		return self
	end,
} }
local Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r, G = g, B = b, kind = "Color3" }, colorMt)
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
local vmt = {}
local Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x, Y = y, Z = z }, vmt)
	end,
}
vmt.__mul = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
local cmt = {
	__mul = function(a, _b)
		return a
	end,
}
local CFrame = {
	new = function(...)
		return setmetatable({}, cmt)
	end,
}
CFrame.Angles = CFrame.new
CFrame.identity = CFrame.new()
local enumMt = {
	__index = function(_self, key)
		return key
	end,
}
local Enum = setmetatable({}, {
	__index = function(self, key)
		local t = setmetatable({}, enumMt)
		rawset(self, key, t)
		return t
	end,
})
local built = 0
local builtParts = {}
local Instance = {
	new = function(className)
		local values = { ClassName = className }
		return setmetatable({}, {
			__index = values,
			__newindex = function(_self, key, value)
				if key == "Color" then
					assert(
						type(value) == "table" and value.kind == "Color3",
						"Invalid Color assignment: " .. type(value)
					)
				end
				if key == "Size" then
					assert(value.X > 0 and value.Y > 0 and value.Z > 0, "Invalid part size")
				end
				values[key] = value
				if key == "Parent" and (className == "Part" or className == "WedgePart") then
					built += 1
					table.insert(builtParts, values)
				end
			end,
		})
	end,
}

local randomSeed = 123
local Random = {
	new = function(seed)
		randomSeed += 1
		local state = seed or randomSeed
		return {
			NextNumber = function(_self, low, high)
				state = (state * 48271) % 2147483647
				return (low or 0) + state / 2147483647 * ((high or 1) - (low or 0))
			end,
			NextInteger = function(_self, low, high)
				state = (state * 48271) % 2147483647
				return low + state % (high - low + 1)
			end,
		}
	end,
}
-- Clock, physics and remotes are deterministic; rules/handlers are the production modules.
local now = 100
local os = { clock = function() return now end }
local math = table.clone(math)
math.random = function() return 1 end -- disable random crit/stagger except when explicitly tested
local function typeof(v)
	if getmetatable(v) == vmt then return "Vector3" end
	return type(v)
end
vmt.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmt.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__div = function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
vmt.__index = function(v,key)
	if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
	if key=="Unit" then return v/v.Magnitude end
	if key=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
Vector3.zero=Vector3.new(0,0,0)
local messages, playerList, registered, listeners = {}, {}, {}, {}
local function signal()
	local callbacks={}
	local event={Connect=function(_,fn) table.insert(callbacks,fn); return {Disconnect=function() end} end}
	function event.Fire(...) for _,fn in callbacks do fn(...) end end
	return event
end
local Players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return playerList end}
local arena=Vector3.new(600,0,0)
local landmarks={GetAttribute=function(_,key) return if key=="ArenaFloor" then arena elseif key=="ArenaRadius" then 30 else nil end}
local ReplicatedStorage={FindFirstChild=function(_,key) return if key=="Landmarks" then landmarks else nil end}
local RunService={Heartbeat=signal()}
local Debris={AddItem=function(_,obj,seconds) table.insert(listeners,{Object=obj,Seconds=seconds}) end}
local services={Players=Players,ReplicatedStorage=ReplicatedStorage,RunService=RunService,Debris=Debris}
local game={GetService=function(_,name) assert(services[name],name); return services[name] end}
local wallBlocks, wallDistance = false, nil
local workspace={
	FindFirstChild=function() return nil end,
	FindFirstChildWhichIsA=function() return nil end,
	Raycast=function() return if wallBlocks then {Distance=2} else nil end,
	Blockcast=function() return if wallDistance then {Distance=wallDistance} else nil end,
	GetServerTimeNow=function() return os.clock() end,
}
CFrame.lookAt=function(position) return {Position=position} end
local RaycastParams={new=function() return {} end}
local Remotes={
	CombatInput={OnServerEvent=signal()},
	CombatFx={FireAllClients=function(_,...) table.insert(messages,{...}) end,FireClient=function(_,player,...) table.insert(messages,{Player=player,...}) end},
}
local Shop={register=function(name,fn) registered[name]=fn end,reply=function(ok,message) return {Ok=ok,Message=message} end}
local Config={MaxGems=200,MarketSellRate=0.5}
local enemyList={}
local Enemies={
	all=function() return enemyList end,
	damage=function(enemy,amount) enemy.Humanoid.Health-=amount; enemy.Hits=(enemy.Hits or 0)+1 end,
	addStatus=function(enemy,kind,amount,seconds) enemy.Status={kind,amount,seconds} end,
	addDot=function(enemy,amount) enemy.Burn=amount end,
}
local EquipmentBalance=(function()
-- One passive equipment budget, independent of armor ratings and temporary rig maneuvers.
local Balance = {}
Balance.MaxDamageReduction = 0.20
Balance.MaxCooldownReduction = 0.60
Balance.MaxCriticalChance = 0.75
Balance.MaxHazardResistance = 0.60
Balance.UtilityCooldowns = { Reflection = 25, PhaseDodge = 30, FirstHitGuard = 30 }
function Balance.passiveDamageMultiplier(taken, resistance)
	return math.max(
		1 - Balance.MaxDamageReduction,
		math.clamp(taken or 1, 0, 1) * (1 - math.clamp(resistance or 0, 0, 1))
	)
end
function Balance.cooldownMultiplier(value)
	return math.clamp(value or 1, 1 - Balance.MaxCooldownReduction, 1)
end
function Balance.criticalChance(speed, bonus)
	-- Rating contributes at most 2.5 points, leaving room for item critical bonuses.
	return math.clamp(0.05 + math.min(math.max(speed, 0) / 4000, 0.025) + (bonus or 0), 0, Balance.MaxCriticalChance)
end
function Balance.hazardResistance(value)
	return math.clamp(value or 0, 0, Balance.MaxHazardResistance)
end
-- Future utility handlers must share the player's gate per utility, not per item.
-- Pass server monotonic time; consuming this gate does not execute the utility.
function Balance.consumeUtility(gates, utility, now)
	local cooldown = Balance.UtilityCooldowns[utility]
	if not cooldown or now < (gates[utility] or 0) then
		return false
	end
	gates[utility] = now + cooldown
	return true
end
return Balance

end)()
local ExpeditionEconomy=(function()
-- Migration and reward compatibility for the loot-and-trade expedition economy.
local Economy = {}
local rates = { Iron = 12, Timber = 8, Leather = 10, Cloth = 10, Mithril = 60, Shards = 20 }

--[[
	Gem potency is an economy number only; combat reads Size, Clarity and Cut
	directly (GemConfig.stats). Cut weighs most because precision is the
	rarest endgame stat.
	  Value = Base Tier Value x (Size x 10 + Clarity x 5 + Cut x 15) x scale
	The scale keeps the average mined gem's price where the economy expects it.
]]
Economy.GemValueScale = 0.045
function Economy.gemPotency(gem)
	return gem.Size * 10 + gem.Clarity * 5 + (gem.Cut or 0) * 15
end
function Economy.gemValue(gem, tierValue)
	return math.max(1, math.floor(tierValue * Economy.gemPotency(gem) * Economy.GemValueScale + 0.5))
end
function Economy.legacyCredits(marks, materials)
	local coins = math.max(0, marks or 0)
	for id, count in materials or {} do
		coins += math.max(0, count) * (rates[id] or 1)
	end
	return math.floor(coins)
end
function Economy.migrate(profile, rng)
	local gems, seen = {}, {}
	local function collect(gem)
		if not gem then
			return
		end
		table.insert(gems, gem)
		if gem.Cut then
			seen[gem.Id] = gem.Cut
		end
	end
	for _, gem in profile.Gems or {} do
		collect(gem)
	end
	local c = profile.Character
	for _, slot in { "Weapon", "Armor", "Helmet", "Gloves", "Boots", "Shield" } do
		collect(c[slot .. "Gem"])
		for _, gem in c.ItemGems and c.ItemGems[slot] or {} do
			collect(gem)
		end
	end
	for _, gem in gems do
		if not gem.Cut then
			gem.Cut = seen[gem.Id] or rng:NextInteger(1, 10)
			gem.CutMethod = "Natural"
			seen[gem.Id] = gem.Cut
		end
	end
	if profile.ExpeditionEconomyVersion ~= 1 then
		profile.Coins += Economy.legacyCredits(profile.Marks, profile.Materials)
		profile.Marks = 0
		profile.Materials = {}
		profile.ExpeditionEconomyVersion = 1
	end
end
return Economy

end)()
local CrowdControl=(function()
--[[
	Crowd control and debuff rules from the PvP balance framework. Pure logic
	with no services, shared by the server (which applies them) and tests.

	Diminishing returns (PvP): within 10 seconds of the last landed CC,
	each new one lasts 100% / 50% / 25% / 0% (immune). 10 seconds without a
	landed CC resets it. PvP CC never lasts longer than 0.5 seconds.

	Anti-heal: Thermal Grievous Wounds 30%, Corrosive Mortal Strike 20%,
	together capped at 50%. Each lasts 4 seconds and refreshes on a new
	application; durations don't add up.

	Debuffs (PvP): capped at 30%, and the same debuff from several sources
	doesn't stack: the strongest one applies.
]]
local CrowdControl = {}

CrowdControl.Window = 10
CrowdControl.Steps = { 1, 0.5, 0.25, 0 }
CrowdControl.MaxPvPSeconds = 0.5
CrowdControl.HealCuts = { GrievousWounds = 0.30, MortalStrike = 0.20 }
CrowdControl.HealCutCap = 0.5
CrowdControl.HealCutSeconds = 4
CrowdControl.DebuffCap = 0.30

export type Tracker = {
	Count: number, -- CCs landed in the current window
	Last: number, -- when the last one landed
	HealCuts: { [string]: number }, -- kind -> expires at
	Debuffs: { [string]: { Amount: number, Until: number } },
}

function CrowdControl.new(): Tracker
	return { Count = 0, Last = -math.huge, HealCuts = {}, Debuffs = {} }
end

-- How long a stun/freeze/root really lasts. PvE is unchanged; PvP is capped
-- and diminished. Only a CC that lands (more than 0s) extends the window.
function CrowdControl.ApplyCC(tracker: Tracker, seconds: number, now: number, pvp: boolean?): number
	if not pvp then
		return seconds
	end
	if now - tracker.Last >= CrowdControl.Window then
		tracker.Count = 0
	end
	local step = CrowdControl.Steps[tracker.Count + 1] or 0
	local duration = math.min(seconds, CrowdControl.MaxPvPSeconds) * step
	if duration > 0 then
		tracker.Count += 1
		tracker.Last = now
	end
	return duration
end

function CrowdControl.applyHealCut(tracker: Tracker, kind: string, now: number)
	if CrowdControl.HealCuts[kind] then
		tracker.HealCuts[kind] = now + CrowdControl.HealCutSeconds
	end
end

-- Multiply incoming healing by this.
function CrowdControl.healingMultiplier(tracker: Tracker, now: number): number
	local total = 0
	for kind, expires in tracker.HealCuts do
		if now < expires then
			total += CrowdControl.HealCuts[kind] or 0
		end
	end
	return 1 - math.min(CrowdControl.HealCutCap, total)
end

-- Applies a debuff (slow, shred, vulnerability) and returns its strength now.
function CrowdControl.applyDebuff(
	tracker: Tracker,
	kind: string,
	amount: number,
	seconds: number,
	now: number,
	pvp: boolean?
): number
	local current = tracker.Debuffs[kind]
	local active = current and now < current.Until
	if pvp then
		amount = math.min(amount, CrowdControl.DebuffCap)
		amount = if active then math.max(current.Amount, amount) else amount
	elseif active then
		amount += current.Amount
	end
	tracker.Debuffs[kind] = {
		Amount = amount,
		Until = math.max(if active then current.Until else 0, now + seconds),
	}
	return amount
end

function CrowdControl.debuff(tracker: Tracker, kind: string, now: number): number
	local current = tracker.Debuffs[kind]
	return if current and now < current.Until then current.Amount else 0
end

-- Removes the longest-lasting debuff or healing cut. Returns its name, if any.
function CrowdControl.cleanse(tracker: Tracker, now: number): string?
	local worst, worstUntil, isCut = nil, now, false
	for kind, debuff in tracker.Debuffs do
		if debuff.Until > worstUntil then
			worst, worstUntil, isCut = kind, debuff.Until, false
		end
	end
	for kind, expires in tracker.HealCuts do
		if expires > worstUntil then
			worst, worstUntil, isCut = kind, expires, true
		end
	end
	if worst then
		if isCut then
			tracker.HealCuts[worst] = nil
		else
			tracker.Debuffs[worst] = nil
		end
	end
	return worst
end

return CrowdControl

end)()
local StatusEffects=(function()
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
Status.Order = {
	"Shielded",
	"EnergySiphon",
	"CryoShield",
	"ResonanceEcho",
	"BurningWard",
	"StaticShell",
	"RiposteStance",
	"Frozen",
	"Shocked",
	"Stunned",
	"Staggered",
	"GuardBroken",
	"Silenced",
	"Blinded",
	"Burning",
	"Bleeding",
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

end)()
local ElementCombos=(function()
--[[
	Element combos: one effect sets up another. The same rules apply to
	everyone (players and the rival), on weapon blows, maneuvers and surges.

	  Shatter       a heavy blow on a Frozen target: +60% damage, and the
	                ice breaks (the freeze ends)
	  Combustion    Fire damage on a target with its armor shredded
	                (Poison): +35% damage
	  Superconduct  Shock damage on a Slowed target (Frost, Armor Melt):
	                a 0.6s stun

	  ElementCombos.check(hit, target)  pure: the combo a hit sets off, or nil
	    hit     { Element = "Fire" | ..., Heavy = boolean }
	    target  { Frozen = boolean, Shredded = boolean, Slowed = boolean }
	    returns id, { Mult = number?, EndFreeze = boolean?, Stun = number? }
]]
local ElementCombos = {}

ElementCombos.List = {
	Shatter = {
		Name = "Shatter",
		Text = "SHATTER!",
		Color = Color3.fromRGB(150, 210, 255),
		Mult = 1.6,
		EndFreeze = true,
	},
	Combustion = {
		Name = "Combustion",
		Text = "COMBUSTION!",
		Color = Color3.fromRGB(255, 140, 60),
		Mult = 1.35,
	},
	Superconduct = {
		Name = "Superconduct",
		Text = "SUPERCONDUCT!",
		Color = Color3.fromRGB(255, 225, 90),
		Stun = 0.6,
	},
}

function ElementCombos.check(hit, target)
	if not hit or not target then
		return nil, nil
	end
	local id = if hit.Heavy and target.Frozen
		then "Shatter"
		elseif hit.Element == "Fire" and target.Shredded then "Combustion"
		elseif hit.Element == "Shock" and target.Slowed then "Superconduct"
		else nil
	return id, if id then ElementCombos.List[id] else nil
end

return ElementCombos

end)()
local ElementMatchup=(function()
--[[
	Elements against armor. Every gem in an armor piece (helmet, chest suit,
	gloves, boots, shield) resists its own element, more for a finer gem:

	  per gem   3.5% (grades all 1) up to 8% (grades all 10) of that
	            element's damage, by the gem's average grade
	  total     capped at 35% per element

	Your main armor element (the one your gems resist most) is weak to the
	element that beats it: that element does 125%. Thermal beats Cryo, Cryo
	beats Ion, Ion beats Corrosive, Corrosive beats Thermal. Resisting the
	element you're weak to softens it.

	Dungeon creatures keep a fixed element and weakness (versus: 75% / 125%).
	Pure, for tests.

	  ElementMatchup.gemResist(gem) -> share of its element a gem resists
	  ElementMatchup.profile(loadout) -> { Resist = { [element]: share }, Main = element? }
	  ElementMatchup.against(attack, profile) -> number, "Resist" | "Weak" | nil
	  ElementMatchup.versus(attack, element, weakness?) -> number, tag (creatures)
	  ElementMatchup.weakTo(element) -> the element that beats it
]]
local ElementMatchup = {}

ElementMatchup.Resist = 0.75 -- a creature against its own element
ElementMatchup.Weak = 1.25
ElementMatchup.PerGem = { Min = 0.035, Max = 0.08 }
ElementMatchup.Cap = 0.35
ElementMatchup.Slots = { "Helmet", "Armor", "Gloves", "Boots", "Shield" }
ElementMatchup.Beats = { Fire = "Frost", Frost = "Shock", Shock = "Poison", Poison = "Fire" }

function ElementMatchup.weakTo(element: string?): string?
	for attack, victim in ElementMatchup.Beats do
		if victim == element then
			return attack
		end
	end
	return nil
end

-- A gem's average grade (1-10; a rough gem's missing Cut doesn't count).
local function grade(gem): number
	local total, count = 0, 0
	for _, metric in { "Size", "Clarity", "Cut" } do
		if type(gem[metric]) == "number" then
			total += gem[metric]
			count += 1
		end
	end
	return if count > 0 then math.clamp(total / count, 1, 10) else 1
end

function ElementMatchup.gemResist(gem): number
	if not gem or not gem.Element then
		return 0
	end
	local span = ElementMatchup.PerGem
	return span.Min + (span.Max - span.Min) * (grade(gem) - 1) / 9
end

function ElementMatchup.profile(loadout)
	local resist, main, best = {}, nil, 0
	if loadout then
		for _, slot in ElementMatchup.Slots do
			local gem = loadout[slot .. "Gem"]
			if gem and gem.Element then
				resist[gem.Element] = (resist[gem.Element] or 0) + ElementMatchup.gemResist(gem)
			end
		end
		-- The main element: resisted most (the chest suit's breaks a tie).
		local chest = loadout.ArmorGem and loadout.ArmorGem.Element
		for element, share in resist do
			if share > best + 1e-9 or (math.abs(share - best) <= 1e-9 and element == chest) then
				main, best = element, share
			end
		end
		for element, share in resist do
			resist[element] = math.min(share, ElementMatchup.Cap)
		end
	end
	return { Resist = resist, Main = main }
end

local function tagOf(mult: number): string?
	return if mult < 0.999 then "Resist" elseif mult > 1.001 then "Weak" else nil
end

function ElementMatchup.against(attack: string?, profile): (number, string?)
	if not attack or not profile then
		return 1, nil
	end
	local mult = 1 - (profile.Resist[attack] or 0)
	if profile.Main and attack == ElementMatchup.weakTo(profile.Main) then
		mult *= ElementMatchup.Weak
	end
	return mult, tagOf(mult)
end

function ElementMatchup.versus(attack: string?, element: string?, weakness: string?): (number, string?)
	if not attack or not element then
		return 1, nil
	end
	if attack == (weakness or ElementMatchup.weakTo(element)) then
		return ElementMatchup.Weak, "Weak"
	end
	if attack == element then
		return ElementMatchup.Resist, "Resist"
	end
	return 1, nil
end

return ElementMatchup

end)()
local Matchmaking=(function()
--[[
	Arena duels between players: the rules both sides share.

	  Modes                       "1v1" (solo) and "2v2" (a party of two)
	  Matchmaking.versus(a, b)    may these two players hurt each other? Duel
	                              opponents only, and never your own party
	  Matchmaking.expected(r, s)  Elo: the chance rating r beats rating s
	  Matchmaking.rated(r, s, won)  r's new rating after a rated match
	  Matchmaking.window(seconds)   how far apart in rating two entries may be
	                              matched, widening the longer they wait
	  Matchmaking.pair(entries, now)  pairs queue entries ({ Rating, Since,
	                              Size }), longest-waiting first
	  Matchmaking.lane(slot, team, index, size)  where a fighter stands in a
	                              lane, and the lane's centre (offsets from the arena floor's centre)

	Party Raids (PvE): a party of at least Raid.Min fights one raid boss.
	  Matchmaking.Raid                 the rules: size, scaling, rewards
	  Matchmaking.raidScale(n, wave)   the boss's health and damage multipliers
	                                   for n raiders on a wave
	  Matchmaking.raidCoins(wave)      each raider's coins for clearing a wave
	  Matchmaking.raidCheck(members, leader, busy)  may this party start a
	                                   raid? (ok, reason)
	  Matchmaking.ownsRival(model, player)  is this Arena rival yours (your
	                                   own, or your raid's boss)?
]]
local Matchmaking = {}

Matchmaking.Modes = {
	["1v1"] = { Name = "1v1 Duel", Size = 1 },
	["2v2"] = { Name = "2v2 Party Duel", Size = 2 },
}
Matchmaking.StartRating = 1000
Matchmaking.K = 32
Matchmaking.Countdown = 4 -- seconds: shielded, facing off
Matchmaking.TimeLimit = 120 -- seconds: then the healthier side wins
Matchmaking.EndPause = 4 -- seconds on the result before heading back
Matchmaking.ChallengeSeconds = 30
Matchmaking.Lanes = 4 -- duels running side by side in the Arena
Matchmaking.Rewards = {
	Ranked = { Win = 40, Loss = 10 },
	Friendly = { Win = 15, Loss = 5 },
}

Matchmaking.Raid = {
	Min = 3, -- raiders needed to start
	Max = 4, -- a full party
	HealthPerRaider = 0.85, -- the boss's extra health for each raider past the first
	HealthPerWave = 0.25, -- and for each wave cleared
	Damage = 1.2, -- it hits harder than a duelling rival
	DamagePerWave = 0.1,
	Coins = 60, -- each raider's coins for wave 1
	CoinsPerWave = 20,
	NextWave = 8, -- seconds between waves
}

function Matchmaking.raidScale(raiders: number, wave: number): (number, number)
	local r = Matchmaking.Raid
	local n, w = math.max(1, raiders), math.max(1, wave)
	local health = (1 + r.HealthPerRaider * (n - 1)) * (1 + r.HealthPerWave * (w - 1))
	local damage = r.Damage + r.DamagePerWave * (w - 1)
	return health, damage
end

function Matchmaking.raidCoins(wave: number): number
	return Matchmaking.Raid.Coins + Matchmaking.Raid.CoinsPerWave * (math.max(1, wave) - 1)
end

-- `members`: the party, leader first or not; `busy(player)`: why that member
-- can't come right now (a string), or nil.
function Matchmaking.raidCheck(members, leader, busy): (boolean, string?)
	if not members or members[1] == nil then
		return false, string.format("Form a party of %d first (Social > Party).", Matchmaking.Raid.Min)
	end
	if not table.find(members, leader) then
		return false, "Only your party's leader can start a raid."
	end
	if #members < Matchmaking.Raid.Min then
		return false,
			string.format(
				"A raid needs at least %d in the party (you have %d). Invite more!",
				Matchmaking.Raid.Min,
				#members
			)
	end
	for _, member in members do
		local why = busy(member)
		if why then
			return false, why
		end
	end
	return true, nil
end

-- A match or party id: a string attribute, or nil.
local function attribute(player, name: string): string?
	local value = if player and player.GetAttribute then player:GetAttribute(name) else nil
	return if type(value) == "string" then value else nil
end

-- Fighters in a duel only fight their opponents in it; party members never
-- fight each other.
function Matchmaking.versus(a, b): boolean
	local matchA, matchB = attribute(a, "MatchId"), attribute(b, "MatchId")
	if matchA ~= nil or matchB ~= nil then
		return matchA == matchB and a:GetAttribute("MatchTeam") ~= b:GetAttribute("MatchTeam")
	end
	local partyA = attribute(a, "PartyId")
	return partyA == nil or partyA ~= attribute(b, "PartyId")
end

-- Your own Arena rival, or the boss your raid is fighting.
function Matchmaking.ownsRival(model, player): boolean
	if not model or not player then
		return false
	end
	local dungeon = attribute(model, "DungeonId")
	if dungeon then
		return dungeon == attribute(player, "DungeonId")
	end
	if player.UserId ~= nil and model:GetAttribute("RivalOwner") == player.UserId then
		return true
	end
	local raid = attribute(model, "RaidId")
	return raid ~= nil and raid == attribute(player, "RaidId")
end

function Matchmaking.expected(rating: number, other: number): number
	return 1 / (1 + 10 ^ ((other - rating) / 400))
end

function Matchmaking.rated(rating: number, other: number, won: boolean): number
	local change = Matchmaking.K * ((if won then 1 else 0) - Matchmaking.expected(rating, other))
	return math.max(100, math.floor(rating + change + 0.5))
end

function Matchmaking.window(seconds: number): number
	return math.min(1000, 100 + 25 * math.max(0, seconds))
end

-- Returns { { i, j } } index pairs into `entries`. The longest-waiting entry
-- takes the closest rating inside the wider of the two windows.
function Matchmaking.pair(entries, now: number)
	local order = {}
	for i in entries do
		table.insert(order, i)
	end
	table.sort(order, function(x, y)
		return entries[x].Since < entries[y].Since
	end)
	local taken, pairs = {}, {}
	for _, i in order do
		if not taken[i] then
			local best, gap = nil, math.huge
			for _, j in order do
				if j ~= i and not taken[j] and entries[j].Size == entries[i].Size then
					local window =
						math.max(Matchmaking.window(now - entries[i].Since), Matchmaking.window(now - entries[j].Since))
					local distance = math.abs(entries[i].Rating - entries[j].Rating)
					if distance <= window and distance < gap then
						best, gap = j, distance
					end
				end
			end
			if best then
				taken[i], taken[best] = true, true
				table.insert(pairs, { i, best })
			end
		end
	end
	return pairs
end

-- Lanes sit around the floor's centre; the two teams face off 16 studs apart,
-- teammates side by side.
local LANE_CENTRES = {
	Vector3.new(-12, 0, -12),
	Vector3.new(12, 0, 12),
	Vector3.new(12, 0, -12),
	Vector3.new(-12, 0, 12),
}
function Matchmaking.lane(slot: number, team: number, index: number, size: number): (Vector3, Vector3)
	local centre = LANE_CENTRES[(slot - 1) % #LANE_CENTRES + 1]
	local side = if team == 1 then -1 else 1
	local across = if size > 1 then (index - (size + 1) / 2) * 5 else 0
	return centre + Vector3.new(across, 0, side * 8), centre
end

return Matchmaking

end)()
local GemConfig=(function()
--[[
	Gemstone definitions, from "GemSoul: Gemstone Property & Generation
	Architecture". Shared by the server (which generates and grades gems) and
	the client (which displays them).

	A gem is a plain table so it can be saved and sent to clients:
	{
		Id: string,
		Element: "Fire" | "Frost" | "Shock" | "Poison",
		Tier: "Common" | "Uncommon" | "Rare" | "UltraRare",
		Clarity: 1-10,   -- rolled on generation
		Size: 1-10,      -- rolled on generation
		Cut: 1-10,       -- natural facet quality, rolled at discovery
		CutMethod: "Natural" | "Starter" | "Crate",
		Source: "MiningNode" | "MiningStore" | "PvEDrop" | "PvPWager",
		Found: number,   -- os.time() when generated
	}
]]

export type Gem = {
	Id: string,
	Element: string,
	Tier: string,
	Clarity: number,
	Size: number,
	Cut: number?,
	CutMethod: string?,
	EnchantmentXPGranted: boolean?,
	Source: string,
	Found: number,
}

export type Shade = { Tier: string, Name: string, Color: Color3, Color2: Color3?, Prismatic: boolean? }


local GemConfig = {}
-- Retain saved element keys while presenting space-tech affinities everywhere.
GemConfig.ElementLabels = { Fire = "Thermal", Frost = "Cryo", Shock = "Ion", Poison = "Corrosive" }
-- Directive names back to the saved keys.
GemConfig.ElementKeys = { Thermal = "Fire", Cryo = "Frost", Ion = "Shock", Corrosive = "Poison" }
function GemConfig.elementKey(name: string): string
	return GemConfig.ElementKeys[name] or name
end
function GemConfig.elementName(element: string): string
	return GemConfig.ElementLabels[element] or element
end

GemConfig.Elements = { "Fire", "Frost", "Shock", "Poison" }

-- Each element's colour tiers, all inside its approved hue: Thermal red,
-- Cryo blue, Corrosive green, Ion yellow. Thermal and Cryo top out at Rare;
-- Ion and Corrosive top out at Ultra-Rare.
GemConfig.Shades = {
	Fire = {
		{ Tier = "Common", Name = "Ember Red", Color = Color3.fromRGB(232, 104, 92) },
		{ Tier = "Uncommon", Name = "Plasma Crimson", Color = Color3.fromRGB(222, 36, 42) },
		{ Tier = "Rare", Name = "Deep Ruby Red", Color = Color3.fromRGB(168, 6, 34) },
		{
			Tier = "UltraRare",
			Name = "Solar Garnet",
			Color = Color3.fromRGB(200, 20, 60),
			Color2 = Color3.fromRGB(120, 0, 24),
		},
		{ Tier = "Legendary", Name = "Starfire Ruby", Color = Color3.fromRGB(255, 46, 46), Prismatic = true },
	},
	Frost = {
		{ Tier = "Common", Name = "Glacier Blue", Color = Color3.fromRGB(150, 200, 246) },
		{ Tier = "Uncommon", Name = "Vivid Blue", Color = Color3.fromRGB(40, 140, 255) },
		{ Tier = "Rare", Name = "Deep Royal Sapphire Blue", Color = Color3.fromRGB(18, 40, 160) },
		{
			Tier = "UltraRare",
			Name = "Abyssal Sapphire",
			Color = Color3.fromRGB(10, 30, 120),
			Color2 = Color3.fromRGB(40, 110, 230),
		},
		{ Tier = "Legendary", Name = "Aurora Sapphire", Color = Color3.fromRGB(60, 120, 255), Prismatic = true },
	},
	Shock = {
		{ Tier = "Common", Name = "Pale Citrine", Color = Color3.fromRGB(240, 222, 132) },
		{ Tier = "Uncommon", Name = "Bright Yellow", Color = Color3.fromRGB(255, 220, 30) },
		{ Tier = "Rare", Name = "Golden Topaz", Color = Color3.fromRGB(230, 180, 20) },
		{
			Tier = "UltraRare",
			Name = "Prismatic Arc Gold",
			Color = Color3.fromRGB(255, 196, 0),
			Prismatic = true,
		},
		{ Tier = "Legendary", Name = "Stormheart Citrine", Color = Color3.fromRGB(255, 236, 90), Prismatic = true },
	},
	Poison = {
		{ Tier = "Common", Name = "Pale Lime", Color = Color3.fromRGB(184, 232, 128) },
		{ Tier = "Uncommon", Name = "Emerald Green", Color = Color3.fromRGB(20, 170, 80) },
		{ Tier = "Rare", Name = "Viridian Jade", Color = Color3.fromRGB(30, 140, 90) },
		{
			Tier = "UltraRare",
			Name = "Toxic Neon Emerald",
			Color = Color3.fromRGB(70, 250, 100),
			Color2 = Color3.fromRGB(0, 110, 60),
		},
		{ Tier = "Legendary", Name = "Venomheart Emerald", Color = Color3.fromRGB(0, 255, 120), Prismatic = true },
	},
} :: { [string]: { Shade } }

-- Rarity odds live in GemRoller (40 / 25 / 20 / 10 / 5).
GemConfig.TierOrder = { "Common", "Uncommon", "Rare", "UltraRare", "Legendary" }

GemConfig.TierLabels = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	UltraRare = "Ultra-Rare",
	Legendary = "Legendary",
}

-- Badge colours for each element.
GemConfig.ElementColors = {
	Fire = Color3.fromRGB(238, 62, 54), -- red
	Frost = Color3.fromRGB(64, 150, 255), -- blue
	Shock = Color3.fromRGB(255, 212, 40), -- yellow
	Poison = Color3.fromRGB(70, 205, 90), -- green
}

-- The element whose badge colour this is (element hits are tinted with it).
function GemConfig.elementOfColor(color: Color3?): string?
	if not color then
		return nil
	end
	for element, tint in GemConfig.ElementColors do
		if
			math.abs(tint.R - color.R) < 0.02
			and math.abs(tint.G - color.G) < 0.02
			and math.abs(tint.B - color.B) < 0.02
		then
			return element
		end
	end
	return nil
end

GemConfig.SourceLabels = {
	MiningNode = "Dug from the mine",
	MiningStore = "Bought at the Mining Store",
	PvEDrop = "Dropped by a monster",
	PvPWager = "Won in a PvP duel",
	StarterSpin = "Starter gem spin",
	FirstStone = "Your first stone, from the mine",
}

-- What a gem does when socketed into a weapon.
GemConfig.ElementEffects = {
	Fire = "Raw damage and anti-heal: burns targets over time.",
	Frost = "Crowd control: slows targets and can freeze them.",
	Shock = "Burst and execute: arcs between enemies and finishes them.",
	Poison = "Anti-tank: shreds armor and leaves targets vulnerable.",
}

GemConfig.TierRank = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }

GemConfig.TierColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(90, 220, 120),
	Rare = Color3.fromRGB(80, 160, 255),
	UltraRare = Color3.fromRGB(255, 90, 220),
	Legendary = Color3.fromRGB(255, 176, 60),
}

-- Clarity and size are graded 1-10. High grades are rarer: these are the
-- relative chances of grades 1..10.
GemConfig.GradeWeights = { 16, 16, 14, 12, 11, 9, 8, 6, 5, 3 }

-- How lucky each source is (0 = baseline, 1 = very lucky). Luck raises the
-- odds of rarer colour tiers and gives clarity/size a chance at a reroll.
GemConfig.SourceLuck = {
	MiningNode = 0,
	VipMiningNode = 0.5,
	MiningStore = 0.15,
	PvEDrop = 0.1, -- plus the monster's own bonus
	StarterSpin = 0.25,
	FirstStone = 0,
}

-- Natural facet quality: 1-10, rolled at recovery. Diamond cut is the only shape.

-- Base value in coins by colour tier, before size, clarity and cut.
GemConfig.TierValue = {
	Common = 10,
	Uncommon = 25,
	Rare = 60,
	UltraRare = 120,
	Legendary = 250,
}

function GemConfig.shade(gem: Gem): Shade
	for _, shade in GemConfig.Shades[gem.Element] do
		if shade.Tier == gem.Tier then
			return shade
		end
	end
	return GemConfig.Shades[gem.Element][1]
end

function GemConfig.displayName(gem: Gem): string
	local state = if gem.Cut then "" else "Rough "
	return state .. GemConfig.shade(gem).Name .. " (" .. GemConfig.elementName(gem.Element) .. ")"
end

-- Coin value: economy-only, see ExpeditionEconomy.gemValue.
function GemConfig.value(gem: Gem): number
	return ExpeditionEconomy.gemValue(gem, GemConfig.TierValue[gem.Tier] or 10)
end

--[[
	Combat enchanting runs on three grades, each with one job:
	  Size     magnitude    raw damage, shield amount, armor shred
	  Clarity  duration     burn length, cooldowns, recharge rate
	  Cut      precision    crit, freeze and stun chances (player-facing "Precision")
	Weapons take Offense enchantments; every other slot takes Defense.
	Potency is economy-only now (ExpeditionEconomy.gemPotency).
]]
GemConfig.MetricOrder = { "Size", "Clarity", "Cut" }
GemConfig.MetricLabels = { Size = "Size", Clarity = "Clarity", Cut = "Precision" }
GemConfig.MetricRoles = { Size = "Magnitude", Clarity = "Duration", Cut = "Trigger rate" }

function GemConfig.side(slot: string): string
	return if slot == "Weapon" then "Offense" else "Defense"
end

-- Per grade point. Kind: "flat", "pct" (a fraction shown as %), "sec", "count".
type Stat = { Key: string, Label: string, Per: number, Kind: string }
GemConfig.Stats = {
	Offense = {
		Fire = {
			Size = { Key = "BurnDamage", Label = "Burn Damage", Per = 1.5, Kind = "flat" },
			Clarity = { Key = "BurnDuration", Label = "Burn Duration", Per = 0.4, Kind = "sec" },
			Cut = { Key = "IgniteChance", Label = "Critical Burn Chance", Per = 0.01, Kind = "pct" },
		},
		Frost = {
			Size = { Key = "SlowAmount", Label = "Slow Amount", Per = 0.02, Kind = "pct" },
			Clarity = { Key = "SlowDuration", Label = "Slow Duration", Per = 0.5, Kind = "sec" },
			Cut = { Key = "FreezeChance", Label = "Freeze Chance", Per = 0.008, Kind = "pct" },
		},
		Poison = {
			Size = { Key = "ArmorShred", Label = "Armor Shred", Per = 0.015, Kind = "pct" },
			Clarity = { Key = "DebuffDuration", Label = "Debuff Duration", Per = 0.5, Kind = "sec" },
			Cut = { Key = "VulnerableChance", Label = "Vulnerability Chance", Per = 0.005, Kind = "pct" },
		},
		Shock = {
			Size = { Key = "ArcDamage", Label = "Arc Damage", Per = 1.2, Kind = "flat" },
			Clarity = { Key = "ChainLength", Label = "Chain Length", Per = 0.5, Kind = "count" },
			Cut = { Key = "StunChance", Label = "Stun Chance", Per = 0.005, Kind = "pct" },
		},
	},
	Defense = {
		Fire = {
			Size = { Key = "ShieldAmount", Label = "Heat Shield Amount", Per = 2, Kind = "flat" },
			Clarity = { Key = "CooldownCut", Label = "Shield Cooldown", Per = 0.2, Kind = "sec" },
			Cut = { Key = "ReflectChance", Label = "Reflect Chance", Per = 0.005, Kind = "pct" },
		},
		Frost = {
			Size = { Key = "ShieldAmount", Label = "Cryo Shield Amount", Per = 2, Kind = "flat" },
			Clarity = { Key = "ShieldDuration", Label = "Cryo Shield Duration", Per = 1, Kind = "sec" },
			Cut = { Key = "Resistance", Label = "Resistance", Per = 0.005, Kind = "pct" },
		},
		Poison = {
			Size = { Key = "ShieldAmount", Label = "Rad Shield Amount", Per = 2, Kind = "flat" },
			Clarity = { Key = "CleanseRate", Label = "Cleanse Rate", Per = 1, Kind = "count" },
			Cut = { Key = "AuraShred", Label = "Corrosion Aura", Per = 0.005, Kind = "pct" },
		},
		Shock = {
			Size = { Key = "ShieldAmount", Label = "Ion Shield Amount", Per = 2, Kind = "flat" },
			Clarity = { Key = "RechargeRate", Label = "Shield Recharge", Per = 0.02, Kind = "pct" },
			Cut = { Key = "DeflectChance", Label = "Deflect Chance", Per = 0.005, Kind = "pct" },
		},
	},
} :: { [string]: { [string]: { [string]: Stat } } }

-- Fixed rules the grades plug into.
GemConfig.Rules = {
	BurnTick = 1, -- seconds between burn ticks; a fresh hit refreshes the burn, never stacks it
	FreezeSeconds = 1.5,
	StunSeconds = 1,
	VulnerableAmount = 0.20, -- extra damage a Vulnerable target takes
	ExecuteThreshold = 0.10, -- Ion hits finish targets below this share of health
	ArcRange = 14,
	ShieldBaseDuration = 4, -- a gem shield holds this long once it raises
	ShieldBaseCooldown = 15, -- then recharges for this long
	ShieldMinCooldown = 5,
	CleanseMaxInterval = 12, -- Corrosive armor cleanses every (12 - Clarity) s, at least every 2 s
	CleanseMinInterval = 2,
	AuraRadius = 12,
	MaxSlow = 0.40,
}

-- PvP rides on top of the PvE numbers: multipliers, then caps.
GemConfig.PvP = {
	Mult = {
		BurnDamage = 0.5,
		SlowAmount = 0.75,
		FreezeChance = 0.6,
		ArmorShred = 0.5,
		ArcDamage = 0.8,
		StunChance = 0,
	},
	Caps = { SlowAmount = 0.30, ArmorShred = 0.30, VulnerableAmount = 0.20 },
	CrowdControlSeconds = 0.5,
	GrievousWounds = 0.30, -- Thermal critical burns
	MortalStrike = 0.20, -- Corrosive vulnerability
	NoChain = true,
}

local function grade(gem: Gem, metric: string): number
	return math.clamp(math.floor((gem :: any)[metric] or 0), 0, 10)
end

--[[
	The numbers behind a socketed gem, as a flat table of stat keys.
	opts.Affinity  { [affixId]: bonus } from equipped armor (see GemConfig.Affixes)
	opts.PvP       apply the PvP multipliers and caps
]]
function GemConfig.stats(
	gem: Gem,
	slot: string,
	opts: { Affinity: { [string]: number }?, PvP: boolean? }?
): { [string]: number }
	local o = opts or {}
	local side = GemConfig.side(slot)
	local values = {}
	for metric, stat in GemConfig.Stats[side][gem.Element] or {} do
		local value = grade(gem, metric) * stat.Per
		if stat.Kind == "count" then
			value = math.floor(value)
		end
		values[stat.Key] = value
	end
	if side == "Offense" then
		if gem.Element == "Shock" then
			values.ChainLength = math.max(1, values.ChainLength)
			values.ExecuteThreshold = GemConfig.Rules.ExecuteThreshold
		elseif gem.Element == "Poison" then
			values.VulnerableAmount = GemConfig.Rules.VulnerableAmount
		elseif gem.Element == "Frost" then
			values.SlowAmount = math.min(values.SlowAmount, GemConfig.Rules.MaxSlow)
			values.FreezeSeconds = GemConfig.Rules.FreezeSeconds
		end
		if gem.Element == "Shock" then
			values.StunSeconds = GemConfig.Rules.StunSeconds
		end
	end
	-- Elemental affinities from armor boost one stat of one element by a percentage.
	for id, bonus in o.Affinity or {} do
		local affix = GemConfig.AffixById[id]
		if affix and affix.Element == gem.Element and affix.Side == side and values[affix.Stat] then
			values[affix.Stat] *= 1 + bonus
		end
	end
	if o.PvP then
		for key, mult in GemConfig.PvP.Mult do
			if values[key] then
				values[key] *= mult
			end
		end
		for key, cap in GemConfig.PvP.Caps do
			if values[key] then
				values[key] = math.min(values[key], cap)
			end
		end
		if values.FreezeSeconds then
			values.FreezeSeconds = math.min(values.FreezeSeconds, GemConfig.PvP.CrowdControlSeconds)
		end
		if values.StunSeconds then
			values.StunSeconds = math.min(values.StunSeconds, GemConfig.PvP.CrowdControlSeconds)
		end
		if gem.Element == "Shock" and side == "Offense" then
			values.ChainLength = 1
		end
		if gem.Element == "Fire" and side == "Offense" then
			values.HealingReduction = GemConfig.PvP.GrievousWounds
		elseif gem.Element == "Poison" and side == "Offense" then
			values.HealingReduction = GemConfig.PvP.MortalStrike
		end
	end
	return values
end

local function percent(value: number): string
	local pct = value * 100
	if math.abs(pct - math.floor(pct + 0.5)) < 0.05 then
		return string.format("%d%%", math.floor(pct + 0.5))
	end
	return string.format("%.1f%%", pct)
end
GemConfig.percent = percent

local function number(value: number): string
	if math.abs(value - math.floor(value + 0.5)) < 0.05 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%.1f", value)
end

-- Tooltip lines: concrete effects, each tagged with the grade that drives it.
export type Line = { Metric: string?, Grade: number?, Text: string } -- no Metric: a fixed rule
function GemConfig.lines(gem: Gem, slot: string, opts: { Affinity: { [string]: number }?, PvP: boolean? }?): { Line }
	local v = GemConfig.stats(gem, slot, opts)
	local side = GemConfig.side(slot)
	local name = GemConfig.elementName(gem.Element)
	local s, c, p = grade(gem, "Size"), grade(gem, "Clarity"), grade(gem, "Cut")
	local lines = {}
	local function add(metric: string?, value: number?, text: string)
		table.insert(lines, { Metric = metric, Grade = value, Text = text })
	end
	if side == "Offense" then
		if gem.Element == "Fire" then
			add("Size", s, string.format("+%s %s damage per tick", number(v.BurnDamage), name))
			add("Clarity", c, string.format("Burns for %ss", number(v.BurnDuration)))
			add("Cut", p, string.format("%s critical burn chance", percent(v.IgniteChance)))
		elseif gem.Element == "Frost" then
			add("Size", s, string.format("Slows targets by %s", percent(v.SlowAmount)))
			add("Clarity", c, string.format("Slow lasts %ss", number(v.SlowDuration)))
			add(
				"Cut",
				p,
				string.format("%s chance to freeze for %ss", percent(v.FreezeChance), number(v.FreezeSeconds))
			)
		elseif gem.Element == "Poison" then
			add("Size", s, string.format("Shreds %s armor", percent(v.ArmorShred)))
			add("Clarity", c, string.format("Corrosion lasts %ss", number(v.DebuffDuration)))
			add(
				"Cut",
				p,
				string.format(
					"%s chance to make targets Vulnerable (+%s damage taken)",
					percent(v.VulnerableChance),
					percent(v.VulnerableAmount)
				)
			)
		else
			add("Size", s, string.format("+%s arc damage per hit", number(v.ArcDamage)))
			add(
				"Clarity",
				c,
				if v.ChainLength <= 1
					then "Arcs to 1 nearby enemy"
					else string.format("Chains through %d enemies", v.ChainLength)
			)
			if v.StunChance > 0 then
				add("Cut", p, string.format("%s chance to stun for %ss", percent(v.StunChance), number(v.StunSeconds)))
			else
				add("Cut", p, "Stun replaced by Execute in PvP")
			end
		end
	else
		local shield = GemConfig.EnchantNames.Armor[gem.Element] or "Shield"
		add("Size", s, string.format("%s absorbs %s damage", shield, number(v.ShieldAmount)))
		if gem.Element == "Fire" then
			add("Clarity", c, string.format("Shield recharges %ss sooner", number(v.CooldownCut)))
			add("Cut", p, string.format("%s chance to reflect a hit", percent(v.ReflectChance)))
		elseif gem.Element == "Frost" then
			add("Clarity", c, string.format("Shield holds %ss longer", number(v.ShieldDuration)))
			add("Cut", p, string.format("Take %s less damage", percent(v.Resistance)))
		elseif gem.Element == "Poison" then
			add(
				"Clarity",
				c,
				string.format("Cleanses a debuff every %ss", number(GemConfig.cleanseInterval(v.CleanseRate, 0)))
			)
			add("Cut", p, string.format("Nearby enemies take %s more damage", percent(v.AuraShred)))
		else
			add("Clarity", c, string.format("Shield recharges %s faster", percent(v.RechargeRate)))
			add("Cut", p, string.format("%s chance to deflect a hit", percent(v.DeflectChance)))
		end
	end
	if side == "Offense" and gem.Element == "Shock" then
		add(nil, nil, string.format("Executes targets below %s health", percent(v.ExecuteThreshold)))
	end
	if opts and opts.PvP and v.HealingReduction then
		add(nil, nil, string.format("Applies %s healing reduction for 4s", percent(v.HealingReduction)))
	end
	return lines
end

function GemConfig.cleanseInterval(clarityRate: number, bonus: number?): number
	local interval = math.max(GemConfig.Rules.CleanseMinInterval, GemConfig.Rules.CleanseMaxInterval - clarityRate)
	return interval / (1 + (bonus or 0))
end

-- What a socketed gem does, in one line, for toasts and compact labels.
GemConfig.EnchantNames = {
	Weapon = { Fire = "Thermal", Frost = "Cryogenic", Shock = "Ionized", Poison = "Corrosive" },
	Armor = { Fire = "Heat Shield", Frost = "Cryo Shield", Shock = "Ion Shield", Poison = "Rad Shield" },
}

function GemConfig.enchantment(
	gem: Gem,
	slot: string,
	opts: { Affinity: { [string]: number }?, PvP: boolean? }?
): (string, string)
	if slot == "Surge1" or slot == "Surge2" or slot == "Surge3" then
		return "Surge Capacitor", "Powers " .. (GemConfig.ElementLabels[gem.Element] or gem.Element) .. " Gem Surges."
	end
	local side = GemConfig.side(slot)
	local name = GemConfig.EnchantNames[if side == "Offense" then "Weapon" else "Armor"][gem.Element] or "Enchanted"
	local parts = {}
	for _, line in GemConfig.lines(gem, slot, opts) do
		table.insert(parts, line.Text)
	end
	return name, table.concat(parts, " · ")
end

-- Universal actions consume the independent Size/Clarity/Precision metrics.
function GemConfig.actionValues(gem: Gem, action: string, opts): { [string]: any }
	local v = GemConfig.stats(gem, if action == "Block" then "Shield" else "Weapon", opts)
	if action == "Block" then
		return {
			Shield = v.ShieldAmount,
			Duration = GemConfig.Rules.ShieldBaseDuration + (v.ShieldDuration or 0),
			Cooldown = math.max(
				GemConfig.Rules.ShieldMinCooldown,
				GemConfig.Rules.ShieldBaseCooldown - (v.CooldownCut or 0)
			) / (1 + (v.RechargeRate or 0)),
			ReflectThermal = if gem.Element == "Fire" then 0.10 else nil,
			ReflectChance = v.ReflectChance,
			Cleanse = gem.Element == "Poison",
			CleanseInterval = if v.CleanseRate then GemConfig.cleanseInterval(v.CleanseRate) else nil,
			Resist = v.Resistance,
			Deflect = v.DeflectChance,
			Aura = v.AuraShred,
		}
	end
	return {
		Burn = v.BurnDamage,
		Duration = v.BurnDuration or v.SlowDuration or v.DebuffDuration,
		Ignite = v.IgniteChance,
		Slow = v.SlowAmount,
		Freeze = v.FreezeChance,
		FreezeSeconds = v.FreezeSeconds,
		Sunder = v.ArmorShred,
		Vulnerable = v.VulnerableChance,
		VulnerableAmount = v.VulnerableAmount,
		Arc = v.ArcDamage,
		Chain = v.ChainLength,
		Stun = v.StunChance,
		StunSeconds = v.StunSeconds,
		Execute = v.ExecuteThreshold,
		HealingReduction = v.HealingReduction,
	}
end

-- Gems no longer add flat ratings; their power lives in their effects.
-- Kept so older callers still work.
function GemConfig.statBonuses(_gem: Gem, _slot: string): { [string]: number }
	return {}
end

--[[
	Elemental Affinity Affixes: random modifiers on Rare+ armor that boost one
	element's stat by a percentage. Each element has an offensive stat for
	every grade (boosting your weapon gem) and a defensive one (boosting
	armor gems), plus Ion's Execute Threshold.
]]
export type Affix = { Id: string, Element: string, Side: string, Stat: string, Metric: string?, Label: string }
GemConfig.Affixes = {} :: { Affix }
GemConfig.AffixById = {} :: { [string]: Affix }
do
	local function addAffix(element: string, side: string, stat: string, metric: string?, label: string)
		local affix = {
			Id = element .. side .. stat,
			Element = element,
			Side = side,
			Stat = stat,
			Metric = metric,
			Label = label,
		}
		table.insert(GemConfig.Affixes, affix)
		GemConfig.AffixById[affix.Id] = affix
	end
	for _, element in GemConfig.Elements do
		for _, side in { "Offense", "Defense" } do
			for _, metric in GemConfig.MetricOrder do
				local stat = GemConfig.Stats[side][element][metric]
				addAffix(element, side, stat.Key, metric, stat.Label)
			end
		end
		if element == "Shock" then
			addAffix(element, "Offense", "ExecuteThreshold", nil, "Execute Threshold")
		end
	end
end
-- Bonus ranges by gear rarity (1-5): Rare +5-10%, Ultra Rare +10-15%, Legendary +15-20%.
GemConfig.AffixCounts = { 0, 0, 1, 2, 3 }
GemConfig.AffixRanges = { [3] = { 5, 10 }, [4] = { 10, 15 }, [5] = { 15, 20 } }

function GemConfig.affixText(id: string, bonus: number): string
	local affix = GemConfig.AffixById[id]
	if not affix then
		return ""
	end
	return string.format("%s Affinity: +%s %s", GemConfig.elementName(affix.Element), percent(bonus), affix.Label)
end

-- "Flawless Thermal Gem": a quality word from the three grades together.
GemConfig.GradeWords = {
	{ 8, "Flawless" },
	{ 6.5, "Pristine" },
	{ 5, "Fine" },
	{ 3.5, "Clear" },
	{ 2, "Chipped" },
	{ 0, "Cracked" },
}
function GemConfig.title(gem: Gem): string
	local average = (gem.Size + gem.Clarity + (gem.Cut or 0)) / 3
	local word = "Cracked"
	for _, entry in GemConfig.GradeWords do
		if average >= entry[1] then
			word = entry[2]
			break
		end
	end
	return word .. " " .. GemConfig.elementName(gem.Element) .. " Gem"
end

-- How strongly a gem's enchantment shows on gear (glow, particles), 0-1.
function GemConfig.strength(gem: Gem): number
	return math.clamp((gem.Size + gem.Clarity + (gem.Cut or 0)) / 30, 0, 1)
end

-- Enchanted gear takes a name from its gem: "Burning Longsword",
-- "Iron Plate of Embers".
GemConfig.ItemAffixes = {
	Weapon = { Fire = "Thermal", Frost = "Cryogenic", Shock = "Ionized", Poison = "Corrosive" },
	Armor = {
		Fire = "of Thermal Shielding",
		Frost = "of Cryo Insulation",
		Shock = "of Ion Shielding",
		Poison = "of Corrosion Warding",
	},
}

function GemConfig.itemName(baseName: string, gem: Gem?, slot: string): string
	slot = if slot == "Weapon" then "Weapon" else "Armor"
	if not gem then
		return baseName
	end
	local affix = GemConfig.ItemAffixes[slot] and GemConfig.ItemAffixes[slot][gem.Element]
	if not affix then
		return baseName
	end
	return if slot == "Armor" then baseName .. " " .. affix else affix .. " " .. baseName
end

return GemConfig

end)()
local ArmorFamilies=(function()
-- Armor defines the build. IDs remain stable; old items stay saved-compatible.
local Armor = {}
Armor.Version = 1
Armor.FullSetPieces = 6 -- five armor pieces plus a matching weapon
Armor.Slots = { "Helmet", "Armor", "Gloves", "Boots", "Shield" }
Armor.Order = { "Prospector", "Skirmisher", "Juggernaut" }
Armor.Budgets = { 10, 15, 22, 30, 40 }
Armor.ModifierSlots = { 0, 0, 1, 2, 3 }
Armor.Weights = { 40, 25, 20, 10, 5 }
Armor.Costs = { Health = 1, Power = 1, Defense = 1, Speed = 2, Critical = 2, Cooldown = 2 }
Armor.Values = { Health = 5, Power = 1, Defense = 1, Speed = 0.5, Critical = 0.005, Cooldown = 0.005 }
Armor.Stats = { "Health", "Power", "Defense", "Speed", "Critical", "Cooldown" }
Armor.Enhancements = {
	Prospector = { BasicDamage = 1.10, Knockback = 1.15, DodgeCooldown = 0.85, BlockWidth = 1.20 },
	Skirmisher = { AttackSpeed = 1.15, HeavyCrit = 0.20, DodgeDistance = 1.25, Deflect = true },
	Juggernaut = {
		Stagger = 0.10,
		HeavyDamage = 1.25,
		DodgeDistance = 0.80,
		Invincible = 0.75,
		BlockReduction = 0.65,
		BlockPvPReduction = 0.50,
	},
}
Armor.EnhancementText = {
	Prospector = "2+ pieces: Attack +10% damage; Heavy +15% knockback; Dodge -15% cooldown; Block +20% width.",
	Skirmisher = "2+ pieces: Attack +15% speed; Heavy +20% critical chance; Dodge +25% distance; Block deflects light projectiles.",
	Juggernaut = "2+ pieces: Attack +10% stagger chance; Heavy +25% damage; Dodge 12 studs / 0.75s PvE immunity; Block 65% PvE / 50% PvP reduction.",
}
Armor.Families = {
	Prospector = {
		Look = "UtilityMiner",
		Description = "Balanced sustain and self-sufficient mining",
		Primary = { Helmet = "Health", Armor = "Health", Gloves = "Power", Boots = "Speed", Shield = "Defense" },
		PreferredWeapon = "Sword",
		Gem = "Corrosive",
		Color = Color3.fromRGB(218, 159, 76),
	},
	Skirmisher = {
		Look = "FrontierRanger",
		Description = "Mobile scout with critical burst",
		Primary = { Helmet = "Speed", Armor = "Power", Gloves = "Critical", Boots = "Speed", Shield = "Defense" },
		PreferredWeapon = "Pistol",
		Gem = "Ion",
		Color = Color3.fromRGB(72, 174, 186),
	},
	Juggernaut = {
		Look = "HeavyVanguard",
		Description = "Armored defense and battlefield control",
		Primary = { Helmet = "Health", Armor = "Health", Gloves = "Power", Boots = "Health", Shield = "Defense" },
		PreferredWeapon = "Sword",
		Gem = "Thermal",
		Color = Color3.fromRGB(104, 139, 189),
	},
}
-- Highest unlocked tier replaces lower tiers; bonuses are not added together.
Armor.Sets = {
	Prospector = {
		[2] = { Health = 10, Power = 1 },
		[4] = { Health = 20, Power = 2, Cooldown = 0.05 },
		[6] = { Health = 30, Power = 3, Cooldown = 0.10, HealingReceived = 0.05 },
	},
	Skirmisher = {
		[2] = { Speed = 0.5, Critical = 0.02 },
		[4] = { Speed = 1, Critical = 0.04, Cooldown = 0.05 },
		[6] = { Speed = 1.5, Critical = 0.08, Cooldown = 0.10, DamageAfterDodge = 0.10 },
	},
	Juggernaut = {
		[2] = { Health = 15, Defense = 1 },
		[4] = { Health = 25, Defense = 2, DamageReduction = 0.05 },
		[6] = { Health = 40, Defense = 4, DamageReduction = 0.10, ThreatGeneration = 0.15 },
	},
}
Armor.DepthWeights = {
	{ 80, 20, 0, 0, 0 },
	{ 50, 40, 10, 0, 0 },
	{ 20, 50, 25, 5, 0 },
	{ 0, 30, 50, 18, 2 },
	{ 0, 10, 40, 40, 10 },
}
Armor.Catalog, Armor.ById = {}, {}
local kinds = { Helmet = "Helmets", Armor = "Armors", Gloves = "Gloves", Boots = "Boots", Shield = "Shields" }
local suffixes = { Helmet = "Helm", Armor = "Rig", Gloves = "Grips", Boots = "Greaves", Shield = "Shield" }
local common = {
	Prospector = {
		"Zero-G Standard Helm",
		"Zero-G Bulk Suit",
		"Reinforced Grips",
		"Mag-Lock Greaves",
		"Titanium Breach Shield",
	},
	Skirmisher = {
		"Frontier Scout Helm",
		"Frontier Scout Rig",
		"Scout Trigger Grips",
		"Scout Striders",
		"Scout Deflector Shield",
	},
	Juggernaut = {
		"Vanguard Guard Helm",
		"Vanguard Guard Rig",
		"Guard Gauntlets",
		"Guard Sabatons",
		"Guard Bulwark Shield",
	},
}
local prefixes = {
	Prospector = { "", "Reinforced Miner", "Surveyor's", "Prospector Elite", "Prospector Prime" },
	Skirmisher = { "", "Recon", "Pathfinder's", "Skirmisher Elite", "Skirmisher Prime" },
	Juggernaut = { "", "Reinforced Vanguard", "Bastion's", "Juggernaut Elite", "Juggernaut Prime" },
}
for familyIndex, family in Armor.Order do
	for slotIndex, slot in Armor.Slots do
		local kind = kinds[slot]
		Armor.Catalog[kind] = Armor.Catalog[kind] or {}
		for rarity = 1, 5 do
			local id = "Armor" .. family .. slot .. rarity
			local item = {
				Id = id,
				Name = if rarity == 1
					then common[family][slotIndex]
					else prefixes[family][rarity] .. " " .. suffixes[slot],
				Tier = rarity,
				RarityTier = rarity,
				StartPool = true,
				ArmorFamily = family,
				AssetFamily = Armor.Families[family].Look,
				Look = Armor.Families[family].Look,
				Style = family,
				Mods = {},
				Budget = Armor.Budgets[rarity],
				PrimaryStat = Armor.Families[family].Primary[slot],
				ModifierSlots = Armor.ModifierSlots[rarity],
				HelmetDesign = (familyIndex - 1) * 5 + rarity,
				Description = Armor.Families[family].Description,
				Passive = {
					Name = "Armor Identity",
					Text = "Wear matching " .. family .. " pieces for set bonuses.",
					Effect = {},
				},
			}
			if rarity >= 3 then
				-- Every element can roll on every family: a Juggernaut chest can carry a
				-- Cryo affinity (the off-meta chase) or an Ion one (trade bait).
				item.AffixTable = {}
				for _, affix in GemConfig.Affixes do
					table.insert(item.AffixTable, affix.Id)
				end
			end
			Armor.ById[id] = item
			table.insert(Armor.Catalog[kind], item)
		end
	end
end
function Armor.rollStats(item, rng)
	local slots = item.ModifierSlots
	local modifierBudget = if slots == 0 then 0 elseif slots == 1 then 6 elseif slots == 2 then 8 else 12
	local primaryBudget = item.Budget - modifierBudget
	local cost = Armor.Costs[item.PrimaryStat]
	-- Odd speed/critical budgets spend the remaining point on Power.
	local points = math.floor(primaryBudget / cost)
	local stats = { [item.PrimaryStat] = points * Armor.Values[item.PrimaryStat] }
	local allocations = { [item.PrimaryStat] = points }
	if primaryBudget % cost > 0 then
		stats.Power = (stats.Power or 0) + 1
		allocations.Power = (allocations.Power or 0) + 1
	end
	local available = {}
	for _, stat in Armor.Stats do
		if stat ~= item.PrimaryStat and not allocations[stat] then
			table.insert(available, stat)
		end
	end
	local modifiers = {}
	for _ = 1, slots do
		local stat = table.remove(available, rng:NextInteger(1, #available))
		local spent = modifierBudget / slots
		local amount = spent / Armor.Costs[stat]
		stats[stat] = (stats[stat] or 0) + amount * Armor.Values[stat]
		allocations[stat] = amount
		table.insert(modifiers, stat)
	end
	return stats, allocations, modifiers
end
-- Elemental Affinity Affixes for a Rare+ armor piece: 1/2/3 distinct affixes at
-- +5-10% / +10-15% / +15-20%. `pool` is the item's AffixTable (defaults to all).
function Armor.rollAffixes(rarity, rng, pool)
	local count = GemConfig.AffixCounts[rarity] or 0
	local range = GemConfig.AffixRanges[rarity]
	local affixes = {}
	if count == 0 or not range then
		return affixes
	end
	local choices = {}
	for _, id in pool or {} do
		table.insert(choices, id)
	end
	if #choices == 0 then
		for _, affix in GemConfig.Affixes do
			table.insert(choices, affix.Id)
		end
	end
	for _ = 1, math.min(count, #choices) do
		local id = table.remove(choices, rng:NextInteger(1, #choices))
		table.insert(affixes, { Id = id, Bonus = rng:NextInteger(range[1], range[2]) / 100 })
	end
	return affixes
end
function Armor.pick(catalog, rng, depth)
	local weights = if depth then Armor.DepthWeights[math.clamp(math.ceil(depth / 2), 1, 5)] else Armor.Weights
	local pick = rng:NextNumber(0, 100)
	local rarity = 5
	for i, weight in weights do
		pick -= weight
		if weight > 0 and pick < 0 then
			rarity = i
			break
		end
	end
	local choices = {}
	for _, item in catalog do
		if item.ArmorFamily and item.RarityTier == rarity then
			table.insert(choices, item)
		end
	end
	return if #choices > 0 then choices[rng:NextInteger(1, #choices)] else nil
end
function Armor.setState(loadout, resolve)
	local counts, bonuses, active = {}, {}, {}
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield", "Weapon" } do
		local gear = resolve(slot, loadout[slot])
		local family = gear and gear.ArmorFamily
		if family then
			counts[family] = (counts[family] or 0) + 1
		end
	end
	for _, family in Armor.Order do
		local count = counts[family] or 0
		local tier = if count >= Armor.FullSetPieces then 6 elseif count >= 4 then 4 elseif count >= 2 then 2 else 0
		active[family] = { Count = count, Tier = tier }
		for stat, amount in Armor.Sets[family][tier] or {} do
			bonuses[stat] = (bonuses[stat] or 0) + amount
		end
	end
	return { Counts = counts, Bonuses = bonuses, Active = active }
end
return Armor

end)()
local Actions=(function()
-- Universal Warrior controls and deterministic rules shared by HUD and server.
local Actions = {}
Actions.Order = { "Basic", "Heavy", "Dodge", "Block" }
Actions.Base = {
	Basic = { Name = "Attack", Damage = 1, SwordCooldown = 0.65, PistolCooldown = 0.45 },
	Heavy = {
		Name = "Heavy",
		Damage = 1.8,
		PvPDamage = 1.5,
		Cooldown = 1.2,
		Charge = 0.45,
		Knockback = 12,
		BreakSeconds = 0.8,
	},
	-- Double-tap Space: a long roll.
	Dodge = { Name = "Dodge", Cooldown = 3, Distance = 15, Duration = 0.25, Invincible = 0.5, PvPInvincible = 0.3 },
	-- Single tap: a quick hop to the side, cheap and fast but a short dodge window.
	Hop = {
		Name = "Hop",
		Cooldown = 0.6,
		Distance = 7,
		Duration = 0.18,
		Lift = 16,
		Invincible = 0.28,
		PvPInvincible = 0.2,
		Cost = 8,
	},
	Block = { Name = "Block", Reduction = 0.5, PvPReduction = 0.4, Arc = 120 },
}
--[[
	Stamina, Elder Scrolls style: every swing and every blow you take on your
	guard costs Stamina, and it only refills once you ease off.

	A light swing costs 0.4 Stamina per point of the weapon's damage, so
	heavier blades tire you faster (Attack.StaminaCost overrides it):
	  Scout Shortsword (15)                           6 light, 17 heavy
	  Frontier Sword, Runeblade, etc (18)             7 light, 20 heavy
	  Impact Falchion, Omega Greatblade (23)          9 light, 26 heavy
	A heavy is 2.85x a light. Against 100 Stamina and 12/s regen (paused
	RegenDelay after any spend, so it never refills mid-flurry): about 14
	light swings or 5 heavies in a row with a standard sword before you're
	winded. A shot (sidearm) costs 0.25 per point (3).

	Guard: holding it up drains GuardDrain per second (no regen while it's
	up), and each blow it takes costs BlockPerDamage per point of the blow
	(at least BlockMin): a rival's 9-11 damage hit costs about 5. A parry (a
	perfect block) costs nothing. A blow you can't pay for breaks your guard
	(GuardBreakSeconds) and lands in full.

	Out of Stamina: a heavy comes out as a light swing, a light swing still
	lands but WindedDamage weaker, and you can't raise your guard below
	BlockMin.
]]
Actions.Stamina = {
	PerDamage = 0.4,
	HeavyMult = 2.85,
	ShotPerDamage = 0.25,
	GuardDrain = 4,
	BlockPerDamage = 0.5,
	BlockMin = 3,
	RegenDelay = 0.8,
	WindedDamage = 0.6,
	GuardBreakSeconds = 1,
}
-- Stamina for one attack with `weapon` (a Classes gear entry).
function Actions.swingCost(weapon, heavy: boolean?): number
	local attack = weapon and weapon.Attack or {}
	local light = attack.StaminaCost
		or math.floor(
			(attack.Damage or 18)
					* (if attack.Kind == "Melee" then Actions.Stamina.PerDamage else Actions.Stamina.ShotPerDamage)
				+ 0.5
		)
	return if heavy then math.floor(light * Actions.Stamina.HeavyMult + 0.5) else light
end
--[[
	Ground blasts (a cast with a warning ring on the ground): a wide ring,
	and the closer to its centre you're caught, the harder it hits.
	  core    (inner 35% of the radius)  full to 77% damage, STUNNED 1.3s at
	                                     the very centre down to 0.7s, and
	                                     thrown off your feet
	  middle  (35-70%)                   77% to 61% damage, STAGGERED 0.55s
	                                     down to 0.25s
	  edge    (70-100%)                  61% to 45% damage, no stagger
	A raised guard takes it down a step (a stun becomes a stagger, a stagger
	nothing); a dodge's immunity avoids it all. Radius: a surge's own radius
	x1.6, 9 to 15 studs (a hop gets you from the core to the edge; a roll
	gets you out).
]]
Actions.Blast = {
	RadiusScale = 1.6,
	MinRadius = 9,
	MaxRadius = 15,
	EdgeDamage = 0.45,
	StunZone = 0.35,
	StaggerZone = 0.7,
	Knockback = 34,
}
function Actions.blastRadius(base: number?): number
	return math.clamp((base or 7) * Actions.Blast.RadiusScale, Actions.Blast.MinRadius, Actions.Blast.MaxRadius)
end
-- How a blast lands at `distance` from its centre: damage scale, and the
-- crowd control ("Stunned", "Staggered" or nil) with its seconds.
function Actions.blastFalloff(distance: number, radius: number): (number, string?, number)
	local blast = Actions.Blast
	local r = math.clamp(distance / math.max(radius, 0.1), 0, 1)
	local scale = 1 - (1 - blast.EdgeDamage) * r
	if r <= blast.StunZone then
		return scale, "Stunned", 1.3 - 0.6 * (r / blast.StunZone)
	elseif r <= blast.StaggerZone then
		return scale, "Staggered", 0.55 - 0.3 * ((r - blast.StunZone) / (blast.StaggerZone - blast.StunZone))
	end
	return scale, nil, 0
end
--[[
	Casting, the same for every fighter (players and the Arena rival alike):
	what a cast is, how long it takes, and how you can move meanwhile.

	  kind     what it is                          cast    moving
	  Bolt     bolts, lances, cones, chains        0.7s    rooted
	  Blast    a ground blast (warning ring)       1.05s   rooted
	  Field    a blast around yourself             1.05s   rooted
	  Channel  a held beam (Cryo Stream)           0.4s    rooted while it pours
	  Buff     a shield or buff on yourself        0.3s    free
	  Move     a quick Rig Maneuver                0.2s    free
	  Heavy    a maneuver or surge with its own    its     rooted
	           wind-up (Breach Hammer, Supernova)  own
]]
Actions.CastTime = { Bolt = 0.7, Blast = 1.05, Field = 1.05, Channel = 0.4, Buff = 0.3, Move = 0.2 }
function Actions.castKind(definition): string?
	if not definition then
		return nil
	end
	if definition.Resource ~= "Charge" then
		return if definition.Windup then "Heavy" else "Move"
	end
	if definition.PerSecond then
		return "Channel"
	elseif not definition.Damage then
		return "Buff"
	elseif definition.Radius then
		return if definition.Self then "Field" else "Blast"
	end
	return "Bolt"
end
function Actions.castTime(definition): number
	if not definition then
		return 0
	end
	return definition.Windup or Actions.CastTime[Actions.castKind(definition) or ""] or 0
end
-- The pose a cast shows (RivalPose kinds): Bolt, Nova, Buff, Slash or Heavy.
function Actions.castPose(definition): string
	if definition.Animation then
		return definition.Animation
	end
	local kind = Actions.castKind(definition)
	return if kind == "Blast" or kind == "Field"
		then "Nova"
		elseif kind == "Buff" then "Buff"
		elseif kind == "Move" then "Slash"
		elseif kind == "Heavy" then (if definition.Resource == "Charge" then "Nova" else "Heavy")
		else "Bolt"
end
-- Moving while you cast: the speed multiplier, and for how long (nil: the
-- whole cast, or while a channel pours).
function Actions.castMovement(definition): (number, number?)
	local kind = Actions.castKind(definition)
	if kind == "Buff" or kind == "Move" or kind == nil then
		return 1, 0
	end
	return 0, nil
end
Actions.AfterDodgeSeconds = 3
Actions.DoubleTap = 0.3 -- seconds between Space taps that make a roll
Actions.BlockLease = 0.6 -- release automatically if focus/disconnection drops an End packet
Actions.PerfectAt = 0.75
Actions.PerfectWindow = 0.09
Actions.OverchargeAt = 1.15
Actions.ComboWindow = 1.8
-- These timings are Saga's tuning. Damage and timing are always resolved on the server.
function Actions.charge(seconds)
	if seconds >= Actions.OverchargeAt then
		return { Heavy = false, Perfect = false, Scale = 0.65, Stage = "OVERCHARGED" }
	end
	local perfect = math.abs(seconds - Actions.PerfectAt) <= Actions.PerfectWindow
	return {
		Heavy = seconds >= Actions.Base.Heavy.Charge,
		Perfect = perfect,
		Scale = 1,
		Stage = if perfect then "PERFECT" elseif seconds >= Actions.Base.Heavy.Charge then "CHARGED" else "QUICK",
	}
end
-- Reject malformed remote payloads before resolving equipment or mutating combat state.
function Actions.validInput(action, a, b)
	if action == "CancelTech" or action == "CancelAttack" then
		return true
	elseif action == "BeginAttack" then
		return a == nil or a == "Left" or a == "Right"
	elseif action == "Attack" or action == "ReleaseAttack" then
		return Actions.finiteVector(a)
	elseif action == "Block" then
		return a == false or (a == true and Actions.finiteVector(b))
	elseif action == "Dodge" then
		return (a == nil or Actions.finiteVector(a)) and (b == nil or b == "Hop" or b == "Roll")
	elseif action == "RigManeuver" then
		return typeof(a) == "string" and #a <= 64 and Actions.finiteVector(b)
	elseif action == "Surge" then
		return (a == "Q" or a == "E" or a == "R") and Actions.finiteVector(b)
	end
	return false
end
function Actions.side(value)
	return if value == "Left" then "Left" else "Right"
end
function Actions.combo(previousSide, count, lastHit, side, now)
	return if previousSide
			and previousSide ~= side
			and lastHit
			and now - lastHit <= Actions.ComboWindow
		then math.min((count or 0) + 1, 3)
		else 1
end
-- `baseCooldown`: the weapon's own swing pace (its Attack.Rate), if it has one.
function Actions.resolve(counts, weaponType, cooldownReduction, baseCooldown: number?)
	local result = {
		BasicDamage = 1,
		BasicCooldown = baseCooldown or if weaponType == "Sword" then 0.65 else 0.45,
		HeavyDamage = 1.8,
		HeavyPvPDamage = 1.5,
		HeavyCooldown = 1.2,
		HeavyCrit = 0,
		Knockback = 12,
		DodgeCooldown = 3,
		DodgeDistance = 15,
		Invincible = 0.5,
		PvPInvincible = 0.3,
		BlockReduction = 0.5,
		BlockPvPReduction = 0.4,
		BlockArc = 120,
		Deflect = false,
		Stagger = 0,
	}
	for _, family in ArmorFamilies.Order do
		if (counts[family] or 0) >= 2 then
			local e = ArmorFamilies.Enhancements[family]
			result.BasicDamage *= e.BasicDamage or 1
			result.BasicCooldown /= e.AttackSpeed or 1
			result.Knockback *= e.Knockback or 1
			result.HeavyDamage *= e.HeavyDamage or 1
			result.HeavyPvPDamage *= e.HeavyDamage or 1
			result.HeavyCrit += e.HeavyCrit or 0
			result.DodgeCooldown *= e.DodgeCooldown or 1
			result.DodgeDistance *= e.DodgeDistance or 1
			result.Invincible = math.max(result.Invincible, e.Invincible or 0)
			result.BlockReduction = math.max(result.BlockReduction, e.BlockReduction or 0)
			result.BlockPvPReduction = math.max(result.BlockPvPReduction, e.BlockPvPReduction or 0)
			result.BlockArc *= e.BlockWidth or 1
			result.Deflect = result.Deflect or e.Deflect == true
			result.Stagger = math.max(result.Stagger, e.Stagger or 0)
		end
	end
	local multiplier = 1 - math.clamp(cooldownReduction or 0, 0, 0.6)
	result.HeavyCooldown *= multiplier
	result.DodgeCooldown *= multiplier
	return result
end

-- The rules a loadout fights by with this weapon: its set bonuses, its own
-- swing pace (Attack.Rate) and its perk (Shared.WeaponForge: faster swings,
-- a heavier knockback). `effects`: Classes.effects of the loadout.
function Actions.forWeapon(counts, weapon, effects)
	effects = effects or {}
	local attack = weapon and weapon.Attack or {}
	local rules = Actions.resolve(
		counts,
		if attack.Kind == "Melee" then "Sword" else "Pistol",
		1 - (effects.CooldownMult or 1),
		attack.Rate
	)
	if effects.AttackSpeed then
		rules.BasicCooldown /= 1 + effects.AttackSpeed
	end
	if effects.Knockback then
		rules.Knockback *= 1 + effects.Knockback
	end
	if weapon and weapon.WeaponBlock then
		rules.BlockReduction = 0.30
		rules.BlockPvPReduction = 0.25
		rules.BlockArc = 90
		rules.Deflect = false
	end
	return rules
end
function Actions.finiteVector(v)
	return typeof(v) == "Vector3"
		and v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) < 1e6
		and math.abs(v.Y) < 1e6
		and math.abs(v.Z) < 1e6
end
function Actions.canPvP(source, target, sourceInArena, targetInArena, sourceOptedIn, targetOptedIn, sameTeam)
	return source ~= target
		and sourceInArena
		and targetInArena
		and sourceOptedIn == true
		and targetOptedIn == true
		and not sameTeam
end
-- `kind` "Hop" has its own, shorter window; otherwise it's a roll.
function Actions.invulnerable(started, now, rules, pvp, kind)
	local window = if kind == "Hop"
		then (if pvp then Actions.Base.Hop.PvPInvincible else Actions.Base.Hop.Invincible)
		else (if pvp then rules.PvPInvincible else rules.Invincible)
	return started ~= nil and now >= started and now - started < window
end

-- Space taps: a second tap within DoubleTap of the last makes a roll.
function Actions.dodgeKind(lastTap: number?, now: number): string
	return if lastTap and now - lastTap <= Actions.DoubleTap then "Roll" else "Hop"
end
function Actions.blockMultiplier(rules, pvp, facingDot, projectile, heavy)
	if heavy or facingDot < math.cos(math.rad(rules.BlockArc / 2)) then
		return 1, false
	end
	if projectile and rules.Deflect then
		return 0, true
	end
	return 1 - (if pvp then rules.BlockPvPReduction else rules.BlockReduction), true
end
return Actions

end)()
local GemRoller=(function()
--[[
	Rolls a mined gem, in order (Ability System v3.0):
	  1. Element   25% each: Thermal (Fire), Cryo (Frost), Corrosive (Poison), Ion (Shock)
	  2. Rarity    40% Common, 25% Uncommon, 20% Rare, 10% Ultra Rare, 5% Legendary
	  3. Tier      the Gem Surge it carries: Novice (1) to Master (4), by rarity
	  4. Surge     the element's surge at that tier; an Apprentice or Adept gem
	               may carry a Resonance surge instead (no element needed)
	  5. Rank      I-III, by rarity
	  6. Metrics   Size, Clarity and Cut, 1-10, in a band set by rarity

	Pure logic (pass in a Random), shared so the client can show the same
	numbers. Saved gems keep their existing keys: `Tier` is the rarity name
	("Common" … "Legendary"); the surge is `Surge` (its id), `SurgeTier` and
	`SurgeRank`.

	Gems saved before surges existed get theirs from a seed of their id, so the
	server and every client agree without a migration (GemRoller.surge).
]]
local GemRoller = {}

GemRoller.Elements = { "Fire", "Frost", "Poison", "Shock" }

GemRoller.Rarities = {
	{ Name = "Common", Weight = 40 },
	{ Name = "Uncommon", Weight = 25 },
	{ Name = "Rare", Weight = 20 },
	{ Name = "UltraRare", Weight = 10 },
	{ Name = "Legendary", Weight = 5 },
}

-- What each rarity can carry: surge tiers (which surge), the chance of each
-- surge rank (its power, I / II / III) and the 1-10 band its metrics roll in
-- (low grades in the band are likelier). Every surge exists at every rank:
-- rarer gems just roll the higher ranks more often (a Legendary is never I).
GemRoller.ByRarity = {
	Common = { Tiers = { 1 }, RankWeights = { 70, 25, 5 }, Metrics = { 1, 4 } },
	Uncommon = { Tiers = { 1, 2 }, RankWeights = { 50, 35, 15 }, Metrics = { 2, 6 } },
	Rare = { Tiers = { 2, 3 }, RankWeights = { 30, 45, 25 }, Metrics = { 4, 8 } },
	UltraRare = { Tiers = { 3, 4 }, RankWeights = { 15, 45, 40 }, Metrics = { 6, 10 } },
	Legendary = { Tiers = { 4 }, RankWeights = { 0, 35, 65 }, Metrics = { 8, 10 } },
}
-- The ranks each rarity can roll (from its weights).
for _, rules in GemRoller.ByRarity do
	rules.Ranks = {}
	for rank, weight in rules.RankWeights do
		if weight > 0 then
			table.insert(rules.Ranks, rank)
		end
	end
end
-- A rank by its weights; `roll` is 0-1.
local function rankFor(rules, roll: number): number
	local total = 0
	for _, weight in rules.RankWeights do
		total += weight
	end
	local at = roll * total
	for rank, weight in rules.RankWeights do
		at -= weight
		if at < 0 and weight > 0 then
			return rank
		end
	end
	return rules.Ranks[#rules.Ranks]
end

-- Each element's surge at each tier (ids in CombatTechnology's catalog).
GemRoller.TierNames = { "Novice", "Apprentice", "Adept", "Master" }
GemRoller.Surges = {
	Fire = { "ThermalBurst", "EmberLance", "SolarFlare", "Supernova" },
	Frost = { "CryoLance", "CryoStream", "CryoShield", "AbsoluteZero" },
	Poison = { "AcidSpray", "ArmorMelt", "ToxicCloud", "BioCorrosion" },
	Shock = { "IonSpark", "StaticField", "ChainLightning", "Overload" },
}
-- Resonance surges have no element: an Apprentice or Adept gem of any element
-- carries one instead of its own surge this often.
GemRoller.Resonance = { [2] = "EnergySiphon", [3] = "ResonanceEcho" }
GemRoller.SurgeVariants = {
	Fire = { "CinderDrill", "FurnaceCrescent", "MagmaFault", "SolarExecution" },
	Frost = { "FrostNeedle", "GlacierFan", "PermafrostSpire", "ShatterCrown" },
	Poison = { "CausticDart", "VitriolSweep", "LeechBloom", "Dissolution" },
	Shock = { "ArcNeedle", "CircuitCleave", "ThunderPylon", "Railstorm" },
}
GemRoller.ResonanceVariants = { [2] = "ResonantReaver", [3] = "NullPrism" }
GemRoller.ResonanceChance = 0.12

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

-- A grade in [low, high], each step up a little less likely than the last.
local function grade(rng, band): number
	local low, high = band[1], band[2]
	local total, weights = 0, {}
	for value = low, high do
		local weight = 1 / (1 + (value - low) * 0.35)
		weights[value] = weight
		total += weight
	end
	local roll = rng:NextNumber() * total
	for value = low, high do
		roll -= weights[value]
		if roll <= 0 then
			return value
		end
	end
	return high
end

-- Rarity weights, nudged toward the rarer end by luck (0 = baseline, 1 = very lucky).
function GemRoller.rarityWeights(luck: number?): { number }
	local weights = {}
	for i, rarity in GemRoller.Rarities do
		weights[i] = rarity.Weight * (1 + (luck or 0) * (i - 1) * 0.75)
	end
	return weights
end

function GemRoller.rollRarity(rng, luck: number?): string
	local weights = GemRoller.rarityWeights(luck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for i, weight in weights do
		roll -= weight
		if roll <= 0 then
			return GemRoller.Rarities[i].Name
		end
	end
	return GemRoller.Rarities[#GemRoller.Rarities].Name
end

-- The rolls, as saved gem fields.
function GemRoller.roll(rng, luck: number?)
	local element = pick(rng, GemRoller.Elements)
	local rarity = GemRoller.rollRarity(rng, luck)
	local rules = GemRoller.ByRarity[rarity]
	local tier = pick(rng, rules.Tiers)
	local alternate = rng:NextNumber() < 0.5
	local surge = (if alternate then GemRoller.SurgeVariants else GemRoller.Surges)[element][tier]
	if GemRoller.Resonance[tier] and rng:NextNumber() < GemRoller.ResonanceChance then
		surge = (if alternate then GemRoller.ResonanceVariants else GemRoller.Resonance)[tier]
	end
	return {
		Element = element,
		Tier = rarity,
		Surge = surge,
		SurgeTier = tier,
		SurgeRank = rankFor(rules, rng:NextNumber()),
		Size = grade(rng, rules.Metrics),
		Clarity = grade(rng, rules.Metrics),
		Cut = grade(rng, rules.Metrics),
	}
end

-- Gives a rolled gem a different element, with that element's surge at the
-- same tier (a Resonance surge has no element and stays).
function GemRoller.setElement(gem, element: string)
	local oldVariants = GemRoller.SurgeVariants[gem.Element]
	local alternate = oldVariants and oldVariants[gem.SurgeTier] == gem.Surge
	local surges = (if alternate then GemRoller.SurgeVariants else GemRoller.Surges)[element]
	if
		surges
		and gem.SurgeTier
		and gem.Surge ~= GemRoller.Resonance[gem.SurgeTier]
		and gem.Surge ~= GemRoller.ResonanceVariants[gem.SurgeTier]
	then
		gem.Surge = surges[gem.SurgeTier] or gem.Surge
	end
	gem.Element = element
	return gem
end

-- The surge a gem carries: its saved roll, or one seeded from its id.
function GemRoller.surge(gem): (number, number)
	if gem.SurgeTier and gem.SurgeRank then
		return math.clamp(gem.SurgeTier, 1, 4), math.clamp(gem.SurgeRank, 1, 3)
	end
	local rules = GemRoller.ByRarity[gem.Tier] or GemRoller.ByRarity.Common
	local seed = 17
	for i = 1, #(gem.Id or "") do
		seed = (seed * 31 + string.byte(gem.Id, i)) % 2147483647
	end
	local tier = rules.Tiers[seed % #rules.Tiers + 1]
	local rank = rankFor(rules, ((seed // 7) % 1000) / 1000)
	return tier, rank
end

return GemRoller

end)()
local Tech=(function()
-- Grounded mining technology. Costs follow the approved universe conversion;
-- recovery, regeneration and unspecified damage are first-playtest tuning.
local Tech = {}
Tech.Resources = {
	Stamina = { Max = 100, Start = 100, Regen = 12, Color = Color3.fromRGB(65, 195, 112) },
	-- Charge fills slowly on its own and faster as your weapon lands hits
	-- (OnHit / OnHeavy), so surges come between blows rather than in a
	-- stream. A fight starts part-full (Start), not with a full bar.
	Charge = { Max = 100, Start = 40, Regen = 3, OnHit = 3, OnHeavy = 7, Color = Color3.fromRGB(70, 130, 255) },
}
-- After any surge, no other surge (or swing) for at least this long, however
-- much Rank and Clarity shorten its recovery: no back-to-back casting.
Tech.SurgeLockout = 0.9
Tech.DodgeCost = 15
Tech.ProgressionTerms = {
	Tree = "Augment Tree",
	Points = "Augment Points",
	Branches = { "Rig Maneuvers", "Surge Amplifiers", "Passive Augments" },
}
Tech.Order = {
	RigManeuvers = {
		"HydraulicSlam",
		"ServoFlurry",
		"KineticRam",
		"StimDodge",
		"BreachHammer",
		"ArmorPiercer",
		"SeismicBreaker",
		"TremorSlam",
		"PneumaticJab",
		"ThrusterLeap",
		"RiposteStance",
	},
	-- Gem Surges come from gems, not the tree: Tech.Surges[element][tier].
	GemSurges = {
		"ThermalBurst",
		"EmberLance",
		"SolarFlare",
		"Supernova",
		"CryoLance",
		"CryoStream",
		"CryoShield",
		"AbsoluteZero",
		"AcidSpray",
		"ArmorMelt",
		"ToxicCloud",
		"BioCorrosion",
		"IonSpark",
		"StaticField",
		"ChainLightning",
		"Overload",
		"EnergySiphon",
		"ResonanceEcho",
	},
}
-- Original and alternate surges at each tier. Saved gems retain their IDs.
Tech.Surges = GemRoller.Surges
Tech.Resonance = GemRoller.Resonance
Tech.SurgeVariants = GemRoller.SurgeVariants
Tech.ResonanceVariants = GemRoller.ResonanceVariants
Tech.TierNames = GemRoller.TierNames
Tech.SurgeSlots = 3 -- Q, E, R
-- The Surge Array keys and the saved capacitor sockets they cast from
-- (Character.Surge1Gem, Surge2Gem, Surge3Gem).
Tech.SurgeSockets = { Q = "Surge1", E = "Surge2", R = "Surge3" }
function Tech.surgeGem(loadout, key: string)
	local slot = Tech.SurgeSockets[key]
	return if slot and loadout then loadout[slot .. "Gem"] else nil
end
Tech.ManeuverSlots = 3 -- 1, 2, 3
Tech.DefaultManeuvers = { "HydraulicSlam", "KineticRam", "StimDodge" }
--[[ Every ability's timing:
  Recovery  the short lockout after using it: no other ability or swing
            until it passes (a global cooldown)
  Cooldown  how long until this one ability is ready again
  Surges climb by tier: about 4s (Novice), 8s (Apprentice), 12s (Adept)
  and 20s (Master), each tier hitting harder per cast.
  Further fields (surges and maneuvers alike):
  Blind     a share of the target's attacks miss, for BlindTime seconds
  Ward      after the cast, a barrier { Kind = "Burn" | "Stun", Shield,
            Duration, Power (burn per second, x weapon damage) or Stun
            (seconds) } that punishes anyone who hits you, once a second
  Leech     you heal this share of the damage it deals
  Interrupt cancels a surge the target is casting or pouring and locks
            its surges for this many seconds (Pneumatic Jab)
  Leap      leaps up to this many studs at the aimed spot; the blow lands
            on touchdown (Thruster Leap)
  Riposte   braced this many seconds: the next blow is turned aside and
            answered for CounterDamage x weapon damage (Riposte Stance) ]]
Tech.Catalog = {
	HydraulicSlam = {
		Name = "Hydraulic Slam",
		Resource = "Stamina",
		Cost = 15,
		Damage = 2,
		Heavy = true,
		Cooldown = 6,
		Recovery = 0.45,
		Range = 7,
		Description = "Hydraulic strike; 200% weapon damage and breaks guard.",
	},
	ServoFlurry = {
		Name = "Servo Flurry",
		Resource = "Stamina",
		Cost = 12,
		Damage = 0.9,
		Hits = 2,
		Cooldown = 5,
		Recovery = 0.45,
		Range = 7,
		Description = "Two servo-assisted strikes, each dealing 90% weapon damage.",
	},
	KineticRam = {
		Name = "Kinetic Ram",
		Resource = "Stamina",
		Cost = 14,
		Damage = 1.65,
		Stun = 0.5,
		Shield = true,
		Cooldown = 8,
		Recovery = 0.45,
		Range = 5,
		Description = "Shield-mounted kinetic pulse; 165% weapon damage and stagger.",
	},
	StimDodge = {
		Name = "Stim Dodge",
		Resource = "Stamina",
		Cost = 15, -- (the dodge's own cost)
		Heal = 0.08,
		Cooldown = 12,
		Recovery = 0.4,
		Description = "Dodge with a medical injector restoring 8% maximum Health.",
	},
	BreachHammer = {
		Name = "Breach Hammer",
		Resource = "Stamina",
		Cost = 22,
		Damage = 3.5,
		Windup = 1,
		Heavy = true,
		Cooldown = 10,
		Recovery = 1,
		Range = 7,
		Description = "One-second hydraulic wind-up, then a 350% overhead strike that breaks guard.",
	},
	ArmorPiercer = {
		Name = "Armor Piercer",
		Resource = "Stamina",
		Cost = 15,
		Damage = 1.6,
		Pierce = true,
		Shred = 0.25,
		ShredTime = 4,
		Cooldown = 8,
		Recovery = 0.45,
		Range = 7,
		Description = "Directed energy pulse: 160% damage that bypasses guard and shreds 25% armor for 4s.",
	},
	-- Counters: answer a cast, close the gap, turn a blow aside.
	PneumaticJab = {
		Name = "Pneumatic Jab",
		Resource = "Stamina",
		Cost = 8,
		Damage = 0.6,
		Interrupt = 2, -- cancels a surge being cast or poured; surges locked this long
		Range = 7,
		Cooldown = 10,
		Recovery = 0.4,
		Description = "A lightning jab: 60% damage, and it cancels a surge being cast and locks the caster's surges for 2s.",
	},
	ThrusterLeap = {
		Name = "Thruster Leap",
		Resource = "Stamina",
		Cost = 14,
		Damage = 2.5,
		Leap = 18, -- studs, at the aimed spot
		Windup = 0.4, -- in the air
		Range = 7,
		Cooldown = 12,
		Recovery = 0.45,
		Description = "A thruster leap of up to 18 studs at your target, slamming down for 250% damage.",
	},
	RiposteStance = {
		Name = "Riposte Stance",
		Resource = "Stamina",
		Cost = 10,
		Riposte = 1, -- seconds braced
		CounterDamage = 1,
		Cooldown = 14,
		Recovery = 0.5,
		Description = "Brace for 1s: the next blow is turned aside, its attacker staggered for 1s and struck back for 100%.",
	},
	ThermalBurst = {
		Name = "Thermal Burst",
		Resource = "Charge",
		Cost = 24,
		Element = "Fire",
		Damage = 0.9,
		Radius = 8,
		Range = 35,
		Cooldown = 6,
		Recovery = 0.6,
		Description = "Socket-powered plasma detonation at the aimed surface.",
	},
	EmberLance = {
		Name = "Ember Lance",
		Resource = "Charge",
		Cost = 25,
		Element = "Fire",
		Damage = 1.5,
		Range = 45,
		Cooldown = 7,
		Recovery = 0.8,
		Description = "A superheated plasma bolt that sets its target burning.",
	},
	SolarFlare = {
		Name = "Solar Flare",
		Resource = "Charge",
		Cost = 35,
		Element = "Fire",
		Damage = 1.55,
		Radius = 12,
		Range = 35,
		Windup = 0.6,
		Blind = 0.35,
		BlindTime = 2.5,
		Cooldown = 12,
		Recovery = 1,
		Description = "A searing flash at the aimed spot: 155% damage and Blinds (35% of attacks miss) for 2.5s.",
	},
	Supernova = {
		Name = "Supernova",
		Resource = "Charge",
		Cost = 45,
		Element = "Fire",
		Damage = 2,
		Radius = 14,
		Range = 30,
		Windup = 1.2,
		Ward = { Kind = "Burn", Shield = 15, Duration = 6, Power = 0.1 },
		Cooldown = 20,
		Recovery = 1.2,
		Description = "A colossal plasma blast, then a Burning Ward: a barrier that burns anyone who hits you.",
	},
	-- Resonance surges: no element; any gem can carry one (GemRoller.Resonance).
	EnergySiphon = {
		Name = "Energy Siphon",
		Resource = "Charge",
		Cost = 28,
		Duration = 4,
		Absorb = 35,
		Cooldown = 10,
		Recovery = 1,
		Description = "An absorption field soaks up 35 incoming damage for four seconds and turns it into Charge.",
	},
	ResonanceEcho = {
		Name = "Resonance Echo",
		Resource = "Charge",
		Cost = 40,
		Duration = 2,
		Cooldown = 16,
		Recovery = 1,
		Description = "Stored gem resonance makes every weapon strike hit twice for two seconds.",
	},
	CryoLance = {
		Name = "Cryo Lance",
		Resource = "Charge",
		Cost = 24,
		Element = "Frost",
		Damage = 0.95,
		Stun = 0.4,
		Range = 45,
		Cooldown = 6,
		Recovery = 0.6,
		Description = "A cryogenic lance that freezes its target in place for a moment.",
	},
	CryoStream = {
		Name = "Cryo Stream",
		Resource = "Charge",
		Cost = 18,
		PerSecond = true,
		Element = "Frost",
		Damage = 1.65,
		Slow = 0.3,
		Range = 24,
		Cooldown = 8,
		Recovery = 0.25,
		Description = "Hold to channel a slowing cryogenic beam; costs 18 Charge per second.",
	},
	CryoShield = {
		Name = "Cryo Shield",
		Resource = "Charge",
		Cost = 30,
		Element = "Frost",
		Duration = 4,
		Cooldown = 14,
		Recovery = 0.6,
		Description = "Cryogenic barrier absorbs damage for four seconds.",
	},
	--[[ Gem Surge fields beyond the basics:
	  Cone      degrees: hits everyone in a cone in front, out to Range
	  Self      the Radius burst centres on you instead of the aimed spot
	  Shred     armor shred (fraction of Defense) for ShredTime seconds
	  Chain     bounces to this many more enemies within ChainRange
	  Execute   finishes a target left below this share of its health
	  Spread    shred and half the hit jump to everyone within this radius
	  Cloud     a lingering pool: { Duration, Every, Damage, Shred }
	  Piercing  the bolt hits everyone along its line, not just the first
	  SlowTime  how long Slow lasts (default 0.75s) ]]
	SeismicBreaker = {
		Name = "Seismic Breaker",
		Resource = "Stamina",
		Cost = 26,
		Damage = 3.8,
		Heavy = true,
		Windup = 1.2,
		Stun = 0.6,
		Cooldown = 16,
		Recovery = 1.2,
		Range = 8,
		Description = "Long wind-up, then a 380% ground-breaker that smashes guard and staggers.",
	},
	TremorSlam = {
		Name = "Tremor Slam",
		Resource = "Stamina",
		Cost = 20,
		Damage = 2.3,
		Stun = 1,
		Cooldown = 14,
		Recovery = 0.6,
		Range = 8,
		Description = "Ground slam: 230% damage and a 1s stun.",
	},
	AcidSpray = {
		Name = "Acid Spray",
		Resource = "Charge",
		Cost = 24,
		Element = "Poison",
		Damage = 1,
		Cone = 70,
		Range = 12,
		Shred = 0.15,
		ShredTime = 5,
		Cooldown = 6,
		Recovery = 0.6,
		Description = "A cone of corrosive spray that eats 15% of armor for five seconds.",
	},
	ArmorMelt = {
		Name = "Armor Melt",
		Resource = "Charge",
		Cost = 25,
		Element = "Poison",
		Damage = 1.1,
		Range = 40,
		Shred = 0.30,
		ShredTime = 5,
		Slow = 0.3,
		SlowTime = 2,
		Cooldown = 9,
		Recovery = 0.8,
		Description = "Corrosive bolt: shreds 30% armor and slows the target 30% for 2s.",
	},
	ToxicCloud = {
		Name = "Toxic Cloud",
		Resource = "Charge",
		Cost = 35,
		Element = "Poison",
		Damage = 0.4,
		Radius = 9,
		Range = 30,
		Shred = 0.10,
		ShredTime = 2,
		Cloud = { Duration = 5, Every = 1, Damage = 0.35, Shred = 0.10 },
		Duration = 5,
		Leech = 0.5,
		Cooldown = 14,
		Recovery = 1,
		Description = "A lingering toxic pool; you drain half of the damage it deals as Health.",
	},
	BioCorrosion = {
		Name = "Bio-Corrosion",
		Resource = "Charge",
		Cost = 45,
		Element = "Poison",
		Damage = 3.55,
		Range = 40,
		Shred = 0.20,
		ShredTime = 6,
		Spread = 10,
		Cooldown = 20,
		Recovery = 1.2,
		Description = "Infect one target; its corrosion and half the hit spread to every enemy within 10 studs.",
	},
	IonSpark = {
		Name = "Ion Spark",
		Resource = "Charge",
		Cost = 24,
		Element = "Shock",
		Damage = 1.25,
		Stun = 0.25,
		Range = 40,
		Chain = 1,
		ChainRange = 12,
		Cooldown = 6,
		Recovery = 0.5,
		Description = "A quick ion bolt that jolts its target (a brief stun) and arcs to one more enemy.",
	},
	StaticField = {
		Name = "Static Field",
		Resource = "Charge",
		Cost = 30,
		Element = "Shock",
		Damage = 0.5,
		Radius = 8,
		Self = true,
		Range = 0,
		Stun = 0.5,
		Ward = { Kind = "Stun", Shield = 15, Duration = 5, Stun = 0.4 },
		Cooldown = 10,
		Recovery = 0.6,
		Description = "A static burst around you, then a Static Shell: a barrier that shocks anyone who hits you.",
	},
	ChainLightning = {
		Name = "Chain Lightning",
		Resource = "Charge",
		Cost = 30,
		Element = "Shock",
		Damage = 4,
		Range = 40,
		Chain = 3,
		ChainRange = 14,
		Cooldown = 12,
		Recovery = 1,
		Description = "A bolt that bounces to up to three more enemies.",
	},
	Overload = {
		Name = "Overload",
		Resource = "Charge",
		Cost = 45,
		Element = "Shock",
		Damage = 2.4,
		Range = 40,
		Execute = 0.20,
		Cooldown = 20,
		Recovery = 1.2,
		Description = "A 240% ion blast that instantly finishes a target left below 20% health.",
	},
	AbsoluteZero = {
		Name = "Absolute Zero",
		Resource = "Charge",
		Cost = 45,
		Element = "Frost",
		Damage = 3.8,
		Radius = 10,
		Range = 30,
		Stun = 1.5,
		Slow = 0.4,
		Cooldown = 20,
		Recovery = 1.2,
		Description = "Flash-freeze the aimed area: everything in it is frozen solid, then slowed.",
	},
}
-- Arsenal expansion: shared definitions drive progression, casts and presentation.
Tech.NewSurges = {}
local expansion = {
	CinderDrill = {
		Name = "Cinder Drill",
		Resource = "Charge",
		Damage = 1.05,
		Cost = 24,
		Cooldown = 6,
		Recovery = 0.6,
		Range = 35,
		Animation = "Drill",
		Signature = "Rail",
		Description = "A narrow thermal drill burns through enemies in a line.",
		Element = "Fire",
		Piercing = true,
	},
	FurnaceCrescent = {
		Name = "Furnace Crescent",
		Resource = "Charge",
		Damage = 1.65,
		Cost = 27,
		Cooldown = 9,
		Recovery = 0.6,
		Range = 15,
		Animation = "Sweep",
		Signature = "Crescent",
		Description = "Sweep a furnace-hot arc through the frontline.",
		Element = "Fire",
		Cone = 95,
	},
	MagmaFault = {
		Name = "Magma Fault",
		Resource = "Charge",
		Damage = 2.1,
		Cost = 36,
		Cooldown = 14,
		Recovery = 0.6,
		Range = 35,
		Animation = "Erupt",
		Signature = "Spikes",
		Description = "Rupture the ground into a short-lived magma damage zone.",
		Element = "Fire",
		Radius = 7,
		Cloud = { Duration = 3, Every = 1, Damage = 0.25 },
		Duration = 3,
	},
	SolarExecution = {
		Name = "Solar Execution",
		Resource = "Charge",
		Damage = 3.4,
		Cost = 48,
		Cooldown = 21,
		Recovery = 0.6,
		Range = 35,
		Animation = "Cross",
		Signature = "Helix",
		Description = "Charge a thermal lance that finishes a badly wounded target.",
		Element = "Fire",
		Pierce = true,
		Execute = 0.12,
		Windup = 1.1,
	},
	FrostNeedle = {
		Name = "Frost Needle",
		Resource = "Charge",
		Damage = 1.05,
		Cost = 24,
		Cooldown = 6,
		Recovery = 0.6,
		Range = 35,
		Animation = "Drill",
		Signature = "Rail",
		Description = "A precise cryo needle slows the target.",
		Element = "Frost",
		Slow = 0.25,
		SlowTime = 2,
	},
	GlacierFan = {
		Name = "Glacier Fan",
		Resource = "Charge",
		Damage = 1.65,
		Cost = 27,
		Cooldown = 9,
		Recovery = 0.6,
		Range = 15,
		Animation = "Sweep",
		Signature = "Crescent",
		Description = "Cast a fan of ice that slows a crowded frontline.",
		Element = "Frost",
		Cone = 100,
		Slow = 0.3,
		SlowTime = 2.5,
	},
	PermafrostSpire = {
		Name = "Permafrost Spire",
		Resource = "Charge",
		Damage = 2.1,
		Cost = 36,
		Cooldown = 14,
		Recovery = 0.6,
		Range = 35,
		Animation = "Erupt",
		Signature = "Spikes",
		Description = "Raise a cryo spire that briefly freezes its impact area.",
		Element = "Frost",
		Radius = 6,
		Stun = 0.6,
		Slow = 0.3,
		SlowTime = 3,
	},
	ShatterCrown = {
		Name = "Shatter Crown",
		Resource = "Charge",
		Damage = 3.4,
		Cost = 48,
		Cooldown = 21,
		Recovery = 0.6,
		Range = 35,
		Animation = "Cross",
		Signature = "Helix",
		Description = "A crown of fractured ice slows enemies and exposes their armor.",
		Element = "Frost",
		Radius = 9,
		Slow = 0.45,
		SlowTime = 4,
		Shred = 0.15,
		ShredTime = 4,
		Windup = 1.2,
	},
	CausticDart = {
		Name = "Caustic Dart",
		Resource = "Charge",
		Damage = 1.05,
		Cost = 24,
		Cooldown = 6,
		Recovery = 0.6,
		Range = 35,
		Animation = "Drill",
		Signature = "Rail",
		Description = "Inject a corrosive dart that weakens armor.",
		Element = "Poison",
		Shred = 0.1,
		ShredTime = 3,
	},
	VitriolSweep = {
		Name = "Vitriol Sweep",
		Resource = "Charge",
		Damage = 1.65,
		Cost = 27,
		Cooldown = 9,
		Recovery = 0.6,
		Range = 15,
		Animation = "Sweep",
		Signature = "Crescent",
		Description = "Sweep a caustic blade through a fan of enemies.",
		Element = "Poison",
		Cone = 90,
		Shred = 0.15,
		ShredTime = 3,
	},
	LeechBloom = {
		Name = "Leech Bloom",
		Resource = "Charge",
		Damage = 2.1,
		Cost = 36,
		Cooldown = 14,
		Recovery = 0.6,
		Range = 35,
		Animation = "Erupt",
		Signature = "Spikes",
		Description = "Bloom a corrosive pool that returns a share of its damage as health.",
		Element = "Poison",
		Radius = 6,
		Leech = 0.2,
		Cloud = { Duration = 3, Every = 1, Damage = 0.2 },
		Duration = 3,
	},
	Dissolution = {
		Name = "Dissolution",
		Resource = "Charge",
		Damage = 3.4,
		Cost = 48,
		Cooldown = 21,
		Recovery = 0.6,
		Range = 35,
		Animation = "Cross",
		Signature = "Helix",
		Description = "Concentrate a drilling acid beam to bypass guard and dissolve armor.",
		Element = "Poison",
		Pierce = true,
		Shred = 0.3,
		ShredTime = 5,
		Windup = 1.1,
	},
	ArcNeedle = {
		Name = "Arc Needle",
		Resource = "Charge",
		Damage = 1.05,
		Cost = 24,
		Cooldown = 6,
		Recovery = 0.6,
		Range = 35,
		Animation = "Drill",
		Signature = "Rail",
		Description = "A fast ion needle disrupts a surge cast.",
		Element = "Shock",
		Interrupt = 1,
	},
	CircuitCleave = {
		Name = "Circuit Cleave",
		Resource = "Charge",
		Damage = 1.65,
		Cost = 27,
		Cooldown = 9,
		Recovery = 0.6,
		Range = 15,
		Animation = "Sweep",
		Signature = "Crescent",
		Description = "Sweep a circuit blade across enemies for a brief stun.",
		Element = "Shock",
		Cone = 100,
		Stun = 0.25,
	},
	ThunderPylon = {
		Name = "Thunder Pylon",
		Resource = "Charge",
		Damage = 2.1,
		Cost = 36,
		Cooldown = 14,
		Recovery = 0.6,
		Range = 35,
		Animation = "Erupt",
		Signature = "Spikes",
		Description = "Erupt an ion pylon that stuns the impact area.",
		Element = "Shock",
		Radius = 7,
		Stun = 0.45,
	},
	Railstorm = {
		Name = "Railstorm",
		Resource = "Charge",
		Damage = 3.4,
		Cost = 48,
		Cooldown = 21,
		Recovery = 0.6,
		Range = 35,
		Animation = "Cross",
		Signature = "Helix",
		Description = "Discharge a piercing rail beam that interrupts enemies along its line.",
		Element = "Shock",
		Piercing = true,
		Interrupt = 2,
		Windup = 1.1,
	},
	ResonantReaver = {
		Name = "Resonant Reaver",
		Resource = "Charge",
		Damage = 1.5,
		Cost = 28,
		Cooldown = 10,
		Recovery = 0.6,
		Range = 14,
		Animation = "Sweep",
		Signature = "Crescent",
		Description = "A neutral resonance sweep converts part of its damage into health.",
		Cone = 90,
		Leech = 0.2,
	},
	NullPrism = {
		Name = "Null Prism",
		Resource = "Charge",
		Damage = 2.2,
		Cost = 37,
		Cooldown = 15,
		Recovery = 0.6,
		Range = 35,
		Animation = "Cross",
		Signature = "Helix",
		Description = "A neutral prism pulse interrupts the target and weakens its armor.",
		Interrupt = 2,
		Shred = 0.15,
		ShredTime = 3,
	},
}
for id, definition in expansion do
	Tech.Catalog[id] = definition
end
table.insert(Tech.Order.GemSurges, "CinderDrill")
table.insert(Tech.NewSurges, "CinderDrill")
table.insert(Tech.Order.GemSurges, "FurnaceCrescent")
table.insert(Tech.NewSurges, "FurnaceCrescent")
table.insert(Tech.Order.GemSurges, "MagmaFault")
table.insert(Tech.NewSurges, "MagmaFault")
table.insert(Tech.Order.GemSurges, "SolarExecution")
table.insert(Tech.NewSurges, "SolarExecution")
table.insert(Tech.Order.GemSurges, "FrostNeedle")
table.insert(Tech.NewSurges, "FrostNeedle")
table.insert(Tech.Order.GemSurges, "GlacierFan")
table.insert(Tech.NewSurges, "GlacierFan")
table.insert(Tech.Order.GemSurges, "PermafrostSpire")
table.insert(Tech.NewSurges, "PermafrostSpire")
table.insert(Tech.Order.GemSurges, "ShatterCrown")
table.insert(Tech.NewSurges, "ShatterCrown")
table.insert(Tech.Order.GemSurges, "CausticDart")
table.insert(Tech.NewSurges, "CausticDart")
table.insert(Tech.Order.GemSurges, "VitriolSweep")
table.insert(Tech.NewSurges, "VitriolSweep")
table.insert(Tech.Order.GemSurges, "LeechBloom")
table.insert(Tech.NewSurges, "LeechBloom")
table.insert(Tech.Order.GemSurges, "Dissolution")
table.insert(Tech.NewSurges, "Dissolution")
table.insert(Tech.Order.GemSurges, "ArcNeedle")
table.insert(Tech.NewSurges, "ArcNeedle")
table.insert(Tech.Order.GemSurges, "CircuitCleave")
table.insert(Tech.NewSurges, "CircuitCleave")
table.insert(Tech.Order.GemSurges, "ThunderPylon")
table.insert(Tech.NewSurges, "ThunderPylon")
table.insert(Tech.Order.GemSurges, "Railstorm")
table.insert(Tech.NewSurges, "Railstorm")
table.insert(Tech.Order.GemSurges, "ResonantReaver")
table.insert(Tech.NewSurges, "ResonantReaver")
table.insert(Tech.Order.GemSurges, "NullPrism")
table.insert(Tech.NewSurges, "NullPrism")

Tech.PassiveAugments = {
	{ Name = "Blade Calibration", Description = "Slashing weapon damage." },
	{ Name = "Cleaver Calibration", Description = "Cleaving weapon damage." },
	{ Name = "Mobility Augment", Description = "Movement speed." },
	{ Name = "Stamina Recycler", Description = "Stamina regeneration." },
	{ Name = "Charge Recycler", Description = "Charge regeneration." },
	{ Name = "Thermal Overcharge", Description = "Thermal damage." },
	{ Name = "Corrosive Overcharge", Description = "Corrosive damage." },
	{ Name = "Ion Overcharge", Description = "Ion damage." },
	{ Name = "Cryo Overcharge", Description = "Cryo damage." },
	{ Name = "Elemental Harmony", Description = "Damage after switching elements." },
}
-- The surge a gem casts: its id, surge tier and rank. Rolled gems save the id;
-- older gems take their element's surge at their tier.
function Tech.surgeOf(gem): (string?, number, number)
	local tier, rank = GemRoller.surge(gem)
	local saved = gem.Surge and Tech.Catalog[gem.Surge]
	if saved and saved.Resource == "Charge" then
		return gem.Surge, tier, rank
	end
	local list = Tech.Surges[gem.Element]
	return list and list[tier], tier, rank
end

--[[
	A gem's surge, with its numbers for this gem (a copy; the catalog is untouched):
	  Rank     I x1 · II x1.25 damage, -10% recovery, -8% cost · III x1.5, -20%, -16%
	  Size     damage +3% per grade (applied per hit, with the Overcharge perk)
	  Clarity  pools, fields and barriers +0.5s per grade; stuns, slows and
	           shred +4% longer per grade; recovery -2% and reach +2% per grade
	  Cut      critical chance +0.5% per grade; shred and execute threshold
	           +0.5 points per grade
	amps: Surge Amplifier effects from the Augment Tree (Tree.effects).
]]
Tech.Ranks = {
	{ Damage = 1, Recovery = 1, Cost = 1 },
	{ Damage = 1.25, Recovery = 0.9, Cost = 0.92 },
	{ Damage = 1.5, Recovery = 0.8, Cost = 0.84 },
}
function Tech.surgeStats(gem, amps)
	local id, tier, rank = Tech.surgeOf(gem)
	local base = id and Tech.Catalog[id]
	if not base then
		return nil
	end
	amps = amps or {}
	local d = table.clone(base)
	local scale = Tech.Ranks[rank] or Tech.Ranks[1]
	local clarity = math.clamp(gem.Clarity or 1, 1, 10)
	local cut = math.clamp(gem.Cut or 0, 0, 10)
	if d.Damage then
		d.Damage *= scale.Damage * (1 + (amps.SurgePower or 0) + (amps.ElementalMastery or 0))
	end
	d.Cost *= scale.Cost
	local longer = 1 + (amps.SurgeDuration or 0)
	if d.Duration then
		d.Duration = (d.Duration + clarity * 0.5) * longer
	end
	if d.Cloud then
		d.Cloud = table.clone(d.Cloud)
		d.Cloud.Duration = (d.Cloud.Duration + clarity * 0.5) * longer
		if d.Cloud.Shred then
			d.Cloud.Shred += cut * 0.005
		end
	end
	for _, key in { "Stun", "SlowTime", "ShredTime", "BlindTime" } do
		if d[key] then
			d[key] *= (1 + clarity * 0.04) * longer
		end
	end
	for _, key in { "Radius", "Range" } do
		if d[key] then
			d[key] *= 1 + clarity * 0.02
		end
	end
	if d.Shred then
		d.Shred += cut * 0.005
	end
	if d.Execute then
		d.Execute += cut * 0.005
	end
	local quicker = scale.Recovery * (1 - clarity * 0.02) * (1 - math.clamp(amps.SurgeEfficiency or 0, 0, 0.6))
	d.Recovery *= quicker
	d.Cooldown = (d.Cooldown or d.Recovery) * quicker
	d.Crit = cut * 0.005
	d.Echo = amps.ArcaneResonance or 0
	d.Id, d.Tier, d.Rank, d.Gem = id, tier, rank, gem
	return d
end

-- A gem's tooltip lines for its surge (the directive's gem tooltip).
function Tech.surgeLines(gem, amps): { string }
	local d = Tech.surgeStats(gem, amps)
	if not d then
		return {}
	end
	local size = math.clamp(gem.Size or 1, 1, 10)
	local lines = {
		string.format(
			"Surge: %s (Rank %s · %s surge)",
			d.Name,
			({ "I", "II", "III" })[d.Rank],
			Tech.TierNames[d.Tier] or ""
		),
	}
	if d.Damage then
		table.insert(lines, string.format("%d%% base damage", math.floor(d.Damage * 100 + 0.5)))
		table.insert(lines, string.format("Size %d (+%d%% damage)", size, size * 3))
	else
		table.insert(lines, string.format("%gs effect", math.floor(d.Duration * 10 + 0.5) / 10))
	end
	table.insert(lines, string.format("Clarity %d (%.1fs recovery)", gem.Clarity or 0, d.Recovery))
	table.insert(lines, string.format("Cut %d (%g%% crit chance)", gem.Cut or 0, d.Crit * 100))
	table.insert(lines, "Sockets into any Surge Slot.")
	return lines
end

-- Is a gem (of `element`, or any) socketed in gear or the Surge Array?
function Tech.hasGem(loadout, element)
	for _, slot in { "Surge1", "Surge2", "Surge3", "Weapon", "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
		local gem = loadout[slot .. "Gem"]
		if gem and (not element or gem.Element == element) then
			return true
		end
	end
	return false
end
function Tech.spend(resources, resource, cost)
	local available = resources[resource] or 0
	if cost < 0 or available < cost then
		return false
	end
	resources[resource] = available - cost
	return true
end
return Tech

end)()
local Tree=(function()
--[[
	Persistent, server-owned build progression, laid out like an Elder Scrolls:
	Blades skill sheet. UI and server share one node graph.

	  Augment Level  1 + XP / 150; every level also earns an Augment Point
	  Tiers          Novice opens at level 1, Apprentice at 3, Adept at 6 and
	                 Master at 10
	  Ranks          most nodes have ranks I-III (Elemental Mastery and
	                 Arcane Resonance have one); rank I learns it (its tier's
	                 cost), rank II costs its tier in points, rank III one more
	  Rank effects   maneuvers hit harder, cost less, recover faster and last
	                 longer; perks and amplifiers add their bonus again

	Branches: Rig Maneuvers (physical abilities), Surge Amplifiers (boost the
	gem surges equipped in the Surge Array) and Passive Augments. Gem Surges
	themselves are not learned here: they come from gems (GemRoller).
	Learning every node at rank I costs Tree.UnlockPoints; the rest of the
	budget (up to Tree.MaxPoints) goes into ranks.
]]
local Tree = {}
Tree.StartingPoints, Tree.XPPerPoint = 3, 150
Tree.MaxRank = 3
-- Tiers, Elder Scrolls style: the level each opens at.
Tree.TierNames = { "Novice", "Apprentice", "Adept", "Master" }
Tree.TierLevels = { 1, 3, 6, 10 }
Tree.TierCosts = { 1, 1, 2, 3 } -- points to learn a node of each tier
-- Per rank above I.
Tree.RankScaling = { Damage = 0.10, Cost = -0.08, Recovery = -0.05, Duration = 0.15, Heal = 0.25 }
Tree.Branches = { "RigManeuvers", "SurgeAmplifiers", "PassiveAugments" }
Tree.BranchNames =
	{ RigManeuvers = "Rig Maneuvers", SurgeAmplifiers = "Surge Amplifiers", PassiveAugments = "Passive Augments" }

-- Columns per branch.
-- Passive Augments has none: each tier's perks sit centred in a row.
Tree.Columns = {
	RigManeuvers = { { Name = "Strikes" }, { Name = "Tactics" }, { Name = "Counters" } },
	SurgeAmplifiers = { { Name = "Power" }, { Name = "Flow" } },
}

-- { id, tier, column, parent? }. Listed tier by tier, so parents come first.
local layout = {
	RigManeuvers = {
		{ "HydraulicSlam", 1, 1 },
		{ "ServoFlurry", 1, 2, "HydraulicSlam" },
		{ "KineticRam", 2, 1, "HydraulicSlam" },
		{ "StimDodge", 2, 2, "ServoFlurry" },
		{ "BreachHammer", 3, 1, "KineticRam" },
		{ "ArmorPiercer", 3, 2, "StimDodge" },
		{ "SeismicBreaker", 4, 1, "BreachHammer" },
		{ "TremorSlam", 4, 2, "ArmorPiercer" },
		{ "PneumaticJab", 2, 3, "ServoFlurry" },
		{ "ThrusterLeap", 3, 3, "PneumaticJab" },
		{ "RiposteStance", 4, 3, "ThrusterLeap" },
	},
	-- Gem Surges come from the gems in the Surge Array (Q, E, R); this branch
	-- only strengthens whatever surges are equipped.
	SurgeAmplifiers = {
		{ "SurgePower", 1, 1 },
		{ "SurgeEfficiency", 1, 2 },
		{ "SurgeDuration", 2, 2, "SurgeEfficiency" },
		{ "ElementalMastery", 3, 1, "SurgePower" },
		{ "ArcaneResonance", 4, 1, "ElementalMastery" },
	},
	PassiveAugments = {
		{ "BladeCalibration", 1, 1 },
		{ "CleaverCalibration", 1, 2 },
		{ "MobilityAugment", 1, 3 },
		{ "ChargeRecycler", 2, 1, "CleaverCalibration" },
		{ "StaminaRecycler", 2, 2, "MobilityAugment" },
		{ "ThermalOvercharge", 3, 1, "ChargeRecycler" },
		{ "CorrosiveOvercharge", 3, 2, "ChargeRecycler" },
		{ "IonOvercharge", 3, 3, "ChargeRecycler" },
		{ "CryoOvercharge", 3, 4, "ChargeRecycler" },
		{ "ElementalHarmony", 4, 1 },
	},
}
-- Free starters: learned from the start at rank I.
local FREE = { HydraulicSlam = true }
-- Single-rank nodes (everything else ranks I-III).
local SINGLE_RANK = { ElementalMastery = true, ArcaneResonance = true }
-- Elemental Harmony asks for any two Overcharges instead of one parent.
local REQUIRES = {
	ElementalHarmony = {
		Any = { "ThermalOvercharge", "CorrosiveOvercharge", "IonOvercharge", "CryoOvercharge" },
		Count = 2,
	},
}

local passiveDefinitions = {
	SurgePower = {
		Name = "Surge Power",
		Description = "+10% / +20% / +30% damage for every equipped surge.",
		Effect = "SurgePower",
		Amount = 0.10,
		Icon = "💠",
	},
	SurgeEfficiency = {
		Name = "Surge Efficiency",
		Description = "-10% / -20% / -30% surge cooldown.",
		Effect = "SurgeEfficiency",
		Amount = 0.10,
		Icon = "⏱",
	},
	SurgeDuration = {
		Name = "Surge Duration",
		Description = "+10% / +20% / +30% surge duration: burns, slows, freezes, shred and clouds.",
		Effect = "SurgeDuration",
		Amount = 0.10,
		Icon = "⏳",
	},
	ElementalMastery = {
		Name = "Elemental Mastery",
		Description = "All surges deal +15% damage.",
		Effect = "ElementalMastery",
		Amount = 0.15,
		Icon = "🌐",
	},
	ArcaneResonance = {
		Name = "Arcane Resonance",
		Description = "20% chance that a surge triggers a second time for free.",
		Effect = "ArcaneResonance",
		Amount = 0.20,
		Icon = "✨",
	},
	BladeCalibration = {
		Name = "Blade Calibration",
		Description = "+5% damage with swords, blades and knives per rank.",
		Effect = "Slashing",
		Amount = 0.05,
		Icon = "⚔",
	},
	CleaverCalibration = {
		Name = "Cleaver Calibration",
		Description = "+5% damage with axes and cleavers per rank.",
		Effect = "Cleaving",
		Amount = 0.05,
		Icon = "⚒",
	},
	MobilityAugment = {
		Name = "Mobility Augment",
		Description = "+5% movement speed per rank.",
		Effect = "Mobility",
		Amount = 0.05,
		Icon = "🥾",
	},
	ChargeRecycler = {
		Name = "Charge Recycler",
		Description = "+15% Charge regeneration per rank while a gem is socketed.",
		Effect = "ChargeRegen",
		Amount = 0.15,
		Icon = "🔋",
	},
	StaminaRecycler = {
		Name = "Stamina Recycler",
		Description = "+15% Stamina regeneration per rank.",
		Effect = "StaminaRegen",
		Amount = 0.15,
		Icon = "✊",
	},
	ThermalOvercharge = {
		Name = "Thermal Overcharge",
		Description = "+10% / +20% / +30% Thermal weapon, surge and burn damage.",
		Effect = "Thermal",
		Amount = 0.10,
		Icon = "🔥",
		Element = "Fire",
	},
	CorrosiveOvercharge = {
		Name = "Corrosive Overcharge",
		Description = "+10% / +20% / +30% Corrosive surge damage.",
		Effect = "Corrosive",
		Amount = 0.10,
		Icon = "☣",
		Element = "Poison",
	},
	IonOvercharge = {
		Name = "Ion Overcharge",
		Description = "+10% / +20% / +30% Ion surge damage.",
		Effect = "Ion",
		Amount = 0.10,
		Icon = "⚡",
		Element = "Shock",
	},
	CryoOvercharge = {
		Name = "Cryo Overcharge",
		Description = "+10% / +20% / +30% Cryo surge damage.",
		Effect = "Cryo",
		Amount = 0.10,
		Icon = "❄",
		Element = "Frost",
	},
	ElementalHarmony = {
		Name = "Elemental Harmony",
		Description = "Deal damage of one element and your other elements hit +10% / +20% / +30% harder for 5 seconds.",
		Effect = "Harmony",
		Amount = 0.10,
		Icon = "✦",
	},
}

Tree.Order, Tree.Nodes = {}, {}
Tree.UnlockPoints = 0
for _, branch in Tree.Branches do
	Tree.Order[branch] = {}
	for _, entry in layout[branch] do
		local id, tier, column, parent = entry[1], entry[2], entry[3], entry[4]
		local d = passiveDefinitions[id] or Tech.Catalog[id]
		local node = {
			Id = id,
			Name = d.Name,
			Description = d.Description,
			Icon = d.Icon or "✦",
			Element = d.Element,
			Effect = d.Effect,
			Amount = d.Amount,
			Branch = branch,
			Tier = tier,
			Column = column,
			Parent = parent,
			Requires = REQUIRES[id],
			Free = FREE[id] == true,
			MaxRank = if SINGLE_RANK[id] then 1 else Tree.MaxRank,
			Cost = if FREE[id] then 0 else Tree.TierCosts[tier],
		}
		Tree.Nodes[id] = node
		table.insert(Tree.Order[branch], id)
		Tree.UnlockPoints += node.Cost
	end
end
-- Learning every node at rank I costs UnlockPoints; the rest of the budget
-- goes into ranks II and III, so a full build is a choice of what to master.
Tree.MaxPoints = Tree.UnlockPoints + 47

-- Is a node's prerequisite (one parent, or "any N of" a set) met?
function Tree.prerequisiteMet(unlocked, id: string): boolean
	local n = Tree.Nodes[id]
	if not n then
		return false
	end
	if n.Parent and not unlocked[n.Parent] then
		return false
	end
	if n.Requires then
		local have = 0
		for _, other in n.Requires.Any do
			if unlocked[other] then
				have += 1
			end
		end
		return have >= n.Requires.Count
	end
	return true
end
function Tree.prerequisiteText(id: string): string?
	local n = Tree.Nodes[id]
	if not n then
		return nil
	end
	if n.Parent then
		return "Learn " .. Tree.Nodes[n.Parent].Name
	end
	if n.Requires then
		return string.format("Learn any %d Overcharges", n.Requires.Count)
	end
	return nil
end
local function finite(value)
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end
local function earned(xp)
	return math.min(Tree.MaxPoints, Tree.StartingPoints + math.floor(xp / Tree.XPPerPoint))
end
Tree.MaxLevel = Tree.MaxPoints - Tree.StartingPoints + 1
function Tree.level(xp: number): number
	return math.min(Tree.MaxLevel, 1 + math.floor(math.max(0, xp) / Tree.XPPerPoint))
end
function Tree.tierLevel(id: string): number
	local n = Tree.Nodes[id]
	return if n then Tree.TierLevels[n.Tier] or 1 else math.huge
end
-- Points to take a node from rank-1 to `rank` (rank 1 = unlocking it).
function Tree.rankCost(id: string, rank: number): number
	local n = Tree.Nodes[id]
	if not n then
		return math.huge
	end
	return if rank <= 1 then n.Cost else n.Tier + rank - 2
end
function Tree.initialize(profile)
	local saved = if typeof(profile.Augments) == "table" then profile.Augments else nil
	local xp = if saved then saved.XP else profile.Season and profile.Season.XP or 0
	xp = if finite(xp) then math.clamp(math.floor(xp), 0, 100000000) else 0
	local unlocked = { HydraulicSlam = true }
	local ranks = { HydraulicSlam = 1 }
	local source = saved and saved.Unlocked
	local savedRanks = if saved and typeof(saved.Ranks) == "table" then saved.Ranks else {}
	local spent, budget, level = 0, earned(xp), Tree.level(xp)
	-- Unlocks first (cheapest, tree order), then ranks; anything the level or
	-- budget can't cover is dropped, so a forged save can't mint power.
	if typeof(source) == "table" then
		for _, branch in Tree.Branches do
			for _, id in Tree.Order[branch] do
				local n = Tree.Nodes[id]
				if
					not n.Free
					and source[id] == true
					and Tree.prerequisiteMet(unlocked, id)
					and level >= Tree.tierLevel(id)
					and spent + n.Cost <= budget
				then
					unlocked[id], ranks[id], spent = true, 1, spent + n.Cost
				end
			end
		end
	end
	for _, branch in Tree.Branches do
		for _, id in Tree.Order[branch] do
			local wanted = savedRanks[id]
			if unlocked[id] and finite(wanted) then
				for rank = 2, math.clamp(math.floor(wanted), 1, Tree.Nodes[id].MaxRank) do
					local cost = Tree.rankCost(id, rank)
					if spent + cost > budget then
						break
					end
					ranks[id], spent = rank, spent + cost
				end
			end
		end
	end
	profile.Augments = {
		Version = 2,
		XP = xp,
		Level = level,
		Unlocked = unlocked,
		Ranks = ranks,
		Points = budget - spent,
		Earned = budget,
		Spent = spent,
	}
	return profile.Augments
end
function Tree.rank(profile, id): number
	local data = profile and profile.Augments
	if not data and profile then
		data = Tree.initialize(profile)
	end
	return if data and data.Unlocked[id] then (data.Ranks and data.Ranks[id] or 1) else 0
end
function Tree.isLearned(profile, id)
	local data = profile and profile.Augments
	if not data and profile then
		data = Tree.initialize(profile)
	end
	return Tree.Nodes[id] ~= nil and data ~= nil and data.Unlocked[id] == true
end
function Tree.learn(profile, id)
	local n = if typeof(id) == "string" then Tree.Nodes[id] else nil
	if not n then
		return false, "Unknown augment."
	end
	local data = Tree.initialize(profile)
	if data.Unlocked[id] then
		return false, "Already unlocked."
	end
	if not Tree.prerequisiteMet(data.Unlocked, id) then
		return false, (Tree.prerequisiteText(id) or "Learn its prerequisite") .. " first."
	end
	if data.Level < Tree.tierLevel(id) then
		return false, string.format("%s tier opens at Augment Level %d.", Tree.TierNames[n.Tier], Tree.tierLevel(id))
	end
	if data.Points < n.Cost then
		return false, "Not enough Augment Points."
	end
	data.Unlocked[id], data.Points = true, data.Points - n.Cost
	data.Ranks[id] = 1
	data.Spent += n.Cost
	return true, "Unlocked " .. n.Name .. "."
end
-- Raises an unlocked node one rank.
function Tree.upgrade(profile, id)
	local n = if typeof(id) == "string" then Tree.Nodes[id] else nil
	if not n then
		return false, "Unknown augment."
	end
	local data = Tree.initialize(profile)
	if not data.Unlocked[id] then
		return false, "Unlock " .. n.Name .. " first."
	end
	local rank = data.Ranks[id] or 1
	if rank >= n.MaxRank then
		return false, n.Name .. " is already at its highest rank."
	end
	local cost = Tree.rankCost(id, rank + 1)
	if data.Points < cost then
		return false, "Not enough Augment Points."
	end
	data.Ranks[id] = rank + 1
	data.Points -= cost
	data.Spent += cost
	return true, string.format("%s raised to rank %d.", n.Name, rank + 1)
end
function Tree.respec(profile)
	local data = Tree.initialize(profile)
	profile.Augments = { XP = data.XP, Unlocked = {} }
	Tree.initialize(profile)
	return true, "Augments reset. Your points have been refunded."
end
function Tree.addXP(profile, amount)
	if not finite(amount) or amount <= 0 then
		return 0
	end
	local data = Tree.initialize(profile)
	local before = data.Earned
	data.XP = math.min(100000000, data.XP + math.floor(amount))
	data.Level = Tree.level(data.XP)
	data.Earned = earned(data.XP)
	data.Points = data.Earned - data.Spent
	return data.Earned - before
end
function Tree.available(profile, branch)
	local result = {}
	for _, id in Tech.Order[branch] or {} do
		if Tree.isLearned(profile, id) then
			table.insert(result, id)
		end
	end
	return result
end
function Tree.effects(profile)
	local effects = {}
	-- Perks and Surge Amplifiers both add their bonus per rank.
	for _, branch in { "PassiveAugments", "SurgeAmplifiers" } do
		for _, id in Tree.Order[branch] do
			local rank = Tree.rank(profile, id)
			if rank > 0 then
				local n = Tree.Nodes[id]
				effects[n.Effect] = n.Amount * rank
			end
		end
	end
	return effects
end
-- A technology's numbers at the rank the player owns (a copy; the catalog is untouched).
function Tree.scaled(definition, rank: number)
	local stats = table.clone(definition)
	local steps = math.max(0, (rank or 1) - 1)
	if steps == 0 then
		return stats
	end
	local s = Tree.RankScaling
	if stats.Damage then
		stats.Damage *= 1 + s.Damage * steps
	end
	if stats.Cost then
		stats.Cost *= 1 + s.Cost * steps
	end
	if stats.Recovery then
		stats.Recovery *= 1 + s.Recovery * steps
		if stats.Cooldown then
			stats.Cooldown *= 1 + s.Recovery * steps
		end
	end
	if stats.Duration then
		stats.Duration *= 1 + s.Duration * steps
	end
	if stats.Heal then
		stats.Heal *= 1 + s.Heal * steps
	end
	return stats
end
function Tree.techStats(profile, id)
	local definition = Tech.Catalog[id]
	return definition and Tree.scaled(definition, math.max(1, Tree.rank(profile, id)))
end
function Tree.weaponMultiplier(effects, weapon)
	if weapon.Attack.Kind ~= "Melee" then
		return 1
	end
	local look = string.lower(weapon.Look or "")
	if string.find(look, "axe") or string.find(look, "cleaver") then
		return 1 + (effects.Cleaving or 0)
	end
	if string.find(look, "sword") or string.find(look, "blade") or string.find(look, "kniv") then
		return 1 + (effects.Slashing or 0)
	end
	return 1
end
return Tree

end)()
local Season=(function()
--[[
	The Season Path: earn XP by playing, level up, and claim a reward at
	every level (a free track, like a battle pass). 30 levels.

	XP comes from everything you do; a 2x XP boost (from bundles) doubles it.
]]
local Season = {}

Season.Name = "Season 1: Lunar Frontier"
Season.MaxLevel = 30

-- XP for each activity.
Season.XP = {
	Mine = 15,
	Sell = 5,
	Enchant = 20,
	SlayCrawler = 12,
	SlayBrute = 35,
	Daily = 50,
	DuelWin = 40,
	DuelPlay = 15,
}

-- XP needed to go from `level` to the next.
function Season.xpToNext(level: number): number
	return 100 + 25 * (level - 1)
end

-- The reward for reaching each level (see Store.Reward).
local SPECIAL = {
	[5] = { Cosmetics = { "TrimEmber" } },
	[10] = { Cosmetics = { "BackGeode" } },
	[15] = { Cosmetics = { "TrimRoseGold" }, Crates = { MasterworkCrate = 1 } },
	[20] = { Cosmetics = { "BackWings" } },
	[25] = { Cosmetics = { "TrimPrismatic" } },
	[30] = { Cosmetics = { "BackHalo" }, Crates = { MasterworkCrate = 2 } },
}

function Season.reward(level: number): { [string]: any }
	if SPECIAL[level] then
		return SPECIAL[level]
	end
	-- A steady rhythm between the special levels.
	local step = level % 5
	if step == 1 then
		return { Coins = 100 + level * 10 }
	elseif step == 2 then
		return { Coins = 80 + level * 8 }
	elseif step == 3 then
		return { Crates = { GeodeCrate = 1 } }
	end
	return { CutGems = 1 }
end

-- Level and progress for a total XP.
function Season.levelFor(totalXp: number): (number, number, number)
	local level, remaining = 1, totalXp
	while level < Season.MaxLevel and remaining >= Season.xpToNext(level) do
		remaining -= Season.xpToNext(level)
		level += 1
	end
	return level, remaining, Season.xpToNext(level)
end

return Season

end)()
local WeaponForge=(function()
--[[
	The Forge: the weapons found in the mine and traded between players.
	Five kinds, each fighting its own way, in five rarities. Every one of the
	25 carries its own signature perk: a different ability at a different
	strength, growing with rarity.

	  Cleaver    (Prospector)  balanced sword, three-hit combo
	  Twin Blades (Skirmisher) fast, light, both hands
	  Lance      (Skirmisher)  long reach, narrow thrust
	  Greataxe   (Juggernaut)  slow, heavy, a wide arc
	  Warhammer  (Prospector)  slowest, hardest, knocks foes back

	Two-handed types deal higher base damage per second to offset their lost shield; what changes is how
	(reach, arc, pace) and what their perk does. Perk effects are read by
	CombatServer from Passive.Effect (see WeaponForge.Perks for every key).

	  WeaponForge.Types        the five kinds, in order
	  WeaponForge.Catalog      the 25 weapons (gear entries)
	  WeaponForge.Perks        [key] = what the perk does, for the UI and tests
	  WeaponForge.perkText(weapon)  "Siphon Edge: heals you for 5% of ..."
]]
local WeaponForge = {}

WeaponForge.Types = {
	{
		Id = "Cleaver",
		Family = "Prospector",
		Attack = { Kind = "Melee", Damage = 18, Rate = 0.65, Range = 7, Arc = 95, Combo = 3 },
		Names = {
			"Rustbite Cleaver",
			"Ironvein Cutlass",
			"Quarrylord's Edge",
			"Starfall Claymore",
			"Eclipse Sunderblade",
		},
		Blurb = "A balanced sword: steady swings, a three-hit combo.",
	},
	{
		Id = "TwinBlades",
		Family = "Skirmisher",
		Attack = { Kind = "Melee", Damage = 14, Rate = 0.44, Range = 6, Arc = 85, Combo = 3 },
		Names = { "Scrapper Fangs", "Ion Twinfangs", "Viper Duet", "Phantom Shears", "Nebula Reapers" },
		Blurb = "A blade in each hand: quick, light cuts.",
	},
	{
		Id = "Lance",
		Family = "Skirmisher",
		Attack = { Kind = "Melee", Damage = 20, Rate = 0.62, Range = 10, Arc = 40, Combo = 3 },
		Names = { "Survey Pike", "Frostline Lance", "Arcspire Lance", "Voidpiercer", "Saga Starlance" },
		Blurb = "Long reach, a narrow thrust: hit them before they reach you.",
	},
	{
		Id = "Greataxe",
		Family = "Juggernaut",
		Attack = { Kind = "Melee", Damage = 31, Rate = 0.95, Range = 8.5, Arc = 140, Combo = 3 },
		Names = { "Pit Splitter", "Ember Reaver", "Bloodrage Maw", "Titan Cleft", "Worldbreaker" },
		Blurb = "Slow, brutal, and wide: every swing sweeps around you.",
	},
	{
		Id = "Warhammer",
		Family = "Prospector",
		Attack = { Kind = "Melee", Damage = 35, Rate = 1.05, Range = 7, Arc = 90, Combo = 3 },
		Names = { "Stone Knocker", "Piston Maul", "Thunder Gavel", "Gravitas Hammer", "Singularity Maul" },
		Blurb = "The slowest and hardest: blows that send foes flying.",
	},
}

-- What each perk does. `Value` is a fraction (0.05 = 5%) unless noted.
-- (TakenMult is a multiplier: 0.88 = 12% less damage taken.)
WeaponForge.Perks = {
	Lifesteal = { Name = "Siphon Edge", Text = "heals you for %d%% of the damage you deal" },
	StaminaOnHit = { Name = "Second Wind", Text = "each hit restores %d%% Stamina" },
	KillHeal = { Name = "Victor's Feast", Text = "a kill heals %d%% of your max health" },
	FirstStrike = { Name = "Opening Cut", Text = "+%d%% damage to foes at full health" },
	Execute = { Name = "Executioner", Text = "+%d%% damage to foes under 35%% health" },
	AttackSpeed = { Name = "Flurry", Text = "swings %d%% faster" },
	CritAdd = { Name = "Keen Edges", Text = "+%d%% critical chance" },
	ComboFinisher = { Name = "Crossfang", Text = "the third hit of a combo deals +%d%%" },
	Bleed = { Name = "Serrated", Text = "hits bleed for %d%% of their damage over 3s" },
	CritDamage = { Name = "Nebula Rend", Text = "critical hits deal +%d%% more" },
	ChargeOnHit = { Name = "Conductor", Text = "each hit restores %d%% Charge" },
	SlowOnHit = { Name = "Frost Tip", Text = "hits slow the target by %d%% for 2s" },
	StunOnHit = { Name = "Arc Jolt", Text = "%d%% chance on hit to stun for 0.6s" },
	Sunder = { Name = "Piercer", Text = "hits make the target take %d%% more damage for 5s" },
	SurgeBonus = { Name = "Saga Conduit", Text = "your surges deal +%d%% damage" },
	HeavyBonus = { Name = "Cleave", Text = "heavy blows deal +%d%% damage" },
	BurnOnHit = { Name = "Ember Bite", Text = "%d%% chance on hit to burn for 40%% of the hit over 3s" },
	Berserk = { Name = "Bloodrage", Text = "+%d%% damage while you're under 50%% health" },
	Duelist = { Name = "Gladiator", Text = "+%d%% damage against players and rivals" },
	TakenMult = { Name = "Titan Hide", Text = "take %d%% less damage", Inverse = true },
	Knockback = { Name = "Heavy Head", Text = "heavy blows knock foes %d%% farther" },
	GuardBreaker = { Name = "Shieldcrusher", Text = "+%d%% damage to foes who are blocking" },
	Thorns = { Name = "Retribution", Text = "melee attackers take %d%% of their hit back" },
	BlockStamina = { Name = "Iron Will", Text = "blocking costs %d%% less Stamina" },
	Tenacity = { Name = "Unstoppable", Text = "stuns and freezes on you last %d%% shorter" },
}

-- [type][rarity] = { perk key, value }. 25 different perks, stronger with rarity.
local PERKS = {
	Cleaver = {
		{ "Lifesteal", 0.05 },
		{ "StaminaOnHit", 0.06 },
		{ "KillHeal", 0.15 },
		{ "FirstStrike", 0.30 },
		{ "Execute", 0.40 },
	},
	TwinBlades = {
		{ "AttackSpeed", 0.08 },
		{ "CritAdd", 0.07 },
		{ "ComboFinisher", 0.30 },
		{ "Bleed", 0.25 },
		{ "CritDamage", 0.50 },
	},
	Lance = {
		{ "ChargeOnHit", 0.04 },
		{ "SlowOnHit", 0.20 },
		{ "StunOnHit", 0.10 },
		{ "Sunder", 0.12 },
		{ "SurgeBonus", 0.25 },
	},
	Greataxe = {
		{ "HeavyBonus", 0.15 },
		{ "BurnOnHit", 0.18 },
		{ "Berserk", 0.25 },
		{ "Duelist", 0.18 },
		{ "TakenMult", 0.88 },
	},
	Warhammer = {
		{ "Knockback", 0.35 },
		{ "GuardBreaker", 0.35 },
		{ "Thorns", 0.15 },
		{ "BlockStamina", 0.30 },
		{ "Tenacity", 0.30 },
	},
}
WeaponForge.PerkTable = PERKS

local function percent(key: string, value: number): number
	local perk = WeaponForge.Perks[key]
	return math.floor((if perk and perk.Inverse then 1 - value else value) * 100 + 0.5)
end

-- "Siphon Edge: heals you for 5% of the damage you deal."
function WeaponForge.perkText(key: string, value: number): (string, string)
	local perk = WeaponForge.Perks[key]
	if not perk then
		return "", ""
	end
	local body = string.format(perk.Text, percent(key, value))
	return perk.Name, string.upper(string.sub(body, 1, 1)) .. string.sub(body, 2) .. "."
end

-- How much a weapon's perk changes one blow (pure, shared by CombatServer
-- and the Arena rival). `context`: Heavy, Crit, Combo (1-3), TargetRatio and
-- OwnRatio (health / max), Versus (a player or rival), TargetGuarding.
function WeaponForge.multiplier(effects, context): number
	local bonus = 0
	if context.Heavy then
		bonus += effects.HeavyBonus or 0
	end
	if (context.TargetRatio or 0) >= 0.99 then
		bonus += effects.FirstStrike or 0
	end
	if (context.TargetRatio or 1) < 0.35 then
		bonus += effects.Execute or 0
	end
	if (context.OwnRatio or 1) < 0.5 then
		bonus += effects.Berserk or 0
	end
	if context.Versus then
		bonus += effects.Duelist or 0
	end
	if (context.Combo or 0) >= 3 then
		bonus += effects.ComboFinisher or 0
	end
	if context.TargetGuarding then
		bonus += effects.GuardBreaker or 0
	end
	local multiplier = 1 + bonus
	if context.Crit then
		multiplier *= 1 + (effects.CritDamage or 0)
	end
	return multiplier
end

-- Whether the Forge weapons are handed out (starter kits, the regenerate
-- tool, mine and Outpost loot, the Arena rival). Off: the original swords
-- (Frontier Sword and family) are what rolls, as before the Forge. Forge
-- weapons players already own stay valid either way.
WeaponForge.Enabled = false

WeaponForge.Catalog = {}
for _, kind in WeaponForge.Types do
	for rarity = 1, 5 do
		local key, value = PERKS[kind.Id][rarity][1], PERKS[kind.Id][rarity][2]
		local name, text = WeaponForge.perkText(key, value)
		table.insert(WeaponForge.Catalog, {
			Id = "Forge" .. kind.Id .. rarity,
			Name = kind.Names[rarity],
			Tier = rarity,
			RarityTier = rarity,
			StartPool = WeaponForge.Enabled,
			Forge = true,
			Style = "Frontier",
			Look = "Forge" .. kind.Id,
			WeaponType = kind.Id,
			Hands = if kind.Id == "Cleaver" then 1 else 2,
			WeaponBlock = kind.Id ~= "Cleaver",
			ArmorFamily = kind.Family,
			Mods = {},
			BuffReady = true,
			ProposedBuff = text,
			Blurb = kind.Blurb,
			Passive = { Name = name, Text = text, Effect = { [key] = value } },
			Attack = table.clone(kind.Attack),
		})
	end
end

return WeaponForge

end)()
local ExpandedTraits=(function()
-- Expanded equipment identities from the supplied traits matrix.
-- Proposed effects remain metadata until their gameplay systems exist.
local Traits = {}
Traits.Catalog = {}
Traits.Visors = {}
Traits.Weights = { 40, 25, 20, 10, 5 }

Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets1",
	Name = "Zero-G Standard Helm",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Kinetic Resistance +5% Physical Defense",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets2",
	Name = "Platon Tactical Helm",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Shield Capacity +10 Max Energy Shield",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets3",
	Name = "Asterois Closed Helm",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Elemental Resist +8% Cryo Resistance",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets4",
	Name = "Intableed Visored Helm",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Critical Strike +4% Critical Hit Chance",
	BuffReady = true,
	Passive = { Name = "Signature", Text = "+4% critical hit chance.", Effect = { CritAdd = 0.04 } },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets5",
	Name = "Jutaim Command Helm",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Saga Resonance +15% Saga Stone Yield",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets6",
	Name = "Qutany Fpv Helm",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Sensor Array +5% Detection Range",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets7",
	Name = "Watten Speed Helm",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Agility Boost +6% Movement Acceleration",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets8",
	Name = "Photon Shield Helm",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Energy Barrier +12 Shield Rejuvenation",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets9",
	Name = "Photrin Perfect Helm",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Precision Lock +10% Weakpoint Damage",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Helmets = Traits.Catalog.Helmets or {}
table.insert(Traits.Catalog.Helmets, {
	Id = "MatrixHelmets10",
	Name = "Metron Meshed Helm",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Neural Sync +15% Cooldown Reduction",
	BuffReady = true,
	Passive = {
		Name = "Signature",
		Text = "Rig Maneuvers and Gem Surges recharge 15% faster.",
		Effect = { CooldownMult = 0.85 },
	},
})
table.insert(
	Traits.Visors,
	{ Id = "MatrixVisor1", Name = "Standard Amber", Rarity = 1, ProposedBuff = "Accuracy +2% Ranged Accuracy" }
)
table.insert(
	Traits.Visors,
	{ Id = "MatrixVisor2", Name = "Glacial Cyan (Cryo)", Rarity = 2, ProposedBuff = "Cryo Affinity +5% Freeze Chance" }
)
table.insert(
	Traits.Visors,
	{ Id = "MatrixVisor3", Name = "Electric Amber (Volt)", Rarity = 3, ProposedBuff = "Ion Affinity +5% Stun Chance" }
)
table.insert(Traits.Visors, {
	Id = "MatrixVisor4",
	Name = "Corrosive Emerald (Corrosive)",
	Rarity = 4,
	ProposedBuff = "Corrosive Affinity +8% Armor Shred",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor5",
	Name = "Void Violet (Plasma)",
	Rarity = 5,
	ProposedBuff = "Thermal Affinity +12% Burn Damage",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor6",
	Name = "Crimson Infrared",
	Rarity = 1,
	ProposedBuff = "Threat Detection +6% Vision Through Smoke",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor7",
	Name = "Cobalt Deep-Space",
	Rarity = 2,
	ProposedBuff = "Vacuum Seal Immunity to Asphyxiation Hazards",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor8",
	Name = "Solar Gold",
	Rarity = 3,
	ProposedBuff = "Energy Reflection Reflects 3% Projectile Damage",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor9",
	Name = "Matrix Green",
	Rarity = 4,
	ProposedBuff = "Data Scans Reveals Enemy Weak Points Automatically",
})
table.insert(Traits.Visors, {
	Id = "MatrixVisor10",
	Name = "Prismatic Opaque",
	Rarity = 5,
	ProposedBuff = "Refraction Shield Negates 1st Hit Every 30s",
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors1",
	Name = "Zero-G Bulk Suit",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Armor Plating +20 Flat Armor",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors2",
	Name = "Platon Armor Rig",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Stamina Regeneration +10% Stamina Regen",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors3",
	Name = "Asterois Exosuit",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Mobility +5% Movement Speed",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors4",
	Name = "Intableed Combat Rig",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Lifesteal / Bio +3% Damage Converted to Health",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors5",
	Name = "Jutaim Heavy Vanguard",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Damage Reduction +15% Overall Damage Reduction",
	BuffReady = true,
	Passive = { Name = "Signature", Text = "Take 15% less damage.", Effect = { TakenMult = 0.85 } },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors6",
	Name = "Qutany Fpv Suit",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Power Conduit +10 Max Power Pool",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors7",
	Name = "Watten Speed Suit",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Velocity Matrix +8% Dash Speed",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors8",
	Name = "Photon Shield Suit",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Barrier Generator +25 Max Energy Shield",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors9",
	Name = "Photrin Reflective Suit",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Energy Deflection +10% Elemental Resistance",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Armors = Traits.Catalog.Armors or {}
table.insert(Traits.Catalog.Armors, {
	Id = "MatrixArmors10",
	Name = "Metron Meshed Suit",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Nanite Repair Regenerates 1% HP per second",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves1",
	Name = "Reinforced Grips",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Melee Impact +5% Kinetic Ram Stagger",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves2",
	Name = "Capacitor Liners",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Volt Synergy +6% Electrical Arc Chance",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves3",
	Name = "Cryo-Cooler Gauntlets",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Chill Infusion +8% Slow Application",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves4",
	Name = "Thermal Conduit Gloves",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Plasma Overcharge +10% Critical Damage",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves5",
	Name = "Saga-Tuned Handwraps",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Attack Speed +12% Weapon Cycle Speed",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves6",
	Name = "Hydraulic Crushers",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Stagger Force +15% Heavy Melee Knockback",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves7",
	Name = "Nanite Weave Gloves",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Self-Cleaning Immunity to Corrosive Sludge",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves8",
	Name = "Kinetic Shock Mitts",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Impact Absorption Reduces Melee Damage Taken by 10%",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves9",
	Name = "Void-weave Bracers",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Phase Strike Melee Attacks Ignore 20% Armor",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Gloves = Traits.Catalog.Gloves or {}
table.insert(Traits.Catalog.Gloves, {
	Id = "MatrixGloves10",
	Name = "Overclocked Servos",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Burst Action +20% Attack Speed for 5s on Kill",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots1",
	Name = "Mag-Lock Greaves",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Knockback Resist +10% Stability against Shoves",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots2",
	Name = "Hydraulic Striders",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Sprint Efficiency -10% Stamina Drain on Sprint",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots3",
	Name = "Phase-Dodge Treads",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Evade Distance +15% Dodge Roll I-Frames",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots4",
	Name = "Reactor-Core Boots",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Energy Recharge +8% Shield Recharge Rate",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots5",
	Name = "Void-Strider Sabatons",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Traversal Speed +20% Movement Speed in Combat",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots6",
	Name = "Gravity-Stabilized Treads",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Fall Mitigation -25% Fall Damage Taken",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots7",
	Name = "Aero-Stream Greaves",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Slipstream +10% Movement Speed after Sprinting 3s",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots8",
	Name = "Crystalline Striders",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Saga Resonance +5% Extra Saga Stones on Pickup",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots9",
	Name = "Thermal-Insulated Boots",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Thermal Shielding Immunity to Lava and Fire Hazards",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Boots = Traits.Catalog.Boots or {}
table.insert(Traits.Catalog.Boots, {
	Id = "MatrixBoots10",
	Name = "Quantum-Step Sabatons",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Teleport Dodge Dodge Roll Leaves a Decoy Explosion",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons1",
	Name = "Standard Sidearm",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "PistolShield",
	Mods = {},
	ProposedBuff = "Base Kinetic 100% Base Weapon Damage",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons2",
	Name = "Cryo-Pistol Sub-Zero",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SurveyorKit",
	Mods = {},
	ProposedBuff = "Cryo Application Applies Slow on Hit",
	BuffReady = true,
	Passive = {
		Name = "Signature",
		Text = "Hits slow targets by 15% for 2 seconds.",
		Effect = { SlowOnHit = 0.15 },
	},
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons3",
	Name = "Volt-Spark Blaster",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SurveyorKit",
	Mods = {},
	ProposedBuff = "Volt Stun Chain Lightning on Crit",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons4",
	Name = "Radiation Corrupter",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "PistolShield",
	Mods = {},
	ProposedBuff = "Armor Shred Reduces Target Armor by 15%",
	BuffReady = true,
	Passive = {
		Name = "Signature",
		Text = "Hits apply +15% damage vulnerability for 5 seconds, stacking to +45%.",
		Effect = { Sunder = 0.15 },
	},
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons5",
	Name = "Plasma Melter",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "BulwarkKit",
	Mods = {},
	ProposedBuff = "Thermal Burn Applies Stackable Burn Over Time",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons6",
	Name = "Pulse-Laser Repeater",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "PistolShield",
	Mods = {},
	ProposedBuff = "Rapid Fire +25% Fire Rate, -10% Base Damage",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons7",
	Name = "Heavy Mag-Driver",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "BulwarkKit",
	Mods = {},
	ProposedBuff = "Impact Slug Staggers Light Targets on Hit",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons8",
	Name = "Void-Caster Handgun",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "PistolShield",
	Mods = {},
	ProposedBuff = "Spatial Distortion Pulls Targets Toward Impact Point",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons9",
	Name = "Saga-Infused Repeater",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SurveyorKit",
	Mods = {},
	ProposedBuff = "Energy Surge Generates Shield on Kills with Pistol",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Weapons = Traits.Catalog.Weapons or {}
table.insert(Traits.Catalog.Weapons, {
	Id = "MatrixWeapons10",
	Name = "Omega-Protocol Handcannon",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "PistolShield",
	Mods = {},
	ProposedBuff = "Annihilation Round Fires Explosive Rounds every 5th Shot",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
	Attack = { Kind = "Shot", Damage = 11, Rate = 0.45, Range = 45 },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields1",
	Name = "Titanium Breach Shield",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Block Stability +50 Shield Block Health",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields2",
	Name = "Cryo-Barrier Aegis",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Chill Deflection Chills Attackers on Block",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields3",
	Name = "Volt-Field Bulwark",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Shock Retaliation Shocks Melee Attackers",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields4",
	Name = "Radiation-Vented Wall",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Corrosive Aura Deals Radiation AoE when Raised",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields5",
	Name = "Saga-Reactor Aegis",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Energy Reflection Reflects 10% Ranged Damage Back",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields6",
	Name = "Composite Riot Gate",
	Tier = 1,
	RarityTier = 1,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitScrap",
	Mods = {},
	ProposedBuff = "Coverage Area +15% Shield Width",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields7",
	Name = "Kinetic Deflector Wall",
	Tier = 2,
	RarityTier = 2,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitZeroG",
	Mods = {},
	ProposedBuff = "Projectile Redirect Deflects Minor Projectiles Automatically",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields8",
	Name = "Plasma-Edge Bulwark",
	Tier = 3,
	RarityTier = 3,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitRanger",
	Mods = {},
	ProposedBuff = "Thermal Counter Melee Attackers Take Plasma Burn",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields9",
	Name = "Phase-Shield Barrier",
	Tier = 4,
	RarityTier = 4,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitCrusader",
	Mods = {},
	ProposedBuff = "Ethereal Guard Allows Ranged Shots Through Shield at 50% Penalty",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})
Traits.Catalog.Shields = Traits.Catalog.Shields or {}
table.insert(Traits.Catalog.Shields, {
	Id = "MatrixShields10",
	Name = "World-Breaker Aegis",
	Tier = 5,
	RarityTier = 5,
	StartPool = true,
	Style = "Frontier",
	Look = "SuitThermal",
	Mods = {},
	ProposedBuff = "Bulwark Slam Kinetic Ram Creates a Shockwave Stun",
	BuffReady = false,
	Passive = { Name = "Signature", Text = "Visual prototype. Signature effect is planned.", Effect = {} },
})

-- Swords supplement the original pistol catalog with distinct persistent IDs.
local swordNames = {
	"Frontier Sword",
	"Cryo-Edge Saber",
	"Volt-Spark Blade",
	"Radium Cleaver",
	"Solarbrand",
	"Scout Shortsword",
	"Impact Falchion",
	"Void-Edge Sword",
	"Saga Runeblade",
	"Omega Greatblade",
}
local pistols = table.clone(Traits.Catalog.Weapons)
for index, pistol in pistols do
	pistol.WeaponType = "Pistol"
	if index == 1 then
		pistol.BuffReady = true
		pistol.Passive = { Name = "Base Kinetic", Text = "Standard kinetic sidearm damage.", Effect = {} }
	elseif index == 6 then
		pistol.BuffReady = true
		pistol.Attack.Rate = 0.36
		pistol.Attack.Damage = 9.9
		pistol.Passive = { Name = "Rapid Fire", Text = "+25% fire rate; -10% base damage.", Effect = {} }
	end
	local weapon = table.clone(pistol)
	weapon.Id = "MatrixSwords" .. index
	weapon.Passive = table.clone(pistol.Passive)
	weapon.Name = swordNames[index]
	weapon.Look = "FrontierSword"
	weapon.WeaponType = "Sword"
	weapon.Attack = { Kind = "Melee", Damage = 18, Rate = 0.65, Range = 7, Arc = 90, Combo = 3 }
	weapon.ProposedBuff = "Three-strike sword combo. Socket a gem to attune its attacks."
	if index == 1 then
		weapon.Passive = { Name = "Tempered Edge", Text = "Three-strike melee combo.", Effect = {} }
	end
	if not weapon.BuffReady then
		weapon.Passive = { Name = "Tempered Edge", Text = "Three-strike melee combo.", Effect = {} }
		weapon.BuffReady = true
	end
	if index == 6 then
		weapon.Attack = { Kind = "Melee", Damage = 15, Rate = 0.52, Range = 6, Arc = 80, Combo = 3 }
		weapon.Passive = { Name = "Quick Edge", Text = "Faster swings with less damage and reach.", Effect = {} }
	elseif index == 7 or index == 10 then
		weapon.Attack = { Kind = "Melee", Damage = 23, Rate = 0.85, Range = 7.5, Arc = 100, Combo = 3 }
	end
	table.insert(Traits.Catalog.Weapons, weapon)
end

local visorColors = {
	Color3.fromRGB(255, 178, 62),
	Color3.fromRGB(87, 220, 255),
	Color3.fromRGB(255, 199, 63),
	Color3.fromRGB(82, 230, 139),
	Color3.fromRGB(168, 99, 246),
	Color3.fromRGB(243, 77, 93),
	Color3.fromRGB(78, 124, 234),
	Color3.fromRGB(255, 216, 103),
	Color3.fromRGB(103, 248, 154),
	Color3.fromRGB(225, 228, 255),
}
for index, visor in Traits.Visors do
	visor.Index = index
	visor.Color = visorColors[index]
	visor.StartPool = true
	visor.RarityTier = visor.Rarity
end

-- Render the equipment matrix through three restrained, interchangeable asset families.
for kind, entries in Traits.Catalog do
	if kind ~= "Weapons" then
		for _, item in entries do
			item.AssetFamily = if item.RarityTier == 1
				then "UtilityMiner"
				elseif item.RarityTier <= 3 then "FrontierRanger"
				else "HeavyVanguard"
			item.Look = item.AssetFamily
		end
	end
end

-- Simplify future signatures into a small set of shared systems.
for _, entries in Traits.Catalog do
	for _, item in entries do
		local description = string.lower(item.ProposedBuff)
		item.TraitFamily = if string.find(description, "shield", 1, true)
				or string.find(description, "barrier", 1, true)
			then "Barrier"
			elseif
				string.find(description, "speed", 1, true) or string.find(description, "dodge", 1, true)
			then "Mobility"
			elseif string.find(description, "saga", 1, true) then "Recovery"
			elseif
				string.find(description, "critical", 1, true) or string.find(description, "precision", 1, true)
			then "Precision"
			elseif
				string.find(description, "regen", 1, true) or string.find(description, "health", 1, true)
			then "Recovery"
			else "Combat"
		if string.find(description, "immunity", 1, true) then
			item.TraitFamily = "HazardResistance"
			item.PlannedHazardResistance = EquipmentBalance.MaxHazardResistance
			item.ProposedBuff = if item.Id == "MatrixBoots9"
				then "Thermal resistance: reduce fire and lava hazard damage by up to 60%."
				else "Corrosive resistance: reduce corrosive hazard damage by up to 60%."
		end
		local utility = if item.Id == "MatrixBoots10"
			then "PhaseDodge"
			elseif item.Id == "MatrixShields5" or item.Id == "MatrixShields7" then "Reflection"
			else nil
		if utility then
			item.TraitFamily = "Utility"
			item.PlannedUtility = utility
			item.InternalCooldown = EquipmentBalance.UtilityCooldowns[utility]
		end
	end
end
for _, visor in Traits.Visors do
	if visor.Index == 7 then
		visor.ProposedBuff = "Vacuum endurance: slow environmental air depletion by up to 60%; never grant immunity."
		visor.PlannedHazardResistance = EquipmentBalance.MaxHazardResistance
	elseif visor.Index == 8 then
		visor.PlannedUtility = "Reflection"
		visor.InternalCooldown = EquipmentBalance.UtilityCooldowns.Reflection
	elseif visor.Index == 10 then
		visor.PlannedUtility = "FirstHitGuard"
		visor.InternalCooldown = EquipmentBalance.UtilityCooldowns.FirstHitGuard
	end
end

-- Pistols are switched off for now: no roll, drop, mine find, starter kit
-- or reward hands one out (pistols already owned still work). Set to true to
-- bring them back.
Traits.PistolsObtainable = false

-- Can this item be handed out right now?
function Traits.obtainable(gear): boolean
	return gear ~= nil and (Traits.PistolsObtainable or gear.WeaponType ~= "Pistol")
end

function Traits.pick(catalog, rng, weights)
	weights = weights or Traits.Weights
	local groups = {}
	for _, gear in catalog do
		if gear.StartPool and Traits.obtainable(gear) then
			local rarity = gear.RarityTier
			groups[rarity] = groups[rarity] or {}
			table.insert(groups[rarity], gear)
		end
	end
	local total = 0
	for rarity, weight in weights do
		if groups[rarity] then
			total += weight
		end
	end
	if total == 0 then
		return nil
	end
	local pick = rng:NextNumber(0, total)
	for rarity, weight in weights do
		local group = groups[rarity]
		if group and weight > 0 then
			pick -= weight
			if pick <= 0 then
				return group[rng:NextInteger(1, #group)]
			end
		end
	end
	return nil
end
-- Preserve all old IDs for ownership/sockets, but only the uniform grid drops.
Traits.LegacyCatalog = {}
for kind, catalog in ArmorFamilies.Catalog do
	Traits.LegacyCatalog[kind] = Traits.Catalog[kind]
	for _, item in Traits.LegacyCatalog[kind] do
		item.StartPool = false
	end
	Traits.Catalog[kind] = catalog
end
for _, weapon in Traits.Catalog.Weapons do
	weapon.ArmorFamily = if weapon.WeaponType == "Sword"
		then (if tonumber(string.match(weapon.Id, "%d+$")) <= 5 then "Prospector" else "Juggernaut")
		else "Skirmisher"
end
-- The Forge's 25 weapons (Shared.WeaponForge) join the catalog so saved
-- kits stay valid. While WeaponForge.Enabled is off they never roll, and the
-- original swords (Frontier Sword and family) are what's handed out; when
-- it's on, the Forge weapons replace the swords in the rolls.
if WeaponForge.Enabled then
	for _, weapon in Traits.Catalog.Weapons do
		weapon.StartPool = false
	end
end
for _, weapon in WeaponForge.Catalog do
	table.insert(Traits.Catalog.Weapons, weapon)
end
return Traits

end)()
local Slots=(function()
-- Weapon/Armor remain the saved keys for pistol/chest for backward compatibility.
local Slots = {}
Slots.SurgeOrder = { "Surge1", "Surge2", "Surge3" }
Slots.SurgeDefinitions =
	{ Surge1 = { Label = "Gem Surge 1" }, Surge2 = { Label = "Gem Surge 2" }, Surge3 = { Label = "Gem Surge 3" } }
Slots.Order = { "Helmet", "Armor", "Gloves", "Boots", "Weapon", "Shield" }
Slots.Definitions = {
	Weapon = { Kind = "Weapons", Label = "Weapon" },
	Armor = { Kind = "Armors", Label = "Chest Suit" },
	Helmet = { Kind = "Helmets", Label = "Helmet" },
	Gloves = { Kind = "Gloves", Label = "Gloves" },
	Boots = { Kind = "Boots", Label = "Boots" },
	Shield = { Kind = "Shields", Label = "Shield" },
}
Slots.Kinds = { "Weapons", "Shields", "Helmets", "Armors", "Gloves", "Boots" }
Slots.ByKind =
	{ Weapons = "Weapon", Shields = "Shield", Helmets = "Helmet", Armors = "Armor", Gloves = "Gloves", Boots = "Boots" }
Slots.Catalog = {}
local variants = {
	{ "Scrap", "SuitScrap", "Utility", 1 },
	{ "Survey", "SuitZeroG", "Mobility", 2 },
	{ "Containment", "SuitThermal", "Survival", 3 },
	{ "Crusader", "SuitCrusader", "Defensive", 4 },
}
for _, slot in { "Helmet", "Gloves", "Boots", "Shield" } do
	local list = {}
	for i, variant in variants do
		local mods = {}
		local passive = { Name = "Utility", Text = "Standard expedition equipment.", Effect = {} }
		if i > 1 then
			if slot == "Boots" then
				passive =
					{ Name = "Magnetic Stride", Text = "+" .. (i - 1) .. " walk speed.", Effect = { SpeedAdd = i - 1 } }
			elseif slot == "Helmet" then
				passive = {
					Name = "Targeting Array",
					Text = "Rig Maneuvers and Gem Surges recharge " .. (i * 2) .. "% faster.",
					Effect = { CooldownMult = 1 - i * 0.02 },
				}
			elseif slot == "Gloves" then
				mods.Power = i * 2
				passive = { Name = "Emitter Stabilizer", Text = "+" .. (i * 2) .. " power rating.", Effect = {} }
			else
				passive = {
					Name = "Barrier Capacitor",
					Text = "Periodically absorb " .. (12 + i * 4) .. " damage.",
					Effect = { Ward = 12 + i * 4 },
				}
			end
		elseif slot == "Shield" then
			passive = { Name = "Barrier Capacitor", Text = "Periodically absorb 20 damage.", Effect = { Ward = 20 } }
		end
		table.insert(list, {
			Id = variant[1] .. slot,
			Name = variant[1] .. " " .. slot,
			Style = variant[3],
			Tier = variant[4],
			Look = variant[2],
			Mods = mods,
			Passive = passive,
		})
	end
	Slots.Catalog[Slots.Definitions[slot].Kind] = list
end
function Slots.effectSlot(slot: string): string
	return if slot == "Weapon" then "Weapon" else "Armor"
end
function Slots.initialize(profile)
	local c = profile.Character
	c.ItemGems = c.ItemGems or {}
	profile.Owned = profile.Owned or {}
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		profile.Owned[kind] = profile.Owned[kind] or {}
		if slot ~= "Weapon" and slot ~= "Armor" and c.Class then
			local id = c[slot] or Slots.Catalog[kind][1].Id
			c[slot] = id
			profile.Owned[kind][id] = profile.Owned[kind][id] or 1
			c[slot .. "Quality"] = profile.Owned[kind][id]
		end
		c.ItemGems[slot] = c.ItemGems[slot] or {}
		if c[slot] and c[slot .. "Gem"] then
			c.ItemGems[slot][c[slot]] = c[slot .. "Gem"]
		end
	end
end
return Slots

end)()
local Crafting=(function()
-- Compatibility module name: recovered equipment quality and gem exchange prices.
-- There are no crafting recipes, upgrade services or salvage materials.
local Crafting = {}
export type Quality = { Name: string, Color: Color3 }

Crafting.Qualities = {
	{ Name = "Standard", Color = Color3.fromRGB(225, 225, 225) },
	{ Name = "Fine", Color = Color3.fromRGB(90, 220, 90) },
	{ Name = "Superior", Color = Color3.fromRGB(80, 150, 255) },
	{ Name = "Masterwork", Color = Color3.fromRGB(255, 150, 40) },
} :: { Quality }
Crafting.MaxQuality = #Crafting.Qualities

-- Rating bonus from quality: weapons hit harder, armor protects more.
function Crafting.qualityBonus(kind: string, quality: number?): { [string]: number }
	local steps = math.max(0, (quality or 1) - 1)
	if steps == 0 then
		return {}
	end
	if kind == "Weapons" then
		return { Power = steps * 10 }
	end
	return { Defense = steps * 8, Health = steps * 6 }
end

-- Quality-coloured name, e.g. "Fine Longsword".
function Crafting.gearName(baseName: string, quality: number?): string
	local q = quality or 1
	return if q > 1 then Crafting.Qualities[q].Name .. " " .. baseName else baseName
end

-- What Tamsin at the Market pays for a stone, in coins.
function Crafting.marketPrice(gem: GemConfig.Gem): number
	return math.max(1, math.floor(GemConfig.value(gem) * Config.MarketSellRate))
end

return Crafting

end)()
local GearRolls=(function()
-- Serializable item rolls. Only the server creates them; clients read saved results.
local GearRolls = {}
GearRolls.Rarities = {
	{ Name = "Common", Weight = 40, Color = Color3.fromRGB(205, 216, 225) },
	{ Name = "Uncommon", Weight = 25, Color = Color3.fromRGB(96, 211, 143) },
	{ Name = "Rare", Weight = 20, Color = Color3.fromRGB(89, 163, 248) },
	{ Name = "Ultra Rare", Weight = 10, Color = Color3.fromRGB(184, 115, 237) },
	{ Name = "Legendary", Weight = 5, Color = Color3.fromRGB(242, 172, 74) },
}
local colors = {
	Color3.fromRGB(225, 146, 60),
	Color3.fromRGB(196, 215, 228),
	Color3.fromRGB(61, 168, 182),
	Color3.fromRGB(145, 111, 192),
	Color3.fromRGB(211, 176, 84),
}
local visors = {
	Color3.fromRGB(80, 211, 247),
	Color3.fromRGB(240, 160, 68),
	Color3.fromRGB(129, 154, 248),
	Color3.fromRGB(237, 102, 198),
	Color3.fromRGB(100, 235, 174),
}
-- Each roll's look, by name, so players can tell (and trade for) them.
GearRolls.FinishNames = { "Ember Copper", "Polar Steel", "Lagoon Teal", "Nebula Violet", "Solar Gold" }
GearRolls.VisorNames = { "Arctic Visor", "Amber Visor", "Periwinkle Visor", "Rose Visor", "Mint Visor" }
-- About 1 in 100 rolls comes out Prismatic: its finish shimmers through every colour.
GearRolls.PrismaticChance = 0.01
-- Ultra Rare and Legendary finds are numbered (#12 of everything found).
GearRolls.SerialFrom = 4

-- One line naming what makes this roll its own: "Solar Gold finish  ·  ✦ PRISMATIC
-- ·  #12  ·  Found by Marc".
function GearRolls.identity(roll): string
	if not roll then
		return ""
	end
	local parts = { (GearRolls.FinishNames[roll.Finish] or "Standard") .. " finish" }
	if roll.Prismatic then
		table.insert(parts, "✦ PRISMATIC")
	end
	if roll.Serial then
		table.insert(parts, "#" .. roll.Serial)
	end
	if roll.FoundBy then
		table.insert(parts, "Found by " .. roll.FoundBy)
	end
	return table.concat(parts, "  ·  ")
end

-- Rare+ armor carries Elemental Affinity Affixes. Saved rolls from before
-- affixes get theirs once (AffixVersion); weapons never roll them.
GearRolls.AffixVersion = 1
function GearRolls.addAffixes(roll, rng, gear)
	if roll.AffixVersion then
		return
	end
	roll.Affixes = ArmorFamilies.rollAffixes(roll.Rarity, rng, gear and gear.AffixTable)
	roll.AffixVersion = GearRolls.AffixVersion
end
function GearRolls.roll(rng, fixedRarity, gear)
	local pick, rarity = rng:NextInteger(1, 100), 1
	for i, entry in GearRolls.Rarities do
		pick -= entry.Weight
		if pick <= 0 then
			rarity = i
			break
		end
	end
	rarity = fixedRarity or rarity
	local stats = {}
	local names = { "Health", "Power", "Defense", "Speed" }
	for _ = 1, if rarity >= 3 then 2 else 1 do
		local index = rng:NextInteger(1, #names)
		local name = table.remove(names, index)
		stats[name] = rng:NextInteger(2, 4) * rarity
	end
	local roll = {
		Rarity = rarity,
		Stats = stats,
		Helmet = rng:NextInteger(1, 5),
		Visor = rng:NextInteger(1, 5),
		Finish = rng:NextInteger(1, 5),
		Variant = rng:NextInteger(1, 4),
	}
	if rng:NextNumber() < GearRolls.PrismaticChance then
		roll.Prismatic = true
	end
	if gear and ArmorFamilies.ById[gear.Id] then
		roll.Stats, roll.Points, roll.Modifiers = ArmorFamilies.rollStats(gear, rng)
		roll.ArmorBudgetVersion = ArmorFamilies.Version
		roll.Budget = gear.Budget
	end
	if gear and not gear.Attack and not gear.WeaponType then
		GearRolls.addAffixes(roll, rng, gear)
	end
	return roll
end
-- Gear score: every rolled stat on the six worn pieces (percent stats count
-- as points), as the Armory shows it and the leaderboards rank it.
function GearRolls.gearScore(loadout): number
	local score = 0
	for _, slot in Slots.Order do
		local roll = GearRolls.get(loadout, slot)
		for stat, amount in roll and roll.Stats or {} do
			score += if stat == "Critical" or stat == "Cooldown" then amount * 100 else amount
		end
	end
	return math.floor(score + 0.5)
end
function GearRolls.get(loadout, slot, id)
	local kind = Slots.Definitions[slot].Kind
	return loadout.GearRolls and loadout.GearRolls[kind] and loadout.GearRolls[kind][id or loadout[slot]]
end
function GearRolls.appearance(roll)
	return {
		Rarity = roll.Rarity,
		Helmet = roll.Helmet,
		HelmetName = "Variant " .. roll.Helmet,
		HelmetRarity = GearRolls.Rarities[roll.Rarity].Name,
		VisorColor = if roll.MatrixVisor
			then (ExpandedTraits.Visors[roll.MatrixVisor] or {}).Color or visors[roll.Visor]
			else visors[roll.Visor],
		FinishColor = colors[roll.Finish],
		FinishName = GearRolls.FinishNames[roll.Finish],
		Prismatic = roll.Prismatic == true,
		Variant = roll.Variant,
		VisorName = if roll.MatrixVisor
			then ExpandedTraits.Visors[roll.MatrixVisor].Name
			else GearRolls.VisorNames[roll.Visor],
	}
end
function GearRolls.ensure(profile, rng)
	local c = profile.Character
	c.GearRolls = c.GearRolls or {}
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		c.GearRolls[kind] = c.GearRolls[kind] or {}
		for id in profile.Owned[kind] or {} do
			if not c.GearRolls[kind][id] then
				local fixedRarity, item
				for _, gear in ExpandedTraits.Catalog[kind] or {} do
					if gear.Id == id then
						fixedRarity = gear.RarityTier
						item = gear
						break
					end
				end
				if not item then
					for _, gear in ExpandedTraits.LegacyCatalog[kind] or {} do
						if gear.Id == id then
							fixedRarity, item = gear.RarityTier, gear
							break
						end
					end
				end
				local roll = GearRolls.roll(rng, fixedRarity, item)
				if fixedRarity then
					local visor = ExpandedTraits.pick(ExpandedTraits.Visors, rng)
					roll.MatrixVisor = visor.Index
				end
				c.GearRolls[kind][id] = roll
			end
			if kind ~= "Weapons" then
				GearRolls.addAffixes(c.GearRolls[kind][id], rng, ArmorFamilies.ById[id])
			end
		end
	end
end
function GearRolls.grant(profile, class, rng)
	Slots.initialize(profile)
	local c = profile.Character
	if c.RandomLoadoutVersion == 1 then
		GearRolls.ensure(profile, rng)
		return false
	end
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		local catalog = class[kind]
		-- Retire the fixed basic starter; independently roll every equipment category.
		local gear = (if kind ~= "Weapons" then ArmorFamilies.pick(catalog, rng) else ExpandedTraits.pick(catalog, rng))
		if not gear then
			-- Fallback: any item that can be handed out (never a disabled pistol).
			local pool = {}
			for _, item in catalog do
				if ExpandedTraits.obtainable(item) then
					table.insert(pool, item)
				end
			end
			pool = if #pool > 0 then pool else catalog
			gear = pool[rng:NextInteger(if #pool > 1 then 2 else 1, #pool)]
		end
		if c[slot] and c[slot .. "Gem"] then
			c.ItemGems[slot][c[slot]] = c[slot .. "Gem"]
		end
		profile.Owned[kind][gear.Id] = profile.Owned[kind][gear.Id] or 1
		c[slot] = gear.Id
		c[slot .. "Quality"] = profile.Owned[kind][gear.Id]
		c[slot .. "Gem"] = c.ItemGems[slot][gear.Id]
	end
	GearRolls.ensure(profile, rng)
	c.RandomLoadoutVersion = 1
	return true
end
return GearRolls

end)()
local Classes=(function()
--[[
 Shared equipment and passive augment catalog. All players are Warriors;
 armor families define their build. CombatTechnology owns the universal
 Stamina-powered Rig Maneuvers and socket-powered Gem Surges.
 Retired class records remain for saved equipment compatibility.
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
export type RigManeuver = {
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
export type SpecRigManeuver = { Name: string, Description: string }
export type Spec = { Name: string, Style: string, Nodes: { string }, Signature: SpecRigManeuver }
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
	RigManeuvers: { RigManeuver }, -- six; any three go on Q / E / R
	Ultimate: RigManeuver?,
	Weapons: { Gear },
	Armors: { Gear },
	Specs: { Spec },
}


local Classes = {}

Classes.StatNames = { "Health", "Power", "Defense", "Speed" }
Classes.Order = { "Warrior", "Wizard", "Archer", "Tank" }
Classes.RigManeuverKeys = { "Q", "E", "R" }
Classes.UltimateKey = "F"

-- Armor passives, one per style.
local BASTION = { Name = "Bastion", Text = "Take 12% less damage.", Effect = { TakenMult = 0.88 } }
local ATTUNED =
	{ Name = "Attuned", Text = "Rig Maneuvers and Gem Surges recharge 10% faster.", Effect = { CooldownMult = 0.9 } }
local FLEET = { Name = "Fleet", Text = "+2 walk speed.", Effect = { SpeedAdd = 2 } }

Classes.List = {
	Warrior = {
		Id = "Warrior",
		-- The Saga Miner: a colonist in a spacesuit with a pistol and shield,
		-- defending the Saga Stones. (The id stays "Warrior" for saved data.)
		Name = "Saga Vanguard",
		Role = "Frontier combat miner",
		Tagline = "Guard the Saga Stones. Shield up, blaster out.",
		Color = Color3.fromRGB(90, 210, 255),
		ResourceId = "Rage",
		Resource = "Rage: builds as you hit and get hit, fades out of combat",
		ArmorWeight = "Heavy",
		Difficulty = 1,
		Stats = { Health = 4, Power = 4, Defense = 3, Speed = 2 },
		RigManeuvers = {
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
				Id = "PistolShield",
				Name = "Saga Pistol & Shield",
				Style = "Iconic",
				Description = "A trusty blaster and a riot shield: every Saga Miner's kit.",
				Look = "PistolShield",
				Mods = { Defense = 1 },
				Attack = { Kind = "Shot", Damage = 11, Range = 45, Rate = 0.45 },
				Passive = {
					Name = "Riot Shield",
					Text = "Every 8 seconds, your shield absorbs 20 damage.",
					Effect = { Ward = 20 },
				},
			},
			{
				Id = "SurveyorKit",
				Name = "Surveyor Pistol & Shield",
				Style = "Precision",
				Description = "A teal survey pistol with a raised sight and compact shield. Longer reach, slower shots.",
				Look = "SurveyorKit",
				Mods = { Speed = 1, Defense = -1 },
				Attack = { Kind = "Shot", Damage = 11, Range = 58, Rate = 0.6 },
				Passive = { Name = "Survey Guard", Text = "Every 8 seconds, absorb 12 damage.", Effect = { Ward = 12 } },
			},
			{
				Id = "BulwarkKit",
				Name = "Bulwark Pistol & Shield",
				Style = "Defensive",
				Description = "An ivory heavy blaster and reinforced tower shield. Trades mobility and fire rate for protection.",
				Look = "BulwarkKit",
				Mods = { Defense = 2, Speed = -1 },
				Attack = { Kind = "Shot", Damage = 14, Range = 38, Rate = 0.7 },
				Passive = { Name = "Heavy Guard", Text = "Every 8 seconds, absorb 24 damage.", Effect = { Ward = 24 } },
			},
			{
				Id = "Longsword",
				Name = "Frontier Pistol & Shield",
				Style = "Balanced",
				Description = "A balanced frontier sidearm and survey shield.",
				Look = "SurveyorKit",
				Mods = {},
				Attack = { Kind = "Shot", Damage = 12, Range = 48, Rate = 0.5 },
				Passive = { Name = "Keen Edge", Text = "+10% critical hit chance.", Effect = { CritAdd = 0.1 } },
			},
			{
				Id = "Greataxe",
				Name = "Breach Pistol & Shield",
				Style = "Heavy hitter",
				Description = "A heavy breaching sidearm with a reinforced shield.",
				Look = "BulwarkKit",
				Mods = { Power = 1, Speed = -1 },
				Attack = { Kind = "Shot", Damage = 18, Range = 32, Rate = 0.9 },
				Passive = {
					Name = "Armor Breaker",
					Text = "Hits make enemies take 8% more damage for 5s (stacks 3 times).",
					Effect = { Sunder = 0.08 },
				},
			},
			{
				Id = "TwinBlades",
				Name = "Rapid Pistol & Shield",
				Style = "Swift",
				Description = "A fast cycling sidearm with a light survey shield.",
				Look = "SurveyorKit",
				Mods = { Speed = 1, Power = -1 },
				Attack = { Kind = "Shot", Damage = 8, Range = 40, Rate = 0.34 },
				Passive = {
					Name = "Destabilize",
					Text = "Hits destabilize enemies for 30% more damage over 3s.",
					Effect = { Bleed = 0.3 },
				},
			},
			{
				Id = "Spear",
				Name = "Longshot Pistol & Shield",
				Style = "Reach",
				Description = "A precision sidearm with a long-range emitter and survey shield.",
				Look = "SurveyorKit",
				Mods = { Speed = 1, Defense = -1 },
				Attack = { Kind = "Shot", Damage = 13, Range = 65, Rate = 0.7 },
				Passive = {
					Name = "Longshot Optics",
					Text = "Precision emitter reaches targets up to 65 studs away.",
					Effect = {},
				},
			},
		},
		-- Suits are a ladder: you start in the Scrap Suit, then forge (or find
		-- in the Mine) each better suit in turn. Tier sets the forge cost.
		-- (Ids are from the old medieval sets, kept for saved data.)
		Armors = {
			{
				Id = "PaddedJack",
				Name = "Scrap Suit",
				Tier = 1,
				Style = "Starter",
				Description = "An amber work helmet, cyan visor, navy utility suit and magnetic boots. Your first expedition kit.",
				Look = "SuitScrap",
				Mods = { Defense = -1 },
				Passive = {
					Name = "Life Support",
					Text = "+1 walk speed from lightweight utility gear.",
					Effect = { SpeedAdd = 1 },
				},
			},
			{
				Id = "IronChain",
				Name = "Miner Suit",
				Tier = 2,
				Style = "Agile",
				Description = "Hi-vis work suit with a headlamp and twin air tanks.",
				Look = "SuitMiner",
				Mods = { Speed = 1 },
				Passive = FLEET,
			},
			{
				Id = "IronScale",
				Name = "Ranger Suit",
				Tier = 3,
				Style = "Balanced",
				Description = "Armour plates, pauldrons and a glowing visor for the rift frontier.",
				Look = "SuitRanger",
				Mods = { Defense = 1 },
				Passive = ATTUNED,
			},
			{
				Id = "IronPlate",
				Name = "Crusader Exo",
				Tier = 4,
				Style = "Defensive",
				Description = "White and gold exo-armour with a jet pack and a crusader's cape.",
				Look = "SuitCrusader",
				Mods = { Defense = 2, Speed = -1 },
				Passive = BASTION,
			},
			{
				Id = "ZeroGSuit",
				Name = "Zero-G Survey Suit",
				Tier = 2,
				Style = "Mobility",
				Description = "Light survey shell with a compact maneuver pack and recon helmet.",
				Look = "SuitZeroG",
				Mods = { Speed = 1, Defense = -1 },
				Passive = {
					Name = "Maneuver Thrusters",
					Text = "+3 walk speed; sacrifices armor weight.",
					Effect = { SpeedAdd = 3 },
				},
			},
			{
				Id = "ThermalSuit",
				Name = "Thermal Containment Suit",
				Tier = 3,
				Style = "Survival",
				Description = "Reinforced containment shell with twin scrubber tanks and heavy shoulders.",
				Look = "SuitThermal",
				Mods = { Health = 1, Speed = -1 },
				Passive = {
					Name = "Containment Barrier",
					Text = "Every 8 seconds, absorb 18 damage.",
					Effect = { Ward = 18 },
				},
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
		Role = "Ranged gemstone energy",
		Tagline = "Bend the elements from a safe distance.",
		Color = Color3.fromRGB(150, 90, 255),
		ResourceId = "Charge",
		Resource = "Charge: spent on gem surges, refills steadily",
		ArmorWeight = "Light",
		Difficulty = 3,
		Stats = { Health = 1, Power = 4, Defense = 1, Speed = 3 },
		RigManeuvers = {
			{
				Id = "ArcaneBolt",
				Name = "Resonance Bolt",
				Description = "A fast bolt of pure gemstone energy.",
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
				Id = "SiphonField",
				Name = "Charge Shield",
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
				Id = "ThermalBurst",
				Name = "Thermal Burst",
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
				Description = "Rapid bolts from a wand, backed by a field console.",
				Look = "WandTome",
				Mods = { Speed = 1, Power = -1 },
				Attack = { Kind = "Shot", Damage = 9, Range = 45, Rate = 0.35 },
				Passive = {
					Name = "Resonance Flow",
					Text = "Each hit restores 3 Charge.",
					Effect = { ResourceOnHit = 3 },
				},
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
				Nodes = { "Overload: more gem surge power", "Chain Cast: bolts bounce to a second target" },
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
		RigManeuvers = {
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
		RigManeuvers = {
			{
				Id = "ShieldBash",
				Name = "Kinetic Ram",
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

-- Miner weapon entries now represent only the sidearm; shields are independent.
for _, weapon in Classes.List.Warrior.Weapons do
	weapon.Name = string.gsub(weapon.Name, " & Shield", "")
	if weapon.Passive.Effect.Ward then
		weapon.Passive = { Name = "Stable Emitter", Text = "Standard precision sidearm.", Effect = {} }
	end
end
for _, class in Classes.List do
	for kind, catalog in Slots.Catalog do
		class[kind] = catalog
	end
end
-- Keep saved legacy equipment valid; only new-player draws use the expanded pool.
for kind, entries in ExpandedTraits.LegacyCatalog do
	Classes.List.Warrior[kind] = table.clone(Classes.List.Warrior[kind])
	for _, gear in entries do
		table.insert(Classes.List.Warrior[kind], gear)
	end
end
for kind, entries in ExpandedTraits.Catalog do
	Classes.List.Warrior[kind] = table.clone(Classes.List.Warrior[kind])
	for _, gear in entries do
		table.insert(Classes.List.Warrior[kind], gear)
	end
end
-- Original pistols keep their ranged attacks; new sword IDs use melee models.
for _, weapon in Classes.List.Warrior.Weapons do
	if weapon.WeaponType ~= "Sword" and not weapon.Forge then
		weapon.Look = "CleanSidearm"
		weapon.WeaponType = "Pistol"
	end
end
-- Every player is a Warrior; retain other-class items so migration never erases gear.
for classId, class in Classes.List do
	if classId ~= "Warrior" then
		for _, kind in Slots.Kinds do
			for _, item in class[kind] do
				local exists = false
				for _, old in Classes.List.Warrior[kind] do
					if old.Id == item.Id then
						exists = true
						break
					end
				end
				if not exists then
					table.insert(Classes.List.Warrior[kind], item)
				end
			end
		end
	end
end
Classes.Order = { "Warrior" }
-- Universal actions replace all active rigManeuver/ultimate picks.
Classes.List.Warrior.ResourceId = "Stamina"
Classes.List.Warrior.Resource = "Stamina powers your exosuit; socketed gemstones store Charge for Gem Surges."
Classes.List.Warrior.RigManeuvers = {}
Classes.List.Warrior.Ultimate = nil
Classes.List.Warrior.Specs = {}
function Classes.setState(loadout)
	loadout = Classes.activeLoadout(loadout)
	return ArmorFamilies.setState(loadout, function(slot, id)
		return Classes.gear(loadout.Class, Slots.Definitions[slot].Kind, id)
	end)
end
function Classes.armorBonuses(loadout)
	loadout = Classes.activeLoadout(loadout)
	local bonuses = table.clone(Classes.setState(loadout).Bonuses)
	for _, slot in ArmorFamilies.Slots do
		local roll = GearRolls.get(loadout, slot)
		if roll and roll.ArmorBudgetVersion then
			for stat, amount in roll.Stats do
				bonuses[stat] = (bonuses[stat] or 0) + amount
			end
		end
	end
	return bonuses
end
-- Elemental Affinity Affixes from every equipped armor piece, summed per affix:
-- { [affixId]: bonus }. Feed it to GemConfig.stats / GemConfig.lines.
function Classes.affinities(loadout): { [string]: number }
	loadout = Classes.activeLoadout(loadout)
	local totals = {}
	for _, slot in ArmorFamilies.Slots do
		local roll = GearRolls.get(loadout, slot)
		for _, affix in roll and roll.Affixes or {} do
			totals[affix.Id] = (totals[affix.Id] or 0) + affix.Bonus
		end
	end
	return totals
end
function Classes.gear(classId: string, kind: string, id: string?)
	local class = Classes.List[classId]
	for _, gear in class and class[kind] or {} do
		if gear.Id == id then
			return gear
		end
	end
	return nil
end
function Classes.effects(loadout)
	loadout = Classes.activeLoadout(loadout)
	local effects = {}
	for _, slot in Slots.Order do
		local gear = Classes.gear(loadout.Class, Slots.Definitions[slot].Kind, loadout[slot])
		for key, value in gear and gear.Passive.Effect or {} do
			if key == "TakenMult" or key == "CooldownMult" then
				effects[key] = (effects[key] or 1) * value
			elseif key == "SpeedAdd" or key == "CritAdd" then
				effects[key] = (effects[key] or 0) + value
			elseif key == "Ward" then
				effects[key] = math.max(effects[key] or 0, value)
			else
				effects[key] = value
			end
		end
	end
	local bonuses = Classes.armorBonuses(loadout)
	effects.CritAdd = (effects.CritAdd or 0) + (bonuses.Critical or 0)
	effects.CooldownMult = (effects.CooldownMult or 1) * (1 - math.min(bonuses.Cooldown or 0, 0.60))
	effects.TakenMult = (effects.TakenMult or 1) * (1 - (bonuses.DamageReduction or 0))
	effects.HealingReceived = bonuses.HealingReceived or 0
	effects.DamageAfterDodge = bonuses.DamageAfterDodge or 0
	effects.ThreatGeneration = bonuses.ThreatGeneration or 0
	if effects.TakenMult then
		effects.TakenMult = EquipmentBalance.passiveDamageMultiplier(effects.TakenMult, 0)
	end
	if effects.CooldownMult then
		effects.CooldownMult = EquipmentBalance.cooldownMultiplier(effects.CooldownMult)
	end
	if effects.CritAdd then
		effects.CritAdd = math.clamp(effects.CritAdd, 0, EquipmentBalance.MaxCriticalChance)
	end
	return effects
end

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

-- The weapon a new kit starts with. Given an rng it's a rarity-weighted
-- draw (ExpandedItemTraits.Weights) from what can be handed out right now,
-- so a new kit can come with anything from Common to Legendary; without
-- one, the first weapon that can be handed out (the first sword while
-- pistols are switched off).
function Classes.starterWeapon(class: Class, rng: Random?): Gear
	if rng then
		local drawn = ExpandedTraits.pick(class.Weapons, rng)
		if drawn then
			return drawn
		end
	end
	for _, weapon in class.Weapons do
		if ExpandedTraits.obtainable(weapon) then
			return weapon
		end
	end
	return class.Weapons[1]
end

function Classes.weapon(classId: any, weaponId: any): Gear?
	local class = Classes.get(classId)
	return class and find(class.Weapons, weaponId)
end

-- Weapons that take both hands (a blade in each, or one big two-handed
-- weapon): no shield is worn with them, and shield moves can't be used.
Classes.TwoHanded = { TwinBlades = true, Greataxe = true, Warhammer = true, Lance = true }

-- Keep the saved shield for swapping back to one hand, but remove every active
-- contribution while both hands are occupied. Never mutate inventory here.
function Classes.activeLoadout(loadout)
	if not loadout then
		return loadout
	end
	local weapon = Classes.weapon(loadout.Class, loadout.Weapon)
	if
		weapon
		and Classes.TwoHanded[weapon.WeaponType]
		and (loadout.Shield or loadout.ShieldGem or loadout.ShieldQuality)
	then
		local active = table.clone(loadout)
		active.Shield, active.ShieldGem, active.ShieldQuality = nil, nil, nil
		return active
	end
	return loadout
end

-- The shield a loadout actually carries: its Shield, unless the weapon needs
-- both hands.
function Classes.heldShield(loadout): Gear?
	if not loadout then
		return nil
	end
	local weapon = Classes.weapon(loadout.Class, loadout.Weapon)
	if weapon and Classes.TwoHanded[weapon.WeaponType] then
		return nil
	end
	return Classes.gear(loadout.Class, "Shields", loadout.Shield)
end

function Classes.armor(classId: any, armorId: any): Gear?
	local class = Classes.get(classId)
	return class and find(class.Armors, armorId)
end

function Classes.rigManeuver(classId: any, maneuverId: any): RigManeuver?
	local class = Classes.get(classId)
	if not class then
		return nil
	end
	if class.Ultimate and class.Ultimate.Id == maneuverId then
		return class.Ultimate
	end
	for _, rigManeuver in class.RigManeuvers do
		if rigManeuver.Id == maneuverId then
			return rigManeuver
		end
	end
	return nil
end

-- The three rig maneuvers on Q / E / R: the saved picks if they're valid,
-- otherwise the class's first three.
function Classes.loadout(classId: any, picks: { any }?): { RigManeuver }
	local class = Classes.get(classId)
	if not class then
		return {}
	end
	local chosen, seen = {}, {}
	for i = 1, 3 do
		local id = picks and picks[i]
		local rigManeuver = Classes.rigManeuver(classId, id)
		if rigManeuver and not rigManeuver.Ultimate and not seen[id] then
			chosen[i] = rigManeuver
			seen[id] = true
		end
	end
	-- Fill gaps with the first rig maneuvers not already chosen.
	for i = 1, 3 do
		if not chosen[i] then
			for _, rigManeuver in class.RigManeuvers do
				if not seen[rigManeuver.Id] then
					chosen[i] = rigManeuver
					seen[rigManeuver.Id] = true
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
	loadout = Classes.activeLoadout(loadout)
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
	for _, slot in { "Helmet", "Gloves", "Boots", "Shield" } do
		if slot == "Shield" and not loadout.Shield then
			continue
		end
		local gear = Classes.gear(loadout.Class, Slots.Definitions[slot].Kind, loadout[slot])
		for stat, value in gear and gear.Mods or {} do
			ratings[stat].Base += value
		end
		for stat, value in Crafting.qualityBonus("Armors", loadout[slot .. "Quality"]) do
			ratings[stat].Base += math.floor(value * 0.25)
		end
	end
	for _, slot in Slots.Order do
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
	for _, slot in Slots.Order do
		local roll = GearRolls.get(loadout, slot)
		for stat, amount in (if roll and not roll.ArmorBudgetVersion then roll.Stats else {}) or {} do
			ratings[stat].Base += amount
		end
	end
	local bonuses = Classes.armorBonuses(loadout)
	-- Convert physical HP/SPD into the existing rating units exactly once.
	ratings.Health.Base += (bonuses.Health or 0) / 0.6
	ratings.Speed.Base += (bonuses.Speed or 0) / 0.1
	ratings.Power.Base += bonuses.Power or 0
	ratings.Defense.Base += bonuses.Defense or 0
	return ratings
end

-- What ratings do to the avatar (16 speed and 100 health at ratings of 40
-- and 67, the Roblox defaults).
function Classes.walkSpeed(speedRating: number): number
	return math.max(12 + speedRating * 0.1, 12)
end

-- Speed in a fight: slower and closer together than walking about, so
-- spacing and footwork matter and better gear is an edge, not an escape
-- (about 13 for starter gear, at most 16).
Classes.CombatSpeedMax = 16
function Classes.combatSpeed(speedRating: number): number
	return math.clamp(11 + speedRating * 0.05, 11, Classes.CombatSpeedMax)
end

function Classes.maxHealth(healthRating: number): number
	return math.floor(60 + healthRating * 0.6)
end

-- The armor one tier below `armorId` in its class's ladder (nil for the first).
function Classes.previousArmor(classId: string, armorId: string)
	local class = Classes.get(classId)
	local armor = Classes.armor(classId, armorId)
	if not class or not armor or not armor.Tier then
		return nil
	end
	for _, other in class.Armors do
		if other.Tier == armor.Tier - 1 then
			return other
		end
	end
	return nil
end

return Classes

end)()
local Combat=(function()
--[[
	Combat rules shared by the server (which runs every hit) and the client
	(HUD, cooldowns, where you can fight).

	Where: fighting is off inside the town walls, except in the Arena
	(training dummies). Outside the south gate are the Crystal Wilds, where
	crystal monsters roam and drop stones and coins.

	Numbers:
	  damage = base x (Power / 60) x buffs, x1.6 on a crit or combo finisher
	  crit chance = min(75%, 5% + min(2.5%, Speed / 4000) + equipment bonus)
	  damage taken = hit x 60 / (60 + Defense) x armor/weapon/buff multipliers
	Resources (per class) fill and drain as below; rig maneuvers spend them.

	RigManeuver kinds (numbers live on each rigManeuver in Classes):
	  Cone  hit enemies in front: Damage, Range, Arc
	  Nova  hit enemies around you (or the aimed spot with AtTarget): Radius
	  Dash  move Distance (Backward, Teleport), then hit around you if Damage
	  Bolt  a projectile at the aimed spot: Range, Pierce, Splash, Chain
	  Buff  on yourself: Duration, DamageMult, TakenMult, RateMult, Heal, Shield
	  Zone  a lasting area at the aimed spot: Radius, Duration, Tick damage
	Shared extras: Stun, Slow + SlowTime, Taunt, Burn, Poison, Gain, Cost.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = {}

Combat.TownRadius = 192 -- the walls and moat; no fighting inside (but the Arena)
Combat.CritMult = 1.6
Combat.FinisherMult = 1.6
Combat.InCombatSeconds = 5 -- Rage and Resolve start fading after this long

export type Resource = { Max: number, Start: number, Regen: number, OnHit: number, OnHurt: number }

-- Regen is per second; negative means it fades while out of combat.
Combat.Resources = {
	Stamina = { Max = 100, Start = 100, Regen = 12, OnHit = 0, OnHurt = 0 },
	Charge = { Max = 100, Start = 100, Regen = 7, OnHit = 0, OnHurt = 0 },
} :: { [string]: Resource }
Combat.ResourceColors = {
	Health = Color3.fromRGB(198, 62, 73),
	Stamina = Color3.fromRGB(65, 195, 112),
	Charge = Color3.fromRGB(70, 130, 255),
}

function Combat.powerMult(power: number): number
	return math.max(0.3, power / 60)
end

function Combat.defenseMult(defense: number): number
	return 60 / (60 + math.max(0, defense))
end

function Combat.critChance(speed: number, bonus: number?): number
	return EquipmentBalance.criticalChance(speed, bonus)
end

-- Landmarks the world builder publishes (see Builder.landmark).
local function landmark(name: string): any
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	return landmarks and landmarks:GetAttribute(name)
end

function Combat.inArena(position: Vector3): boolean
	local center, radius = landmark("ArenaFloor"), landmark("ArenaRadius")
	if typeof(center) ~= "Vector3" or typeof(radius) ~= "number" then
		return false
	end
	local offset = position - center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius + 2 and math.abs(offset.Y) < 30
end

-- Can a fight happen at this spot?
function Combat.canFight(position: Vector3): boolean
	return Vector3.new(position.X, 0, position.Z).Magnitude > Combat.TownRadius or Combat.inArena(position)
end

return Combat

end)()
local DuelistBrain=(function()
--[[
	The PvP Duelist's decisions (pure, so they can be tested): given what it
	sees this moment, what to do next. It plays aggressively and reads the
	player:

	  Stagger   stunned or parried: does nothing
	  Riposte   a counter-swing straight after blocking one of yours
	  Guard     raises its guard against your swings (most of the time, and
	            longer when you're pressing it); a hit that lands just as
	            it raises it is parried
	  Dodge     sidesteps a charged heavy (which would break its guard) or a
	            surge wind-up, and anything once its guard is broken
	  GuardAdvance  walks you down shield-first (from mid range, or under fire)
	  Punish    a fast counter-swing while the player recovers from an attack
	  Surge     casts its gem's surge: from range, or point-blank when the
	            player is stunned, slowed or hiding behind their guard
	  Retreat   backs off briefly when badly hurt (never when the player is low)
	  Lunge     dashes in from mid range and swings straight away
	  Approach  closes the distance
	  Light     a quick swing (may chain into a combo)
	  Heavy     a slow, telegraphed blow that breaks a raised guard
	  Strafe    circles the player between attacks
]]
local Brain = {}

Brain.Reach = 6.5 -- melee range, studs
-- Wind-ups, seconds. Bolts, blasts and heavies are slow enough to see on the
-- enemy cast bar and dodge (tap Space to hop aside, double-tap to roll).
Brain.Windup = { Light = 0.3, Heavy = 0.75, Punish = 0.18, Lunge = 0.25, Bolt = 0.7, Nova = 1.05 } -- (a blast's ring is wide: a moment more to get out)
Brain.BoltRadius = 3.5 -- a bolt hits within this many studs of where it was aimed
Brain.SurgeRange = 32
Brain.LungeRange = 18
Brain.IdleAfter = 1.2 -- seconds of you doing nothing before it presses the attack
Brain.MaxLull = 1.6 -- the longest it goes without attacking while you're in reach

export type View = {
	Now: number,
	Distance: number,
	HealthRatio: number,
	Stunned: boolean,
	FoeCharging: boolean, -- winding up a swing
	FoeHeavy: boolean?, -- held long enough to be a heavy (breaks a guard)
	FoeAttacking: boolean?, -- swung in the last half second (mid-combo)
	FoeAggressive: boolean?, -- two or more swings in the last few seconds
	FoeRanged: boolean?, -- fights with a gun
	GuardBroken: boolean?, -- its guard was just broken: can't raise it
	JustBlocked: boolean?, -- just blocked one of your swings
	Guarding: boolean?, -- its guard is up right now
	FoeCasting: boolean, -- winding up a surge or maneuver
	FoeBlocking: boolean, -- guard up
	FoeRecovering: boolean, -- just attacked and can't act yet
	FoeVulnerable: boolean, -- stunned or slowed
	FoeLow: boolean, -- below 30% health
	FoeIdle: boolean?, -- not swinging, blocking, casting or charging for a while: press the attack
	SinceOffense: number?, -- seconds since it last attacked or cast
	NextAttack: number,
	NextSurge: number,
	NextDefense: number,
	NextRetreat: number,
	NextLunge: number,
}

-- A bolt aimed at `aim` hits a player now at `at` (only sideways distance counts).
function Brain.boltHits(aim: Vector3, at: Vector3): boolean
	local offset = at - aim
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Brain.BoltRadius
end

-- `roll` is a random number in [0, 1).
function Brain.decide(v: View, roll: number): string
	if v.Stunned then
		return "Stagger"
	end
	-- Blocked your swing: hit back while you're open.
	-- (Most of the time; otherwise it stays behind the shield.)
	if v.JustBlocked and v.Distance <= Brain.Reach + 1.5 and (roll < 0.7 or not v.FoeAttacking) then
		return "Riposte"
	end
	-- Shield already up and you're still swinging: hold it (a heavy is
	-- dodged instead, below). It answers once a swing is blocked.
	if v.Guarding and (v.FoeAttacking or v.FoeCharging) and not v.FoeHeavy then
		return "Guard"
	end
	-- Defend against what's coming, but not every time (it reads, not cheats).
	local threat = v.FoeCharging or v.FoeCasting or v.FoeAttacking
	if threat and v.Distance <= Brain.Reach + 4 and v.Now >= v.NextDefense then
		if v.FoeHeavy or v.GuardBroken then
			-- A heavy would break the guard: get out of the way instead.
			if roll < 0.75 then
				return "Dodge"
			end
		elseif v.FoeCasting and not v.FoeCharging then
			if roll < 0.45 then
				return "Guard"
			elseif roll < 0.85 then
				return "Dodge"
			end
		else
			-- Quick swings: shield up nearly always, more so against a flurry.
			local guard = if v.FoeAggressive then 0.92 else 0.85
			if roll < guard then
				return "Guard"
			elseif roll < 0.97 then
				return "Dodge"
			end
		end
	end
	-- Facing a gun: close in behind the shield.
	if v.FoeRanged and v.Distance > Brain.Reach + 2 and not v.GuardBroken then
		if v.FoeRecovering or roll < 0.8 then
			return "GuardAdvance"
		end
	end
	-- Never stalls: too long without attacking and it swings as soon as it
	-- can, whatever you're doing.
	if (v.SinceOffense or 0) > Brain.MaxLull and v.Distance <= Brain.Reach + 1 and v.Now >= v.NextAttack then
		return if roll < 0.3 then "Heavy" else "Light"
	end
	-- An opening: hit the player while they recover.
	if v.FoeRecovering and v.Distance <= Brain.Reach + 2 then
		return "Punish"
	end
	if v.Now >= v.NextSurge and v.Distance <= Brain.SurgeRange then
		if v.Distance >= 8 or v.FoeVulnerable or v.FoeBlocking or v.FoeIdle then
			return "Surge"
		end
	end
	if v.HealthRatio < 0.25 and not v.FoeLow and v.Now >= v.NextRetreat then
		return "Retreat"
	end
	if v.Distance > Brain.Reach + 2 and v.Distance <= Brain.LungeRange and v.Now >= v.NextLunge then
		return "Lunge"
	end
	if v.Distance > Brain.Reach then
		-- Mid range: walk you down behind the shield; from far, or when
		-- you're standing idle, run straight in.
		if v.Distance <= Brain.LungeRange + 6 and not v.GuardBroken and not v.FoeIdle then
			return "GuardAdvance"
		end
		return "Approach"
	end
	if v.Now >= v.NextAttack then
		if v.FoeBlocking then
			return if roll < 0.7 then "Heavy" else "Light"
		end
		if v.FoeLow then
			return if roll < 0.15 then "Heavy" else "Light" -- quick pressure to finish
		end
		-- An idle foe is a free target: more heavies.
		return if roll < (if v.FoeIdle then 0.4 else 0.25) then "Heavy" else "Light"
	end
	-- Waiting on its next swing up close: shield up rather than open, unless
	-- you're doing nothing (then it stays on you, ready to swing).
	if v.Distance <= Brain.Reach + 3 and not v.GuardBroken and not v.FoeIdle and roll < 0.6 then
		return "Guard"
	end
	return "Strafe"
end

-- Which ready surge suits this moment, or nil. Surges are
-- { Kind = "Bolt" | "Nova" | "Self", SelfCentered, Radius, Power, Next }.
function Brain.pickSurge(surges, now: number, distance: number, v: View)
	local best, bestScore = nil, 0
	for _, surge in surges do
		if now >= surge.Next then
			local score = 0
			if surge.Kind == "Self" then
				-- Shields, heals and buffs: when hurt or in the thick of it.
				score = if v.HealthRatio < 0.7 or distance <= Brain.Reach then 3 else 0
			elseif surge.Kind == "Nova" then
				if surge.SelfCentered then
					score = if distance <= surge.Radius then 4 else 0
				else
					-- Blasts land best on a target that can't step away.
					score = if v.FoeVulnerable or v.FoeBlocking then 5 else 2
				end
			else
				score = if distance >= 8 then 4 else 1 -- bolts from range
			end
			if score > 0 then
				score += surge.Power
				if score > bestScore then
					best, bestScore = surge, score
				end
			end
		end
	end
	return best
end

-- Swaps a basic action for one of its Rig Maneuvers (keys 1, 2, 3) when one
-- fits, as a player would. Moves are { Id, Power, Windup?, Next }.
function Brain.pickMove(moves, choice: string, now: number, distance: number, roll: number)
	local function ready(id: string)
		for _, move in moves do
			if move.Id == id and now >= move.Next then
				return move
			end
		end
		return nil
	end
	if choice == "Dodge" then
		return ready("StimDodge") -- a dodge that also heals
	elseif choice == "Lunge" then
		return ready("ThrusterLeap") or ready("KineticRam") -- close the gap
	elseif choice == "Interrupt" then
		-- Jab a cast in progress, if in reach.
		return if distance <= Brain.Reach + 1 then ready("PneumaticJab") else nil
	elseif choice == "Guard" and roll < 0.3 then
		return ready("RiposteStance") -- sometimes brace to turn the blow aside
	elseif
		(choice == "Light" or choice == "Heavy" or choice == "Punish")
		and distance <= Brain.Reach
		and roll < 0.4
	then
		-- The strongest ready strike; slow wind-up ones only in place of a heavy.
		local best = nil
		for _, move in moves do
			if
				now >= move.Next
				and move.Id ~= "StimDodge"
				and move.Id ~= "RiposteStance"
				and move.Id ~= "PneumaticJab"
				and (choice == "Heavy" or not move.Windup)
				and (not best or move.Power > best.Power)
			then
				best = move
			end
		end
		return best
	end
	return nil
end

return Brain

end)()
local RivalPose=(function()
--[[
	Body language for the Arena rival. The server plays its walk, run and idle
	animations and, every frame, this layers the fighting on top by bending
	its joints (Motor6D C0, or an AnimationConstraint's attachment) from what
	the rival is doing. Done on the server, so it replicates to every client:

	  ActionKind   Slash, Heavy, Bolt, Nova, Buff, Dodge or Stagger
	  ActionStart  server time the wind-up began
	  ActionAt     server time the blow lands (or the cast releases)
	  ActionSide   1 or -1: which way a slash or a dodge goes
	  GuardUntil   server time its guard drops
	  HurtAt       server time it was hit (a flinch), HurtSide which way
	  BlockedAt    server time a blow landed on its shield (a jolt)

	A slash winds the arm back and whips it across; a heavy goes overhead with
	both hands and slams down; a bolt gathers and thrusts the palm forward; a
	blast raises both arms and drives them into the ground; a buff throws the
	arms wide; a guard crosses the forearms in front of the face; a dodge
	tucks and leans; a stagger rocks it back.
]]
local RivalPose = {}

-- Joint -> the part that holds it (R15).
local JOINTS = {
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	LeftShoulder = "LeftUpperArm",
	RightElbow = "RightLowerArm",
	LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftKnee = "LeftLowerLeg",
}
local JOINT_COUNT = 10
local FOLLOW = 0.32 -- how long a strike's follow-through holds, seconds

-- Angles are radians about the joint's X (positive swings a limb forward and
-- up, or leans the torso back), Y (twists left) and Z (positive raises the
-- right arm outward; negative the left).
-- Fighting stance: shield arm forward, sword held out, knees soft.
local READY = {
	RightShoulder = { 0.45, 0, 0.12 },
	RightElbow = { 0.85, 0, 0 },
	LeftShoulder = { 0.75, 0, 0.18 },
	LeftElbow = { 1.0, 0, 0 },
	Waist = { -0.05, -0.12, 0 },
	RightHip = { 0.12, 0, 0 },
	LeftHip = { 0.12, 0, 0 },
	RightKnee = { -0.18, 0, 0 },
	LeftKnee = { -0.18, 0, 0 },
}

local function lerp(a, b, t: number)
	local out = {}
	for joint, angles in a do
		local to = b[joint] or { 0, 0, 0 }
		out[joint] = {
			angles[1] + (to[1] - angles[1]) * t,
			angles[2] + (to[2] - angles[2]) * t,
			angles[3] + (to[3] - angles[3]) * t,
		}
	end
	for joint, angles in b do
		if not out[joint] then
			out[joint] = { angles[1] * t, angles[2] * t, angles[3] * t }
		end
	end
	return out
end

-- Wind-up and strike poses for each action; `s` mirrors a slash or dodge.
local function frames(kind: string, s: number)
	if kind == "Mine" then
		return {
			Waist = { 0.15, -0.2, 0 },
			RightShoulder = { 2.7, 0, 0.2 },
			RightElbow = { 1, 0, 0 },
			LeftShoulder = {
				1.1,
				0,
				-0.3,
			},
		}, {
			Waist = { -0.35, 0.15, 0 },
			RightShoulder = { 0.6, 0, -0.2 },
			RightElbow = { 0.1, 0, 0 },
			LeftShoulder = {
				0.5,
				0,
				-0.3,
			},
		}
	elseif kind == "Feed" then
		return {
			Waist = { -0.2, 0, 0 },
			Neck = { 0.1, 0, 0 },
			RightShoulder = { 0.5, 0, 0.2 },
			LeftShoulder = {
				0.5,
				0,
				-0.2,
			},
		}, {
			Waist = { -0.55, 0, 0 },
			Neck = { -0.35, 0, 0 },
			RightShoulder = { 0.9, 0, 0.2 },
			LeftShoulder = {
				0.9,
				0,
				-0.2,
			},
		}
	elseif kind == "Drill" then
		return {
			Waist = { 0.12, -0.55, 0 },
			RightShoulder = { 1.2, -0.3, 0.65 },
			RightElbow = { 1.65, 0, 0 },
			LeftShoulder = { 0.8, 0, -0.3 },
			LeftElbow = { 1.2, 0, 0 },
		}, {
			Waist = { -0.18, 0.35, 0 },
			RightShoulder = { 1.65, 0.12, -0.08 },
			RightElbow = { 0.02, 0, 0 },
			LeftShoulder = { 0.5, 0, -0.5 },
			LeftElbow = { 0.8, 0, 0 },
		}
	elseif kind == "Sweep" then
		return {
			Waist = { 0.05, -0.8, 0.08 },
			RightShoulder = { 1.7, -0.4, 1.05 },
			RightElbow = { 0.7, 0, 0 },
			LeftShoulder = { 0.9, 0, -0.5 },
			LeftElbow = { 1.1, 0, 0 },
		}, {
			Waist = { -0.1, 0.8, -0.08 },
			RightShoulder = { 1.4, 0.4, -1.0 },
			RightElbow = { 0.15, 0, 0 },
			LeftShoulder = { 0.6, 0, -0.75 },
			LeftElbow = { 0.6, 0, 0 },
		}
	elseif kind == "Erupt" then
		return {
			Waist = { 0.3, 0, 0 },
			RightShoulder = { 2.8, 0, 0.5 },
			LeftShoulder = { 2.8, 0, -0.5 },
			RightElbow = { 1.1, 0, 0 },
			LeftElbow = { 1.1, 0, 0 },
			RightKnee = { -0.25, 0, 0 },
			LeftKnee = { -0.25, 0, 0 },
		}, {
			Waist = { -0.5, 0, 0 },
			RightShoulder = { 0.3, 0, 0.4 },
			LeftShoulder = { 0.3, 0, -0.4 },
			RightElbow = { 0.1, 0, 0 },
			LeftElbow = { 0.1, 0, 0 },
			RightHip = { 0.55, 0, 0 },
			LeftHip = { 0.55, 0, 0 },
			RightKnee = { -0.85, 0, 0 },
			LeftKnee = { -0.85, 0, 0 },
		}
	elseif kind == "Cross" then
		return {
			Waist = { 0.18, 0, 0 },
			RightShoulder = { 1.3, 0.5, -0.65 },
			LeftShoulder = { 1.3, -0.5, 0.65 },
			RightElbow = { 1.45, 0, 0 },
			LeftElbow = { 1.45, 0, 0 },
		}, {
			Waist = { -0.2, 0, 0 },
			RightShoulder = { 1.7, -0.3, 0.9 },
			LeftShoulder = { 1.7, 0.3, -0.9 },
			RightElbow = { 0.15, 0, 0 },
			LeftElbow = { 0.15, 0, 0 },
		}
	elseif kind == "Slash" then
		return {
			Waist = { 0, -0.55 * s, 0 },
			RightShoulder = { 2.3, 0, 0.7 * s },
			RightElbow = { 0.9, 0, 0 },
			LeftShoulder = { 0.6, 0, -0.3 },
			LeftElbow = { 0.9, 0, 0 },
		}, {
			Waist = { -0.15, 0.6 * s, 0 },
			RightShoulder = { 1.2, 0, -0.7 * s },
			RightElbow = { 0.15, 0, 0 },
			LeftShoulder = { 0.3, 0, -0.4 },
			LeftElbow = { 0.6, 0, 0 },
		}
	elseif kind == "Heavy" then
		return {
			Waist = { 0.3, -0.2, 0 },
			Neck = { 0.15, 0, 0 },
			RightShoulder = { 3.0, 0, 0.2 },
			LeftShoulder = { 3.0, 0, -0.2 },
			RightElbow = { 0.9, 0, 0 },
			LeftElbow = { 0.9, 0, 0 },
		}, {
			Waist = { -0.55, 0.1, 0 },
			Neck = { -0.2, 0, 0 },
			RightShoulder = { 0.7, 0, -0.15 },
			LeftShoulder = { 0.7, 0, 0.15 },
			RightElbow = { 0.1, 0, 0 },
			LeftElbow = { 0.1, 0, 0 },
			RightHip = { 0.5, 0, 0 },
			LeftHip = { -0.2, 0, 0 },
			RightKnee = { -0.6, 0, 0 },
			LeftKnee = { -0.3, 0, 0 },
		}
	elseif kind == "Bolt" then
		return {
			Waist = { 0, -0.4, 0 },
			RightShoulder = { 1.0, 0, 0.5 },
			RightElbow = { 1.5, 0, 0 },
			LeftShoulder = { 1.1, 0, -0.3 },
			LeftElbow = { 1.2, 0, 0 },
		}, {
			Waist = { -0.1, 0.25, 0 },
			RightShoulder = { 1.65, 0, -0.1 },
			RightElbow = { 0.05, 0, 0 },
			LeftShoulder = { 0.4, 0, -0.4 },
			LeftElbow = { 0.5, 0, 0 },
		}
	elseif kind == "Nova" then
		return {
			Waist = { 0.25, 0, 0 },
			Neck = { 0.35, 0, 0 },
			RightShoulder = { 2.7, 0, 0.6 },
			LeftShoulder = { 2.7, 0, -0.6 },
			RightElbow = { 0.3, 0, 0 },
			LeftElbow = { 0.3, 0, 0 },
		}, {
			Waist = { -0.6, 0, 0 },
			Neck = { -0.25, 0, 0 },
			RightShoulder = { 0.5, 0, 0.25 },
			LeftShoulder = { 0.5, 0, -0.25 },
			RightHip = { 0.7, 0, 0.1 },
			LeftHip = { 0.7, 0, -0.1 },
			RightKnee = { -1.0, 0, 0 },
			LeftKnee = { -1.0, 0, 0 },
		}
	elseif kind == "Buff" then
		return {
			RightShoulder = { 0.6, 0, 0.3 },
			LeftShoulder = { 0.6, 0, -0.3 },
			RightElbow = { 1.4, 0, 0 },
			LeftElbow = { 1.4, 0, 0 },
			Waist = { -0.2, 0, 0 },
		}, {
			-- Both hands raised in front, channelling.
			Waist = { 0.12, 0, 0 },
			Neck = { 0.2, 0, 0 },
			RightShoulder = { 1.9, 0, 0.45 },
			LeftShoulder = { 1.9, 0, -0.45 },
			RightElbow = { 0.6, 0, 0 },
			LeftElbow = { 0.6, 0, 0 },
		}
	elseif kind == "Dodge" then
		local tuck = {
			Waist = { -0.5, 0, 0.35 * s },
			Neck = { -0.2, 0, 0 },
			RightShoulder = { 1.0, 0, -0.2 },
			LeftShoulder = { 1.0, 0, 0.2 },
			RightElbow = { 1.3, 0, 0 },
			LeftElbow = { 1.3, 0, 0 },
			RightHip = { 1.0, 0, 0 },
			LeftHip = { 1.0, 0, 0 },
			RightKnee = { -1.3, 0, 0 },
			LeftKnee = { -1.3, 0, 0 },
		}
		return tuck, tuck
	elseif kind == "Stagger" then
		local reel = {
			Waist = { 0.45, 0.2, 0 },
			Neck = { 0.4, 0, 0 },
			RightShoulder = { 0.4, 0, 0.9 },
			LeftShoulder = { 0.4, 0, -0.9 },
			RightKnee = { -0.4, 0, 0 },
			LeftKnee = { -0.4, 0, 0 },
		}
		return reel, reel
	end
	return nil, nil
end

-- Guard: the shield arm raised square in front of the chest and face, the
-- weapon lowered beside the hip, crouched behind the shield.
local GUARD = {
	Waist = { -0.18, -0.3, 0 },
	Neck = { -0.1, 0.15, 0 },
	LeftShoulder = { 1.4, -0.25, 0.7 },
	LeftElbow = { 1.4, 0, 0 },
	RightShoulder = { 0.12, 0.12, -0.12 },
	RightElbow = { 0.4, 0, 0 },
	RightHip = { 0.35, 0, 0 },
	LeftHip = { 0.2, 0, 0 },
	RightKnee = { -0.5, 0, 0 },
	LeftKnee = { -0.35, 0, 0 },
}

-- Sahur uses the same action frames and timeline as a Warrior. With no shield,
-- brace the bat across the chest and raise the free hand to protect the face.
local BAT_GUARD = table.clone(GUARD)
BAT_GUARD.RightShoulder = { 1.35, 0, -0.55 }
BAT_GUARD.RightElbow = { 1.15, 0, 0 }
BAT_GUARD.LeftShoulder = { 1.2, 0, 0.3 }
BAT_GUARD.LeftElbow = { 1.45, 0, 0 }
-- Both-hand guards share the same raise/recoil/recovery path in every world view.
local WEAPON_GUARDS = {
	TwinBlades = {
		RightShoulder = { 1.3, 0, -0.65 },
		RightElbow = { 1.3, 0, 0 },
		LeftShoulder = { 1.3, 0, 0.65 },
		LeftElbow = {
			1.3,
			0,
			0,
		},
	},
	Lance = {
		RightShoulder = { 1.1, 0, -0.55 },
		RightElbow = { 1.1, 0, 0 },
		LeftShoulder = { 1.45, 0, 0.35 },
		LeftElbow = {
			0.85,
			0,
			0,
		},
	},
	Greataxe = {
		RightShoulder = { 1.35, 0, -0.7 },
		RightElbow = { 1.05, 0, 0 },
		LeftShoulder = { 1.45, 0, 0.5 },
		LeftElbow = {
			1.1,
			0,
			0,
		},
	},
	Warhammer = {
		RightShoulder = { 1.25, 0, -0.6 },
		RightElbow = { 1.2, 0, 0 },
		LeftShoulder = { 1.4, 0, 0.45 },
		LeftElbow = {
			1.1,
			0,
			0,
		},
	},
}
for _, guard in WEAPON_GUARDS do
	for joint, angles in GUARD do
		if not guard[joint] then
			guard[joint] = angles
		end
	end
end

-- Smoothstep: slow in, slow out.
local function ease(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- `layer` added on top of `pose` at weight `w` (hit flinches, shield jolts).
local function add(pose, layer, w: number)
	local out = table.clone(pose)
	for joint, angles in layer do
		local from = out[joint] or { 0, 0, 0 }
		out[joint] = { from[1] + angles[1] * w, from[2] + angles[2] * w, from[3] + angles[3] * w }
	end
	return out
end

-- Timing of a blow after its wind-up: the snap through (overshooting the
-- strike pose a little), the follow-through settling back onto it, then an
-- eased recovery to the stance.
local SNAP, OVERSHOOT, RECOVER = 0.07, 0.15, 0.3

-- Hit reactions, layered over whatever the body is doing:
--   HurtAt     server time it was hit: the torso snaps back, head jerks
--   HurtSide   1 or -1: which way the hit twists it
--   BlockedAt  server time a blow landed on its shield: the shield arm
--              is knocked back and the body braces
local HURT_TIME, BLOCK_TIME = 0.32, 0.22
local FLINCH = {
	Waist = { 0.28, 0.18, 0 },
	Neck = { 0.32, 0, 0 },
	RightShoulder = { -0.25, 0, 0.25 },
	LeftShoulder = { -0.25, 0, -0.25 },
	RightKnee = { -0.15, 0, 0 },
	LeftKnee = { -0.15, 0, 0 },
}
local JOLT = {
	LeftShoulder = { -0.35, 0, 0.15 },
	LeftElbow = { 0.35, 0, 0 },
	Waist = { 0.15, 0, 0 },
	RightKnee = { -0.2, 0, 0 },
	LeftKnee = { -0.2, 0, 0 },
}
local BAT_JOLT = table.clone(JOLT)
BAT_JOLT.RightShoulder = { -0.35, 0, -0.15 }
BAT_JOLT.RightElbow = { 0.25, 0, 0 }

-- A reaction's weight `d` seconds after it lands: up fast, then fades.
local function impulse(d: number, length: number): number
	if d < 0 or d >= length then
		return 0
	end
	if d < 0.05 then
		return d / 0.05
	end
	return (1 - (d - 0.05) / (length - 0.05)) ^ 2
end

-- Breathing and a slight weight shift in the fighting stance, so it never
-- stands frozen between blows.
local function breathe(pose, t: number)
	local b = math.sin(t * 2.4)
	local shift = math.sin(t * 0.9)
	return add(pose, {
		Waist = { 0.03 * b, 0.05 * shift, 0 },
		Neck = { -0.02 * b, -0.04 * shift, 0 },
		RightShoulder = { 0.04 * b, 0, 0 },
		LeftShoulder = { 0.04 * b, 0, 0 },
		RightKnee = { -0.04 * (1 + b), 0, 0 },
		LeftKnee = { -0.04 * (1 + b), 0, 0 },
	}, 1)
end

-- The action itself: the pose and how snappily the joints follow it.
local function actionPose(a, t: number, base)
	local kind, start, at = a.ActionKind, a.ActionStart, a.ActionAt
	if type(kind) ~= "string" or type(start) ~= "number" or type(at) ~= "number" or t < start then
		return nil, 0
	end
	local windup, strike = frames(kind, if a.ActionSide == -1 then -1 else 1)
	if not windup then
		return nil, 0
	end
	if t < at then
		-- Ease into the wind-up, then coil a little past it just before the
		-- release (the anticipation that sells the blow). A heavy trembles
		-- with the strain.
		local length = math.max(0.05, at - start)
		local p = (t - start) / length
		local pose = lerp(base, windup, ease(p * 1.4) * (1 + 0.12 * ease((p - 0.75) / 0.25)))
		if kind == "Heavy" or kind == "Nova" or kind == "Erupt" then
			local shake = 0.035 * ease((p - 0.5) / 0.5) * math.sin(t * 47)
			pose = add(pose, { RightShoulder = { shake, 0, 0 }, LeftShoulder = { -shake, 0, 0 } }, 1)
		end
		return pose, 18
	end
	local hold = if kind == "Dodge" then 0.4 elseif kind == "Stagger" then 0.45 elseif kind == "Buff" then 0.6 else FOLLOW
	-- A held beam keeps its cast pose while it pours (ActionHold).
	if type(a.ActionHold) == "number" then
		hold = math.max(hold, a.ActionHold - at)
	end
	local d = t - at
	if d < SNAP then
		-- The blow snaps through, past the strike pose.
		return lerp(windup, strike, ease(d / SNAP) * (1 + OVERSHOOT)), 45
	elseif d < hold then
		-- Follow-through: settle back onto the strike pose.
		return lerp(windup, strike, 1 + OVERSHOOT * (1 - ease((d - SNAP) / math.max(0.05, hold - SNAP)))), 35
	elseif d < hold + RECOVER then
		-- Recover to the stance, smoothly.
		return lerp(strike, base, ease((d - hold) / RECOVER)), 28
	end
	return nil, 0
end

-- The pose for these attributes at server time `t` (pure, for testing):
-- { [joint] = { x, y, z } }, plus how snappily to move into it. `rest`: a
-- player's body, which stands as its own animations have it between
-- actions (no fighting stance, no breathing).
local REST = {}
function RivalPose.pose(a, t: number, rest: boolean?): ({ [string]: { number } }, number)
	local base = if rest then REST else breathe(READY, t)
	local bat = a.CombatPoseProfile == "SahurBat"
	local weaponGuard = if a.WeaponBlock then WEAPON_GUARDS[a.CombatWeaponType] else nil
	local guard = weaponGuard or (if bat then BAT_GUARD else GUARD)
	local pose, speed = actionPose(a, t, base)
	if not pose then
		if type(a.GuardUntil) == "number" and t < a.GuardUntil then
			pose, speed = if rest then guard else breathe(guard, t), 22
		else
			pose, speed = base, 10
		end
	end
	-- Hit reactions on top.
	if type(a.HurtAt) == "number" then
		local w = impulse(t - a.HurtAt, HURT_TIME)
		if w > 0 then
			local side = if a.HurtSide == -1 then -1 else 1
			pose = add(pose, FLINCH, w)
			pose = add(pose, { Waist = { 0, 0.18 * (side - 1), 0 } }, w)
			speed = math.max(speed, 40)
		end
	end
	if type(a.BlockedAt) == "number" then
		local w = impulse(t - a.BlockedAt, BLOCK_TIME)
		if w > 0 then
			pose = add(pose, if bat or weaponGuard then BAT_JOLT else JOLT, w)
			speed = math.max(speed, 40)
		end
	end
	return pose, speed
end

-- [model] = { Joints = { [joint] = { Object, Property, Rest } }, Angles = {...} }
-- (Not weak-keyed: a dropped entry would be rebuilt mid-pose.)
local rigs = {}

-- A joint and the CFrame that sets its resting offset: a Motor6D's C0, or for
-- rigs built with AnimationConstraints (Roblox's newer avatar joints) the
-- constraint's Attachment0. The rest value is remembered on the object the
-- first time it's seen, so a re-scan never mistakes an already-bent joint for
-- its rest pose (which would stack every pose on top of the last).
local function handle(model: Model, joint: string, partName: string)
	local part = model:FindFirstChild(partName)
	local object = part and part:FindFirstChild(joint)
	local target, property
	if object and object:IsA("Motor6D") then
		target, property = object, "C0"
	else
		local constraint = model:FindFirstChild(joint, true)
		if constraint and constraint:IsA("AnimationConstraint") and constraint.Attachment0 then
			target, property = constraint.Attachment0, "CFrame"
		end
	end
	if not target then
		return nil
	end
	local rest = target:GetAttribute("RestPose")
	if typeof(rest) ~= "CFrame" then
		rest = (target :: any)[property]
		target:SetAttribute("RestPose", rest)
	end
	return { Object = target, Property = property, Rest = rest }
end

-- Its joints. With streaming on, the body parts can arrive after the model
-- itself, so any joint not found yet is looked for again every half second.
local function rigOf(model: Model, clock: number)
	local rig = rigs[model]
	if not rig then
		rig = { Joints = {}, Angles = {}, Found = 0, NextScan = 0 }
		rigs[model] = rig
	end
	if rig.Found < JOINT_COUNT and clock >= rig.NextScan then
		rig.NextScan = clock + 0.5
		for joint, partName in JOINTS do
			local entry = rig.Joints[joint]
			if not entry or entry.Object.Parent == nil then
				local found = handle(model, joint, partName)
				if found then
					rig.Joints[joint] = found
					rig.Angles[joint] = rig.Angles[joint] or { 0, 0, 0 }
				end
			end
		end
		rig.Found = 0
		for _ in rig.Joints do
			rig.Found += 1
		end
	end
	return rig
end

-- How many joints it can pose (for diagnostics).
function RivalPose.jointCount(model: Model): number
	local count = 0
	for joint, partName in JOINTS do
		if handle(model, joint, partName) then
			count += 1
		end
	end
	return count
end

local ATTRIBUTES = {
	"CombatWeaponType",
	"WeaponBlock",
	"CombatPoseProfile",
	"ActionKind",
	"ActionStart",
	"ActionAt",
	"ActionSide",
	"ActionHold",
	"GuardUntil",
	"HurtAt",
	"HurtSide",
	"BlockedAt",
}

-- Call every frame (clients pose every body: Client.BodyPoses) with the
-- model and server time. Joints only change when they move noticeably.
local nextSweep = 0
function RivalPose.update(model: Model?, dt: number, now: number, clock: number?, rest: boolean?)
	local tick = clock or now
	if tick >= nextSweep then
		nextSweep = tick + 1
		for known in rigs do
			if not known.Parent then
				rigs[known] = nil -- gone: forget it
			end
		end
	end
	if not model or not model.Parent then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local rig = rigOf(model, clock or now)
	local attrs = {}
	for _, name in ATTRIBUTES do
		attrs[name] = model:GetAttribute(name)
	end
	local target, speed = RivalPose.pose(attrs, now, rest)
	local alpha = 1 - math.exp(-speed * math.min(dt, 0.1))
	for joint, entry in rig.Joints do
		local angles = rig.Angles[joint]
		local to = target[joint] or { 0, 0, 0 }
		local moved = 0
		for i = 1, 3 do
			local step = (to[i] - angles[i]) * alpha
			angles[i] += step
			moved = math.max(moved, math.abs(step))
		end
		if moved > 0.002 or not entry.Written then
			entry.Written = true;
			(entry.Object :: any)[entry.Property] = entry.Rest * CFrame.Angles(angles[1], angles[2], angles[3])
		end
	end
end

return RivalPose

end)()
local Matchup=(function()
--[[
	You vs the Arena rival: the numbers each side really fights with, and
	plain-language strengths and weaknesses for both (pure, for tests).

	Matchup.build(you, foe) with, for each side:
	  Name, Health (max), Hit (damage per quick hit on the other, after
	  armor), Speed (walk speed), Element (weapon gem), Armor
	  (ElementMatchup.profile of its armor gems), Surges (list of
	  { Id, Name, Kind = "Bolt" | "Nova" | "Self" }), Moves (maneuver ids)
	returns {
	  Rows = { { Stat, You, Foe, Better = "You" | "Foe" | nil } },
	  FoeEdges = { strings }, FoeWeak = { strings },
	  YourEdges = { strings }, YourWeak = { strings },
	}
]]

local Matchup = {}

local ELEMENT_NAME = { Fire = "Thermal", Frost = "Cryo", Shock = "Ion", Poison = "Corrosive" }

local CLEAR = 1.12 -- a stat counts as an edge when it's this much better

local ELEMENT_EDGE = {
	Fire = "Thermal hits burn (damage over time)",
	Frost = "Cryo hits slow and can freeze",
	Poison = "Corrosive hits shred armor",
	Shock = "Ion hits arc and can stun",
}

local function better(a: number, b: number, lowerWins: boolean?): string?
	if lowerWins then
		a, b = b, a
	end
	if a >= b * CLEAR then
		return "You"
	elseif b >= a * CLEAR then
		return "Foe"
	end
	return nil
end

local function hitsToWin(hit: number, health: number): number
	return math.max(1, math.ceil(health / math.max(1, hit)))
end

local function has(list, predicate): boolean
	for _, item in list or {} do
		if predicate(item) then
			return true
		end
	end
	return false
end

local function names(list, predicate): { string }
	local out = {}
	for _, item in list or {} do
		if predicate(item) then
			table.insert(out, item.Name)
		end
	end
	return out
end

local function heals(side): boolean
	return has(side.Surges, function(s)
		return s.Id == "EnergySiphon"
	end) or has(side.Moves, function(m)
		return m == "StimDodge"
	end)
end

local function cutsHealing(side): boolean
	return side.Element == "Fire" or side.Element == "Poison"
end

function Matchup.build(you, foe)
	local yourHits = hitsToWin(you.Hit, foe.Health) -- your hits to beat it
	local foeHits = hitsToWin(foe.Hit, you.Health) -- its hits to beat you
	local result = {
		Rows = {
			{ Stat = "Health", You = you.Health, Foe = foe.Health, Better = better(you.Health, foe.Health) },
			{ Stat = "Damage / hit", You = you.Hit, Foe = foe.Hit, Better = better(you.Hit, foe.Hit) },
			{ Stat = "Hits to win", You = yourHits, Foe = foeHits, Better = better(yourHits, foeHits, true) },
			{ Stat = "Speed", You = you.Speed, Foe = foe.Speed, Better = better(you.Speed, foe.Speed) },
		},
		FoeEdges = {},
		FoeWeak = {},
		YourEdges = {},
		YourWeak = {},
	}
	local function add(list, text)
		if #list < 4 then
			table.insert(list, text)
		end
	end

	-- Raw numbers.
	if better(yourHits, foeHits, true) == "Foe" then
		add(result.FoeEdges, string.format("Wins the trade: beats you in %d hits, you need %d", foeHits, yourHits))
	elseif better(yourHits, foeHits, true) == "You" then
		add(result.YourEdges, string.format("You win the trade: %d hits to beat it, it needs %d", yourHits, foeHits))
	end
	-- Healing, and whether you can cut it.
	if heals(foe) then
		if cutsHealing(you) then
			add(result.YourEdges, "Your gem cuts its healing (Grievous Wounds / Mortal Strike)")
		else
			add(result.FoeWeak, "Heals itself: burst it down between heals")
		end
	end
	if better(you.Health, foe.Health) == "Foe" then
		add(
			result.FoeEdges,
			string.format("Tougher: %d%% more health", math.floor((foe.Health / you.Health - 1) * 100))
		)
	elseif better(you.Health, foe.Health) == "You" then
		add(
			result.FoeWeak,
			string.format("Fragile: %d%% less health than you", math.floor((1 - foe.Health / you.Health) * 100))
		)
	end
	if better(you.Hit, foe.Hit) == "Foe" then
		add(result.YourWeak, "Its quick hits hit harder than yours: don't trade blow for blow")
	elseif better(you.Hit, foe.Hit) == "You" then
		add(result.YourEdges, "Your hits are heavier than its")
	end
	if better(you.Speed, foe.Speed) == "Foe" then
		add(result.FoeEdges, "Faster than you: you can't outrun it")
	elseif better(you.Speed, foe.Speed) == "You" then
		add(result.YourEdges, "You're faster: step out of its casts")
	end

	-- Elements and kits.
	if ELEMENT_EDGE[foe.Element] then
		add(result.FoeEdges, ELEMENT_EDGE[foe.Element])
	end
	if ELEMENT_EDGE[you.Element] then
		add(result.YourEdges, ELEMENT_EDGE[you.Element])
	end
	if has(foe.Surges, function(s)
		return s.Id == "CryoShield"
	end) then
		add(result.FoeWeak, "Cryo Shield halves your damage for 4s: dodge and wait it out")
	end
	local casts = names(foe.Surges, function(s)
		return s.Kind ~= "Self"
	end)
	if #casts > 0 then
		add(result.FoeWeak, "Telegraphs " .. table.concat(casts, ", ") .. ": dodge on the red cue")
	end
	-- How it fights, always true.
	add(result.FoeWeak, "Heavy attacks break its guard")
	add(result.FoeWeak, "Stuns and parries cancel its wind-ups")
	if heals(you) and not heals(foe) then
		add(result.YourEdges, "You can heal mid-fight; it can't")
	end
	if not ELEMENT_EDGE[you.Element] then
		add(result.YourWeak, "No weapon gem: your hits carry no element")
	end
	-- Elements against armor (ElementMatchup): what each side's weapon
	-- element does to the other's armor gems.
	local function armorLine(attack, armor, whose)
		local mult, tag = ElementMatchup.against(attack, armor)
		if not tag then
			return nil, nil
		end
		local percent = math.floor(mult * 100 + 0.5)
		local name = ELEMENT_NAME[attack] or attack
		if tag == "Resist" then
			return tag, string.format("%s armor resists %s: it lands at %d%%", whose, name, percent)
		end
		return tag, string.format("%s armor is weak to %s: it lands at %d%%", whose, name, percent)
	end
	local tag, line = armorLine(you.Element, foe.Armor, "Its")
	if tag == "Resist" then
		add(result.YourWeak, line)
	elseif tag == "Weak" then
		add(result.YourEdges, line)
	end
	tag, line = armorLine(foe.Element, you.Armor, "Your")
	if tag == "Resist" then
		add(result.FoeWeak, line)
	elseif tag == "Weak" then
		add(result.FoeEdges, line)
	end
	if #result.YourWeak == 0 then
		add(
			result.YourWeak,
			if foeHits <= 8 then "Low margin: it beats you in " .. foeHits .. " hits" else "Nothing glaring"
		)
	end
	return result
end

return Matchup

end)()
local CombatLogUI=(function()
--[[
	The combat log and fight details, like an RPG's.

	  Log      the last few lines, colour-coded:
	             Your Swing hits Kade Vorn for 24 (crit)
	             Kade Vorn's Heavy Blow hits you for 40 (31 blocked)
	             You are Burning (Thermal)
	  Details  this fight's breakdown: damage done (DPS, crit rate, biggest
	           hit, per ability) and damage taken (blocked, absorbed,
	           dodged, per ability), plus healing.

	Entries come from the server's "Log" events (see DamageLog); status lines
	come from the HUD's status bars. `format` and `tally` are pure, for tests.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local CombatLogUI = {}

local LINES = 6
local INK = Color3.fromRGB(12, 17, 28)
local TEXT = Color3.fromRGB(226, 232, 242)
local MUTED = Color3.fromRGB(150, 162, 182)
local GOLD = Color3.fromRGB(255, 196, 90)
local HURT = Color3.fromRGB(255, 110, 100)
local HEAL = Color3.fromRGB(110, 230, 140)

local function hex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function escape(value: string): string
	return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function paint(value: string, color: Color3, bold: boolean?): string
	local body = string.format('<font color="%s">%s</font>', hex(color), value)
	return if bold then "<b>" .. body .. "</b>" else body
end

local function abilityText(entry): string?
	if not entry.Ability then
		return nil
	end
	local color = GemConfig.ElementColors[entry.Element or ""] or GOLD
	return paint(escape(entry.Ability), color, true)
end

local function details(entry): string
	local notes = {}
	if entry.Crit then
		table.insert(notes, paint("critical", GOLD, true))
	end
	if entry.Blocked then
		table.insert(
			notes,
			string.format("%d %s", entry.Blocked, if entry.Kind == "Heal" then "prevented" else "blocked")
		)
	end
	if entry.Absorbed then
		table.insert(notes, string.format("%d absorbed", entry.Absorbed))
	end
	local text = if #notes > 0 then paint(" (" .. table.concat(notes, ", ") .. ")", MUTED) else ""
	if entry.Parried then
		text ..= paint(" PARRIED!", GOLD, true)
	end
	if entry.GuardBroken then
		text ..= paint(" GUARD BROKEN!", HURT, true)
	end
	return text
end

-- One log line (RichText).
function CombatLogUI.format(entry): string
	local who = escape(entry.Who or "Something")
	local ability = abilityText(entry)
	local amount = entry.Amount or 0
	if entry.Kind == "Status" then
		local effect = StatusEffects.Catalog[entry.Status]
		local color = if effect then effect.Color else MUTED
		local label = paint(StatusEffects.label(entry.Status), color, true)
		local value = if entry.Value
				and entry.Value > 0
				and effect
				and string.find(effect.Text, "%d%%", 1, true)
			then string.format(" %d%%", entry.Value)
			else ""
		if entry.Dir == "In" then
			return string.format("You are %s%s", label, value)
		end
		return string.format("%s is %s%s", who, label, value)
	elseif entry.Kind == "Dodge" then
		if entry.Dir == "In" then
			return string.format("You %s %s's %s", paint("dodged", HEAL, true), who, ability or "attack")
		end
		return string.format("%s %s your %s", who, paint("dodged", HURT, true), ability or "attack")
	elseif entry.Kind == "Combo" then
		-- An element combo (Shatter, Combustion, Superconduct).
		local combo = paint(string.upper(entry.Combo or "Combo") .. "!", GOLD, true)
		if entry.Dir == "In" then
			return string.format("%s %s on you", combo, if entry.Who then "by " .. who else "")
		end
		return string.format("%s on %s", combo, who)
	elseif entry.Kind == "Miss" then
		-- A blinded fighter's blow goes wide (Solar Flare).
		if entry.Dir == "In" then
			return string.format("%s's %s %s (blinded)", who, ability or "attack", paint("misses you", HEAL, true))
		end
		return string.format("Your %s %s (blinded)", ability or "attack", paint("misses", HURT, true))
	elseif entry.Kind == "Heal" then
		local healed = paint(tostring(amount), HEAL, true)
		if entry.Dir == "Foe" then
			return string.format("%s's %s heals it for %s%s", who, ability or "heal", healed, details(entry))
		end
		return string.format("Your %s heals you for %s%s", ability or "heal", healed, details(entry))
	elseif entry.Kind == "GuardBreak" then
		return string.format("You %s %s's guard!", paint("broke", GOLD, true), who)
	elseif entry.Kind == "Parried" then
		return string.format("%s %s your %s!", who, paint("parried", HURT, true), ability or "attack")
	elseif entry.Kind == "Cast" then
		return string.format("%s casts %s", who, ability or "a surge")
	elseif entry.Kind == "Kill" then
		return string.format("You defeated %s!", paint(who, GOLD, true))
	end
	-- A hit.
	if entry.Dir == "Out" then
		return string.format(
			"Your %s hits %s for %s%s",
			ability or "attack",
			who,
			paint(tostring(amount), if entry.Crit then GOLD else TEXT, true),
			details(entry)
		)
	end
	local from = if entry.Who and ability
		then string.format("%s's %s", who, ability)
		elseif ability then ability
		else who
	return string.format("%s hits you for %s%s", from, paint(tostring(amount), HURT, true), details(entry))
end

local function newSide()
	return { Total = 0, Hits = 0, Crits = 0, Biggest = 0, Blocked = 0, Absorbed = 0, Dodged = 0, ByAbility = {} }
end

function CombatLogUI.newStats(now: number)
	return { Started = now, Last = now, Done = newSide(), Taken = newSide(), Healed = 0, FoeHealed = 0 }
end

-- Adds an entry to a fight's numbers.
function CombatLogUI.tally(stats, entry, now: number)
	stats.Last = now
	local amount = entry.Amount or 0
	if entry.Kind == "Heal" then
		if entry.Dir == "Foe" then
			stats.FoeHealed += amount
		else
			stats.Healed += amount
		end
		return
	end
	local side = if entry.Dir == "Out" then stats.Done elseif entry.Dir == "In" then stats.Taken else nil
	if not side then
		return
	end
	if entry.Kind == "Dodge" then
		side.Dodged += 1
		return
	end
	if entry.Kind ~= "Hit" then
		return
	end
	local key = entry.Ability or "Attack"
	if entry.Dir == "In" and entry.Who and entry.Ability then
		key = entry.Who .. " · " .. entry.Ability
	end
	local row = side.ByAbility[key]
	if not row then
		row = { Name = key, Element = entry.Element, Total = 0, Hits = 0, Crits = 0, Biggest = 0 }
		side.ByAbility[key] = row
	end
	for _, bucket in { side, row } do
		bucket.Total += amount
		bucket.Hits += 1
		bucket.Crits += if entry.Crit then 1 else 0
		bucket.Biggest = math.max(bucket.Biggest, amount)
	end
	side.Blocked += entry.Blocked or 0
	side.Absorbed += entry.Absorbed or 0
end

-- Rows sorted biggest first, each with its share of the total.
function CombatLogUI.rows(side)
	local rows = {}
	for _, row in side.ByAbility do
		table.insert(rows, row)
	end
	table.sort(rows, function(a, b)
		return a.Total > b.Total
	end)
	for _, row in rows do
		row.Share = if side.Total > 0 then row.Total / side.Total else 0
	end
	return rows
end

-- UI --------------------------------------------------------------------------------------

local function make(class: string, props, parent: Instance?)
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function label(parent, text, size, color, font)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function panel(parent, size)
	local frame = make("Frame", {
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.18,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = size,
	}, parent)
	HudChrome.dress(frame, { Transparency = 0.25, Studs = false })
	return frame
end

local function button(parent, text, x)
	local b = make("TextButton", {
		BackgroundColor3 = Color3.fromRGB(28, 36, 54),
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, x, 0, 5),
		Size = UDim2.fromOffset(74, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = GOLD,
		Text = text,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
	return b
end

-- The panel. Call :add(entry), :reset() and :layout(viewport) from the HUD.
function CombatLogUI.new(parent: Instance)
	local self = { Entries = {}, Stats = CombatLogUI.newStats(os.clock()), Showing = "Log", Dirty = true }

	-- The log --------------------------------------------------------------
	local logPanel = panel(parent, UDim2.fromOffset(340, 34 + LINES * 16))
	local title = label(logPanel, "COMBAT LOG", 11, HudChrome.Gold, HudChrome.Title)
	title.Position, title.Size = UDim2.fromOffset(10, 4), UDim2.new(1, -100, 0, 20)
	local detailsButton = button(logPanel, "DETAILS  L", -6)
	local lineHolder = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 26),
		Size = UDim2.new(1, -20, 1, -30),
	}, logPanel)
	local lines = {}
	for i = 1, LINES do
		local line = label(lineHolder, "", 11, TEXT)
		line.Position, line.Size = UDim2.fromOffset(0, (i - 1) * 16), UDim2.new(1, 0, 0, 16)
		line.TextStrokeTransparency = 0.7
		lines[i] = line
	end
	local empty = label(lineHolder, "Hits, blocks and effects show up here.", 11, MUTED)
	empty.Size = UDim2.new(1, 0, 0, 16)

	-- The details -----------------------------------------------------------
	local detailPanel = panel(parent, UDim2.fromOffset(460, 316))
	detailPanel.Visible = false
	local detailTitle = label(detailPanel, "FIGHT DETAILS", 11, HudChrome.Gold, HudChrome.Title)
	detailTitle.Position, detailTitle.Size = UDim2.fromOffset(12, 4), UDim2.new(1, -180, 0, 20)
	local backButton = button(detailPanel, "LOG  L", -6)
	local resetButton = button(detailPanel, "RESET", -86)
	local function column(x, heading, color)
		local holder = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(x, if x == 0 then 12 else 6, 0, 28),
			Size = UDim2.new(0.5, -18, 1, -36),
		}, detailPanel)
		local head = label(holder, heading, 11, color, Enum.Font.GothamBold)
		head.Size = UDim2.new(1, 0, 0, 16)
		local total = label(holder, "", 20, TEXT, Enum.Font.GothamBlack)
		total.Position, total.Size = UDim2.fromOffset(0, 16), UDim2.new(1, 0, 0, 24)
		local facts = label(holder, "", 10, MUTED)
		facts.Position, facts.Size = UDim2.fromOffset(0, 40), UDim2.new(1, 0, 0, 30)
		facts.TextWrapped, facts.TextYAlignment = true, Enum.TextYAlignment.Top
		local rows = {}
		for i = 1, 8 do
			local y = 74 + (i - 1) * 25
			local name = label(holder, "", 10, TEXT, Enum.Font.GothamBold)
			name.Position, name.Size = UDim2.fromOffset(0, y), UDim2.new(1, -44, 0, 14)
			local value = label(holder, "", 10, TEXT, Enum.Font.GothamBold)
			value.Position, value.Size = UDim2.new(1, -44, 0, y), UDim2.fromOffset(44, 14)
			value.TextXAlignment = Enum.TextXAlignment.Right
			local track = make("Frame", {
				BackgroundColor3 = Color3.fromRGB(28, 34, 50),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, y + 15),
				Size = UDim2.new(1, 0, 0, 5),
			}, holder)
			make("UICorner", { CornerRadius = UDim.new(0, 2) }, track)
			local fill =
				make("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
			make("UICorner", { CornerRadius = UDim.new(0, 2) }, fill)
			rows[i] = { Name = name, Value = value, Track = track, Fill = fill }
		end
		return { Total = total, Facts = facts, Rows = rows }
	end
	local done = column(0, "DAMAGE DONE", GOLD)
	local taken = column(0.5, "DAMAGE TAKEN", HURT)
	local healing = label(detailPanel, "", 10, HEAL)
	healing.AnchorPoint, healing.Position, healing.Size =
		Vector2.new(0, 1), UDim2.new(0, 12, 1, -6), UDim2.new(1, -24, 0, 14)

	local function fillColumn(view, side, isDone, seconds)
		view.Total.Text = tostring(math.floor(side.Total + 0.5))
		if isDone then
			view.Facts.Text = string.format(
				"%.0f DPS  ·  %d hits  ·  %d%% crit  ·  best %d%s",
				side.Total / math.max(1, seconds),
				side.Hits,
				if side.Hits > 0 then math.floor(side.Crits / side.Hits * 100 + 0.5) else 0,
				side.Biggest,
				if side.Dodged > 0 then string.format("  ·  %d dodged by foe", side.Dodged) else ""
			)
		else
			view.Facts.Text = string.format(
				"%d hits  ·  %d blocked  ·  %d absorbed  ·  %d dodged  ·  worst %d",
				side.Hits,
				side.Blocked,
				side.Absorbed,
				side.Dodged,
				side.Biggest
			)
		end
		local rows = CombatLogUI.rows(side)
		for i, row in view.Rows do
			local data = rows[i]
			local show = data ~= nil
			row.Name.Visible, row.Value.Visible, row.Track.Visible = show, show, show
			if data then
				row.Name.Text = escape(data.Name)
				row.Name.TextColor3 = GemConfig.ElementColors[data.Element or ""] or TEXT
				row.Value.Text = string.format("%d", data.Total)
				row.Fill.Size = UDim2.fromScale(data.Share, 1)
			end
		end
	end

	local function refresh()
		self.Dirty = false
		for i, line in lines do
			local entry = self.Entries[#self.Entries - LINES + i]
			line.Text = if entry then entry.Text else ""
			line.TextTransparency = if entry then math.clamp((LINES - i) * 0.07, 0, 0.45) else 0
		end
		empty.Visible = #self.Entries == 0
		if detailPanel.Visible then
			local stats = self.Stats
			local seconds = stats.Last - stats.Started
			detailTitle.Text = string.format("FIGHT DETAILS  ·  %ds", math.floor(seconds + 0.5))
			fillColumn(done, stats.Done, true, seconds)
			fillColumn(taken, stats.Taken, false, seconds)
			healing.Text = string.format(
				"You healed %d  ·  Foe healed %d",
				math.floor(stats.Healed + 0.5),
				math.floor(stats.FoeHealed + 0.5)
			)
		end
	end

	function self.add(_, entry)
		local now = os.clock()
		entry.Text = CombatLogUI.format(entry)
		table.insert(self.Entries, entry)
		if #self.Entries > 60 then
			table.remove(self.Entries, 1)
		end
		CombatLogUI.tally(self.Stats, entry, now)
		self.Dirty = true
	end

	function self.reset()
		self.Stats = CombatLogUI.newStats(os.clock())
		self.Dirty = true
	end

	function self.toggle()
		local showDetails = not detailPanel.Visible
		detailPanel.Visible, logPanel.Visible = showDetails, not showDetails
		self.Dirty = true
	end

	function self.step(_, visible: boolean)
		if not visible then
			logPanel.Visible, detailPanel.Visible = false, false
			return
		end
		if not detailPanel.Visible then
			logPanel.Visible = true
		end
		if self.Dirty then
			refresh()
		end
	end

	detailsButton.Activated:Connect(self.toggle)
	backButton.Activated:Connect(self.toggle)
	resetButton.Activated:Connect(self.reset)
	self.LogPanel, self.DetailPanel = logPanel, detailPanel
	return self
end

return CombatLogUI

end)()
local HealthRegen=(function()
--[[
	Health recovery. Roblox puts a "Health" script in every player character
	that heals 1% a second, even mid-fight, while computer fighters (the
	Arena rival) never get it, so duels were one-sided. That script is
	removed and replaced by this rule, the same for everyone:

	  · no recovery during an Arena fight (a PvP or Training session)
	  · elsewhere, 1% of max health a second once 5 seconds have passed
	    without taking damage
]]
local Players = game:GetService("Players")

local HealthRegen = {}

local RATE = 0.01 -- of max health, per second
local DELAY = 5 -- seconds without damage before recovery starts
local STEP = 1

-- [humanoid] = { Health = last seen, HurtAt = os.clock() of the last drop }
local seen = setmetatable({}, { __mode = "k" })

-- Pure, for testing: how much to restore this step.
function HealthRegen.amount(health: number, maxHealth: number, inArena: boolean, sinceHurt: number, dt: number): number
	if inArena or health <= 0 or health >= maxHealth or sinceHurt < DELAY then
		return 0
	end
	return math.min(maxHealth - health, maxHealth * RATE * dt)
end

local function removeDefault(character: Model)
	local default = character:FindFirstChild("Health") or character:WaitForChild("Health", 10)
	if default and default:IsA("Script") then
		default:Destroy()
	end
end

local function step(dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local entry = seen[humanoid]
			if not entry then
				entry = { Health = humanoid.Health, HurtAt = -math.huge }
				seen[humanoid] = entry
			end
			if humanoid.Health < entry.Health then
				entry.HurtAt = now
			end
			local inArena = player:GetAttribute("CombatSession") ~= nil
			local heal = HealthRegen.amount(humanoid.Health, humanoid.MaxHealth, inArena, now - entry.HurtAt, dt)
			if heal > 0 then
				humanoid.Health += heal
			end
			entry.Health = humanoid.Health
		end
	end
end

function HealthRegen.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(removeDefault, character)
		end)
		if player.Character then
			task.spawn(removeDefault, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	task.spawn(function()
		while true do
			step(task.wait(STEP))
		end
	end)
end

return HealthRegen

end)()
local DungeonLoadout=(function()
-- Dungeon equipment uses the same catalog, armor budgets and gem effects as players.
local Loadout = {}
Loadout.Families = { Fire = "Juggernaut", Frost = "Juggernaut", Poison = "Prospector", Shock = "Skirmisher" }
Loadout.Labels = { "Common", "Uncommon", "Rare", "Ultra Rare", "Legendary" }
function Loadout.apply(c, spec, rarity, rng)
	rarity = math.clamp(math.floor(rarity), 1, 5)
	local family = Loadout.Families[spec.Element]
	local catalog = Classes.get("Warrior")
	c.GearRolls = c.GearRolls or {}
	c.ItemGems = c.ItemGems or {}
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		local selected = nil
		for _, item in catalog[kind] do
			if item.ArmorFamily == family and (slot == "Weapon" or item.RarityTier == rarity) then
				if slot ~= "Weapon" or ((item.Attack.Kind == "Shot") == (spec.Shape == "Crocodile")) then
					selected = item
					if slot ~= "Weapon" or item.RarityTier == rarity then
						break
					end
				end
			end
		end
		assert(selected, "Missing dungeon equipment: " .. family .. " / " .. slot)
		c[slot] = selected.Id
		c[slot .. "Quality"] = 1
		c.GearRolls[kind] = c.GearRolls[kind] or {}
		c.GearRolls[kind][selected.Id] = GearRolls.roll(rng, rarity, selected)
	end
	local keys = {}
	for _, slot in Slots.Order do
		table.insert(keys, slot)
	end
	for _, slot in Slots.SurgeOrder do
		table.insert(keys, slot)
	end
	local tierName = GemRoller.Rarities[rarity].Name
	local rules = GemRoller.ByRarity[tierName]
	for i, slot in keys do
		local gem = c[slot .. "Gem"] or { Id = "dungeon-" .. slot, Source = "DungeonNPC", Found = 0, CutMethod = "Natural" }
		gem.Tier = tierName
		gem.Element = spec.Element
		-- Disjoint metric bands make each difficulty a measurable upgrade.
		for _, metric in { "Size", "Clarity", "Cut" } do
			gem[metric] = rng:NextInteger(rarity * 2, math.min(10, rarity * 2 + 1))
		end
		gem.SurgeTier = rules.Tiers[1 + (i - 1) % #rules.Tiers]
		gem.SurgeRank = rules.Ranks[#rules.Ranks]
		gem.Surge = GemRoller.Surges[spec.Element][gem.SurgeTier]
		c[slot .. "Gem"] = gem
		if Slots.Definitions[slot] then
			c.ItemGems[slot] = c.ItemGems[slot] or {}
			c.ItemGems[slot][c[slot]] = gem
		end
	end
	return family
end
return Loadout

end)()

local function encode(v)
 if type(v)=='string' then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"' end
 if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
 if type(v)~='table' then return 'null' end
 local parts={}
 if #v>0 then for _,item in v do table.insert(parts,encode(item)) end; return '['..table.concat(parts,',')..']' end
 for k,item in v do if type(item)~='function' then table.insert(parts,encode(tostring(k))..':'..encode(item)) end end
 return '{'..table.concat(parts,',')..'}'
end
local abilities={}
for _,group in {'RigManeuvers','GemSurges'} do
 for _,id in Tech.Order[group] do
  local entry=table.clone(Tech.Catalog[id]);entry.id=id
  for el,ids in GemRoller.Surges do for tier,v in ids do if v==id or GemRoller.SurgeVariants[el][tier]==id then entry.Tier=tier end end end
  for tier,v in GemRoller.Resonance do if v==id or GemRoller.ResonanceVariants[tier]==id then entry.Tier=tier end end
  table.insert(abilities,entry)
 end
end
print(encode({Abilities=abilities,GemRules=GemRoller.ByRarity,Tree=Tree.Nodes,TreeOrder=Tree.Order,Armor=ArmorFamilies.Catalog,Weapons=Classes.get('Warrior').Weapons,Resources=Tech.Resources}))
