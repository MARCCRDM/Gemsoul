--[[
	Your mini kaiju in the Outpost (Shared.Kaiju has the rules; see
	docs/kaiju.md). Wild kaiju and moon bugs are KaijuWilds'.

	  Your kaiju   out beside you whenever you're in the Outpost (in
	               workspace.Kaiju). It follows you and takes on any creature
	               that comes near you (wild kaiju and moon bugs), fighting
	               as the Arena's duellist does (KaijuFighter): combos,
	               heavies, guard and parry, hops, and its Gemsoul's E. At 0
	               health it's knocked back into its Gemsoul, out again after
	               Kaiju.KnockoutSeconds.
	  A starter    everyone's first visit to the Outpost brings one: a
	               random kind in a random element.

	Requests (Shop.register):
	  "KaijuRecall"         back to you, out of the fight for Kaiju.RecallSeconds
	  "KaijuActive", id     which of yours is out
	  "KaijuFeed", { gemId }   feed it stones from your pouch (Kaiju.feedExp)

	Profile.Kaiju (Kaiju.roster) is in the profile snapshot. The one out
	carries, for every client: KaijuOwner (UserId), KaijuId, KaijuName,
	KaijuLevel, KaijuExp, KaijuExpNext, KaijuAbility, KaijuAbilityAt (server
	time of its last E), KaijuRecallUntil, and its fight (KaijuFighter's
	Action* and GuardUntil, HurtAt and BlockedAt, for CreatureAnimation);
	and the Player carries KaijuDownUntil (server time it's back) while it's
	knocked out.

	KaijuWilds asks here:
	  KaijuServer.pets()                     every kaiju out, by owner
	  KaijuServer.petOf(model)               the pet a model is
	  KaijuServer.hurt(pet, amount, element, status?, heavy?) -> outcome   a creature's blow
	  KaijuServer.reward(player, exp)        EXP for the kaiju out
	  KaijuServer.adopt(player, species, soul, level) -> record?   a tamed one
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuFight = require(ReplicatedStorage.Shared.KaijuFight)
local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Enemies = require(script.Parent.Enemies)
local Gems = require(script.Parent.Gems)
local KaijuAbilities = require(script.Parent.KaijuAbilities)
local KaijuFighter = require(script.Parent.KaijuFighter)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local KaijuServer = {}

export type Pet = {
	Owner: Player,
	Record: any,
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Element: string,
	Stats: any,
	Ability: string?,
	Target: any?, -- the Enemies record it's fighting
	Fighter: any, -- how it fights (KaijuFighter), with this as its body
	LastFight: number,
	RecallUntil: number,
	StunUntil: number,
	SlowUntil: number,
	Slow: number,
	BlindUntil: number,
	VulnerableUntil: number,
	-- Its guard and hops (KaijuFight.resolve).
	GuardUntil: number,
	GuardMult: number?,
	GuardRaisedAt: number?,
	ParrySpent: boolean?,
	GuardBrokenUntil: number,
	DodgeUntil: number,
	BlockedAt: number?,
	Dots: { { PerTick: number, Ticks: number, Element: string?, Next: number } },
	Fill: Frame,
	Label: TextLabel,
	-- Its owner standing about: where (its spot by them) and since when, and
	-- what it's doing meanwhile ({ Mood, Until, To? }: Kaiju.Roam.Pet).
	IdleSpot: Vector3?,
	IdleSince: number?,
	Plan: any?,
}

local pets: { [Player]: Pet } = {}
local rng = Random.new()
-- Knocked out: back at this os.clock(), by player.
local downUntil: { [Player]: number } = {}
-- A pet's health between its trips out (a recall or a walk to the Arena
-- doesn't heal it), by player and kaiju id.
local kept: { [Player]: { [string]: number } } = {}
local lastSwitch: { [Player]: number } = {}
local folder: Folder

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function aliveOf(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function fx(kind: string, ...)
	Remotes.CombatFx:FireAllClients(kind, ...)
end

-- Bodies -------------------------------------------------------------------------------------------

-- A kaiju's body on its feet: its model (Shared.KaijuModels) at `scale`,
-- with a Humanoid to walk it. (KaijuWilds builds the wild ones with this.)
function KaijuServer.body(speciesId: string, element: string, scale: number): (Model, Humanoid, BasePart)
	local model = KaijuModels.build(speciesId, element)
	KaijuModels.scale(model, scale)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutomaticScalingEnabled = false
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.HipHeight = model:GetAttribute("KaijuHipHeight") or 1
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model
	-- In a fight it faces its foe as it circles (KaijuFighter turns this on).
	local root = model.PrimaryPart :: BasePart
	local attachment = Instance.new("Attachment")
	attachment.Name = "FaceAttachment"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "FaceAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = 30
	align.MaxTorque = 1e6
	align.Enabled = false
	align.Parent = root
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model, humanoid, root
end

-- The ground under a point (or the point itself when there's none).
function KaijuServer.ground(point: Vector3, ignore: { Instance }?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = { folder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(skip, enemies)
	end
	for _, item in ignore or {} do
		table.insert(skip, item)
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(point + Vector3.new(0, 30, 0), Vector3.new(0, -120, 0), params)
	return if hit then hit.Position else point
end

-- Stands a body on the ground at `point`, facing `look`.
function KaijuServer.place(model: Model, point: Vector3, look: Vector3?)
	local root = model.PrimaryPart :: BasePart
	local floor = KaijuServer.ground(point)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local up = (if humanoid then humanoid.HipHeight else 1) + root.Size.Y / 2
	local at = floor + Vector3.new(0, up, 0)
	local facing = if look and flat(look - at).Magnitude > 0.1
		then Vector3.new(look.X, at.Y, look.Z)
		else at + Vector3.new(0, 0, -1)
	model:PivotTo(CFrame.lookAt(at, facing))
end

-- Its nameplate: owner, name and level over a health bar.
local function nameplate(pet: Pet)
	local head = pet.Model:FindFirstChild("Head") :: BasePart?
	local height = if head then head.Position.Y - pet.Root.Position.Y + head.Size.Y / 2 + 1.2 else 3
	local board = Instance.new("BillboardGui")
	board.Name = "KaijuPlate"
	board.Size = UDim2.fromOffset(140, 30)
	board.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	board.MaxDistance = 70
	board.Parent = pet.Root
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = GemConfig.ElementColors[pet.Element] or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = board
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
	back.BorderSizePixel = 0
	back.Position = UDim2.fromOffset(25, 18)
	back.Size = UDim2.new(1, -50, 0, 6)
	back.Parent = board
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(96, 214, 120)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	pet.Fill, pet.Label = fill, label
end

local function refreshPlate(pet: Pet)
	local h = pet.Humanoid
	pet.Fill.Size = UDim2.fromScale(math.clamp(h.Health / math.max(1, h.MaxHealth), 0, 1), 1)
	pet.Label.Text = string.format("%s · Lv %d", Kaiju.title(pet.Record), pet.Record.Level)
end

-- Stats and the attributes clients read, after a level or a new kaiju.
local function refresh(pet: Pet)
	local record = pet.Record
	local stats = Kaiju.stats(record.Species, record.Level, record.Soul and record.Soul.Tier)
	local h = pet.Humanoid
	local share = h.Health / math.max(1, h.MaxHealth)
	pet.Stats = stats
	KaijuFighter.restat(pet.Fighter, stats, Kaiju.Scale.Pet)
	h.MaxHealth = stats.Health
	h.Health = math.max(1, math.floor(stats.Health * share + 0.5))
	local model = pet.Model
	-- Its Q and R wake as it levels (Kaiju.MoveLevels).
	local moves = Kaiju.moves(record.Soul, record.Level)
	KaijuFighter.setMoves(pet.Fighter, moves)
	model:SetAttribute("KaijuQ", moves.Q)
	model:SetAttribute("KaijuR", moves.R)
	model:SetAttribute("KaijuLevel", record.Level)
	model:SetAttribute("KaijuExp", record.Exp or 0)
	local next = Kaiju.expToNext(record.Level)
	model:SetAttribute("KaijuExpNext", if next == math.huge then 0 else next)
	refreshPlate(pet)
end

-- Out and back ------------------------------------------------------------------------------------

local function despawn(player: Player)
	local pet = pets[player]
	if not pet then
		return
	end
	pets[player] = nil
	if pet.Humanoid.Health > 0 then
		kept[player] = kept[player] or {}
		kept[player][pet.Record.Id] = pet.Humanoid.Health
	end
	KaijuFighter.forget(pet.Fighter)
	pet.Model:Destroy()
end

local function spawnPet(player: Player, record): Pet?
	local root = rootOf(player)
	if not root then
		return nil
	end
	local model, humanoid, petRoot = KaijuServer.body(record.Species, record.Element, Kaiju.Scale.Pet)
	model.Name = player.Name .. "Kaiju"
	model:SetAttribute("KaijuOwner", player.UserId)
	model:SetAttribute("KaijuId", record.Id)
	model:SetAttribute("KaijuName", Kaiju.title(record))
	local ability = Kaiju.ability(record.Soul)
	model:SetAttribute("KaijuAbility", ability)
	local pet: Pet = {
		Owner = player,
		Record = record,
		Model = model,
		Root = petRoot,
		Humanoid = humanoid,
		Element = record.Element,
		Stats = Kaiju.stats(record.Species, record.Level, record.Soul and record.Soul.Tier),
		Ability = ability,
		Target = nil,
		Fighter = nil,
		LastFight = 0,
		RecallUntil = 0,
		StunUntil = 0,
		SlowUntil = 0,
		Slow = 0,
		BlindUntil = 0,
		VulnerableUntil = 0,
		GuardUntil = 0,
		GuardBrokenUntil = 0,
		DodgeUntil = 0,
		Dots = {},
		Fill = nil :: any,
		Label = nil :: any,
	}
	pet.Fighter = KaijuFighter.new({
		Model = model,
		Root = petRoot,
		Humanoid = humanoid,
		Species = record.Species,
		Element = record.Element,
		Scale = Kaiju.Scale.Pet,
		Body = pet,
		Stats = pet.Stats,
		Ability = ability,
		Moves = Kaiju.moves(record.Soul, record.Level),
		Strike = function(foe, amount: number, heavy: boolean, _name: string): string
			return if foe.Enemy then KaijuServer.strike(pet, foe.Enemy, amount, nil, heavy) else "Missed"
		end,
		Caster = function()
			return KaijuServer.caster(pet)
		end,
	})
	humanoid.MaxHealth = pet.Stats.Health
	local health = kept[player] and kept[player][record.Id]
	humanoid.Health = math.clamp(health or pet.Stats.Health, 1, pet.Stats.Health)
	nameplate(pet)
	refresh(pet)
	local side = root.CFrame.RightVector * 3 - root.CFrame.LookVector * 3
	KaijuServer.place(model, root.Position + side, root.Position + root.CFrame.LookVector * 10)
	model.Parent = folder
	pcall(petRoot.SetNetworkOwner, petRoot, nil)
	pets[player] = pet
	return pet
end

-- Can `player` have their kaiju out right now? In the Outpost, on their
-- feet, not in a fight, a match, a dungeon or an expedition.
local function canBeOut(player: Player): boolean
	return player:GetAttribute("Outpost") == true
		and player:GetAttribute("CombatSession") == nil
		and player:GetAttribute("MatchId") == nil
		and player:GetAttribute("DungeonId") == nil
		and player:GetAttribute("Expedition") == nil
		and aliveOf(player)
end

-- Everyone's first kaiju.
local function grantStarter(player: Player)
	local profile = PlayerData.get(player)
	if not profile or (profile :: any).KaijuStarter then
		return
	end
	local roster = Kaiju.roster(profile)
	if Kaiju.count(roster) > 0 then
		(profile :: any).KaijuStarter = true
		return
	end
	local rng = Gems.random()
	local species = Kaiju.Order[rng:NextInteger(1, #Kaiju.Order)]
	local element = Kaiju.Elements[rng:NextInteger(1, #Kaiju.Elements)]
	local soul = Kaiju.rollSoul(rng, element, { Id = PlayerData.newGemId(), Time = os.time(), Species = species })
	local record = Kaiju.add(roster, species, soul, Kaiju.StarterLevel);
	(profile :: any).KaijuStarter = true
	PlayerData.sync(player)
	if record then
		Remotes.Notify:FireClient(
			player,
			string.format("Meet your kaiju: %s! It fights beside you in the Outpost.", Kaiju.title(record))
		)
	end
end

-- Puts the right kaiju out (or away) for `player`.
local function upkeep(player: Player, now: number)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if player:GetAttribute("Outpost") == true then
		grantStarter(player)
	end
	local record = Kaiju.active(profile.Kaiju)
	local down = downUntil[player]
	if down and now >= down then
		downUntil[player] = nil
		player:SetAttribute("KaijuDownUntil", nil)
		down = nil
	end
	local pet = pets[player]
	local want = record ~= nil and down == nil and canBeOut(player)
	if pet and (not want or pet.Record ~= record or not pet.Model.Parent) then
		despawn(player)
		pet = nil
	end
	if want and not pet then
		spawnPet(player, record)
	end
end

-- Fighting --------------------------------------------------------------------------------------

-- Whether `owner`'s kaiju may fight this creature: a moon bug always; a
-- wild kaiju only once `owner` has started on it (KaijuWilds keeps who has,
-- in Engaged).
local function fair(owner: Player, enemy): boolean
	-- (Not one held by a tame: it's being caught, not fought.)
	if enemy.Model and enemy.Model:GetAttribute("KaijuTameBy") ~= nil then
		return false
	end
	local engaged = (enemy :: any).Engaged
	return engaged == nil or engaged[owner] ~= nil
end

-- Creatures its foes are (KaijuWilds marks them OutpostCreature), inside a
-- circle: those `owner`'s kaiju may fight.
local function creaturesNear(center: Vector3, radius: number, owner: Player): { any }
	local list = {}
	for _, enemy in Enemies.all() do
		if
			(enemy :: any).OutpostCreature
			and fair(owner, enemy)
			and (enemy.Root.Position - center).Magnitude <= radius
		then
			table.insert(list, { Root = enemy.Root, Enemy = enemy })
		end
	end
	return list
end

-- What a hit of its element leaves on a creature.
local function afflict(enemy, status: string?, amount: number, element: string)
	local color = GemConfig.ElementColors[element]
	if status == "Burn" then
		Enemies.addDot(enemy, amount * 0.25, 4, nil, color, "Burning")
	elseif status == "Poison" then
		Enemies.addDot(enemy, amount * 0.3, 5, nil, color, "Poisoned")
	elseif status == "Slow" then
		Enemies.addStatus(enemy, "Slow", 0.4, 2)
	elseif status == "Freeze" then
		Enemies.addStatus(enemy, "Stun", 1, 1.2);
		(enemy :: any).StunKind = "Frozen"
	elseif status == "Stun" then
		Enemies.addStatus(enemy, "Stun", 1, 0.6);
		(enemy :: any).StunKind = "Shocked"
	elseif status == "Blind" then
		Enemies.addStatus(enemy, "Blind", 0.5, 3)
	elseif status == "Vulnerable" then
		Enemies.addStatus(enemy, "Vulnerable", 0.15, 6)
	end
end

-- A blow (or an E) from `pet` landing on a creature. Credited to its owner
-- (for the kill's rewards), without the owner's own hit sounds. `heavy` is
-- true or false for its blows (a wild kaiju's guard meets them as a
-- player's), nil for its E. Returns how it landed (KaijuFight.resolve's
-- words; "Parried" leaves it reeling).
local function strike(pet: Pet, enemy, amount: number, status: string?, heavy: boolean?): string
	if not enemy.Alive then
		return "Missed"
	end
	local now = os.clock()
	pet.LastFight = now
	-- A light blow just as a wild kaiju braces is parried (Enemies.damage
	-- parries only a player's swings).
	if KaijuFight.parries(enemy, heavy, now) then
		fx("BlockSpark", enemy.Root.Position, false)
		enemy.Model:SetAttribute("BlockedAt", serverNow())
		return "Parried"
	end
	local outcome = if enemy.DodgeUntil and now < enemy.DodgeUntil
		then "Dodged"
		elseif KaijuFight.guarding(enemy, now) then (if heavy == true then "Broken" else "Guarded")
		else "Hit"
	local before = enemy.Humanoid.Health
	local color = GemConfig.ElementColors[pet.Element]
	Enemies.damage(enemy, amount, nil, false, color, heavy, pet.Element)
	local e = enemy :: any
	e.KaijuCredit = e.KaijuCredit or {}
	e.KaijuCredit[pet.Owner] = (e.KaijuCredit[pet.Owner] or 0) + math.max(0, before - enemy.Humanoid.Health)
	e.LastPet, e.LastPetAt = pet, now
	if enemy.Alive and (outcome == "Hit" or outcome == "Broken") then
		afflict(enemy, status, amount, pet.Element)
	end
	return outcome
end
KaijuServer.strike = strike

-- Its caster for its moves (KaijuAbilities.cast): its foes are the
-- creatures near; its R's shell sits on the pet.
function KaijuServer.caster(pet: Pet)
	local soul = pet.Record.Soul
	return {
		Model = pet.Model,
		Root = pet.Root,
		Element = pet.Element,
		Ability = pet.Ability,
		Damage = Kaiju.abilityDamage(pet.Stats.Damage, soul, pet.Ability),
		DamageOf = function(id: string): number
			return Kaiju.abilityDamage(pet.Stats.Damage, soul, id)
		end,
		Body = pet,
		Humanoid = pet.Humanoid,
		Foes = function(center: Vector3, radius: number)
			return creaturesNear(center, radius, pet.Owner)
		end,
		Hit = function(victim, amount: number, status: string?)
			strike(pet, victim.Enemy, amount, status, nil)
		end,
		Alive = function(): boolean
			return pet.Model.Parent ~= nil and pet.Humanoid.Health > 0
		end,
	}
end

local function knockOut(pet: Pet)
	local player = pet.Owner
	fx("TriadBreak", pet.Root.Position, 4, pet.Element)
	if kept[player] then
		kept[player][pet.Record.Id] = nil
	end
	pets[player] = nil
	KaijuFighter.forget(pet.Fighter)
	pet.Model:Destroy()
	downUntil[player] = os.clock() + Kaiju.KnockoutSeconds
	player:SetAttribute("KaijuDownUntil", serverNow() + Kaiju.KnockoutSeconds)
	Remotes.Notify:FireClient(
		player,
		string.format(
			"%s was knocked out: back in its Gemsoul for %ds.",
			Kaiju.title(pet.Record),
			Kaiju.KnockoutSeconds
		)
	)
end

-- A creature's blow (or E) on a pet: its guard or a hop first
-- (KaijuFight.resolve: `heavy` true or false for blows, nil for an E),
-- then its element against the pet's and its kind's Guard, then what the
-- element leaves. Returns how it landed ("Parried" leaves the attacker
-- reeling).
function KaijuServer.hurt(pet: Pet, amount: number, element: string?, status: string?, heavy: boolean?): string
	if not pet.Model.Parent or pet.Humanoid.Health <= 0 then
		return "Missed"
	end
	local now = os.clock()
	pet.LastFight = now
	local model = pet.Model
	local outcome, share = KaijuFight.resolve(pet, heavy, now)
	if outcome == "Dodged" then
		return outcome
	elseif outcome == "Parried" then
		fx("BlockSpark", pet.Root.Position, false)
		model:SetAttribute("BlockedAt", serverNow())
		return outcome
	elseif outcome == "Broken" then
		fx("BlockSpark", pet.Root.Position, true)
		model:SetAttribute("GuardUntil", 0)
	elseif outcome == "Guarded" then
		fx("BlockSpark", pet.Root.Position, false)
		model:SetAttribute("BlockedAt", serverNow())
	end
	local mult, tag = Kaiju.taken(pet.Record.Species, pet.Element, element)
	if now < pet.VulnerableUntil then
		mult *= 1.15
	end
	-- Its R's shell or ward takes its share first.
	local through = KaijuAbilities.soak(pet, amount * share * mult)
	if through <= 0 then
		fx("BlockSpark", pet.Root.Position, false)
		return outcome
	end
	local dealt = math.max(1, math.floor(through + 0.5))
	local h = pet.Humanoid
	h.Health = math.max(0, h.Health - dealt)
	fx(
		"Damage",
		pet.Root.Position + Vector3.new(0, 2, 0),
		dealt,
		false,
		if element then GemConfig.ElementColors[element] else nil,
		tag
	)
	if h.Health <= 0 then
		knockOut(pet)
		return outcome
	end
	if outcome == "Guarded" then
		refreshPlate(pet)
		return outcome -- (a guard keeps out what the element leaves)
	end
	-- (It flinches: CreatureAnimation.)
	model:SetAttribute("HurtAt", serverNow())
	model:SetAttribute("HurtSide", if math.random() < 0.5 then -1 else 1)
	if status == "Burn" or status == "Poison" then
		table.insert(pet.Dots, { PerTick = amount * 0.06, Ticks = 5, Element = element, Next = now + 1 })
	elseif status == "Slow" then
		pet.Slow, pet.SlowUntil = 0.4, now + 2
	elseif status == "Freeze" then
		pet.StunUntil = math.max(pet.StunUntil, now + 1.2)
	elseif status == "Stun" then
		pet.StunUntil = math.max(pet.StunUntil, now + 0.6)
	elseif status == "Blind" then
		pet.BlindUntil = now + 3
	elseif status == "Vulnerable" then
		pet.VulnerableUntil = now + 6
	end
	refreshPlate(pet)
	return outcome
end

-- Who it fights: what it's already fighting, if that's still near its
-- owner; else a creature that's after it or its owner; else the nearest
-- creature near its owner. (A wild kaiju only once its owner has started on
-- it.)
local function chooseTarget(pet: Pet, ownerRoot: BasePart)
	local engage = Kaiju.Follow.Engage
	local current = pet.Target
	if
		current
		and current.Alive
		and fair(pet.Owner, current)
		and (current.Root.Position - ownerRoot.Position).Magnitude <= engage + 12
	then
		return current
	end
	local best, bestScore = nil, math.huge
	for _, entry in creaturesNear(ownerRoot.Position, engage, pet.Owner) do
		local enemy = entry.Enemy
		local distance = (enemy.Root.Position - pet.Root.Position).Magnitude
		local after = (enemy :: any).Foe
		-- (One already after it or its owner comes first.)
		local score = distance - (if after == pet or after == pet.Owner then 100 else 0)
		if score < bestScore then
			best, bestScore = enemy, score
		end
	end
	return best
end

-- What it's doing, for every client to pose (KaijuMood, KaijuMoodAt).
local function setMood(pet: Pet, mood: string?)
	local shown = if mood == "Walk" then nil else mood
	if pet.Model:GetAttribute("KaijuMood") ~= shown then
		pet.Model:SetAttribute("KaijuMood", shown)
		pet.Model:SetAttribute("KaijuMoodAt", workspace:GetServerTimeNow())
	end
end

-- Its day stops (a fight, its owner moving on).
local function settle(pet: Pet)
	if pet.Plan then
		pet.Plan = nil
		setMood(pet, nil)
	end
end

-- With its owner standing about a while it potters round them: sniffing,
-- looking about, lying down (Kaiju.Roam.Pet). Returns whether it is.
local function potter(pet: Pet, spot: Vector3, now: number): boolean
	local rules = Kaiju.Roam.Pet
	if not pet.IdleSpot or flat(spot - pet.IdleSpot).Magnitude > 4 then
		pet.IdleSpot, pet.IdleSince = spot, now -- (they moved: up and after them)
		settle(pet)
		return false
	end
	if now - (pet.IdleSince or now) < rules.After then
		return false
	end
	local plan = pet.Plan
	if not plan and flat(spot - pet.Root.Position).Magnitude > rules.Range + 2 then
		return false -- (beside them first)
	end
	local h = pet.Humanoid
	if not plan or now >= plan.Until then
		local mood = Kaiju.mood(rules.Moods, rng:NextNumber())
		local times = rules.Times[mood]
		plan = { Mood = mood, Until = now + rng:NextNumber(times[1], times[2]) }
		if mood == "Walk" then
			local a = rng:NextNumber(0, math.pi * 2)
			plan.To = pet.IdleSpot + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(1.5, rules.Range)
		end
		pet.Plan = plan
		setMood(pet, mood)
	end
	if plan.To and flat(plan.To - pet.Root.Position).Magnitude > 1.5 then
		h.WalkSpeed = pet.Stats.Speed * 0.5
		h:MoveTo(plan.To)
	else
		h:MoveTo(pet.Root.Position)
	end
	return true
end

local function follow(pet: Pet, ownerRoot: BasePart, recalled: boolean, now: number)
	local h = pet.Humanoid
	local gap = Kaiju.Follow.Gap
	local offset = ownerRoot.CFrame.RightVector * 3 - ownerRoot.CFrame.LookVector * gap
	local spot = ownerRoot.Position + offset
	if not recalled and potter(pet, spot, now) then
		return
	end
	if recalled then
		settle(pet)
	end
	h.WalkSpeed = math.max(pet.Stats.Speed, 22) * (if recalled then 1.4 else 1)
	if flat(spot - pet.Root.Position).Magnitude > 2 then
		h:MoveTo(spot)
	else
		h:MoveTo(pet.Root.Position)
	end
end

local function think(pet: Pet, now: number, dt: number)
	local owner = pet.Owner
	local ownerRoot = rootOf(owner)
	if not ownerRoot or not pet.Model.Parent then
		return
	end
	local h = pet.Humanoid
	-- Burns and poisons on it, a tick a second.
	for i = #pet.Dots, 1, -1 do
		local dot = pet.Dots[i]
		if now >= dot.Next then
			dot.Next += 1
			dot.Ticks -= 1
			if dot.Ticks <= 0 then
				table.remove(pet.Dots, i)
			end
			KaijuServer.hurt(pet, dot.PerTick, dot.Element, nil)
			if not pet.Model.Parent then
				return
			end
		end
	end
	-- Out of a fight a while: it heals.
	if now - pet.LastFight > 4 and h.Health < h.MaxHealth then
		h.Health = math.min(h.MaxHealth, h.Health + h.MaxHealth * Kaiju.Regen * dt)
		refreshPlate(pet)
	end
	local away = flat(ownerRoot.Position - pet.Root.Position).Magnitude
	if away > Kaiju.Follow.Teleport then
		pet.Target = nil
		KaijuFighter.calm(pet.Fighter)
		local side = ownerRoot.CFrame.RightVector * 3 - ownerRoot.CFrame.LookVector * 3
		KaijuServer.place(pet.Model, ownerRoot.Position + side, ownerRoot.Position)
		return
	end
	local recalled = now < pet.RecallUntil
	local target = if recalled or away > Kaiju.Follow.Leash then nil else chooseTarget(pet, ownerRoot)
	pet.Target = target
	if target then
		-- It fights as a duellist does (KaijuFighter: it reels when stunned).
		pet.LastFight = now
		settle(pet)
		pet.IdleSpot = nil
		KaijuFighter.step(pet.Fighter, { Root = target.Root, Enemy = target }, now)
		return
	end
	KaijuFighter.calm(pet.Fighter)
	if now < pet.StunUntil then
		h:MoveTo(pet.Root.Position)
	else
		follow(pet, ownerRoot, recalled, now)
	end
end

-- For KaijuWilds ---------------------------------------------------------------------------------------

function KaijuServer.pets(): { [Player]: Pet }
	return pets
end

function KaijuServer.petOf(model: Instance?): Pet?
	for _, pet in pets do
		if pet.Model == model then
			return pet
		end
	end
	return nil
end

-- Can a creature go after this pet right now? (Not while it's recalled.)
function KaijuServer.targetable(pet: Pet): boolean
	return pet.Model.Parent ~= nil and pet.Humanoid.Health > 0 and os.clock() >= pet.RecallUntil
end

-- EXP for `player`'s kaiju out (a kill, a moon bug). Its level and EXP show
-- on its model at once; the profile's copy reaches the client on a level-up.
function KaijuServer.reward(player: Player, exp: number)
	local profile = PlayerData.get(player)
	local record = profile and Kaiju.active(profile.Kaiju)
	if not record or exp <= 0 then
		return
	end
	local gained = Kaiju.addExp(record, exp)
	local pet = pets[player]
	if pet and pet.Record == record then
		refresh(pet)
	end
	if gained > 0 then
		PlayerData.sync(player)
		Remotes.Notify:FireClient(player, string.format("%s reached level %d!", Kaiju.title(record), record.Level))
		if pet then
			fx("TriadBreak", pet.Root.Position, 5, pet.Element)
		end
	end
end

-- A rock `player` broke with their kaiju out beside them (OutpostServer's
-- onRockMined): a little EXP for it (Kaiju.mineExp). Nothing while it's
-- down or put away.
function KaijuServer.mined(player: Player, size: string)
	local pet = pets[player]
	if pet and pet.Humanoid.Health > 0 then
		KaijuServer.reward(player, Kaiju.mineExp(size))
	end
end

-- A tamed kaiju joins `player`. Returns its record, or nil if they have
-- room for no more.
function KaijuServer.adopt(player: Player, speciesId: string, soul, level: number)
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	local record = Kaiju.add(Kaiju.roster(profile), speciesId, soul, level)
	if record then
		PlayerData.sync(player)
	end
	return record
end

-- Requests -----------------------------------------------------------------------------------------

local function recall(player: Player)
	local pet = pets[player]
	if not pet then
		return reply(false, "Your kaiju isn't out.")
	end
	local now = os.clock()
	pet.RecallUntil = now + Kaiju.RecallSeconds
	pet.Target = nil
	pet.Model:SetAttribute("KaijuRecallUntil", serverNow() + Kaiju.RecallSeconds)
	return reply(true, "")
end

local function setActive(player: Player, id: any)
	local profile = PlayerData.get(player)
	local roster = profile and Kaiju.roster(profile)
	if not roster or type(id) ~= "string" or not roster.List[id] then
		return reply(false, "That kaiju isn't yours.")
	end
	if roster.Active == id then
		return reply(true, "")
	end
	local now = os.clock()
	if lastSwitch[player] and now - lastSwitch[player] < 3 then
		return reply(false, "One moment.")
	end
	local pet = pets[player]
	if pet and now - pet.LastFight < 3 then
		return reply(false, "Not in the middle of a fight.")
	end
	lastSwitch[player] = now
	roster.Active = id
	despawn(player)
	PlayerData.sync(player)
	upkeep(player, now)
	return reply(true, string.format("%s is out.", Kaiju.title(roster.List[id])))
end

local MAX_FEED = Kaiju.FeedBatch

local function feed(player: Player, ids: any)
	local profile = PlayerData.get(player)
	local record = profile and Kaiju.active(profile.Kaiju)
	if not record then
		return reply(false, "You have no kaiju out to feed.")
	end
	if type(ids) ~= "table" or #ids == 0 or #ids > MAX_FEED then
		return reply(false, string.format("Pick 1 to %d stones.", MAX_FEED))
	end
	if record.Level >= Kaiju.MaxLevel then
		return reply(false, string.format("%s is at its highest level.", Kaiju.title(record)))
	end
	local total, eaten, levels = 0, 0, 0
	local seen = {}
	for _, id in ids do
		if type(id) == "string" and not seen[id] then
			seen[id] = true
			local gem = PlayerData.findGem(player, id)
			if gem and record.Level < Kaiju.MaxLevel then
				local exp = Kaiju.feedExp(gem, record)
				PlayerData.removeGem(player, id)
				levels += Kaiju.addExp(record, exp)
				total += exp
				eaten += 1
			end
		end
	end
	if eaten == 0 then
		return reply(false, "Those stones aren't in your pouch.")
	end
	local pet = pets[player]
	if pet and pet.Record == record then
		refresh(pet)
		fx("TriadBreak", pet.Root.Position, 3, pet.Element)
	end
	PlayerData.sync(player)
	local message =
		string.format("%s ate %d stone%s: +%d EXP", Kaiju.title(record), eaten, if eaten == 1 then "" else "s", total)
	if levels > 0 then
		message ..= string.format(" · level %d!", record.Level)
	end
	return reply(true, message, { Exp = total, Levels = levels, Level = record.Level })
end

local function left(player: Player)
	despawn(player)
	pets[player], downUntil[player], kept[player], lastSwitch[player] = nil, nil, nil, nil
end

function KaijuServer.start()
	folder = Instance.new("Folder")
	folder.Name = "Kaiju"
	folder.Parent = workspace
	Shop.register("KaijuRecall", recall)
	Shop.register("KaijuActive", setActive)
	Shop.register("KaijuFeed", feed)
	Players.PlayerRemoving:Connect(left)
	local thinkTimer, upkeepTimer = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		thinkTimer += dt
		upkeepTimer += dt
		local now = os.clock()
		if upkeepTimer >= 0.5 then
			upkeepTimer = 0
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(upkeep, player, now)
				if not ok then
					warn("[Kaiju] upkeep:", err)
				end
			end
		end
		if thinkTimer >= 0.15 then
			local step = thinkTimer
			thinkTimer = 0
			for _, pet in pets do
				local ok, err = pcall(think, pet, now, step)
				if not ok then
					warn("[Kaiju] think:", err)
				end
			end
		end
	end)
end

-- For tests.
KaijuServer._upkeep, KaijuServer._think, KaijuServer._feed = upkeep, think, feed
KaijuServer._recall, KaijuServer._setActive, KaijuServer._grantStarter = recall, setActive, grantStarter
KaijuServer._despawn, KaijuServer._fair = despawn, fair

return KaijuServer
