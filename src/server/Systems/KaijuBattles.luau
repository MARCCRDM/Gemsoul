--[[
	Kaiju battles in the Outpost (Shared.KaijuBattle has the rules): two
	players set their kaiju teams against each other, place them in a
	formation, and the kaiju fight it out by themselves. Requests:

	  "KaijuBattleAsk", userId              ask someone near you
	  "KaijuBattleRespond", userId, accept  answer someone who asked you
	  "KaijuBattleFormation", { [kaijuId]: cellId }   where yours stand
	                                        (in the formation phase)
	  "KaijuBattleReady"                    ready: both ready starts it early
	  "KaijuBattleLeave"                    leave it (the other side wins);
	                                        once it's over, close it
	  "KaijuBattleRematch"                  once it's over: again? Both
	                                        saying so before it closes
	                                        (KaijuBattle.OverSeconds) starts
	                                        a new one, the same two on the
	                                        same sides, same court and stake

	The Social remote tells clients:
	  "KaijuBattleAsk", fromId, fromName, seconds   someone asks you
	  "KaijuBattleAskOver", fromId          that ask is gone: take its card down
	  "KaijuBattle", state | nil            the battle you're in, as it stands
	                                        (nil: it's over and gone). state =
	                                        { Id, Phase, EndsAt (server time),
	                                        Side ("A" | "B"), Foe (their name),
	                                        Center, Axis, Mine ({ [id]: cell }),
	                                        Theirs ({ [id]: cell }, once it
	                                        starts), Units ({ Side, Id, Name,
	                                        Species, Element, Model }), Ready
	                                        ({ A, B }), Result ("Win" | "Lose" |
	                                        "Draw", and Exp, once it's over),
	                                        Rematch (once it's over: { A, B
	                                        (who's asked for one), Off (why
	                                        there can't be one), Cost (what
	                                        it'd take of yours) }) }

	Players in one carry the KaijuBattle attribute (its Id). Their kaiju
	do as KaijuServer.battle says: stand at their places through the
	formation phase, then fight the other side's by their roles, as an
	auto battler's pieces (Server.KaijuBattleBrain, Shared.KaijuRoles). A
	battle ends when one side's kaiju
	are all down, when time's up, or when one of the two leaves the
	Outpost, walks off past KaijuBattle.Leash, or leaves the game (the
	other wins). It's fought at full health and leaves every kaiju as it
	was: each side's whole team is brought to full for it (the knocked out
	too, KaijuServer.battleStart), and once it's over each kaiju goes back
	to the health it had before, win or lose (KaijuServer.battleEnd).

	The Kaiju Arena downstairs (Server.KaijuPitServer) sets:
	  KaijuBattles.findCourt(a, b) -> court?   a free court for a battle
	      asked for from a card, both brought down onto its pads (nil:
	      every court's taken)
	  KaijuBattles.onOver(battle, winner)   the stakes paid out
	  KaijuBattles.inPit(player) -> boolean   still downstairs
	  KaijuBattles.rematchOn(battle) -> (battle?, problem?)   a rematch on
	      its court: the stake taken again, then KaijuBattles.again
	  KaijuBattles.rematchCost(battle, player) -> string?   what one would
	      take of theirs ("250 COINS", or the gem)
	and starts the ones on its pads itself: KaijuBattles.beginOn(a, b,
	court, pot). On a court the field is the court's (Shared.KaijuPit), and
	the kaiju are kept inside its rails (orders' Bounds).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuBattle = require(ReplicatedStorage.Shared.KaijuBattle)
local KaijuPit = require(ReplicatedStorage.Shared.KaijuPit)
local KaijuRoles = require(ReplicatedStorage.Shared.KaijuRoles)
local Spar = require(ReplicatedStorage.Shared.Spar)
local KaijuServer = require(script.Parent.KaijuServer)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local KaijuBattles = {}

-- The clock (os.clock; tests replace it).
KaijuBattles.clock = os.clock

type Battle = {
	Id: string,
	A: Player,
	B: Player,
	Field: KaijuBattle.Field,
	Phase: string, -- "Formation" | "Battle" | "Over"
	EndsAt: number,
	Formation: { [Player]: { [string]: string } },
	Ready: { [Player]: boolean },
	Brought: { [Player]: { [string]: number } }, -- kaiju id -> its MaxHealth
	Names: { [Player]: { [string]: string } },
	Bounds: any, -- what its kaiju keep inside (Shared.KaijuRoles.clamp)
	Result: { [Player]: string }?,
	Court: any?, -- the Kaiju Arena's court it's on (Shared.KaijuPit)
	Pot: any?, -- { Stake, Held }: what each put in (Server.KaijuPitServer)
	Spoils: any?, -- the gem the winner took, if any
	Rematch: { [Player]: boolean }, -- once it's over: who's asked for one
	RematchOff: string?, -- why there can't be one (one left, short of the stake)
}

-- The Kaiju Arena's hooks (Server.KaijuPitServer sets them).
KaijuBattles.findCourt = nil :: ((Player, Player) -> any)?
KaijuBattles.onOver = nil :: ((any, string) -> ())?
KaijuBattles.inPit = nil :: ((Player) -> boolean)?
KaijuBattles.rematchOn = nil :: ((any) -> (any?, string?))?
KaijuBattles.rematchCost = nil :: ((any, Player) -> string?)?

local battleOf: { [Player]: Battle } = {}
local nextId = 0
-- Open asks: asks[target][from] = when it runs out; again[from][target]
-- = when you can ask them again; lastAsk[from] = your last ask.
local asks: { [Player]: { [Player]: number } } = {}
local again: { [Player]: { [Player]: number } } = {}
local lastAsk: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function byUserId(userId: any): Player?
	return if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function sideOf(battle: Battle, player: Player): string
	return if battle.A == player then "A" else "B"
end

local function foeOf(battle: Battle, player: Player): Player
	return if battle.A == player then battle.B else battle.A
end

-- A player's kaiju out and up (brought to the battle: all of the team,
-- once KaijuServer.battleStart has them up).
local function upOf(player: Player): { any }
	local list = {}
	for _, pet in KaijuServer.team(player) do
		if pet.Model.Parent and pet.Humanoid.Health > 0 then
			table.insert(list, pet)
		end
	end
	return list
end

-- A side's kaiju in the battle, still up.
local function petsIn(battle: Battle, player: Player): { any }
	local list = {}
	for _, pet in upOf(player) do
		if battle.Brought[player][pet.Record.Id] then
			table.insert(list, pet)
		end
	end
	return list
end

-- Busy with something else: a fight, a match, a spar, a hunt.
local function busy(player: Player): boolean
	return player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
		or player:GetAttribute("RiftRun") ~= nil
		or Spar.sparring(player)
		or Spar.hunting(player)
end

local function distance(a: Player, b: Player): number
	local ra, rb = rootOf(a), rootOf(b)
	return if ra and rb then (ra.Position - rb.Position).Magnitude else math.huge
end

-- The battle as `player` sees it (the Social remote's "KaijuBattle").
local function stateFor(battle: Battle, player: Player)
	local foe = foeOf(battle, player)
	local started = battle.Phase ~= "Formation"
	local units = {}
	for _, who in { battle.A, battle.B } do
		if who == player or started then
			for _, pet in KaijuServer.team(who) do
				if battle.Brought[who][pet.Record.Id] then
					table.insert(units, {
						Side = sideOf(battle, who),
						Id = pet.Record.Id,
						Name = Kaiju.nameOf(pet.Record),
						Species = pet.Record.Species,
						Element = pet.Record.Element,
						Model = pet.Model,
					})
				end
			end
		end
	end
	local result = battle.Result and battle.Result[player]
	local stake = battle.Pot and battle.Pot.Stake
	return {
		Id = battle.Id,
		Court = if battle.Court then battle.Court.Id else nil,
		Stake = stake,
		Pot = if battle.Pot then KaijuPit.pot(stake, stake) else nil,
		Restored = result ~= nil, -- (every kaiju back as it was: the result card says so)
		Spoils = if result == "Win" then battle.Spoils else nil,
		Phase = battle.Phase,
		EndsAt = serverNow() + (battle.EndsAt - KaijuBattles.clock()),
		Side = sideOf(battle, player),
		Foe = foe.DisplayName,
		Center = battle.Field.Center,
		Axis = battle.Field.Axis,
		Mine = battle.Formation[player],
		Theirs = if started then battle.Formation[foe] else nil,
		Units = units,
		Ready = { A = battle.Ready[battle.A] == true, B = battle.Ready[battle.B] == true },
		Result = result,
		Exp = if result
			then KaijuBattle.Exp[if result == "Win" then "Win" elseif result == "Lose" then "Lose" else "Draw"]
			else nil,
		Rematch = if result
			then {
				A = battle.Rematch[battle.A] == true,
				B = battle.Rematch[battle.B] == true,
				Off = battle.RematchOff,
				Cost = if battle.Pot and KaijuBattles.rematchCost
					then KaijuBattles.rematchCost(battle, player)
					else nil,
			}
			else nil,
	}
end

local function tell(battle: Battle)
	for _, player in { battle.A, battle.B } do
		-- (Not one who's closed it: they're done with it.)
		if player.Parent and battleOf[player] == battle then
			Remotes.Social:FireClient(player, "KaijuBattle", stateFor(battle, player))
		end
	end
end

-- Asks ---------------------------------------------------------------------------------------------------

local function askProblem(player: Player, target: Player?, answering: boolean): string?
	if not target or target == player or not target.Parent then
		return KaijuBattle.askProblem({ Here = false, Name = "" })
	end
	if player:GetAttribute("Outpost") ~= true or target:GetAttribute("Outpost") ~= true then
		return KaijuBattle.askProblem({ Here = false, Name = target.DisplayName })
	end
	local waits = again[player]
	return KaijuBattle.askProblem({
		Here = true,
		Name = target.DisplayName,
		Distance = distance(player, target),
		Mine = KaijuServer.battleable(player),
		Theirs = KaijuServer.battleable(target),
		MyBattle = battleOf[player] ~= nil,
		TheirBattle = battleOf[target] ~= nil,
		Busy = busy(player),
		TheirBusy = busy(target),
		Asked = not answering and asks[target] ~= nil and asks[target][player] ~= nil,
		Wait = if not answering and waits and waits[target] then waits[target] - KaijuBattles.clock() else nil,
	})
end

-- Every ask to or from `player` taken down (they're in a battle now, or gone).
local function dropAsks(player: Player)
	for from in asks[player] or {} do
		if from.Parent then
			Remotes.Social:FireClient(player, "KaijuBattleAskOver", from.UserId)
		end
	end
	asks[player] = nil
	for target, pending in asks do
		if pending[player] then
			pending[player] = nil
			if target.Parent then
				Remotes.Social:FireClient(target, "KaijuBattleAskOver", player.UserId)
			end
		end
	end
end

-- Both agreed: the field (a court's, or between them), each one's whole
-- team brought at full health (KaijuServer.battleStart), each in its
-- default place (on a court, put there at once).
local function begin(a: Player, b: Player, court: any?, pot: any?): Battle?
	local ra, rb = rootOf(a), rootOf(b)
	if not ra or not rb then
		return nil
	end
	nextId += 1
	local battle: Battle = {
		Id = "KB" .. nextId,
		A = a,
		B = b,
		Court = court,
		Pot = pot,
		Field = if court
			then KaijuPit.field(court)
			else KaijuBattle.field(
				ra.Position - Vector3.new(0, ra.Size.Y / 2 + 1.5, 0),
				rb.Position - Vector3.new(0, rb.Size.Y / 2 + 1.5, 0)
			),
		Phase = "Formation",
		EndsAt = KaijuBattles.clock() + KaijuBattle.FormationSeconds,
		Formation = {},
		Ready = {},
		Brought = {},
		Names = {},
		Rematch = {},
	}
	-- What its kaiju keep inside: the court, or a court's size round the field.
	battle.Bounds = court or KaijuRoles.fieldBounds(battle.Field, KaijuPit.Court.HalfLength, KaijuPit.Court.HalfWidth)
	for _, player in { a, b } do
		battleOf[player] = battle
		player:SetAttribute("KaijuBattle", battle.Id)
		KaijuServer.battleStart(player)
	end
	for _, player in { a, b } do
		local records = {}
		battle.Brought[player], battle.Names[player] = {}, {}
		for _, pet in upOf(player) do
			table.insert(records, pet.Record)
			battle.Brought[player][pet.Record.Id] = pet.Humanoid.MaxHealth
			battle.Names[player][pet.Record.Id] = Kaiju.nameOf(pet.Record)
			pet.Target = nil
			-- (Its side, for its ring in the side's colour: Client.KaijuTeamRings.)
			pet.Model:SetAttribute("KaijuTeam", sideOf(battle, player))
		end
		battle.Formation[player] = KaijuBattle.defaultFormation(records)
		dropAsks(player)
		if court then
			local side = sideOf(battle, player)
			local look = KaijuBattle.facing(battle.Field, side)
			for _, pet in upOf(player) do
				local spot = KaijuServer.ground(
					KaijuBattle.cellSpot(battle.Field, side, battle.Formation[player][pet.Record.Id])
				)
				KaijuServer.place(pet.Model, spot, spot + look)
			end
		end
	end
	tell(battle)
	return battle
end

-- Two agreed on the card: down to a court of the Kaiju Arena if there's
-- one, else (no arena) the field between them.
local function agreed(a: Player, b: Player): (Battle?, string?)
	if KaijuBattles.findCourt then
		local court = KaijuBattles.findCourt(a, b)
		if not court then
			return nil, "Every court in the Kaiju Arena is taken. Try again in a moment."
		end
		return begin(a, b, court), nil
	end
	return begin(a, b), nil
end

-- A battle on a court of the Kaiju Arena, its pot in (Server.KaijuPitServer).
function KaijuBattles.beginOn(a: Player, b: Player, court: any, pot: any?): Battle?
	if battleOf[a] or battleOf[b] or KaijuServer.battleable(a) == 0 or KaijuServer.battleable(b) == 0 then
		return nil
	end
	return begin(a, b, court, pot)
end

local function ask(player: Player, userId: any)
	local target = byUserId(userId)
	local now = KaijuBattles.clock()
	if lastAsk[player] and now - lastAsk[player] < KaijuBattle.AskGap then
		return reply(false, "One moment.")
	end
	-- They asked you first: asking back is a yes.
	local theirs = if target and asks[player] then asks[player][target] else nil
	local answering = theirs ~= nil and theirs > now
	local problem = askProblem(player, target, answering)
	if problem then
		return reply(false, problem)
	end
	lastAsk[player] = now
	local to = target :: Player
	if answering then
		local battle, why = agreed(to, player)
		if not battle then
			return reply(false, why or "Couldn't start the battle.")
		end
		Remotes.Notify:FireClient(to, player.DisplayName .. " accepted. Place your kaiju!")
		return reply(true, "")
	end
	asks[to] = asks[to] or {}
	asks[to][player] = now + KaijuBattle.AskSeconds
	Remotes.Social:FireClient(to, "KaijuBattleAsk", player.UserId, player.DisplayName, KaijuBattle.AskSeconds)
	return reply(true, "Asked " .. to.DisplayName .. " to a kaiju battle.")
end

local function respond(player: Player, userId: any, accept: any)
	local from = byUserId(userId)
	local pending = asks[player]
	local expiry = from and pending and pending[from]
	if pending and from then
		pending[from] = nil
	end
	if not from or not expiry or KaijuBattles.clock() > expiry then
		return reply(false, "That request has expired.")
	end
	if accept ~= true then
		again[from] = again[from] or {}
		again[from][player] = KaijuBattles.clock() + KaijuBattle.AskAgain
		Remotes.Notify:FireClient(from, player.DisplayName .. " said no to a kaiju battle.")
		return reply(true, "")
	end
	local problem = askProblem(player, from, true) or askProblem(from, player, true)
	if problem then
		return reply(false, problem)
	end
	local battle, why = agreed(from, player)
	if not battle then
		return reply(false, why or "Couldn't start the battle.")
	end
	Remotes.Notify:FireClient(from, player.DisplayName .. " accepted. Place your kaiju!")
	return reply(true, "")
end

-- The battle --------------------------------------------------------------------------------------------

-- What a pet in a battle does (KaijuServer.battle): in the formation
-- phase, stand at its place; then fight by its role (Server.
-- KaijuBattleBrain): its side's and the other side's kaiju still up, and
-- the court (or a court's size round the field) to keep inside. Foe: the
-- one it's on (or, before it's picked one, the nearest).
local function orders(pet, now: number)
	local battle = battleOf[pet.Owner]
	if not battle or battle.Phase == "Over" or not battle.Brought[pet.Owner][pet.Record.Id] then
		return nil
	end
	local player = pet.Owner
	local side = sideOf(battle, player)
	local look = KaijuBattle.facing(battle.Field, side)
	local cell = battle.Formation[player][pet.Record.Id]
	local spot = KaijuServer.ground(KaijuBattle.cellSpot(battle.Field, side, cell or "FrontCentre"))
	if battle.Phase == "Formation" then
		return { Spot = spot, Look = look }
	end
	local foes = petsIn(battle, foeOf(battle, player))
	local foe = pet.Brain and pet.Brain.Target
	if not foe or not table.find(foes, foe) then
		local best = math.huge
		foe = nil
		for _, other in foes do
			local d = (other.Root.Position - pet.Root.Position).Magnitude
			if d < best then
				foe, best = other, d
			end
		end
	end
	return {
		Fighting = true,
		Foe = foe,
		Foes = foes,
		Allies = petsIn(battle, player),
		Spot = spot,
		Look = look,
		Bounds = battle.Bounds,
	}
end

-- A side's { Up, Share }: kaiju still up, and the health they have left
-- over all they brought.
local function standing(battle: Battle, player: Player)
	local most, left = 0, 0
	for _, max in battle.Brought[player] do
		most += max
	end
	local up = petsIn(battle, player)
	for _, pet in up do
		left += pet.Humanoid.Health
	end
	return { Up = #up, Share = if most > 0 then left / most else 0 }
end

-- Each side's kaiju's health left, 0 to 1 (the arena's boards).
function KaijuBattles.shares(battle: Battle)
	return { A = standing(battle, battle.A).Share, B = standing(battle, battle.B).Share }
end

-- Over: the result to both, EXP to every kaiju of theirs still out, then
-- every kaiju back as it was before (KaijuServer.battleEnd), the stakes
-- paid out (the arena's).
local function finish(battle: Battle, winner: string, reason: string?)
	if battle.Phase == "Over" then
		return
	end
	battle.Phase = "Over"
	battle.EndsAt = KaijuBattles.clock() + KaijuBattle.OverSeconds
	if KaijuBattles.onOver then
		local ok, err = pcall(KaijuBattles.onOver, battle, winner)
		if not ok then
			warn("[KaijuBattles] onOver:", err)
		end
	end
	battle.Result = {}
	for _, player in { battle.A, battle.B } do
		local side = sideOf(battle, player)
		local result = if winner == "Draw" then "Draw" elseif winner == side then "Win" else "Lose"
		battle.Result[player] = result
		if player.Parent then
			KaijuServer.reward(player, KaijuBattle.Exp[result])
			if result == "Win" then
				PlayerData.count(player, "KaijuWins") -- (the Hall of Fame's KAIJU BATTLES)
			end
			KaijuServer.battleEnd(player)
			local foe = foeOf(battle, player)
			-- XP for you too, by the other player's level against yours
			-- (Shared.Levelling: the same one beaten again soon, less).
			if foe.Parent then
				Progress.won(player, if result == "Win" then "KaijuWin" else "KaijuPlay", Progress.levelOf(foe), nil, foe)
			end
			local line = if result == "Win"
				then string.format("Your kaiju beat %s's!", foe.DisplayName)
				elseif result == "Lose" then string.format("%s's kaiju won the battle.", foe.DisplayName)
				else string.format("A draw with %s's kaiju.", foe.DisplayName)
			if reason == "Left" and result == "Win" then
				line = string.format("%s left the battle: you win!", foe.DisplayName)
			end
			Remotes.Notify:FireClient(player, line)
		end
	end
	tell(battle)
end

-- One of them done with it: their kaiju back as they were before it (if
-- finish hasn't already).
local function release(battle: Battle, player: Player)
	if battleOf[player] == battle then
		battleOf[player] = nil
	end
	for _, pet in KaijuServer.team(player) do
		pet.Model:SetAttribute("KaijuTeam", nil)
	end
	if player.Parent then
		KaijuServer.battleEnd(player)
		player:SetAttribute("KaijuBattle", nil)
		Remotes.Social:FireClient(player, "KaijuBattle", nil)
	end
end

-- Gone: both free again, their kaiju back beside them, as they were.
local function close(battle: Battle)
	for _, player in { battle.A, battle.B } do
		release(battle, player)
	end
end

-- Still fit to battle: here, in the Outpost (downstairs, for a court),
-- on their feet, near the field.
local function present(battle: Battle, player: Player): boolean
	if not player.Parent or player:GetAttribute("Outpost") ~= true then
		return false
	end
	if battle.Court and KaijuBattles.inPit and not KaijuBattles.inPit(player) then
		return false
	end
	local root = rootOf(player)
	if not root then
		return false
	end
	local away = Vector3.new(root.Position.X - battle.Field.Center.X, 0, root.Position.Z - battle.Field.Center.Z)
	return away.Magnitude <= KaijuBattle.Leash
end

-- Each kaiju of a side put at its place, facing the other side (the
-- battle starts square).
local function line(battle: Battle, player: Player)
	local side = sideOf(battle, player)
	local look = KaijuBattle.facing(battle.Field, side)
	for _, pet in petsIn(battle, player) do
		local cell = battle.Formation[player][pet.Record.Id] or "FrontCentre"
		local spot = KaijuServer.ground(KaijuBattle.cellSpot(battle.Field, side, cell))
		KaijuServer.place(pet.Model, spot, spot + look)
	end
end

function KaijuBattles.step(battle: Battle, now: number)
	if battle.Phase == "Over" then
		if now >= battle.EndsAt then
			close(battle)
		end
		return
	end
	-- One of them gone or walked off: the other wins.
	for _, player in { battle.A, battle.B } do
		if not present(battle, player) then
			finish(battle, sideOf(battle, foeOf(battle, player)), "Left")
			return
		end
	end
	if battle.Phase == "Formation" then
		if now >= battle.EndsAt or (battle.Ready[battle.A] and battle.Ready[battle.B]) then
			battle.Phase = "Battle"
			battle.EndsAt = now + KaijuBattle.BattleSeconds
			line(battle, battle.A)
			line(battle, battle.B)
			for _, player in { battle.A, battle.B } do
				Remotes.Notify:FireClient(player, "Kaiju battle: FIGHT!")
			end
			tell(battle)
		end
		return
	end
	local a, b = standing(battle, battle.A), standing(battle, battle.B)
	local timedOut = now >= battle.EndsAt
	if a.Up <= 0 or b.Up <= 0 or timedOut then
		finish(battle, KaijuBattle.winner(a, b, timedOut))
	end
end

local function setFormation(player: Player, wanted: any)
	local battle = battleOf[player]
	if not battle or battle.Phase ~= "Formation" then
		return reply(false, "Your kaiju can only be placed before the battle starts.")
	end
	local records = {}
	for _, pet in petsIn(battle, player) do
		table.insert(records, pet.Record)
	end
	local formation, problem = KaijuBattle.formation(wanted, records)
	if not formation then
		return reply(false, problem or "That isn't a formation.")
	end
	battle.Formation[player] = formation
	tell(battle)
	return reply(true, "")
end

local function ready(player: Player)
	local battle = battleOf[player]
	if not battle or battle.Phase ~= "Formation" then
		return reply(false, "")
	end
	battle.Ready[player] = true
	tell(battle)
	KaijuBattles.step(battle, KaijuBattles.clock())
	return reply(true, "")
end

local function leave(player: Player)
	local battle = battleOf[player]
	if not battle then
		return reply(false, "You're not in a kaiju battle.")
	end
	if battle.Phase == "Over" then
		-- (Closed for you; the other still sees the result a moment, with
		-- no rematch.)
		release(battle, player)
		battle.RematchOff = player.DisplayName .. " left."
		tell(battle)
	else
		finish(battle, sideOf(battle, foeOf(battle, player)), "Left")
	end
	return reply(true, "")
end

local function gone(player: Player)
	local battle = battleOf[player]
	if battle then
		-- (The other sees the result a moment, then it closes: step. Their
		-- kaiju back as they were, if the profile's still here; else a rejoin
		-- does it: KaijuServer upkeep.)
		finish(battle, sideOf(battle, foeOf(battle, player)), "Left")
		release(battle, player)
		battle.RematchOff = player.DisplayName .. " left."
		tell(battle)
	end
	dropAsks(player)
	again[player], lastAsk[player] = nil, nil
	for _, waits in again do
		waits[player] = nil
	end
end

-- A rematch: a new battle for the same two on the same sides, on the same
-- court (or the field between them), with `pot` (the arena's: the stake
-- taken again). The old one's closed for them without its result going,
-- so their screens go straight to placing again.
function KaijuBattles.again(battle: Battle, pot: any?): Battle?
	for _, player in { battle.A, battle.B } do
		if battleOf[player] == battle then
			battleOf[player] = nil
		end
		for _, pet in KaijuServer.team(player) do
			pet.Model:SetAttribute("KaijuTeam", nil)
		end
		-- (Back as they were already, at finish: this is in case.)
		KaijuServer.battleEnd(player)
	end
	battle.EndsAt = KaijuBattles.clock()
	local new = begin(battle.A, battle.B, battle.Court, pot)
	if not new then
		-- (Couldn't: both let go of the old one.)
		for _, player in { battle.A, battle.B } do
			release(battle, player)
		end
	end
	return new
end

-- REMATCH: once it's over, before it closes. One asking tells the other;
-- both, and it starts again.
local function rematch(player: Player)
	local battle = battleOf[player]
	if not battle or battle.Phase ~= "Over" then
		return reply(false, "There's no battle to have again.")
	end
	local foe = foeOf(battle, player)
	if battle.RematchOff then
		return reply(false, battle.RematchOff)
	end
	if not foe.Parent or battleOf[foe] ~= battle then
		return reply(false, foe.DisplayName .. " left.")
	end
	if not present(battle, player) or not present(battle, foe) then
		return reply(false, "You both need to be at the battle for a rematch.")
	end
	for _, who in { player, foe } do
		if KaijuServer.battleable(who) <= 0 then
			return reply(
				false,
				if who == player
					then "You need your kaiju out to battle."
					else foe.DisplayName .. " has no kaiju out to battle."
			)
		end
	end
	if battle.Rematch[player] then
		return reply(true, "")
	end
	battle.Rematch[player] = true
	if not battle.Rematch[foe] then
		Remotes.Notify:FireClient(foe, player.DisplayName .. " wants a rematch!")
		tell(battle)
		return reply(true, "")
	end
	-- Both: again (on a court, the stake taken again first).
	local new, problem = nil, nil
	if battle.Court and KaijuBattles.rematchOn then
		new, problem = KaijuBattles.rematchOn(battle)
	else
		new = KaijuBattles.again(battle, nil)
	end
	if not new then
		battle.Rematch = {}
		battle.RematchOff = problem or "The rematch couldn't start."
		tell(battle)
		return reply(false, battle.RematchOff)
	end
	for _, who in { battle.A, battle.B } do
		Remotes.Notify:FireClient(who, "Rematch! Place your kaiju.")
	end
	return reply(true, "")
end

-- Every battle going.
function KaijuBattles.all(): { Battle }
	local list, seen = {}, {}
	for _, battle in battleOf do
		if not seen[battle] then
			seen[battle] = true
			table.insert(list, battle)
		end
	end
	return list
end

function KaijuBattles.of(player: Player): Battle?
	return battleOf[player]
end

function KaijuBattles.start()
	KaijuServer.battle = orders
	KaijuServer.battling = function(player: Player): boolean
		local battle = battleOf[player]
		return battle ~= nil and battle.Phase ~= "Over"
	end
	Shop.register("KaijuBattleAsk", ask)
	Shop.register("KaijuBattleRespond", respond)
	Shop.register("KaijuBattleFormation", setFormation)
	Shop.register("KaijuBattleReady", ready)
	Shop.register("KaijuBattleLeave", leave)
	Shop.register("KaijuBattleRematch", rematch)
	Players.PlayerRemoving:Connect(gone)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer < 0.25 then
			return
		end
		timer = 0
		local now = KaijuBattles.clock()
		for _, battle in KaijuBattles.all() do
			local ok, err = pcall(KaijuBattles.step, battle, now)
			if not ok then
				warn("[KaijuBattles] step:", err)
			end
		end
		-- Asks run out.
		for target, pending in asks do
			for from, expiry in pending do
				if now > expiry then
					pending[from] = nil
					if target.Parent then
						Remotes.Social:FireClient(target, "KaijuBattleAskOver", from.UserId)
					end
				end
			end
		end
	end)
end

-- For tests.
KaijuBattles._ask, KaijuBattles._respond = ask, respond
KaijuBattles._formation, KaijuBattles._ready, KaijuBattles._leave = setFormation, ready, leave
KaijuBattles._rematch = rematch
KaijuBattles._orders, KaijuBattles._gone, KaijuBattles._state = orders, gone, stateFor

return KaijuBattles
