--[[
	Your mini kaiju in the Outpost (Shared.Kaiju has the rules; see
	docs/kaiju.md). Wild kaiju and moon bugs are KaijuWilds'.

	  Your support a fourth kaiju out, a support kind (Kaiju.SupportRole),
	               in the middle of the team out ahead of you
	               (Kaiju.SupportSlot): it takes no share
	               of a fight; in one (in danger) it mends you and the
	               team when one of you is hurt (pulse, Kaiju.SupportPulse);
	               out of one, healing is the gems'. Everyone is given
	               Kaiju.StarterSupport once (giveSupport: with the starter
	               roll, or on an older save's next visit).
	  Your team    up to three kaiju out with you whenever you're in the
	               Outpost (in workspace.Kaiju), each at its own spot,
	               leading the way out in front of you (Kaiju.TeamSpots:
	               one ahead, two side by side behind it), where your camera
	               sees them (your client's Remotes.KaijuView: Kaiju.leadSpot).
	               They follow you (jumping after you
	               when you jump, one after another: Kaiju.Hop) and take on any
	               creature that comes near you (wild kaiju and moon bugs),
	               fighting as the Arena's duellist does (KaijuFighter):
	               combos, heavies, guard and parry, hops, and their
	               Gemsouls' moves. They fight as a team (Shared.Squad): the
	               creatures shared out (each its own while there are
	               enough, the rest waiting their turn), one they share
	               flanked from either side, and never on top of each other.
	               You first: one on you or your support brings them back
	               from any fight elsewhere, and none chases a foe off past
	               Kaiju.Follow.Chase from where its fight began (teamPlan).
	               Its health is kept (record.Health) and never comes
	               back on its own; gems heal it (KaijuInfuse), only out of
	               danger (Kaiju.Danger: the player's KaijuDanger attribute
	               says when they're in it). At 0 one is knocked back into
	               its Gemsoul (record.Down) and stays there, its place in
	               the team empty, until its revive time is up
	               (record.DownUntil, Kaiju.reviveSeconds), or at once for
	               Robux or a Revive coupon (KaijuServer.reviveAll).
	  Call back    the whole team put away in its Gemsouls (roster.Away:
	               Kaiju.away), none of it out till you deploy it again,
	               at once, in a fight or out of one; each kaiju comes back
	               out with its moves' waits as they were (`waits`).
	               Getting into the game, Team 1 is the one out (once a
	               visit). Every kaiju that comes out plays its deploy for
	               everyone (KaijuOutAt on it: KaijuHud plays yours again
	               once your loading screen's gone).
	  Auto heal    switched on (Kaiju.AutoHeal, kept as roster.AutoHeal),
	               your spare Commons heal your team by themselves, out of
	               danger, never a gem wasted. Quiet, but for running out
	               of Commons.
	  The roll     everyone starts with Kaiju.StarterTeam kaiju, rolled (the
	               intro's roll, or one full roll in the Outpost for a
	               player who took an older one: Kaiju.RollVersion):
	               prepared here and saved, so a retry never rerolls, then
	               claimed, the ones rolled becoming the team; a roll left
	               unclaimed is given after Kaiju.RollGrace seconds in the
	               Outpost.

	Requests (Shop.register):
	  "KaijuRecall"         the team back to you, out of the fight for Kaiju.RecallSeconds
	  "KaijuTeam", { id }   which of yours are out (the first leads)
	  "KaijuActive", id     this one out, leading (in the lead's place if it wasn't out)
	  "KaijuSupport", id    this support kind in the support slot (Kaiju.supportId)
	  "KaijuInfuse", { gemId }, id?   heals one of yours with gems from your
	                        pouch (the lead if no id; Kaiju.infusePlan: only
	                        the gems it needs are used, and never a Gemsoul);
	                        not one that's down, nor one out while you're in
	                        danger
	  "KaijuSocket", id, gemId   a gem of its own element from your pouch
	                        enchants it (Kaiju.canSocket), the old one back
	                        in the pouch; not in a fight
	  "KaijuName", id, name   names it (Kaiju.cleanName, then Roblox's filter:
	                        KaijuServer.filterName); "" for no name
	  "KaijuAutoHeal", on   auto heal on or off
	  "KaijuCallBack", away   true: the team put away (Kaiju.away); false:
	                        deployed again
	  "KaijuTeamOut", n     a team key (1 to Kaiju.Teams), at once: the team
	                        out's own number calls it back or deploys it;
	                        another's swaps that team in, or, called back,
	                        deploys it
	  "KaijuSwap", a, b     two of yours swap places in your teams (Kaiju.swap)
	  "KaijuRoll"           the starter roll owed: { Rolls = { { Species, Element, Soul } } }
	  "KaijuRollClaim"      take it: the kaiju join you

	Profile.Kaiju (Kaiju.roster), KaijuRoll and KaijuRolled are in the
	profile snapshot (Kaiju.rollsOwed reads them). Each one out carries, for every client: KaijuOwner
	(UserId), KaijuId, KaijuSlot, KaijuName, KaijuLevel, KaijuExp,
	KaijuExpNext, KaijuAbility, KaijuAbilityAt (server time of its last E),
	KaijuQ, KaijuR and their *At, KaijuGemSurge and KaijuGemAt (its gem
	surge, its enchant's E), KaijuRecallUntil, and its fight
	(KaijuFighter's Action* and GuardUntil, HurtAt and BlockedAt, for
	CreatureAnimation). A record's Health and Down are in the snapshot (the
	HUD's health for one at home, and DOWN).

	KaijuWilds asks here:
	  KaijuServer.all()                      every kaiju out
	  KaijuServer.team(player)               a player's kaiju out, in team order
	  KaijuServer.pets()                     each player's lead out, by owner
	  KaijuServer.petOf(model)               the pet a model is
	  KaijuServer.hurt(pet, amount, element, status?, heavy?) -> outcome   a creature's blow
	  KaijuServer.reward(player, exp)        EXP for each kaiju out
	  KaijuServer.adopt(player, species, soul, level, traits?) -> record?   a tamed one
	  KaijuServer.saleGrant(player, "Daily" | "Rare") -> (ok, lines?)   a Kennel sale paid for

	The store and coupons ask here:
	  KaijuServer.reviveAll(player) -> count   every one of theirs that's down, back now

	A kaiju battle (KaijuBattles) sets KaijuServer.battle(pet, now) -> what
	a pet of one in a battle does: { Spot, Look } to stand at its place in
	the formation, or { Fighting, Foes, Allies, Bounds } to fight the other
	side's kaiju by its role (Server.KaijuBattleBrain: a blow or a move on
	another's pet lands through KaijuServer.hurt); nil for one not in a
	battle. KaijuServer.battling(player) says when a player's in one: their
	team can't be changed or recalled meanwhile. The Bounds (a court of the
	Kaiju Arena, Shared.KaijuPit, or a court's size round the field) keep
	it in: it never walks past them, and one that's well out (a shove) is
	put back.

	A battle is fought at full health and leaves every kaiju as it was:
	  KaijuServer.battleStart(player)        each of the team's health kept on
	                                         its record (BattleKeep, saved), then
	                                         all of them full, the knocked out
	                                         back out for it
	  KaijuServer.battleEnd(player)          each put back as it was (a rejoin or
	                                         a restart does it too: upkeep)
	  KaijuServer.battleable(player) -> n    how many could battle: the team,
	                                         down or not, if it can be out
	A kaiju knocked out in a battle is out of it quietly: no notice, no
	critter raid, no revive timer running (and a revive bought meanwhile
	applies to how it was).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuKennel = require(ReplicatedStorage.Shared.KaijuKennel)
local Aggro = require(ReplicatedStorage.Shared.Aggro)
local KaijuFight = require(ReplicatedStorage.Shared.KaijuFight)
local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local Squad = require(ReplicatedStorage.Shared.Squad)
local Enemies = require(script.Parent.Enemies)
local Gems = require(script.Parent.Gems)
local KaijuAbilities = require(script.Parent.KaijuAbilities)
local KaijuBattleBrain = require(script.Parent.KaijuBattleBrain)
local KaijuFighter = require(script.Parent.KaijuFighter)
local KaijuRoles = require(ReplicatedStorage.Shared.KaijuRoles)
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
	GemSurge: string?, -- its Gemsoul's E, cast beside its own moves (Kaiju.gemSurge)
	Target: any?, -- the Enemies record it's fighting
	FightAt: Vector3?, -- where that fight began: it chases a foe no further off (Kaiju.Follow.Chase)
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
	-- Its owner standing about: where (its spot by them) and since when, and
	-- what it's doing meanwhile ({ Mood, Until, To? }: Kaiju.Roam.Pet).
	IdleSpot: Vector3?,
	IdleSince: number?,
	Plan: any?,
	Slot: number, -- its place in the team (Kaiju.TeamSpots)
	-- Jumping after its owner (Kaiju.Hop): when, and when it last did.
	HopAt: number?,
	HoppedAt: number?,
	HopAgain: boolean?, -- (another jump of yours came while it waited its turn)
	-- The support's pulse (pulse): when each of its moves is next ready.
	PulseAt: { [string]: number }?,
	LastPulse: string?, -- (the support: what it cast last, Kaiju.supportChoice)
	-- In the team's hyperbeam (KaijuBeamServer): its own thinking waits till then.
	BeamUntil: number?,
}

-- The kaiju out, by player and kaiju id.
local teams: { [Player]: { [string]: Pet } } = {}

-- Kaiju battles (KaijuBattles sets these; see the top).
KaijuServer.battle = function(_pet, _now): any
	return nil
end
-- The whole team out knocked out (FrontierServer sets it: a gem raid).
KaijuServer.onTeamDown = function(_player: Player) end
-- The team's hyperbeam (KaijuBeamServer sets these): a blow of a pet's
-- landing (its mana), a pet casting one of its moves (that costs mana),
-- and whether its owner is saving its charge (it casts nothing then).
KaijuServer.onStrike = function(_pet, _outcome: string, _heavy: boolean?) end
KaijuServer.onCast = function(_pet) end
KaijuServer.holding = function(_pet): boolean
	return false
end
KaijuServer.battling = function(_player: Player): boolean
	return false
end
local rng = Random.new()
-- When a player owing a starter roll was first seen in the Outpost.
local owedSince: { [Player]: number } = {}
-- Each of a player's kaiju's waits as it went back in its Gemsoul (its
-- fighter's NextQ, NextR, NextSurge, NextGem and LastFight, its pulses,
-- and the HUD's *At), by record id, so one swapped out and straight back
-- in comes out with them as they were: swaps are instant, and none of
-- them resets a move.
local waits: { [Player]: { [string]: any } } = {}
local CAST_SHOWN = { "KaijuQAt", "KaijuAbilityAt", "KaijuRAt", "KaijuGemAt" }
-- How fast each owner was rising last frame (to see them jump: Kaiju.leapt),
-- when their client last said they jumped (Remotes.KaijuJump), and when the
-- last jump of theirs was counted (Kaiju.newJump).
local rising: { [Player]: number } = {}
local saidJump: { [Player]: number } = {}
local lastJump: { [Player]: number } = {}
-- Which way each player's camera looks along the ground (their client says:
-- Remotes.KaijuView), so the team stands where they can see it (Kaiju.leadSpot).
local views: { [Player]: Vector3 } = {}
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
-- An effect on a pet, at its size ("Sized": the client draws it, sounds it
-- and shakes your screen as big as it stands, FxSize).
local PET_SIZE = Kaiju.size(Kaiju.Scale.Pet)
local function petFx(kind: string, ...)
	fx("Sized", PET_SIZE, kind, ...)
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
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Kaiju.Hop.Height
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

-- Stands a body on the ground at `point`, facing `look` (`lift` studs up
-- off it: the team's hyperbeam, fired from the air).
-- Where place puts it (its pivot), not moving it (the team's hyperbeam
-- sends its landing to clients ahead).
function KaijuServer.spot(model: Model, point: Vector3, look: Vector3?, lift: number?): CFrame
	local root = model.PrimaryPart :: BasePart
	local floor = KaijuServer.ground(point)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local up = (if humanoid then humanoid.HipHeight else 1) + root.Size.Y / 2 + (lift or 0)
	local at = floor + Vector3.new(0, up, 0)
	local facing = if look and flat(look - at).Magnitude > 0.1
		then Vector3.new(look.X, at.Y, look.Z)
		else at + Vector3.new(0, 0, -1)
	return CFrame.lookAt(at, facing)
end

function KaijuServer.place(model: Model, point: Vector3, look: Vector3?, lift: number?)
	model:PivotTo(KaijuServer.spot(model, point, look, lift))
end

-- Its health kept on its record (saved: it never comes back on its own).
local function keepHealth(pet: Pet)
	pet.Record.Health = math.max(0, math.floor(pet.Humanoid.Health + 0.5))
end

-- Stats and the attributes clients read, after a level or a new kaiju.
local function refresh(pet: Pet)
	local record = pet.Record
	local stats = Kaiju.recordStats(record)
	local h = pet.Humanoid
	local share = h.Health / math.max(1, h.MaxHealth)
	pet.Stats = stats
	KaijuFighter.restat(pet.Fighter, stats, Kaiju.Scale.Pet)
	h.MaxHealth = stats.Health
	h.Health = math.max(1, math.floor(stats.Health * share + 0.5))
	keepHealth(pet)
	local model = pet.Model
	-- Its Q and R wake as it levels (its role's moves: Kaiju.kitMoves).
	local moves = Kaiju.kitMoves(record.Species, record.Level)
	KaijuFighter.setMoves(pet.Fighter, moves)
	model:SetAttribute("KaijuQ", moves.Q)
	model:SetAttribute("KaijuR", moves.R)
	-- Its gem surge, attuned (a new Gemsoul may give or take it); a
	-- support's gem move is its R instead (Kaiju.gemMove, cast by its pulse).
	local surge = Kaiju.recordSurge(record)
	if surge ~= pet.GemSurge then
		pet.GemSurge = surge
		KaijuFighter.setGemSurge(pet.Fighter, surge)
	end
	model:SetAttribute("KaijuGemSurge", Kaiju.gemMove(record))
	model:SetAttribute("KaijuLevel", record.Level)
	model:SetAttribute("KaijuExp", record.Exp or 0)
	local next = Kaiju.expToNext(record.Level)
	model:SetAttribute("KaijuExpNext", if next == math.huge then 0 else next)
end

-- Out and back ------------------------------------------------------------------------------------

-- A player's kaiju out, in team order.
local function petsOf(player: Player): { Pet }
	local list = {}
	for _, pet in teams[player] or {} do
		table.insert(list, pet)
	end
	table.sort(list, function(a, b)
		return a.Slot < b.Slot
	end)
	return list
end

-- Puts one of `player`'s kaiju away (`id`), or all of them.
local function despawn(player: Player, id: string?)
	local out = teams[player]
	if not out then
		return
	end
	for petId, pet in out do
		if id == nil or petId == id then
			out[petId] = nil
			if pet.Humanoid.Health > 0 then
				keepHealth(pet)
			end
			local f = pet.Fighter
			if f then
				local shown = {}
				for _, name in CAST_SHOWN do
					shown[name] = pet.Model:GetAttribute(name)
				end
				waits[player] = waits[player] or {}
				waits[player][petId] = {
					NextQ = f.NextQ,
					NextR = f.NextR,
					NextSurge = f.NextSurge,
					NextGem = f.NextGem,
					Ability = f.Ability,
					GemSurge = f.GemSurge,
					LastFight = f.LastFight,
					PulseAt = table.clone(pet.PulseAt or {}),
					Shown = shown,
				}
			end
			KaijuFighter.forget(pet.Fighter)
			pet.Model:Destroy()
		end
	end
end

-- Where `player`'s kaiju in `slot` walks, leading `root` the way it's going,
-- where their camera sees it (Kaiju.TeamSpots, Kaiju.leadSpot).
local function spotBy(root: BasePart, slot: number, player: Player): Vector3
	local moving = root.AssemblyLinearVelocity or Vector3.zero
	return Kaiju.leadSpot(root.Position, root.CFrame.LookVector, moving, slot, views[player])
end

local creaturesNear -- (the creatures about a point: below)

local function spawnPet(player: Player, record, slot: number): Pet?
	local root = rootOf(player)
	if not root then
		return nil
	end
	local model, humanoid, petRoot = KaijuServer.body(record.Species, record.Element, Kaiju.Scale.Pet)
	model.Name = player.Name .. "Kaiju"
	model:SetAttribute("KaijuOwner", player.UserId)
	model:SetAttribute("KaijuId", record.Id)
	model:SetAttribute("KaijuSlot", slot)
	model:SetAttribute("KaijuName", Kaiju.nameOf(record))
	-- (When it came out: a client under its loading screen then plays the
	-- deploy once it can see it, KaijuHud.)
	model:SetAttribute("KaijuOutAt", serverNow())
	local ability = Kaiju.kitMoves(record.Species, record.Level).E
	model:SetAttribute("KaijuAbility", ability)
	-- Beside its own moves, its gem surge (its Gemsoul's E, attuned; a
	-- support has none, its gem's R instead: Kaiju.gemMove).
	local gem = Kaiju.recordSurge(record)
	model:SetAttribute("KaijuGemSurge", Kaiju.gemMove(record))
	local pet: Pet = {
		Owner = player,
		Record = record,
		Model = model,
		Root = petRoot,
		Humanoid = humanoid,
		Element = record.Element,
		Stats = Kaiju.recordStats(record),
		Ability = ability,
		GemSurge = gem,
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
		Slot = slot,
		PulseAt = {},
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
		Moves = Kaiju.kitMoves(record.Species, record.Level),
		GemSurge = gem,
		Strike = function(foe, amount: number, heavy: boolean, _name: string): string
			if foe.Enemy then
				return KaijuServer.strike(pet, foe.Enemy, amount, nil, heavy)
			elseif foe.Pet and KaijuServer.battle(pet, os.clock()) then
				-- (Another's kaiju, in a battle.)
				pet.LastFight = os.clock()
				return KaijuServer.hurt(foe.Pet, amount, pet.Element, nil, heavy)
			end
			return "Missed"
		end,
		Caster = function()
			return KaijuServer.caster(pet)
		end,
		-- (The rest of a swarm round it: its heavies sweep through them.)
		Around = function()
			return creaturesNear(petRoot.Position, Kaiju.Follow.Gap * 3, player)
		end,
	})
	humanoid.MaxHealth = pet.Stats.Health
	humanoid.Health = math.clamp(Kaiju.health(record), 1, pet.Stats.Health)
	-- (Back from a swap: its waits as they were, not fresh: see `waits`.)
	local kept = waits[player] and waits[player][record.Id]
	if kept then
		waits[player][record.Id] = nil
		local f = pet.Fighter :: any
		f.NextQ, f.NextR, f.LastFight = kept.NextQ, kept.NextR, kept.LastFight
		-- (a new E or Gemsoul since starts its own wait, as a fresh one)
		f.NextSurge = if kept.Ability == ability then kept.NextSurge else f.NextSurge
		f.NextGem = if kept.GemSurge == gem then kept.NextGem else f.NextGem
		pet.PulseAt = kept.PulseAt
		for name, at in kept.Shown do
			model:SetAttribute(name, at)
		end
	end
	refresh(pet)
	KaijuServer.place(model, spotBy(root, slot, player), root.Position + root.CFrame.LookVector * 10)
	model.Parent = folder
	pcall(petRoot.SetNetworkOwner, petRoot, nil)
	teams[player] = teams[player] or {}
	teams[player][record.Id] = pet
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

-- The starter roll -------------------------------------------------------------------------------

-- The roll a profile is owed (Kaiju.rollsOwed), made once and saved, so a
-- retry or a rejoin shows the same kaiju: { Rolls = { { Species, Element,
-- Soul } }, Version }. Nil if none is owed. (One saved by an older version,
-- a short top-up, is made again.)
local function prepareRoll(profile)
	local p = profile :: any
	local roll = p.KaijuRoll
	if
		type(roll) == "table"
		and type(roll.Rolls) == "table"
		and #roll.Rolls > 0
		and roll.Version == Kaiju.RollVersion
		and p.KaijuRolled ~= Kaiju.RollVersion
	then
		return roll
	end
	-- (A boss roll made and not yet taken: the same one again.)
	if type(roll) == "table" and roll.Boss and type(roll.Rolls) == "table" and #roll.Rolls == 1
		and Kaiju.bossRollsOwed(profile) > 0 then
		return roll
	end
	local owed = Kaiju.rollsOwed(profile)
	if owed <= 0 then
		-- A boss roll owed (Kaiju.bossRollsOwed): one kaiju, any kind. A
		-- rare roll bought at the Kennel (Kaiju.rareRollsOwed) comes first:
		-- one of the rarest batch, its traits and Gemsoul better (Sale.Rare).
		if Kaiju.bossRollsOwed(profile) <= 0 then
			return nil
		end
		local random = Gems.random()
		local rare = Kaiju.rareRollsOwed(profile) > 0
		local sale = Kaiju.Sale.Rare
		local pick = if rare then Kaiju.rarePick(random) else Kaiju.bossPick(random)
		local soul = Kaiju.rollSoul(random, pick.Element, {
			Id = PlayerData.newGemId(),
			Time = os.time(),
			Species = pick.Species,
			Luck = if rare then sale.Luck else nil,
		})
		local traits = Kaiju.rollTraits(random, if rare then sale.TraitFloor else nil)
		roll = {
			Rolls = { { Species = pick.Species, Element = pick.Element, Soul = soul, Traits = traits } },
			Version = Kaiju.RollVersion,
			Boss = true,
			Rare = rare or nil,
		}
		p.KaijuRoll = roll
		return roll
	end
	local roster = Kaiju.roster(profile)
	local owned = {}
	for _, record in roster.List do
		table.insert(owned, record)
	end
	local random = Gems.random()
	roll = { Rolls = {}, Version = Kaiju.RollVersion }
	for _, pick in Kaiju.starterPicks(random, owed, owned) do
		local soul = Kaiju.rollSoul(
			random,
			pick.Element,
			{ Id = PlayerData.newGemId(), Time = os.time(), Species = pick.Species }
		)
		table.insert(roll.Rolls, { Species = pick.Species, Element = pick.Element, Soul = soul, Traits = Kaiju.rollTraits(random) })
	end
	-- (and the starter support's element, rolled with them so the card shows it)
	roll.Support = { Species = Kaiju.StarterSupport.Species, Element = Kaiju.supportElement(random) }
	p.KaijuRoll = roll
	return roll
end

-- The starter support (Kaiju.StarterSupport), once: added (past a full
-- roster if it must be), put in the support slot. Returns it, or nil if
-- it isn't owed.
local function giveSupport(player: Player, element: string?)
	local profile = PlayerData.get(player)
	if not profile or not Kaiju.supportOwed(profile) then
		return nil
	end
	local roster = Kaiju.roster(profile)
	local starter = Kaiju.StarterSupport
	-- (its element the roll's, or any for a save that had no roll)
	element = if element and table.find(Kaiju.Elements, element) then element else Kaiju.supportElement()
	local soul = Kaiju.rollSoul(
		Gems.random(),
		element :: string,
		{ Id = PlayerData.newGemId(), Time = os.time(), Species = starter.Species }
	)
	local record = Kaiju.add(roster, starter.Species, soul, Kaiju.StarterLevel, true)
	;(profile :: any).KaijuSupport = Kaiju.SupportVersion
	if record then
		Kaiju.setSupport(roster, record.Id)
	end
	PlayerData.sync(player)
	if record then
		Remotes.Notify:FireClient(
			player,
			string.format("%s joins you: your support. It floats in the middle of your team and heals you and your team.", Kaiju.nameOf(record))
		)
	end
	return record
end

-- Takes the roll: its kaiju join `player`. Returns the records added.
local function claimRoll(player: Player): { any }
	local profile = PlayerData.get(player)
	local roll = profile and prepareRoll(profile)
	if not profile or not roll then
		return {}
	end
	local roster = Kaiju.roster(profile)
	local added = {}
	if roll.Boss then
		-- A boss roll: its one kaiju joins as a reserve (your team stays).
		local entry = roll.Rolls[1]
		local record = entry and Kaiju.add(roster, entry.Species, entry.Soul, Kaiju.StarterLevel, nil, entry.Traits)
		local p = profile :: any
		p.KaijuRoll = nil
		local counter = if roll.Rare then "KaijuRareRolls" else "KaijuBossRolls"
		p[counter] = math.max(0, math.floor(tonumber(p[counter]) or 0) - 1)
		PlayerData.sync(player)
		if record then
			table.insert(added, record)
			Remotes.Notify:FireClient(player, string.format("%s joins your kaiju. Swap it into a team from YOUR KAIJU.", Kaiju.nameOf(record)))
		end
		return added
	end
	for _, entry in roll.Rolls do
		local record = Kaiju.add(roster, entry.Species, entry.Soul, Kaiju.StarterLevel, nil, entry.Traits)
		if record then
			table.insert(added, record)
		end
	end
	local p = profile :: any
	p.KaijuRoll, p.KaijuRolled, p.KaijuStarter = nil, Kaiju.RollVersion, true
	-- The ones rolled are your team.
	local ids = {}
	for _, record in added do
		table.insert(ids, record.Id)
	end
	Kaiju.setTeam(roster, if #ids > 0 then ids else Kaiju.teamIds(roster))
	owedSince[player] = nil
	PlayerData.sync(player)
	-- (And the support, the fourth, comes with them.)
	giveSupport(player, roll.Support and roll.Support.Element)
	if #added > 0 then
		local names = {}
		for _, record in added do
			table.insert(names, Kaiju.nameOf(record))
		end
		Remotes.Notify:FireClient(
			player,
			string.format("Your kaiju: %s. They fight beside you in the Outpost.", table.concat(names, ", "))
		)
	end
	return added
end

-- One knocked out back on its feet: its revive time up, weak (at
-- Kaiju.Revive.Health of its health, to be healed with gems), or bought
-- (at Revive.Bought).
local function wake(record, bought: boolean?, into: any?)
	local _, most = Kaiju.health({ Id = record.Id, Species = record.Species, Level = record.Level, Soul = record.Soul, Traits = record.Traits })
	local target = into or record
	target.Down, target.DownUntil = nil, nil
	local share = if bought then Kaiju.Revive.Bought else Kaiju.Revive.Health
	target.Health = math.max(1, math.floor(most * share + 0.5))
end

-- A battle's keep put back on every record that has one (Server.KaijuBattles:
-- battleEnd, or a rejoin / restart through upkeep). Returns the ids.
local function putBack(roster): { string }
	local ids = {}
	for _, record in (roster and roster.List) or {} do
		local keep = record.BattleKeep
		if keep then
			record.BattleKeep = nil
			record.Health, record.Down, record.DownUntil = keep.Health, keep.Down, keep.DownUntil
			table.insert(ids, record.Id)
		end
	end
	return ids
end

-- Puts the right kaiju out (or away) for `player`.
-- Getting into the game: team 1 out, whatever was out (or called back)
-- when you left, once a visit, as your profile comes in.
local joined: { [Player]: boolean } = {}
local function teamOneOnJoin(player: Player, roster)
	if joined[player] or not roster then
		return
	end
	joined[player] = true
	local ids = Kaiju.teamOf(roster, 1)
	if #ids == 0 or (Kaiju.outTeam(roster) == 1 and not Kaiju.away(roster)) then
		return
	end
	roster.Out, roster.Away = 1, nil
	roster.Team, roster.Active = Kaiju.teamIds(roster), ids[1]
	PlayerData.sync(player)
end

local function upkeep(player: Player, now: number)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	teamOneOnJoin(player, profile.Kaiju)
	-- A roll left unclaimed: given after a while in the Outpost.
	if player:GetAttribute("Outpost") == true and Kaiju.rollsOwed(profile) > 0 then
		owedSince[player] = owedSince[player] or now
		if now - owedSince[player] >= Kaiju.RollGrace then
			claimRoll(player)
		end
	end
	-- The starter support, for one who has none yet (an older save).
	if player:GetAttribute("Outpost") == true and Kaiju.supportOwed(profile) then
		giveSupport(player)
	end
	local roster = profile.Kaiju
	-- A battle's keep left behind (they left mid-battle, or the server
	-- restarted): each kaiju back as it was before it (battleEnd comes back
	-- here once it has).
	if player:GetAttribute("KaijuBattle") == nil then
		for _, record in (roster and roster.List) or {} do
			if record.BattleKeep then
				KaijuServer.battleEnd(player)
				return
			end
		end
	end
	-- Knocked out and its time is up: back by itself (at home too). (Not one
	-- knocked out in a battle: that's put back after it.)
	local woke = nil
	for _, record in (roster and roster.List) or {} do
		if record.Down and not record.BattleKeep and Kaiju.reviveIn(record, os.time()) <= 0 then
			wake(record)
			woke = woke or {}
			table.insert(woke, Kaiju.nameOf(record))
		end
	end
	if woke then
		PlayerData.sync(player)
		Remotes.Notify:FireClient(
			player,
			string.format(
				"%s is back on its feet, but weak: heal with gems before the next fight.",
				table.concat(woke, ", ")
			)
		)
	end
	local want = {}
	if roster and canBeOut(player) and not Kaiju.away(roster) then
		-- (The team in its slots, the support in SupportSlot: Kaiju.squadIds.)
		local ids, slots = Kaiju.squadIds(roster)
		for _, id in ids do
			-- (One knocked out keeps its place, down, till it's revived.)
			if not roster.List[id].Down then
				want[id] = slots[id]
			end
		end
	end
	for id, pet in teams[player] or {} do
		if not want[id] or pet.Record ~= roster.List[id] or not pet.Model.Parent then
			despawn(player, id)
		end
	end
	for id, slot in want do
		local pet = teams[player] and teams[player][id]
		if pet then
			if pet.Slot ~= slot then
				pet.Slot = slot
				pet.IdleSpot = nil
				pet.Model:SetAttribute("KaijuSlot", slot)
			end
		else
			-- Out of its Gemsoul (arriving, deployed, swapped in, back on its
			-- feet, back from a fight): a shard from you, and it opens out of
			-- the light, for everyone to see.
			local made = spawnPet(player, roster.List[id], slot)
			if made then
				local root = rootOf(player)
				fx("Deploy", made.Root.Position, 4 * PET_SIZE, made.Element, root and root.Position)
			end
		end
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

-- In a fight: on a foe that's still up and still its owner's to fight. (A
-- kaiju in one sees it through, however far its owner walks off, up to
-- Kaiju.Follow.Battle.)
local function inFight(pet: Pet, owner: Player): boolean
	local foe = pet.Target
	return foe ~= nil and foe.Alive and fair(owner, foe)
end

-- Creatures its foes are (KaijuWilds marks them OutpostCreature), inside a
-- circle: those `owner`'s kaiju may fight.
function creaturesNear(center: Vector3, radius: number, owner: Player): { any }
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
-- (The team's hyperbeam finds what it hits with this: KaijuBeamServer.)
KaijuServer.creaturesNear = function(center: Vector3, radius: number, owner: Player)
	return creaturesNear(center, radius, owner)
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

-- `seconds` off each of `owner`'s support's waits (Kaiju.SupportCharge):
-- its pulse's, and its gem R's as the HUD shows it (KaijuGemAt). (Past
-- ready it banks nothing: a cast sets its wait afresh.)
function KaijuServer.chargeSupport(owner: Player, seconds: number)
	for _, pet in petsOf(owner) do
		if pet.Slot == Kaiju.SupportSlot and pet.Model.Parent then
			for id, at in pet.PulseAt or {} do
				pet.PulseAt[id] = at - seconds
			end
			local shown = pet.Model:GetAttribute("KaijuGemAt")
			if type(shown) == "number" then
				pet.Model:SetAttribute("KaijuGemAt", shown - seconds)
			end
		end
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
		local size = (enemy :: any).FxSize or 1
		if size ~= 1 then
			fx("Sized", size, "BlockSpark", enemy.Root.Position, false)
		else
			fx("BlockSpark", enemy.Root.Position, false)
		end
		enemy.Model:SetAttribute("BlockedAt", serverNow())
		return "Parried"
	end
	local outcome = if enemy.DodgeUntil and now < enemy.DodgeUntil
		then "Dodged"
		elseif KaijuFight.guarding(enemy, now) then (if heavy == true then "Broken" else "Guarded")
		else "Hit"
	local before = enemy.Humanoid.Health
	local color = GemConfig.ElementColors[pet.Element]
	local e = enemy :: any
	-- Its owner's credit goes on before the blow: a killing blow runs the
	-- kill's rewards (OnDeath: a critter's coins and EXP) inside
	-- Enemies.damage, and they'd have missed it. Set right after.
	local guess = math.clamp(amount, 0, math.max(before, 0))
	e.KaijuCredit = e.KaijuCredit or {}
	e.KaijuCredit[pet.Owner] = (e.KaijuCredit[pet.Owner] or 0) + guess
	e.LastPet, e.LastPetAt = pet, now
	Enemies.damage(enemy, amount, nil, false, color, heavy, pet.Element)
	local dealt = math.max(0, before - enemy.Humanoid.Health)
	e.KaijuCredit[pet.Owner] = math.max(0, (e.KaijuCredit[pet.Owner] or 0) + dealt - guess)
	-- Its own threat on what it hits (Shared.Aggro): a boss turns on the
	-- kaiju hurting it, not only on their owner (Duelist's raidTarget).
	if e.Threat and e.ThreatAt then
		Aggro.add(e.Threat, e.ThreatAt, pet, dealt, now)
	end
	if enemy.Alive and (outcome == "Hit" or outcome == "Broken") then
		afflict(enemy, status, amount, pet.Element)
	end
	-- A teammate's blow landing charges the support (Kaiju.SupportCharge).
	if (outcome == "Hit" or outcome == "Broken") and not Kaiju.isSupport(pet.Record.Species) then
		KaijuServer.chargeSupport(pet.Owner, Kaiju.SupportCharge.PerHit)
	end
	KaijuServer.onStrike(pet, outcome, heavy)
	return outcome
end
KaijuServer.strike = strike

-- Its caster for its moves (KaijuAbilities.cast): its foes are the
-- creatures near; its R's shell sits on the pet.
function KaijuServer.caster(pet: Pet)
	KaijuServer.onCast(pet)
	local soul = pet.Record.Soul
	return {
		Model = pet.Model,
		Root = pet.Root,
		Size = Kaiju.size(Kaiju.Scale.Pet),
		Element = pet.Element,
		Ability = pet.Ability,
		Damage = Kaiju.abilityDamage(pet.Stats.Damage, soul, pet.Ability),
		DamageOf = function(id: string): number
			return Kaiju.abilityDamage(pet.Stats.Damage, soul, id)
		end,
		Body = pet,
		Humanoid = pet.Humanoid,
		Foes = function(center: Vector3, radius: number)
			-- (In a battle: the other side's kaiju.)
			local battle = KaijuServer.battle(pet, os.clock())
			if battle and battle.Foes then
				local list = {}
				for _, other in battle.Foes do
					if flat(other.Root.Position - center).Magnitude <= radius then
						table.insert(list, { Root = other.Root, Pet = other })
					end
				end
				return list
			end
			return creaturesNear(center, radius, pet.Owner)
		end,
		Hit = function(victim, amount: number, status: string?)
			if victim.Pet then
				pet.LastFight = os.clock()
				KaijuServer.hurt(victim.Pet, amount, pet.Element, status, nil)
			elseif victim.Enemy then
				strike(pet, victim.Enemy, amount, status, nil)
			end
		end,
		Alive = function(): boolean
			return pet.Model.Parent ~= nil and pet.Humanoid.Health > 0
		end,
		-- A role's moves (Shared.KaijuRoles).
		Taunt = function(victim, seconds: number)
			if victim.Pet then
				victim.Pet.TauntBy, victim.Pet.TauntUntil = pet, os.clock() + seconds
			end
		end,
		Rally = function(plan)
			pet.RallyUntil = os.clock() + (plan.Duration or 5)
			pet.RallyDamage, pet.RallyHaste = plan.Damage or 1, plan.Haste or 1
		end,
		Pick = function(kind: string)
			-- (Their weakest, in a battle.)
			local battle = KaijuServer.battle(pet, os.clock())
			local best, least = nil, math.huge
			for _, other in (battle and battle.Foes) or {} do
				if kind == "Weakest" and other.Humanoid.Health < least then
					best, least = other, other.Humanoid.Health
				end
			end
			return if best then { Root = best.Root, Pet = best } else nil
		end,
		Leap = function(victim): Vector3?
			-- Behind its foe (the far side from where it leapt), inside the court.
			local at = victim.Root.Position
			local away = flat(at - pet.Root.Position)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
			local battle = KaijuServer.battle(pet, os.clock())
			local spot = KaijuRoles.clamp(battle and battle.Bounds, at + away * 2.2)
			KaijuServer.place(pet.Model, spot, at)
			return spot
		end,
		Hop = function(direction: Vector3, studs: number): Vector3?
			local battle = KaijuServer.battle(pet, os.clock())
			local spot = KaijuRoles.clamp(battle and battle.Bounds, pet.Root.Position + direction * studs)
			KaijuServer.place(pet.Model, spot, spot + direction)
			return spot
		end,
		Allies = function(center: Vector3, radius: number)
			-- (Its side in a battle; else the rest of its team out, and, for
			-- the support, its owner too: a mend heals them, a ward doesn't
			-- sit on them.)
			local battle = KaijuServer.battle(pet, os.clock())
			local pool = if battle and battle.Allies then battle.Allies else teams[pet.Owner] or {}
			local list = {}
			for _, other in pool do
				local up = other.Model.Parent ~= nil and other.Humanoid.Health > 0
				if up and flat(other.Root.Position - center).Magnitude <= radius then
					table.insert(list, { Root = other.Root, Body = other, Humanoid = other.Humanoid })
				end
			end
			if not battle and Kaiju.isSupport(pet.Record.Species) then
				local root = rootOf(pet.Owner)
				local character = pet.Owner.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				-- (You, as far as its pulse reaches.)
				local reach = math.max(radius, Kaiju.SupportPulse.Radius)
				if root and humanoid and humanoid.Health > 0 and flat(root.Position - center).Magnitude <= reach then
					table.insert(list, { Root = root, Humanoid = humanoid })
				end
			end
			return list
		end,
	}
end

-- Down: back in its Gemsoul until its revive time is up (or it's revived
-- for Robux or a coupon: reviveAll).
local function knockOut(pet: Pet)
	local player = pet.Owner
	petFx("TriadBreak", pet.Root.Position, 4 * PET_SIZE, pet.Element)
	local record = pet.Record
	local id = record.Id
	if teams[player] and teams[player][id] == pet then
		teams[player][id] = nil
	end
	KaijuFighter.forget(pet.Fighter)
	pet.Model:Destroy()
	-- (It keeps its place in the team, down, till it's revived or replaced.)
	local profile = PlayerData.get(player)
	if profile and profile.Kaiju then
		Kaiju.setTeam(profile.Kaiju, Kaiju.teamIds(profile.Kaiju))
	end
	local wait = Kaiju.reviveSeconds(record)
	record.Down, record.Health, record.DownUntil = true, 0, os.time() + wait
	PlayerData.sync(player)
	-- Out of a battle quietly: it's back as it was once the battle's over.
	if record.BattleKeep then
		return
	end
	-- The last of the team down: the critters smell your gems.
	if profile and profile.Kaiju then
		local ids, standing = Kaiju.teamIds(profile.Kaiju), 0
		for _, other in ids do
			if not profile.Kaiju.List[other].Down then
				standing += 1
			end
		end
		if #ids > 0 and standing == 0 then
			task.spawn(KaijuServer.onTeamDown, player)
		end
	end
	Remotes.Notify:FireClient(
		player,
		string.format(
			"%s was knocked out! It's back by itself in %d:%02d, or revive it now.",
			Kaiju.nameOf(record),
			wait // 60,
			wait % 60
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
	-- (In its HYPERBEAM, from its leap till it's let go: nothing hurts it.)
	if pet.BeamUntil and now < pet.BeamUntil then
		return "Missed"
	end
	pet.LastFight = now
	local model = pet.Model
	local outcome, share = KaijuFight.resolve(pet, heavy, now)
	if outcome == "Dodged" then
		return outcome
	elseif outcome == "Parried" then
		petFx("BlockSpark", pet.Root.Position, false)
		model:SetAttribute("BlockedAt", serverNow())
		return outcome
	elseif outcome == "Broken" then
		petFx("BlockSpark", pet.Root.Position, true)
		model:SetAttribute("GuardUntil", 0)
	elseif outcome == "Guarded" then
		petFx("BlockSpark", pet.Root.Position, false)
		model:SetAttribute("BlockedAt", serverNow())
	end
	local mult, tag = Kaiju.taken(pet.Record.Species, pet.Element, element, pet.Stats and pet.Stats.Guard)
	if now < pet.VulnerableUntil then
		mult *= 1.15
	end
	-- Its R's shell or ward takes its share first.
	local through = KaijuAbilities.soak(pet, amount * share * mult)
	if through <= 0 then
		petFx("BlockSpark", pet.Root.Position, false)
		return outcome
	end
	local dealt = math.max(1, math.floor(through + 0.5))
	local h = pet.Humanoid
	h.Health = math.max(0, h.Health - dealt)
	keepHealth(pet)
	petFx(
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
	return outcome
end

-- Fighting as a team (Shared.Squad): the creatures near its owner shared
-- out among the team fit to fight (out, not recalled, not run off past the
-- leash, or past Battle if it's in a fight): each its own while there are
-- enough to go round, else as evenly as can be, a creature after it (or
-- after its owner or its owner's support, more so) counting nearer, and the
-- one it's on kept unless another is well nearer. The one it's on stays in
-- the running while it's a little past the engage range of its owner, or
-- within Chase of where that fight began (FightAt: a fight isn't dropped
-- because its owner walked off), and so does a creature after a kaiju
-- fighting there; a foe backing off further (a bomber keeping its distance)
-- is let go, not chased across the Outpost. With a creature on its owner or
-- their support (within Kaiju.Danger.Radius: a bomber shelling them from
-- there is in the running too), its owner comes first: no fight anywhere
-- else stays in it, and the team comes back for what's on them. In the
-- Rift, the critters first: a pack's leaders (RiftLeader) only once none of
-- its critters is left about. Where two or more share one, the side of it
-- each fights from. Returns { [pet]: enemy } and { [pet]: flank }.
local function teamPlan(player: Player, ownerRoot: BasePart, now: number)
	local follow = Kaiju.Follow
	local engage = follow.Engage
	local at = ownerRoot.Position
	-- (After its owner, or their support: it can't fight back.)
	local function guarded(after: any): boolean
		return after == player
			or (type(after) == "table" and after.Owner == player and after.Record ~= nil and Kaiju.isSupport(after.Record.Species))
	end
	local threats = {}
	for _, entry in creaturesNear(at, Kaiju.Danger.Radius, player) do
		if guarded((entry.Enemy :: any).Foe) then
			table.insert(threats, entry.Enemy)
		end
	end
	local threatened = #threats > 0
	local fighters = {}
	for _, pet in petsOf(player) do
		local away = flat(at - pet.Root.Position).Magnitude
		local inRange = away <= follow.Leash or (inFight(pet, player) and away <= follow.Battle)
		-- (Not the support: it stays by its owner and mends: pulse.)
		if
			pet.Model.Parent
			and pet.Humanoid.Health > 0
			and now >= pet.RecallUntil
			and inRange
			and not Kaiju.isSupport(pet.Record.Species)
		then
			table.insert(fighters, pet)
		end
	end
	local foes, listed = {}, {}
	local function list(enemy)
		if not listed[enemy] then
			table.insert(foes, enemy)
			listed[enemy] = true
		end
	end
	for _, entry in creaturesNear(at, engage, player) do
		list(entry.Enemy)
	end
	for _, enemy in threats do
		list(enemy)
	end
	-- (Where its fight began, a fight away from its owner goes on: never
	-- with them under attack, and never after a foe backed off past Chase.)
	local function atFight(pet: Pet, point: Vector3): boolean
		return not threatened and pet.FightAt ~= nil and flat(point - pet.FightAt).Magnitude <= follow.Chase
	end
	for _, pet in fighters do
		local current = pet.Target
		if current and inFight(pet, player) then
			local p = current.Root.Position
			if flat(p - at).Magnitude <= engage + 12 or atFight(pet, p) then
				list(current)
			end
		end
		-- (Off fighting away from its owner: what comes at it there too.)
		if flat(at - pet.Root.Position).Magnitude > engage then
			for _, entry in creaturesNear(pet.Root.Position, engage, player) do
				if (entry.Enemy :: any).Foe == pet and atFight(pet, entry.Root.Position) then
					list(entry.Enemy)
				end
			end
		end
	end
	-- In the Rift the critters come first: a pack's leaders (its fighters,
	-- the boss) are yours, theirs only once no critter's left about.
	local critters = {}
	for _, enemy in foes do
		if not enemy.Model:GetAttribute("RiftLeader") then
			table.insert(critters, enemy)
		end
	end
	if #critters > 0 then
		foes = critters
	end
	-- (It dives a swarm's bomber, and finishes off one that's nearly done.)
	local targets = Squad.assign(fighters, foes, function(pet, enemy)
		local after = (enemy :: any).Foe
		local distance = (enemy.Root.Position - pet.Root.Position).Magnitude
		local h = enemy.Humanoid
		return Squad.cost(distance, pet.Target == enemy, after == pet)
			- (if guarded(after) then Kaiju.Squad.OwnerThreat else 0)
			- (if enemy.Model:GetAttribute("CritterRanged") then Kaiju.Squad.Bomber else 0)
			- (if h and h.Health < h.MaxHealth * 0.25 then Kaiju.Squad.Finish else 0)
	end)
	local groups, order = {}, {}
	for _, pet in fighters do
		local enemy = targets[pet]
		if enemy then
			if not groups[enemy] then
				groups[enemy] = {}
				table.insert(order, enemy)
			end
			table.insert(groups[enemy], pet)
		end
	end
	local flanks = {}
	for _, enemy in order do
		local group = groups[enemy]
		if #group > 1 then
			local spots = {}
			for i, pet in group do
				spots[i] = pet.Root.Position
			end
			for i, dir in Squad.slots(enemy.Root.Position, spots) do
				flanks[group[i]] = dir
			end
		end
	end
	return targets, flanks
end

-- A push clear of any other kaiju out crowding it (Kaiju.Squad.Space).
local function spacing(pet: Pet): Vector3
	local space = Kaiju.Squad.Space
	local others = {}
	for _, out in teams do
		for _, other in out do
			if other ~= pet and other.Model.Parent then
				local at = other.Root.Position
				if flat(at - pet.Root.Position).Magnitude < space then
					table.insert(others, at)
				end
			end
		end
	end
	return Squad.apart(pet.Root.Position, others, space, pet.Slot)
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
	local spot = spotBy(ownerRoot, pet.Slot, pet.Owner)
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

-- The support's pulse (Kaiju.SupportPulse), only in a fight (in danger,
-- Kaiju.Danger: out of one, healing is the gems'). It reads the health of
-- you and of every one of the team in its reach, each and on average, and
-- casts what that calls for (Kaiju.supportChoice): a big mend for someone
-- nearly down or a team in a bad way, its gem's R on you and itself once
-- you're worn (Kaiju.supportGuard, KaijuAbilities.guard), a mend for the
-- hurt, a ward when someone's taking the hits, and when nobody needs it,
-- its attack on the nearest foe (KaijuRoles.supportMoves; all its own from
-- level 1).
local function pulse(pet: Pet, ownerRoot: BasePart, now: number)
	local rules = Kaiju.SupportPulse
	if not KaijuServer.inDanger(pet.Owner, now) then
		return
	end
	local healths = {}
	local function look(h: Humanoid?, at: Vector3)
		if h and h.Health > 0 and flat(at - pet.Root.Position).Magnitude <= rules.Radius then
			table.insert(healths, h.Health / math.max(1, h.MaxHealth))
		end
	end
	local character = pet.Owner.Character
	local ownerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	look(ownerHumanoid, ownerRoot.Position)
	for _, other in petsOf(pet.Owner) do
		if other.Model.Parent then
			look(other.Humanoid, other.Root.Position)
		end
	end
	-- Its foes: the nearest creature in its reach (the team's foe first).
	local foe, near = nil, math.huge
	for _, victim in creaturesNear(pet.Root.Position, rules.StrikeRange, pet.Owner) do
		local d = flat(victim.Root.Position - pet.Root.Position).Magnitude
		for _, other in petsOf(pet.Owner) do
			if other.Target and other.Target.Enemy == victim.Enemy then
				d -= 1000 -- (the one the team's on)
				break
			end
		end
		if d < near then
			foe, near = victim, d
		end
	end
	pet.PulseAt = pet.PulseAt or {}
	local moves = table.clone(KaijuRoles.supportMoves(pet.Record.Species))
	moves.Guard = Kaiju.supportGuard(pet.Record)
	local ready = {}
	for use, id in moves do
		ready[use] = now >= (pet.PulseAt[id] or 0)
	end
	local owner = if ownerHumanoid then ownerHumanoid.Health / math.max(1, ownerHumanoid.MaxHealth) else nil
	local use = Kaiju.supportChoice({ Healths = healths, Owner = owner, Foes = if foe then 1 else 0, Ready = ready })
	local id = use and moves[use]
	if not id then
		return
	end
	local cast
	if use == "Guard" then
		local player = pet.Owner
		cast = KaijuAbilities.guard(KaijuServer.caster(pet), id, {
			Root = ownerRoot,
			Humanoid = ownerHumanoid,
			Shield = function(amount: number, seconds: number)
				Enemies.shieldPlayer(player, amount, seconds)
			end,
		})
	else
		local aim = if use == "Strike" then foe else { Root = pet.Root }
		cast = aim ~= nil and KaijuAbilities.cast(KaijuServer.caster(pet), aim, id)
	end
	if cast then
		pet.PulseAt[id] = now + (rules.Gaps[use] or rules.Every)
		pet.LastPulse = use
	end
end

local function think(pet: Pet, now: number, _dt: number)
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
	-- In the team's hyperbeam: KaijuBeamServer has it till that's over.
	if pet.BeamUntil and now < pet.BeamUntil then
		return
	end
	-- In a kaiju battle: at its place in the formation, or fighting the
	-- other side's kaiju (KaijuBattles).
	local battle = KaijuServer.battle(pet, now)
	if battle then
		pet.Target, pet.FightAt = nil, nil
		settle(pet)
		pet.IdleSpot = nil
		local fighter = pet.Fighter
		if battle.Fighting then
			-- By its role, as an auto battler's piece (KaijuBattleBrain).
			pet.LastFight = now
			KaijuFighter.calm(fighter)
			KaijuBattleBrain.step(pet, battle, now, KaijuServer)
			-- (Well out of bounds somehow, a shove or a fall: put back in.)
			local bounds = battle.Bounds
			if bounds and pet.Model.Parent then
				local at = pet.Root.Position
				local inside = KaijuRoles.clamp(bounds, at)
				if flat(inside - at).Magnitude > 3 then
					KaijuServer.place(pet.Model, inside, inside + (battle.Look or Vector3.new(0, 0, -1)))
					-- (And no walking back out to where it was: a wind-up started
					-- out there left it heading there.)
					h:MoveTo(pet.Root.Position)
				end
			end
			return
		end
		KaijuFighter.calm(fighter)
		h.WalkSpeed = math.max(pet.Stats.Speed, 16)
		if battle.Spot and flat(battle.Spot - pet.Root.Position).Magnitude > 0.6 then
			h:MoveTo(battle.Spot)
		else
			h:MoveTo(pet.Root.Position)
			-- (Facing the other side, turned only when it's well off.)
			local look = battle.Look
			if look and flat(pet.Root.CFrame.LookVector):Dot(look) < 0.95 then
				pet.Root.CFrame = CFrame.lookAt(pet.Root.Position, pet.Root.Position + look)
			end
		end
		return
	end
	if pet.Brain then
		KaijuBattleBrain.reset(pet) -- (just out of a battle)
	end
	local away = flat(ownerRoot.Position - pet.Root.Position).Magnitude
	-- In a fight it sees it through, however far you've walked off to mine
	-- (up to Kaiju.Follow.Battle): no running back, no putting back beside you.
	local fighting = inFight(pet, owner) and away <= Kaiju.Follow.Battle
	if away > Kaiju.Follow.Teleport and not fighting then
		pet.Target, pet.FightAt = nil, nil
		KaijuFighter.calm(pet.Fighter)
		KaijuServer.place(pet.Model, spotBy(ownerRoot, pet.Slot, owner), ownerRoot.Position)
		return
	end
	local recalled = now < pet.RecallUntil
	if Kaiju.isSupport(pet.Record.Species) then
		-- The support: by you, mending (pulse), never off after a creature.
		pet.Target, pet.FightAt = nil, nil
		KaijuFighter.calm(pet.Fighter)
		if not recalled then
			pulse(pet, ownerRoot, now)
		end
		if now < pet.StunUntil then
			h:MoveTo(pet.Root.Position)
		else
			follow(pet, ownerRoot, recalled, now)
		end
		return
	end
	local target, flank = nil, nil
	if not recalled and (away <= Kaiju.Follow.Leash or fighting) then
		local targets, flanks = teamPlan(owner, ownerRoot, now)
		target, flank = targets[pet], flanks[pet]
	end
	-- Where this fight is (FightAt, see teamPlan): set as it takes on a foe
	-- fresh, or one away from it (back by you), so a foe it's led off by
	-- never moves it.
	if target == nil then
		pet.FightAt = nil
	elseif target ~= pet.Target and (pet.FightAt == nil or flat(target.Root.Position - pet.FightAt).Magnitude > Kaiju.Follow.Chase) then
		pet.FightAt = target.Root.Position
	end
	pet.Target = target
	if target then
		-- It fights as a duellist does (KaijuFighter: it reels when stunned),
		-- on its own side of a foe it shares, clear of the others.
		pet.LastFight = now
		settle(pet)
		pet.IdleSpot = nil
		local fighter = pet.Fighter
		fighter.Flank, fighter.Apart = flank, spacing(pet)
		if KaijuServer.holding(pet) then
			KaijuFighter.hold(fighter, now) -- (saving its charge: blows alone)
		end
		KaijuFighter.step(fighter, { Root = target.Root, Enemy = target }, now)
		return
	end
	KaijuFighter.calm(pet.Fighter)
	if now < pet.StunUntil then
		h:MoveTo(pet.Root.Position)
	else
		follow(pet, ownerRoot, recalled, now)
	end
end

-- You jump, they jump, follow the leader: the kaiju following you (not
-- fighting, reeling or in a kaiju battle) jump after you one after another,
-- the head of your line (nearest where you jumped) first, a beat apart
-- (Kaiju.Hop, Kaiju.hopLine). Each one's take-off goes on its model as
-- KaijuHopAt (server time) so clients pose its crouch, spring and landing.
-- Run every frame, so the beats land where they should.
local function canHop(pet: Pet, now: number): boolean
	return pet.Model.Parent ~= nil
		and not pet.Target
		and now >= pet.StunUntil
		and not (pet.BeamUntil and now < pet.BeamUntil)
		and not KaijuServer.battle(pet, now)
end

local function hops(player: Player, now: number)
	local out = teams[player]
	local ownerRoot = rootOf(player)
	if not out or not next(out) or not ownerRoot then
		rising[player], saidJump[player] = nil, nil
		return
	end
	local rise = ownerRoot.AssemblyLinearVelocity.Y
	-- (Seen rising here, or told by your client, which never misses one:
	-- either way, counted once.)
	local said = saidJump[player]
	saidJump[player] = nil
	if (Kaiju.leapt(rising[player], rise) or said ~= nil) and Kaiju.newJump(lastJump[player], now) then
		lastJump[player] = now
		-- Every jump of yours is followed: one still waiting its turn for
		-- your last jumps once more after it (HopAgain), and one that's only
		-- just landed waits out its Rest rather than sitting this one out.
		local line, distances, slots = {}, {}, {}
		for _, pet in out do
			if canHop(pet, now) then
				if pet.HopAt then
					pet.HopAgain = true
				else
					table.insert(line, pet)
					table.insert(distances, (pet.Root.Position - ownerRoot.Position).Magnitude)
					table.insert(slots, pet.Slot)
				end
			end
		end
		local serverNow = workspace:GetServerTimeNow()
		for place, i in Kaiju.hopLine(distances, slots) do
			local pet = line[i]
			local at = math.max(now + Kaiju.hopDelay(place), (pet.HoppedAt or -math.huge) + Kaiju.Hop.Rest)
			pet.HopAt = at
			pet.Model:SetAttribute("KaijuHopAt", serverNow + (at - now))
		end
	end
	rising[player] = rise
	for _, pet in out do
		if pet.HopAt and now >= pet.HopAt then
			pet.HopAt = nil
			if canHop(pet, now) then
				pet.HoppedAt = now
				pet.Humanoid.Jump = true
				-- (Its body is the server's: one anchored and let go since, by
				-- the HYPERBEAM's formation, falls to a nearby client, which
				-- ignores a jump asked for here. And a lift of its own, so a
				-- humanoid that doesn't take the jump, mid-stride or on a
				-- slope, still goes up: every jump of yours, not just one.)
				pcall(pet.Root.SetNetworkOwner, pet.Root, nil)
				local v = pet.Root.AssemblyLinearVelocity or Vector3.zero
				local lift = math.sqrt(2 * (tonumber(workspace.Gravity) or 196.2) * Kaiju.Hop.Height)
				if v.Y < lift * 0.5 then
					pet.Root.AssemblyLinearVelocity = Vector3.new(v.X, lift, v.Z)
				end
			elseif pet.Model.Parent then
				pet.HopAgain = nil
				pet.Model:SetAttribute("KaijuHopAt", nil) -- (pulled into a fight: no jump to pose)
			end
			-- (Your next jump came while it waited for this one: once more.)
			if pet.HopAgain and pet.HoppedAt == now then
				pet.HopAgain = nil
				pet.HopAt = now + Kaiju.Hop.Rest
				pet.Model:SetAttribute("KaijuHopAt", workspace:GetServerTimeNow() + Kaiju.Hop.Rest)
			end
		end
	end
end

-- Your client saying you jumped (Remotes.KaijuJump): counted next frame.
local function jumped(player: Player)
	if teams[player] then
		saidJump[player] = os.clock()
	end
end

-- Your client saying which way your camera looks (Remotes.KaijuView): along
-- the ground, a unit; nothing else is taken (one looking straight down says
-- nothing, and the last one stands).
local function viewed(player: Player, look: any)
	if typeof(look) ~= "Vector3" then
		return
	end
	local along = Vector3.new(look.X, 0, look.Z)
	local size = along.Magnitude
	if size ~= size or size < 0.2 or size > 2 then
		return
	end
	views[player] = along / size
end

-- For KaijuWilds ---------------------------------------------------------------------------------------

-- Every kaiju out.
function KaijuServer.all(): { Pet }
	local list = {}
	for _, out in teams do
		for _, pet in out do
			table.insert(list, pet)
		end
	end
	return list
end

-- A player's kaiju out, in team order.
KaijuServer.team = petsOf

-- Each player's lead out (the first of their team out), by owner.
function KaijuServer.pets(): { [Player]: Pet }
	local leads = {}
	for player in teams do
		leads[player] = petsOf(player)[1]
	end
	return leads
end

function KaijuServer.petOf(model: Instance?): Pet?
	for _, pet in KaijuServer.all() do
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

-- EXP for each of `player`'s kaiju out (a kill, a moon bug), or for its
-- lead if none is out (knocked out just as the kill landed). Their level
-- and EXP show on their models at once; the profile's copy reaches the
-- What `gained` levels just woke in a kaiju: a move ("Its R move,
-- Tidal Crush, awakens."), or more health and damage.
local function awoken(record, gained: number): string
	for _, key in { "Q", "E", "R" } do
		local move, awake = Kaiju.kitMove(record.Species, key, record.Level)
		local _, before = Kaiju.kitMove(record.Species, key, record.Level - gained)
		if awake and not before and move then
			local info = Kaiju.moveInfo(move)
			return string.format("Its %s move, %s, awakens.", key, if info and info.Name then info.Name else move)
		end
	end
	return "More health and damage."
end

-- client on a level-up.
function KaijuServer.reward(player: Player, exp: number)
	local profile = PlayerData.get(player)
	if not profile or exp <= 0 then
		return
	end
	local out = petsOf(player)
	local records = {}
	for _, pet in out do
		if pet.Humanoid.Health > 0 then
			table.insert(records, pet.Record)
		end
	end
	if #records == 0 then
		local lead = Kaiju.active(profile.Kaiju)
		if lead then
			table.insert(records, lead)
		end
	end
	local levelled = false
	for _, record in records do
		local gained = Kaiju.addExp(record, exp)
		local pet = teams[player] and teams[player][record.Id]
		if pet and pet.Record == record then
			refresh(pet)
		end
		if gained > 0 then
			levelled = true
			if pet then
				-- (Its light seen by everyone near, its banner on its owner's
				-- screen: LevelUpFx.)
				fx(
					"LevelUp",
					pet.Model,
					record.Level,
					"Kaiju",
					pet.Element,
					Kaiju.nameOf(record),
					awoken(record, gained)
				)
			else
				Remotes.Notify:FireClient(
					player,
					string.format("%s reached level %d.", Kaiju.nameOf(record), record.Level)
				)
			end
		end
	end
	if levelled then
		PlayerData.sync(player)
	end
end

-- A tamed kaiju joins `player`. Returns its record, or nil if they have
-- room for no more.
function KaijuServer.adopt(player: Player, speciesId: string, soul, level: number, traits: { [string]: number }?)
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	local record = Kaiju.add(Kaiju.roster(profile), speciesId, soul, level, nil, traits)
	if record then
		PlayerData.sync(player)
	end
	return record
end

-- Requests -----------------------------------------------------------------------------------------

local function recall(player: Player)
	if KaijuServer.battling(player) then
		return reply(false, "Not during a kaiju battle.")
	end
	local out = petsOf(player)
	if #out == 0 then
		return reply(false, "Your kaiju aren't out.")
	end
	local now = os.clock()
	for _, pet in out do
		pet.RecallUntil = now + Kaiju.RecallSeconds
		pet.Target = nil
		pet.Model:SetAttribute("KaijuRecallUntil", serverNow() + Kaiju.RecallSeconds)
	end
	return reply(true, "")
end

-- The team called back into its Gemsouls (the player's own CALL BACK, or
-- the Rift when they go down at the boss). Returns whether it was out.
function KaijuServer.recallTeam(player: Player): boolean
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	if not roster or Kaiju.away(roster) then
		return false
	end
	roster.Away = true
	local root = rootOf(player)
	for _, pet in petsOf(player) do
		fx("CallBack", pet.Root.Position, 4 * PET_SIZE, pet.Element, root and root.Position)
	end
	despawn(player)
	PlayerData.sync(player)
	return true
end

-- The team deployed again, at once, in danger or out of it (back from a
-- swap with their waits as they were: see `waits`); not while you're down
-- (the Rift calls them back till you're up). Returns ok, why not.
function KaijuServer.deployTeam(player: Player): (boolean, string)
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	if not roster then
		return false, "You have no kaiju."
	end
	if not Kaiju.away(roster) then
		return true, ""
	end
	if player:GetAttribute("SparDown") ~= nil then
		return false, "Not while you're down."
	end
	roster.Away = nil
	PlayerData.sync(player)
	upkeep(player, os.clock()) -- (out they come, each with its deploy)
	return true, "Team deployed."
end

-- The team called back (`away`), into its Gemsouls; or deployed again,
-- at once (KaijuServer.deployTeam).
local function callBack(player: Player, away: any)
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	if not roster or type(away) ~= "boolean" then
		return reply(false, "You have no kaiju.")
	end
	if KaijuServer.battling(player) then
		return reply(false, "Not during a kaiju battle.")
	end
	if away then
		if not KaijuServer.recallTeam(player) then
			return reply(true, "")
		end
		return reply(true, "Team called back.")
	end
	local ok, text = KaijuServer.deployTeam(player)
	return reply(ok, text)
end

-- A team key (1 to 4: Kaiju.Teams), at once, fight or no fight. The team
-- out's own number calls it back, or deploys it again (as DEPLOY). Another
-- team's swaps it in: the one out goes back in its Gemsouls and that one
-- comes out. Called back, another team's number picks it and deploys it.
-- (No wait between: each kaiju keeps its waits through a swap, `waits`, so
-- swapping back and forth resets no move.)
local function teamOut(player: Player, n: any)
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	if not roster or type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > Kaiju.Teams then
		return reply(false, "You have no kaiju.")
	end
	if KaijuServer.battling(player) then
		return reply(false, "Not during a kaiju battle.")
	end
	local ids = Kaiju.teamOf(roster, n)
	if #ids == 0 then
		return reply(false, string.format("Team %d is empty: fill Team %d first, then catch more kaiju.", n, Kaiju.teamCount(roster)))
	end
	local current, away = Kaiju.outTeam(roster), Kaiju.away(roster)
	if n == current then
		if away then
			local ok, text = KaijuServer.deployTeam(player)
			return reply(ok, if ok then string.format("Team %d out.", n) else text)
		end
		KaijuServer.recallTeam(player)
		return reply(true, string.format("Team %d called back.", n))
	end
	local standing = 0
	for _, id in ids do
		if not roster.List[id].Down then
			standing += 1
		end
	end
	if standing == 0 then
		return reply(false, string.format("Everyone in Team %d is knocked out.", n))
	end
	local now = os.clock()
	if away then
		if player:GetAttribute("SparDown") ~= nil then
			return reply(false, "Not while you're down.")
		end
		roster.Out = n
		roster.Team, roster.Active = Kaiju.teamIds(roster), ids[1]
		local ok, text = KaijuServer.deployTeam(player)
		return reply(ok, if ok then string.format("Team %d out.", n) else text)
	end
	local root = rootOf(player)
	for _, pet in petsOf(player) do
		fx("CallBack", pet.Root.Position, 4 * PET_SIZE, pet.Element, root and root.Position)
	end
	roster.Out = n
	roster.Team, roster.Active = Kaiju.teamIds(roster), ids[1]
	PlayerData.sync(player)
	upkeep(player, now) -- (the new team out, each with its deploy)
	return reply(true, string.format("Team %d out.", n))
end

-- Two of your kaiju swap places in your teams (the TEAMS tab): not during a
-- kaiju battle, nor taking one of the team out away mid-fight.
local function swapKaiju(player: Player, a: any, b: any)
	local profile = PlayerData.get(player)
	local roster = profile and Kaiju.roster(profile)
	if not roster or type(a) ~= "string" or type(b) ~= "string" or not roster.List[a] or not roster.List[b] or a == b then
		return reply(false, "That kaiju isn't yours.")
	end
	if not Kaiju.teamNumber(roster, a) or not Kaiju.teamNumber(roster, b) then
		return reply(false, "A support kaiju has its own slot.")
	end
	if KaijuServer.battling(player) then
		return reply(false, "Not during a kaiju battle.")
	end
	local now = os.clock()
	local out = Kaiju.teamIds(roster)
	for _, pet in petsOf(player) do
		local id = pet.Record.Id
		if (id == a or id == b) and now - pet.LastFight < 3 and table.find(out, id) then
			return reply(false, "Not in the middle of a fight.")
		end
	end
	Kaiju.swap(roster, a, b)
	PlayerData.sync(player)
	upkeep(player, now)
	return reply(true, "")
end

-- Puts `ids` out as the team (the first leads): only your own, and not
-- taking one away mid-fight.
local function changeTeam(player: Player, ids: { string }): (boolean, string)
	local profile = PlayerData.get(player)
	local roster = profile and Kaiju.roster(profile)
	if not roster then
		return false, "That kaiju isn't yours."
	end
	local before = Kaiju.teamIds(roster)
	local check = { List = roster.List, Team = ids, Next = roster.Next }
	local after = Kaiju.teamIds(check)
	if table.concat(before, ",") == table.concat(after, ",") then
		return true, ""
	end
	local now = os.clock()
	if KaijuServer.battling(player) then
		return false, "Not during a kaiju battle."
	end
	for _, pet in petsOf(player) do
		if now - pet.LastFight < 3 and not table.find(after, pet.Record.Id) then
			return false, "Not in the middle of a fight."
		end
	end
	Kaiju.setTeam(roster, after)
	PlayerData.sync(player)
	upkeep(player, now)
	return true, ""
end

local function setTeam(player: Player, ids: any)
	if type(ids) ~= "table" or #ids == 0 or #ids > #Kaiju.SlotLevels then
		return reply(false, "Pick your team.")
	end
	local profile = PlayerData.get(player)
	local roster = profile and Kaiju.roster(profile)
	local seen = {}
	for _, id in ids do
		if type(id) ~= "string" or not (roster and roster.List[id]) or seen[id] then
			return reply(false, "That kaiju isn't yours.")
		end
		seen[id] = true
	end
	local ok, message = changeTeam(player, ids)
	return reply(ok, if ok then "Your team is out." else message)
end

-- `id` (a support kind of yours) in the support slot: not during a kaiju
-- battle, nor with the one there now mid-fight.
local function setSupport(player: Player, id: any)
	local profile = PlayerData.get(player)
	local roster = profile and Kaiju.roster(profile)
	if not roster or type(id) ~= "string" or not roster.List[id] then
		return reply(false, "That kaiju isn't yours.")
	end
	if not Kaiju.isSupport(roster.List[id].Species) then
		return reply(false, "Only a support kaiju goes in the support slot.")
	end
	if Kaiju.supportId(roster) == id then
		return reply(true, "")
	end
	if KaijuServer.battling(player) then
		return reply(false, "Not during a kaiju battle.")
	end
	local now = os.clock()
	Kaiju.setSupport(roster, id)
	PlayerData.sync(player)
	upkeep(player, now)
	return reply(true, string.format("%s is your support.", Kaiju.nameOf(roster.List[id])))
end

-- `id` out, leading: moved to the front, or into the lead's place if it
-- wasn't out.
local function setActive(player: Player, id: any)
	local profile = PlayerData.get(player)
	local roster = profile and Kaiju.roster(profile)
	if not roster or type(id) ~= "string" or not roster.List[id] then
		return reply(false, "That kaiju isn't yours.")
	end
	local ids = Kaiju.teamIds(roster)
	if ids[1] == id then
		return reply(true, "")
	end
	local at = table.find(ids, id)
	if at then
		table.remove(ids, at)
	else
		table.remove(ids, 1)
	end
	table.insert(ids, 1, id)
	local ok, message = changeTeam(player, ids)
	if not ok then
		return reply(false, message)
	end
	return reply(true, string.format("%s is out.", Kaiju.nameOf(roster.List[id])))
end

-- Stones from your pouch into one of yours (the lead if no id): mended,
-- or, knocked out, brought back (Kaiju.infusePlan: only the gems it
-- needs are used; only loose ones, never one on your gear, and never a
-- Gemsoul, which is a kaiju's own).

-- A heal worked out (Kaiju.infusePlan), done: its gems out of the pouch,
-- its health, the glow.
local function applyHeal(player: Player, record, pet: Pet?, plan)
	local used = {}
	for _, gem in plan.Used do
		used[gem.Id] = true
	end
	PlayerData.removeGems(player, used)
	record.Health = math.max(1, math.floor(plan.Health + 0.5))
	if pet then
		pet.Humanoid.Health = math.min(pet.Humanoid.MaxHealth, record.Health)
		petFx("TriadAura", pet.Root, nil, pet.Element, "Heal", 1.5)
	end
	PlayerData.sync(player)
end

-- In danger (Kaiju.Danger): one of your team out has fought in the last
-- Calm seconds, or a creature they'd fight is within Radius of you.
function KaijuServer.inDanger(player: Player, now: number?): boolean
	local clock = now or os.clock()
	local rule = Kaiju.Danger
	for _, pet in teams[player] or {} do
		if pet.Model.Parent and clock - (pet.LastFight or 0) < rule.Calm then
			return true
		end
	end
	local root = rootOf(player)
	return root ~= nil and #creaturesNear(root.Position, rule.Radius, player) > 0
end

-- Every one of yours that's down, back now (Robux, a Revive coupon).
-- Returns how many.
function KaijuServer.reviveAll(player: Player): number
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	local count = 0
	for _, record in (roster and roster.List) or {} do
		if record.BattleKeep then
			-- (In a battle: it's how it was before that's revived.)
			if record.BattleKeep.Down then
				wake(record, true, record.BattleKeep)
				count += 1
			end
		elseif record.Down then
			wake(record, true)
			count += 1
		end
	end
	if count > 0 then
		PlayerData.sync(player)
		upkeep(player, os.clock())
	end
	return count
end

-- A kaiju battle (Server.KaijuBattles) starts: what each of the team has
-- kept on its record, then every one full, the knocked out back out.
function KaijuServer.battleStart(player: Player): number
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	if not roster then
		return 0
	end
	for _, pet in teams[player] or {} do
		if pet.Humanoid.Health > 0 then
			keepHealth(pet)
		end
	end
	local count = 0
	for _, id in (Kaiju.squadIds(roster)) do
		local record = roster.List[id]
		if record then
			if not record.BattleKeep then
				record.BattleKeep = { Health = record.Health, Down = record.Down, DownUntil = record.DownUntil }
			end
			local _, most = Kaiju.health({ Id = record.Id, Species = record.Species, Level = record.Level, Soul = record.Soul, Traits = record.Traits })
			record.Down, record.DownUntil, record.Health = nil, nil, most
			count += 1
		end
	end
	for _, pet in teams[player] or {} do
		pet.Humanoid.Health = pet.Humanoid.MaxHealth
		keepHealth(pet)
	end
	PlayerData.sync(player)
	upkeep(player, os.clock())
	return count
end

-- The battle's over: every kaiju of theirs back as it was before it (one
-- that was down, down again with the same wait).
function KaijuServer.battleEnd(player: Player): number
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	if not roster then
		return 0
	end
	-- (Those out that were down before go away first, so their health isn't
	-- kept off the body on the way.)
	for _, record in roster.List do
		local keep = record.BattleKeep
		if keep and keep.Down and teams[player] and teams[player][record.Id] then
			despawn(player, record.Id)
		end
	end
	local ids = putBack(roster)
	for _, id in ids do
		local pet = teams[player] and teams[player][id]
		local record = roster.List[id]
		if pet and record and pet.Model.Parent then
			local health = Kaiju.health(record)
			pet.Humanoid.Health = math.clamp(health, 1, pet.Humanoid.MaxHealth)
			keepHealth(pet)
		end
	end
	if #ids > 0 then
		PlayerData.sync(player)
		upkeep(player, os.clock())
	end
	return #ids
end

-- How many of `player`'s kaiju could fight a battle: the whole team, down
-- or not (a battle brings them back for itself), if their kaiju can be out.
function KaijuServer.battleable(player: Player): number
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	if not roster or not canBeOut(player) or Kaiju.away(roster) then
		return 0
	end
	return #(Kaiju.squadIds(roster))
end

-- Your kaiju out healed `share` of their health (not the knocked out: a
-- Rift's healing crystal, Server.RiftServer). Returns how many it touched.
function KaijuServer.mend(player: Player, share: number): number
	local count = 0
	for _, pet in teams[player] or {} do
		local humanoid = pet.Humanoid
		if humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * share)
			keepHealth(pet)
			count += 1
		end
	end
	return count
end

-- Every one of yours back to full health, the knocked out ones too (a
-- Rift's RESTORE: Server.RiftServer). Returns how many it touched.
function KaijuServer.restoreAll(player: Player): number
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	local count = 0
	for _, record in (roster and roster.List) or {} do
		local health, most = Kaiju.health(record)
		if record.Down or health < most then
			record.Down, record.DownUntil = nil, nil
			record.Health = most
			count += 1
		end
	end
	for _, pet in teams[player] or {} do
		pet.Humanoid.Health = pet.Humanoid.MaxHealth
		keepHealth(pet)
	end
	if count > 0 then
		PlayerData.sync(player)
		upkeep(player, os.clock())
	end
	return count
end

local function infuse(player: Player, ids: any, kaijuId: any)
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	local record = if type(kaijuId) == "string" and roster and roster.List then roster.List[kaijuId] else nil
	if kaijuId ~= nil and not record then
		return reply(false, "That kaiju isn't yours.")
	end
	record = record or (profile and Kaiju.active(roster))
	if not record then
		return reply(false, "You have no kaiju to heal.")
	end
	if type(ids) ~= "table" or #ids == 0 or #ids > Kaiju.Infuse.Batch then
		return reply(false, string.format("Pick 1 to %d gems.", Kaiju.Infuse.Batch))
	end
	if record.Down then
		local left = math.ceil(Kaiju.reviveIn(record, os.time()))
		return reply(
			false,
			string.format(
				"%s is knocked out: it's back by itself in %d:%02d, or revive it now.",
				Kaiju.nameOf(record),
				left // 60,
				left % 60
			)
		)
	end
	local pet = teams[player] and teams[player][record.Id]
	if pet and pet.Record ~= record then
		pet = nil
	end
	if pet then
		keepHealth(pet)
	end
	-- (Gems heal only out of a fight: not one of yours, out or home, mid-fight.)
	if KaijuServer.inDanger(player) then
		return reply(false, "Not in the middle of a fight: get clear of the critters first.", { Danger = true })
	end
	local health, most = Kaiju.health(record)
	if health >= most then
		return reply(false, string.format("%s is already at full health.", Kaiju.nameOf(record)))
	end
	local loose = {}
	for _, gem in GemInventory.available(profile) do
		loose[gem.Id] = gem
	end
	local gems, seen = {}, {}
	for _, id in ids do
		if type(id) == "string" and not seen[id] then
			seen[id] = true
			local gem = loose[id]
			if gem and not Kaiju.isSoul(gem) then
				table.insert(gems, gem)
			end
		end
	end
	if #gems == 0 then
		return reply(false, "Those gems aren't in your pouch.")
	end
	local plan = Kaiju.infusePlan(record, gems)
	applyHeal(player, record, pet, plan)
	local share = math.floor(record.Health / plan.Most * 100 + 0.5)
	local stones = string.format("%d gem%s", #plan.Used, if #plan.Used == 1 then "" else "s")
	return reply(
		true,
		string.format("%s healed to %d%% (%s).", Kaiju.nameOf(record), share, stones),
		{ Used = #plan.Used, Health = record.Health, Most = plan.Most }
	)
end

-- A gem from your pouch enchants one of yours (Kaiju.canSocket: its own
-- element only, any rarity); the one it had back in the pouch. Attuned:
-- harder hits and its gem surge (Kaiju.attuned). Not in the middle of a
-- fight.
local function socketSoul(player: Player, kaijuId: any, gemId: any)
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	local record = if type(kaijuId) == "string" and roster and roster.List then roster.List[kaijuId] else nil
	local gem = nil
	if profile and type(gemId) == "string" then
		for _, loose in GemInventory.available(profile) do
			if loose.Id == gemId then
				gem = loose
			end
		end
	end
	local ok, why = Kaiju.canSocket(record, gem)
	if not ok then
		return reply(false, why or "That gem can't go in.")
	end
	local pet = teams[player] and teams[player][record.Id]
	if pet and pet.Record ~= record then
		pet = nil
	end
	if pet then
		keepHealth(pet)
		if KaijuServer.inDanger(player) then
			return reply(false, "Not in the middle of a fight: get clear of the critters first.", { Danger = true })
		end
	end
	local old = record.Soul
	PlayerData.removeGems(player, { [gem.Id] = true })
	record.Soul = gem
	if old then
		-- (Back in the pouch: taking the new one made the room. A wild one's
		-- never had an id of its own.)
		if type(old.Id) ~= "string" or old.Id == "wild" then
			old.Id = PlayerData.newGemId()
		end
		PlayerData.returnGem(player, old)
	end
	local _, most = Kaiju.health(record)
	record.Health = math.min(tonumber(record.Health) or most, most)
	if pet then
		refresh(pet)
		petFx("TriadAura", pet.Root, nil, gem.Element, "Heal", 1.2)
	end
	PlayerData.sync(player)
	local tier = GemConfig.TierLabels[gem.Tier] or gem.Tier
	local surge = Kaiju.gemMove(record)
	local move = surge and Kaiju.moveInfo(surge)
	return reply(
		true,
		string.format(
			if Kaiju.isSupport(record.Species)
				then "%s is enchanted with %s %s %s gem. Gem R: %s."
				else "%s is enchanted with %s %s %s gem. Gem surge: %s.",
			Kaiju.nameOf(record),
			Kaiju.article(tier),
			tier,
			GemConfig.elementName(gem.Element),
			if move then move.Name else "none"
		),
		{ Attuned = Kaiju.attuned(record), Surge = surge }
	)
end

-- Its name (Kaiju.cleanName's rules), filtered by Roblox for everyone to
-- see (TextService: what's left after the filter must be what was asked
-- for, or it's refused). "" takes it back to its kind's title. Once every
-- Kaiju.NameEvery seconds.
local lastNamed: { [Player]: number } = {}
function KaijuServer.filterName(player: Player, text: string): string?
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(filtered) == "string" then filtered else nil
end

local function nameKaiju(player: Player, kaijuId: any, text: any)
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	local record = if type(kaijuId) == "string" and roster and roster.List then roster.List[kaijuId] else nil
	if not record then
		return reply(false, "That kaiju isn't yours.")
	end
	local name, why = Kaiju.cleanName(text)
	if not name then
		return reply(false, why or "That isn't a name.")
	end
	local now = os.clock()
	if lastNamed[player] and now - lastNamed[player] < Kaiju.NameEvery then
		return reply(false, "One moment: you've just named one.")
	end
	lastNamed[player] = now
	if name ~= "" then
		local filtered = KaijuServer.filterName(player, name)
		if filtered == nil then
			return reply(false, "Couldn't check that name just now: try again.")
		end
		if filtered ~= name then
			return reply(false, "That name isn't allowed: try another.")
		end
	end
	record.Name = if name == "" then nil else name
	local pet = teams[player] and teams[player][record.Id]
	if pet and pet.Record == record and pet.Model then
		pet.Model:SetAttribute("KaijuName", Kaiju.nameOf(record))
	end
	PlayerData.sync(player)
	return reply(
		true,
		if name == "" then string.format("Back to %s.", Kaiju.title(record)) else string.format("Named it %s.", name),
		{ Name = record.Name }
	)
end
Players.PlayerRemoving:Connect(function(player)
	lastNamed[player] = nil
end)

-- Auto heal (Kaiju.AutoHeal): your spare Commons heal the team by
-- themselves, out of danger, each one hurt in one go, then your spare
-- Uncommons once the Commons are gone (Kaiju.autoHealPick). Quiet (it
-- glows, and the strip's count of gems drops), but once for running out.
local healAt, toldEmpty = {}, {}
local function autoHeal(player: Player, now: number)
	local profile = PlayerData.get(player)
	local roster = profile and profile.Kaiju
	if not roster or not Kaiju.autoHealOn(roster) or not canBeOut(player) or now < (healAt[player] or 0) then
		return
	end
	if KaijuServer.inDanger(player, now) then
		return
	end
	local pools = {}
	for _, tier in Kaiju.AutoHeal.Tiers do
		pools[tier] = GemInventory.spare(profile, tier)
	end
	local healed, stuck = false, false
	for _, id in (Kaiju.squadIds(roster)) do
		local record = roster.List[id]
		local pet = teams[player] and teams[player][id]
		if pet and pet.Record ~= record then
			pet = nil
		end
		if record.Down then
			continue -- (it comes back by itself: Kaiju.Revive)
		end
		if pet then
			keepHealth(pet)
		end
		local health, most = Kaiju.health(record)
		if health < most then
			local gems = Kaiju.autoHealPick(record, pools)
			if #gems > 0 then
				local plan = Kaiju.infusePlan(record, gems)
				applyHeal(player, record, pet, plan)
				healed = true
				local used = {}
				for _, gem in plan.Used do
					used[gem.Id] = true
				end
				for _, pool in pools do
					for i = #pool, 1, -1 do
						if used[pool[i].Id] then
							table.remove(pool, i)
						end
					end
				end
			else
				local left = 0
				for _, pool in pools do
					left += #pool
				end
				stuck = stuck or left == 0
			end
		end
	end
	if healed then
		healAt[player], toldEmpty[player] = now + Kaiju.AutoHeal.Every, nil
	elseif stuck and not toldEmpty[player] then
		toldEmpty[player] = true
		Remotes.Notify:FireClient(
			player,
			"Auto heal is out of spare Commons and Uncommons: mine more to keep your team going."
		)
	end
end

local function setAutoHeal(player: Player, on: any)
	if type(on) ~= "boolean" then
		return reply(false, "")
	end
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	Kaiju.roster(profile).AutoHeal = on
	healAt[player], toldEmpty[player] = nil, nil
	PlayerData.sync(player)
	return reply(
		true,
		if on then "Auto heal on: your spare Commons heal your team between fights." else "Auto heal off.",
		{ AutoHeal = on }
	)
end

-- The starter roll owed, made now if it wasn't: what the reveal shows.
local function rollRequest(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	local roll = prepareRoll(profile)
	if not roll then
		return reply(true, "", { Rolls = {} })
	end
	return reply(true, "", { Rolls = roll.Rolls, Boss = roll.Boss == true, Rare = roll.Rare == true, Support = roll.Support })
end

local function rollClaim(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	local added = claimRoll(player)
	return reply(true, "", { Added = #added })
end

-- A Kennel sale paid for (StoreServer, a Robux receipt): "Daily" puts
-- the Kaiju of the Day (KaijuKennel.special, today's) in your roster, its
-- traits and Gemsoul better than a wild one's (Kaiju.Sale.Daily), even past
-- a full roster (paid for); "Rare" owes you a rare roll, played on the roll
-- screen (Kaiju.rareRollsOwed). Returns whether it was given, and the lines
-- to show.
function KaijuServer.saleGrant(player: Player, which: string): (boolean, { string }?)
	local profile = PlayerData.get(player)
	if not profile then
		return false
	end
	local p = profile :: any
	if which == "Daily" then
		local day = KaijuKennel.day(os.time())
		if Kaiju.dailyBought(p, day) then
			-- (Paid for twice in one day: the second's a rare roll instead,
			-- not lost.)
			p.KaijuRareRolls = math.floor(tonumber(p.KaijuRareRolls) or 0) + 1
			PlayerData.sync(player)
			return true, { "a rare kaiju roll (today's kaiju was yours already)" }
		end
		local special = KaijuKennel.special(day)
		local sale = Kaiju.Sale.Daily
		local random = Gems.random()
		local soul = Kaiju.rollSoul(random, special.Element, {
			Id = PlayerData.newGemId(),
			Time = os.time(),
			Species = special.Species,
			Luck = sale.Luck,
		})
		local record = Kaiju.add(
			Kaiju.roster(profile),
			special.Species,
			soul,
			Kaiju.StarterLevel,
			true,
			Kaiju.rollTraits(random, sale.TraitFloor)
		)
		if not record then
			return false
		end
		p.KaijuDailyDay = day
		PlayerData.sync(player)
		local grade = Kaiju.grade(Kaiju.traits(record))
		Remotes.Notify:FireClient(
			player,
			string.format("%s joins your kaiju (Grade %s). Swap it into a team from YOUR KAIJU.", Kaiju.nameOf(record), grade)
		)
		return true, { string.format("%s, Grade %s", Kaiju.nameOf(record), grade) }
	elseif which == "Rare" then
		if p[Kaiju.Sale.Rare.Once] then
			-- (Bought twice somehow: the roll's given all the same, paid for.)
			p.KaijuRareRolls = math.floor(tonumber(p.KaijuRareRolls) or 0) + 1
		else
			p[Kaiju.Sale.Rare.Once] = true
			p.KaijuRareRolls = math.floor(tonumber(p.KaijuRareRolls) or 0) + 1
		end
		PlayerData.sync(player)
		Remotes.Notify:FireClient(player, "Your Starter Rare Roll is ready: it plays as soon as you have room for a kaiju.")
		return true, { "the Starter Rare Roll" }
	end
	return false
end

-- A boss beaten: one kaiju roll owed (Kaiju.bossRollsOwed), played on the
-- player's screen once they're back where it can show (KaijuHud).
function KaijuServer.grantBossRoll(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local p = profile :: any
	p.KaijuBossRolls = math.floor(tonumber(p.KaijuBossRolls) or 0) + 1
	PlayerData.sync(player)
	Remotes.Notify:FireClient(player, "Boss down: a kaiju roll is yours.")
end

local function left(player: Player)
	despawn(player)
	teams[player], waits[player], owedSince[player], rising[player] = nil, nil, nil, nil
	saidJump[player], lastJump[player], views[player] = nil, nil, nil
	healAt[player], toldEmpty[player] = nil, nil
	joined[player] = nil
end

function KaijuServer.start()
	folder = Instance.new("Folder")
	folder.Name = "Kaiju"
	folder.Parent = workspace
	Shop.register("KaijuRecall", recall)
	Shop.register("KaijuTeam", setTeam)
	Shop.register("KaijuActive", setActive)
	Shop.register("KaijuInfuse", infuse)
	Shop.register("KaijuSocket", socketSoul)
	Shop.register("KaijuName", nameKaiju)
	Shop.register("KaijuAutoHeal", setAutoHeal)
	Shop.register("KaijuCallBack", callBack)
	Shop.register("KaijuTeamOut", teamOut)
	Shop.register("KaijuSwap", swapKaiju)
	Shop.register("KaijuRoll", rollRequest)
	Shop.register("KaijuRollClaim", rollClaim)
	Shop.register("KaijuSupport", setSupport)
	Players.PlayerRemoving:Connect(left)
	Remotes.KaijuJump.OnServerEvent:Connect(jumped)
	Remotes.KaijuView.OnServerEvent:Connect(viewed)
	local thinkTimer, upkeepTimer = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		thinkTimer += dt
		upkeepTimer += dt
		local now = os.clock()
		for player in teams do
			local ok, err = pcall(hops, player, now)
			if not ok then
				warn("[Kaiju] hops:", err)
			end
		end
		if upkeepTimer >= 0.5 then
			upkeepTimer = 0
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(upkeep, player, now)
				if not ok then
					warn("[Kaiju] upkeep:", err)
				end
				ok, err = pcall(autoHeal, player, now)
				if not ok then
					warn("[Kaiju] auto heal:", err)
				end
				-- (The HUD's HEAL waits while you're in danger, the team out
				-- or called back.)
				local profile = PlayerData.get(player)
				local away = profile ~= nil and Kaiju.away(profile.Kaiju) and canBeOut(player)
				local danger = ((teams[player] ~= nil and next(teams[player]) ~= nil) or away)
					and KaijuServer.inDanger(player, now)
				if player:GetAttribute("KaijuDanger") ~= (danger or nil) then
					player:SetAttribute("KaijuDanger", danger or nil)
				end
			end
		end
		if thinkTimer >= 0.15 then
			local step = thinkTimer
			thinkTimer = 0
			for _, pet in KaijuServer.all() do
				local ok, err = pcall(think, pet, now, step)
				if not ok then
					warn("[Kaiju] think:", err)
				end
			end
		end
	end)
end

-- For tests.
KaijuServer._upkeep, KaijuServer._think, KaijuServer._infuse = upkeep, think, infuse
KaijuServer._joined = joined -- (who's had Team 1 put out this visit)
KaijuServer._autoHeal, KaijuServer._socketSoul = autoHeal, socketSoul
KaijuServer._recall, KaijuServer._setActive, KaijuServer._setTeam = recall, setActive, setTeam
KaijuServer._callBack, KaijuServer._hops, KaijuServer._jumped = callBack, hops, jumped
KaijuServer._viewed, KaijuServer._views, KaijuServer._teamPlan = viewed, views, teamPlan
KaijuServer._teamOut, KaijuServer._swap = teamOut, swapKaiju
KaijuServer._despawn, KaijuServer._fair = despawn, fair
KaijuServer._prepareRoll, KaijuServer._claimRoll = prepareRoll, claimRoll

return KaijuServer
