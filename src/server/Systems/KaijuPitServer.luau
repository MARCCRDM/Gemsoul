--[[
	The Kaiju Arena, downstairs (Shared.KaijuPit has the rules,
	Server.World.KaijuPitWorld builds the hall; the battles themselves are
	Server.KaijuBattles'). Walk down the Shelter's stairs and you're on the
	hall's balcony; walk back through the doorway behind it and you're at
	the top of the stairs again. Down there you keep the Outpost's
	attribute (your kaiju stay out) and carry KaijuPit; the Outpost's
	stranded check leaves you be.

	The courts' pads:
	  - Stand on a pad: you're waiting for a challenger. You can set a stake
	    ("KaijuPitStake": coins, or one of your loose gems), shown on the
	    court's board and pedestal for everyone, and the mode
	    ("KaijuPitMode": "Kaiju", the kaiju alone, or "Mixed", 1V1 + KAIJU:
	    you duel each other while they fight; Shared.KaijuBattle.Modes).
	  - Someone steps onto the other pad: they're told who's waiting and for
	    what, and FIGHT ("KaijuPitFight", a gem of theirs if the stake's a
	    gem) puts both stakes in and starts your battle on that court.
	  - Step off for KaijuPit.Grace and your wait (or challenge) is over.
	    After a battle you step off and back on to go again.
	A kaiju battle asked for from a player's card (KaijuBattles) comes down
	here too: both are brought onto a free court's pads.

	The winner takes both stakes; a draw gives each back their own. Leaving
	or walking off is a loss (KaijuBattles).

	REMATCH, once it's over (KaijuBattles): both asking for one starts the
	battle again on the same court, for the same stake, taken again: the
	same coins each, or a gem each as rare as the first (your weakest loose
	one that is). Short of it, there's no rematch, and you're told why.

	Clients are told, on the Social remote:
	  "KaijuPitPad", state | nil   your pad: { Court, Side, Host (you were
	      there first), Foe, FoeId, Stake, Mode, Problem (why you can't
	      fight yet), Mine (your loose gems that could match a gem stake) }
	  "KaijuPitCross", "Down" | "Up"   a moment's cover on the stairs
	and each court's model carries what its board shows: State ("Open",
	"Waiting", "Challenged", "Battle"), AName, BName, AId, BId, Stake
	(KaijuPit.stakeText), StakeKind, StakeCoins, StakeTier, StakeElement,
	StakeGem (its name), Pot, Mode, Phase, EndsAt (server time), AShare and
	BShare (each side's kaiju's health left, 0 to 1), Winner.

	  KaijuPitServer.start(site)
	  KaijuPitServer.down(player) / up(player)   take the stairs
	  KaijuPitServer.pit() -> the hall (KaijuPitWorld.build's)

	COACH-4, the arena's guide, stands on the balcony by where you arrive:
	talk to it (E) for how battles, placing, elements and stakes work, and
	a battle tip (Shared.Vendors.ArenaGuide, Client.Dialogue).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local KaijuBattle = require(ReplicatedStorage.Shared.KaijuBattle)
local KaijuPit = require(ReplicatedStorage.Shared.KaijuPit)
local Outpost = require(ReplicatedStorage.Shared.Outpost)
local Spar = require(ReplicatedStorage.Shared.Spar)
local KaijuBattles = require(script.Parent.KaijuBattles)
local KaijuServer = require(script.Parent.KaijuServer)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Builder = require(script.Parent.Parent.World.Builder)
local KaijuPitWorld = require(script.Parent.Parent.World.KaijuPitWorld)

local reply = Shop.reply

local KaijuPitServer = {}

-- The clock (os.clock; tests replace it).
KaijuPitServer.clock = os.clock

local pit = nil -- the hall (KaijuPitWorld.build's)
local stairs = nil -- the Shelter's stairs: { Landing, Size, Top }
local below: { [Player]: boolean } = {}
local crossedAt: { [Player]: number } = {}
-- Each court's pads: Pads[side] = { Player, Since, OffAt? }; Host (the side
-- there first), Stake and Mode (the host's), Battle, Rest (players who
-- must step off before they count again), Told (what each was last told).
type CourtState = {
	Court: any,
	Pads: { [string]: any },
	Host: string?,
	Stake: any,
	Mode: string,
	Battle: any,
	Rest: { [Player]: boolean },
	Told: { [Player]: string },
}
local states: { CourtState } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function other(side: string): string
	return if side == "A" then "B" else "A"
end

-- Busy with something that keeps you off a pad.
local function busy(player: Player): boolean
	return player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
		or player:GetAttribute("RiftRun") ~= nil
		or player:GetAttribute("KaijuBattle") ~= nil
		or player:GetAttribute("SparDown") ~= nil
		or Spar.sparring(player)
end

-- What they have to stake: coins, and their loose gems by id.
local function holdings(player: Player)
	local profile = PlayerData.get(player)
	local gems = {}
	for _, gem in GemInventory.available(profile) do
		gems[tostring(gem.Id)] = gem
	end
	return { Coins = if profile then profile.Coins or 0 else 0, Gems = gems }
end

-- What a stake shows of a gem (all a client needs to draw it).
local function gemSummary(gem)
	return {
		Id = tostring(gem.Id),
		Name = GemConfig.displayName(gem),
		Tier = gem.Tier,
		Element = gem.Element,
		Size = tonumber(gem.Size),
		Clarity = tonumber(gem.Clarity),
		Cut = tonumber(gem.Cut),
	}
end

-- Stairs -------------------------------------------------------------------------------------------------

local function inBox(cframe: CFrame, size: Vector3, position: Vector3): boolean
	local p = cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= size.X / 2 and math.abs(p.Y) <= size.Y / 2 and math.abs(p.Z) <= size.Z / 2
end

local function moveTo(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(cframe)
	local root = rootOf(player)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function settle(player: Player, down: boolean)
	below[player] = if down then true else nil
	player:SetAttribute("KaijuPit", if down then true else nil)
	crossedAt[player] = KaijuPitServer.clock()
end

-- Down the stairs, onto the balcony (`to`: somewhere else down there).
function KaijuPitServer.down(player: Player, to: CFrame?): boolean
	if not pit or below[player] or not player.Parent then
		return false
	end
	if player:GetAttribute("MechPilot") ~= nil then
		Remotes.Notify:FireClient(player, "Hop out of the mech first: it won't fit down the stairs.")
		crossedAt[player] = KaijuPitServer.clock()
		return false
	end
	settle(player, true)
	Remotes.Social:FireClient(player, "KaijuPitCross", "Down")
	moveTo(player, to or pit.Arrive)
	return true
end

-- Back up, at the top of the Shelter's stairs.
function KaijuPitServer.up(player: Player): boolean
	if not below[player] then
		return false
	end
	settle(player, false)
	Remotes.Social:FireClient(player, "KaijuPitCross", "Up")
	if stairs then
		moveTo(player, stairs.Top)
	end
	return true
end

-- Pads ---------------------------------------------------------------------------------------------------

local function stateOf(courtId: number): CourtState?
	return states[courtId]
end

-- Who stands on `side` of `state`'s court now (in the pit, alive, not
-- resting there after a battle).
local function standing(state: CourtState, side: string, taken: { [Player]: boolean }): Player?
	local court = state.Court
	local keep = state.Pads[side] and state.Pads[side].Player
	-- (Whoever was there keeps it while they're on it.)
	if keep and keep.Parent and below[keep] then
		local root = rootOf(keep)
		if root and KaijuPit.padSide(court, root.Position) == side then
			return keep
		end
	end
	for _, player in Players:GetPlayers() do
		if below[player] and not taken[player] and not state.Rest[player] then
			local root = rootOf(player)
			if root and KaijuPit.padSide(court, root.Position) == side then
				return player
			end
		end
	end
	return nil
end

-- What a court's board shows (each set, or cleared when it's not in `values`).
local BOARD = {
	"State",
	"AName",
	"BName",
	"AId",
	"BId",
	"Stake",
	"StakeKind",
	"StakeCoins",
	"StakeTier",
	"StakeElement",
	"StakeGem",
	"Pot",
	"Mode",
	"Phase",
	"EndsAt",
	"AShare",
	"BShare",
	"Winner",
}
local function setBoard(state: CourtState, values)
	local model = state.Court.Model
	if not model then
		return
	end
	for _, key in BOARD do
		if model:GetAttribute(key) ~= values[key] then
			model:SetAttribute(key, values[key])
		end
	end
end

local function stakeAttributes(stake)
	return {
		Stake = KaijuPit.stakeText(stake),
		StakeKind = if stake then stake.Kind else nil,
		StakeCoins = if stake and stake.Kind == "Coins" then stake.Coins else nil,
		StakeTier = if stake and stake.Kind == "Gem" then stake.Tier else nil,
		StakeElement = if stake and stake.Kind == "Gem" then stake.Gem.Element else nil,
		StakeGem = if stake and stake.Kind == "Gem" then stake.Gem.Name else nil,
		Pot = KaijuPit.pot(stake, stake),
	}
end

-- Why `player` can't fight on a pad just now (nil: they can).
local function problemOf(player: Player): string?
	if busy(player) then
		return "Finish what you're doing first."
	elseif KaijuServer.battleable(player) <= 0 then
		-- (Down ones count: a battle brings the whole team back for itself.)
		return "You need your kaiju out to battle."
	end
	return nil
end

-- Tells each on a pad where they stand (only when it's changed).
local function tellPads(state: CourtState)
	for side, entry in state.Pads do
		local player = entry.Player
		local foeEntry = state.Pads[other(side)]
		local foe = foeEntry and foeEntry.Player
		local host = state.Host == side
		local stake = state.Stake
		local problem = problemOf(player)
		if not problem and not host and stake then
			problem = KaijuPit.matchProblem(stake, nil, holdings(player))
			if problem == "Pick one of your gems to match the stake." then
				problem = nil -- (they pick it on the card)
			end
		end
		local mine = nil
		if not host and stake and stake.Kind == "Gem" then
			mine = {}
			for _, gem in KaijuPit.matches(stake, holdings(player)) do
				table.insert(mine, gemSummary(gem))
				if #mine >= 8 then
					break
				end
			end
		end
		local card = {
			Court = state.Court.Id,
			Side = side,
			Host = host,
			Foe = if foe then foe.DisplayName else nil,
			FoeId = if foe then foe.UserId else nil,
			Stake = stake,
			Mode = state.Mode,
			Problem = problem,
			Mine = mine,
		}
		local key = string.format(
			"%d|%s|%s|%s|%s|%s|%s|%d",
			card.Court,
			side,
			tostring(host),
			tostring(card.FoeId),
			KaijuPit.stakeText(stake) .. (if stake and stake.Gem then stake.Gem.Id else ""),
			state.Mode,
			tostring(problem),
			if mine then #mine else -1
		)
		if state.Told[player] ~= key then
			state.Told[player] = key
			Remotes.Social:FireClient(player, "KaijuPitPad", card)
		end
	end
end

local function untell(state: CourtState, player: Player)
	if state.Told[player] then
		state.Told[player] = nil
		if player.Parent then
			Remotes.Social:FireClient(player, "KaijuPitPad", nil)
		end
	end
end

-- The board when nobody's battling: who's waiting, for what.
local function drawWaiting(state: CourtState)
	local a, b = state.Pads.A, state.Pads.B
	local values = stakeAttributes(state.Stake)
	values.State = if a and b then "Challenged" elseif a or b then "Waiting" else "Open"
	values.Mode = if a or b then state.Mode else nil
	values.AName = if a then a.Player.DisplayName else nil
	values.BName = if b then b.Player.DisplayName else nil
	values.AId = if a then a.Player.UserId else nil
	values.BId = if b then b.Player.UserId else nil
	if not a and not b then
		values.Stake, values.Pot = nil, nil
	end
	setBoard(state, values)
end

local function stepPads(state: CourtState, now: number, taken: { [Player]: boolean })
	-- (Resting after a battle: counted again once they're off the pads.)
	for player in state.Rest do
		local root = rootOf(player)
		if not player.Parent or not root or not KaijuPit.padSide(state.Court, root.Position) then
			state.Rest[player] = nil
		end
	end
	for _, side in { "A", "B" } do
		local here = standing(state, side, taken)
		local entry = state.Pads[side]
		if here then
			taken[here] = true
			if entry and entry.Player == here then
				entry.OffAt = nil
			else
				if entry then
					untell(state, entry.Player)
				end
				state.Pads[side] = { Player = here, Since = now }
			end
		elseif entry then
			entry.OffAt = entry.OffAt or now
			if now - entry.OffAt >= KaijuPit.Grace or not entry.Player.Parent or not below[entry.Player] then
				untell(state, entry.Player)
				state.Pads[side] = nil
			else
				taken[entry.Player] = true
			end
		end
	end
	-- The host: whoever was there first. Their stake and mode go with them.
	if state.Host and not state.Pads[state.Host] then
		state.Stake, state.Mode = nil, "Kaiju"
	end
	local a, b = state.Pads.A, state.Pads.B
	state.Host = if a and b then (if a.Since <= b.Since then "A" else "B") elseif a then "A" elseif b then "B" else nil
	tellPads(state)
	drawWaiting(state)
end

-- The battle on a court: its board, and the court freed once it's gone.
local function stepBattle(state: CourtState)
	local battle = state.Battle
	if KaijuBattles.of(battle.A) ~= battle and KaijuBattles.of(battle.B) ~= battle then
		-- (Its stake and mode go with it: the next to wait sets their own.)
		state.Battle, state.Stake, state.Mode = nil, nil, "Kaiju"
		return
	end
	local values = stakeAttributes(state.Stake)
	values.State = "Battle"
	values.Mode = battle.Mode
	values.Phase = battle.Phase
	values.EndsAt = serverNow() + (battle.EndsAt - KaijuBattles.clock())
	values.AName, values.BName = battle.A.DisplayName, battle.B.DisplayName
	values.AId, values.BId = battle.A.UserId, battle.B.UserId
	local shares = KaijuBattles.shares(battle)
	values.AShare, values.BShare = shares.A, shares.B
	values.Winner = if battle.Result
		then (if battle.Result[battle.A] == "Win"
			then battle.A.DisplayName
			elseif battle.Result[battle.B] == "Win" then battle.B.DisplayName
			else "Draw")
		else nil
	setBoard(state, values)
end

local function step(now: number)
	if not pit then
		return
	end
	-- The stairs, both ways.
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and player:GetAttribute("Outpost") == true then
			local rested = now - (crossedAt[player] or -math.huge) >= 2
			if below[player] then
				-- (Back up only by the door's prompt: exitPrompt. Walking
				-- into the doorway did it, and players backed into it by
				-- accident, mid-battle too.)
				if not KaijuPit.inHall(pit.Origin, root.Position) then
					-- (Somewhere else now: a respawn, the Rift.)
					settle(player, false)
				end
			elseif rested and stairs and inBox(stairs.Landing, stairs.Size, root.Position) then
				KaijuPitServer.down(player)
			end
		elseif below[player] then
			settle(player, false)
		end
	end
	local taken = {}
	for _, state in states do
		if state.Battle then
			stepBattle(state)
		end
		if not state.Battle then
			stepPads(state, now, taken)
		end
	end
end

-- Requests -----------------------------------------------------------------------------------------------

-- The court `player` is on a pad of, and their side.
local function padOf(player: Player): (CourtState?, string?)
	for _, state in states do
		for side, entry in state.Pads do
			if entry.Player == player then
				return state, side
			end
		end
	end
	return nil, nil
end

local function setStake(player: Player, wanted: any)
	local state, side = padOf(player)
	if not state or state.Battle then
		return reply(false, "Stand on a pad first.")
	end
	if state.Host ~= side then
		return reply(false, "The one who was waiting sets the stake.")
	end
	local stake = nil
	if type(wanted) == "table" then
		if wanted.Kind == "Coins" then
			stake = { Kind = "Coins", Coins = tonumber(wanted.Coins) }
		elseif wanted.Kind == "Gem" then
			local gem = holdings(player).Gems[tostring(wanted.GemId)]
			if not gem then
				return reply(false, "That gem isn't loose in your pouch.")
			end
			stake = { Kind = "Gem", Tier = gem.Tier, Gem = gemSummary(gem) }
		else
			return reply(false, "That isn't a stake.")
		end
	elseif wanted ~= nil then
		return reply(false, "That isn't a stake.")
	end
	local problem = KaijuPit.stakeProblem(stake, holdings(player))
	if problem then
		if stake and stake.Kind == "Coins" and (holdings(player).Coins or 0) < (stake.Coins or 0) then
			return Shop.short(player, stake.Coins, problem)
		end
		return reply(false, problem)
	end
	state.Stake = stake
	tellPads(state)
	drawWaiting(state)
	return reply(true, "")
end

-- The host picks the mode: the kaiju alone, or 1V1 + KAIJU (while it's on:
-- Shared.KaijuBattle.offered).
local function setMode(player: Player, wanted: any)
	local state, side = padOf(player)
	if not state or state.Battle then
		return reply(false, "Stand on a pad first.")
	end
	if state.Host ~= side then
		return reply(false, "The one who was waiting picks the mode.")
	end
	if type(wanted) ~= "string" or KaijuBattle.mode(wanted) ~= wanted then
		return reply(false, "That isn't a mode.")
	end
	state.Mode = KaijuBattle.mode(wanted)
	tellPads(state)
	drawWaiting(state)
	return reply(true, "")
end

-- Takes a stake into the pot (coins spent, the gem out of the pouch).
-- Returns what was taken, or nil.
local function take(player: Player, stake, gemId: string?)
	if stake == nil then
		return { Kind = "None" }
	elseif stake.Kind == "Coins" then
		return if PlayerData.spendCoins(player, stake.Coins, "KaijuBet") then { Kind = "Coins", Coins = stake.Coins } else nil
	end
	local id = gemId or stake.Gem.Id
	if not holdings(player).Gems[id] then
		return nil
	end
	local gem = PlayerData.removeGem(player, id)
	return if gem then { Kind = "Gem", Gem = gem } else nil
end

-- Gives a stake back (or to the winner).
local function give(player: Player, held)
	if not held or not player.Parent then
		return
	end
	if held.Kind == "Coins" then
		PlayerData.addCoins(player, held.Coins, "KaijuBet")
	elseif held.Kind == "Gem" then
		PlayerData.returnGem(player, held.Gem)
	end
end

local function fight(player: Player, offer: any)
	local state, side = padOf(player)
	if not state or state.Battle or not side then
		return reply(false, "Stand on a pad across from someone first.")
	end
	local hostSide = state.Host
	if hostSide == side or not hostSide then
		return reply(false, "Wait for a challenger to step up.")
	end
	local hostEntry = state.Pads[hostSide]
	local host = hostEntry and hostEntry.Player
	if not host or hostEntry.OffAt then
		return reply(false, "They've stepped off.")
	end
	local problem = problemOf(player) or problemOf(host)
	if problem then
		return reply(false, if problemOf(player) then problem else host.DisplayName .. " can't battle just now.")
	end
	local stake = state.Stake
	local gemId = if type(offer) == "string" then offer else nil
	problem = KaijuPit.matchProblem(stake, gemId, holdings(player))
	if problem then
		if stake and stake.Kind == "Coins" and (holdings(player).Coins or 0) < (stake.Coins or 0) then
			return Shop.short(player, stake.Coins, problem)
		end
		return reply(false, problem)
	end
	-- Both stakes in.
	local hostHeld = take(host, stake, nil)
	if not hostHeld then
		state.Stake = nil
		tellPads(state)
		return reply(false, host.DisplayName .. " can't cover their stake any more.")
	end
	local mineHeld = take(player, stake, gemId)
	if not mineHeld then
		give(host, hostHeld)
		return reply(false, "You can't cover the stake.")
	end
	local a = if hostSide == "A" then host else player
	local b = if hostSide == "A" then player else host
	local held = { [host] = hostHeld, [player] = mineHeld }
	local battle = KaijuBattles.beginOn(a, b, state.Court, { Stake = stake, Held = held }, state.Mode)
	if not battle then
		give(host, hostHeld)
		give(player, mineHeld)
		return reply(false, "Couldn't start the battle.")
	end
	state.Battle = battle
	for _, entry in state.Pads do
		untell(state, entry.Player)
		state.Rest[entry.Player] = true
	end
	table.clear(state.Pads)
	state.Host = nil
	stepBattle(state)
	Remotes.Notify:FireClient(host, player.DisplayName .. " stepped up. Place your kaiju!")
	return reply(true, "")
end

-- A battle's over: the stakes to the winner (each back their own in a draw).
local function payOut(battle, winner: string)
	local pot = battle.Pot
	if not pot or not pot.Held then
		return
	end
	local a, b = battle.A, battle.B
	local heldA, heldB = pot.Held[a], pot.Held[b]
	if winner == "Draw" then
		give(a, heldA)
		give(b, heldB)
		return
	end
	local won = if winner == "A" then a else b
	local lost = if winner == "A" then b else a
	give(won, heldA)
	give(won, heldB)
	local spoils = pot.Held[lost]
	if spoils and spoils.Kind == "Coins" then
		Remotes.Notify:FireClient(won, string.format("You won %d coins!", spoils.Coins * 2))
		Remotes.Notify:FireClient(lost, string.format("You lost your %d coins.", spoils.Coins))
	elseif spoils and spoils.Kind == "Gem" then
		Remotes.Notify:FireClient(
			won,
			string.format("You won %s's %s!", lost.DisplayName, GemConfig.displayName(spoils.Gem))
		)
		Remotes.Notify:FireClient(
			lost,
			string.format("%s took your %s.", won.DisplayName, GemConfig.displayName(spoils.Gem))
		)
	end
	battle.Spoils = if spoils and spoils.Kind == "Gem" then gemSummary(spoils.Gem) else nil
end

-- What a rematch would take of `player`'s, for the result card: the same
-- coins, or the gem of theirs that would go in (nil: nothing staked).
local function rematchPick(stake, player: Player)
	if not stake then
		return nil
	elseif stake.Kind == "Coins" then
		return { Kind = "Coins", Coins = stake.Coins }
	end
	local gem = KaijuPit.matches(stake, holdings(player))[1]
	return if gem then { Kind = "Gem", Gem = gem } else false
end

local function rematchCost(battle, player: Player): string?
	local stake = battle.Pot and battle.Pot.Stake
	local pick = rematchPick(stake, player)
	if pick == nil then
		return nil
	elseif pick == false then
		-- ("NO RARE GEM LEFT")
		return "NO " .. string.upper((string.gsub(KaijuPit.stakeText(stake), "^an? ", ""))) .. " LEFT"
	elseif pick.Kind == "Coins" then
		return string.format("%d COINS", pick.Coins)
	end
	return string.upper(GemConfig.displayName(pick.Gem))
end

-- Both asked for a rematch: the stake taken again from each, then the
-- battle again on the same court (KaijuBattles.again).
local function rematchOn(battle)
	local state = battle.Court and states[battle.Court.Id]
	if not state then
		return nil, "The court's gone."
	end
	local stake = battle.Pot and battle.Pot.Stake
	local a, b = battle.A, battle.B
	local held = {}
	for _, player in { a, b } do
		local pick = rematchPick(stake, player)
		local taken = nil
		if pick == nil then
			taken = { Kind = "None" }
		elseif pick then
			taken = take(player, stake, if pick.Kind == "Gem" then tostring(pick.Gem.Id) else nil)
		end
		if not taken then
			for who, back in held do
				give(who, back)
			end
			return nil, player.DisplayName .. " can't cover the stake."
		end
		held[player] = taken
	end
	-- (A gem stake shows the blue side's gem on the board, as the first did the host's.)
	local shown = stake
	if stake and stake.Kind == "Gem" and held[a].Gem then
		shown = { Kind = "Gem", Tier = stake.Tier, Gem = gemSummary(held[a].Gem) }
	end
	local new = KaijuBattles.again(battle, { Stake = shown, Held = held })
	if not new then
		for who, back in held do
			give(who, back)
		end
		return nil, "The rematch couldn't start."
	end
	state.Battle = new
	state.Stake = shown
	stepBattle(state)
	return new, nil
end

-- A free court for a battle asked for from a player's card: both brought
-- down onto its pads (nil: every court's taken).
local function courtFor(a: Player, b: Player)
	for _, state in states do
		if not state.Battle and not next(state.Pads) then
			local court = state.Court
			for _, entry in { { a, court.PadA, court.PadB }, { b, court.PadB, court.PadA } } do
				local player, pad, facing = entry[1], entry[2], entry[3]
				local at = CFrame.lookAt(pad + Vector3.new(0, 3, 0), Vector3.new(facing.X, pad.Y + 3, facing.Z))
				if below[player] then
					moveTo(player, at)
				else
					KaijuPitServer.down(player, at)
				end
				state.Rest[player] = true
			end
			return court
		end
	end
	return nil
end

function KaijuPitServer.pit()
	return pit
end

function KaijuPitServer.start(site, world)
	stairs = site and site.Stairs
	local origin = KaijuPit.origin(Outpost.Location)
	pit = (world or KaijuPitWorld).build(origin, workspace)
	if pit.Guide and pit.Folder then
		Builder.vendor(pit.Folder, pit.Guide, "ArenaGuide", Vendors.ArenaGuide)
	end
	table.clear(states)
	for _, court in pit.Courts do
		states[court.Id] = { Court = court, Pads = {}, Rest = {}, Told = {}, Mode = "Kaiju" }
		setBoard(states[court.Id], { State = "Open" })
	end
	KaijuBattles.findCourt = courtFor
	KaijuBattles.onOver = payOut
	KaijuBattles.rematchOn = rematchOn
	KaijuBattles.rematchCost = rematchCost
	KaijuBattles.inPit = function(player: Player): boolean
		return below[player] == true
	end
	-- The way up: the door's prompt (GO UPSTAIRS), held on purpose. Not in
	-- the middle of a kaiju battle: finish it (or its own forfeit) first.
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("PromptKind") ~= "KaijuPitExit" or not below[player] then
			return
		end
		if player:GetAttribute("KaijuBattle") ~= nil then
			Remotes.Notify:FireClient(player, "You're in a kaiju battle: finish it first.")
			return
		end
		KaijuPitServer.up(player)
	end)
	Shop.register("KaijuPitStake", setStake)
	Shop.register("KaijuPitFight", fight)
	Shop.register("KaijuPitMode", setMode)
	Players.PlayerRemoving:Connect(function(player)
		below[player], crossedAt[player] = nil, nil
		for _, state in states do
			state.Rest[player], state.Told[player] = nil, nil
		end
	end)
	local function watch(player: Player)
		local added = (player :: any).CharacterAdded
		if added then
			added:Connect(function()
				-- (A new body's at the spawn: not downstairs any more.)
				if below[player] then
					settle(player, false)
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- The server shutting down mid-battle: every stake back.
	pcall(function()
		game:BindToClose(function()
			for _, state in states do
				local battle = state.Battle
				if battle and battle.Pot and battle.Pot.Held and battle.Phase ~= "Over" then
					for player, held in battle.Pot.Held do
						give(player, held)
					end
					battle.Pot.Held = nil
				end
			end
		end)
	end)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer < 0.25 then
			return
		end
		timer = 0
		local ok, err = pcall(step, KaijuPitServer.clock())
		if not ok then
			warn("[KaijuPitServer] step:", err)
		end
	end)
end

-- For tests.
KaijuPitServer._step, KaijuPitServer._states, KaijuPitServer._stateOf = step, states, stateOf
KaijuPitServer._stake, KaijuPitServer._fight, KaijuPitServer._courtFor = setStake, fight, courtFor
KaijuPitServer._mode = setMode

return KaijuPitServer
