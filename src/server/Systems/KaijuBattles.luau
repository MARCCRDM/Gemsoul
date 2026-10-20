--[[
	Kaiju battles in the Outpost (Shared.KaijuBattle has the rules): two
	players set their kaiju teams against each other, place them in a
	formation, and the kaiju fight it out by themselves. Requests:

	  "KaijuBattleAsk", userId              ask someone near you
	  "KaijuBattleRespond", userId, accept  answer someone who asked you
	  "KaijuBattleFormation", { [kaijuId]: cellId }   where yours stand
	                                        (in the formation phase)
	  "KaijuBattleReady"                    ready: both ready starts it early
	  "KaijuBattleLeave"                    leave it (the other side wins)

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
	                                        "Draw", and Exp, once it's over) }

	Players in one carry the KaijuBattle attribute (its Id). Their kaiju
	do as KaijuServer.battle says: stand at their places through the
	formation phase, then fight the other side's (each side's shared out
	over the other's, Shared.Squad). A battle ends when one side's kaiju
	are all down, when time's up, or when one of the two leaves the
	Outpost, walks off past KaijuBattle.Leash, or leaves the game (the
	other wins). What the kaiju lose stays lost.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuBattle = require(ReplicatedStorage.Shared.KaijuBattle)
local Spar = require(ReplicatedStorage.Shared.Spar)
local Squad = require(ReplicatedStorage.Shared.Squad)
local KaijuServer = require(script.Parent.KaijuServer)
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
	PlanAt: number?,
	Plan: { [any]: any },
	Flanks: { [any]: Vector3 },
	Result: { [Player]: string }?,
}

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

-- A player's kaiju out and up (ready to battle).
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
						Name = Kaiju.title(pet.Record),
						Species = pet.Record.Species,
						Element = pet.Record.Element,
						Model = pet.Model,
					})
				end
			end
		end
	end
	local result = battle.Result and battle.Result[player]
	return {
		Id = battle.Id,
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
	}
end

local function tell(battle: Battle)
	for _, player in { battle.A, battle.B } do
		if player.Parent then
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
		Mine = #upOf(player),
		Theirs = #upOf(target),
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

-- Both agreed: the field between them, their kaiju up and out brought,
-- each in its default place.
local function begin(a: Player, b: Player): Battle?
	local ra, rb = rootOf(a), rootOf(b)
	if not ra or not rb then
		return nil
	end
	nextId += 1
	local battle: Battle = {
		Id = "KB" .. nextId,
		A = a,
		B = b,
		Field = KaijuBattle.field(
			ra.Position - Vector3.new(0, ra.Size.Y / 2 + 1.5, 0),
			rb.Position - Vector3.new(0, rb.Size.Y / 2 + 1.5, 0)
		),
		Phase = "Formation",
		EndsAt = KaijuBattles.clock() + KaijuBattle.FormationSeconds,
		Formation = {},
		Ready = {},
		Brought = {},
		Names = {},
		Plan = {},
		Flanks = {},
	}
	for _, player in { a, b } do
		local records = {}
		battle.Brought[player], battle.Names[player] = {}, {}
		for _, pet in upOf(player) do
			table.insert(records, pet.Record)
			battle.Brought[player][pet.Record.Id] = pet.Humanoid.MaxHealth
			battle.Names[player][pet.Record.Id] = Kaiju.title(pet.Record)
			pet.Target = nil
		end
		battle.Formation[player] = KaijuBattle.defaultFormation(records)
		battleOf[player] = battle
		player:SetAttribute("KaijuBattle", battle.Id)
		dropAsks(player)
	end
	tell(battle)
	return battle
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
		if not begin(to, player) then
			return reply(false, "Couldn't start the battle.")
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
	if not begin(from, player) then
		return reply(false, "Couldn't start the battle.")
	end
	Remotes.Notify:FireClient(from, player.DisplayName .. " accepted. Place your kaiju!")
	return reply(true, "")
end

-- The battle --------------------------------------------------------------------------------------------

-- Each side's kaiju shared out over the other's (Shared.Squad): the one
-- it's on kept unless another's well nearer; where two share one, the side
-- of it each fights from.
local function plan(battle: Battle, now: number)
	battle.PlanAt = now
	table.clear(battle.Plan)
	table.clear(battle.Flanks)
	for _, player in { battle.A, battle.B } do
		local fighters, foes = petsIn(battle, player), petsIn(battle, foeOf(battle, player))
		local targets = Squad.assign(fighters, foes, function(pet, foe)
			local before = battle.Plan[pet]
			return Squad.cost((foe.Root.Position - pet.Root.Position).Magnitude, before == foe, false)
		end)
		local groups = {}
		for _, pet in fighters do
			local foe = targets[pet]
			battle.Plan[pet] = foe
			if foe then
				groups[foe] = groups[foe] or {}
				table.insert(groups[foe], pet)
			end
		end
		for foe, group in groups do
			if #group > 1 then
				local spots = {}
				for i, pet in group do
					spots[i] = pet.Root.Position
				end
				for i, dir in Squad.slots(foe.Root.Position, spots) do
					battle.Flanks[group[i]] = dir
				end
			end
		end
	end
end

-- What a pet in a battle does (KaijuServer.battle).
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
	if battle.PlanAt ~= now then
		plan(battle, now)
	end
	return {
		Foe = battle.Plan[pet],
		Flank = battle.Flanks[pet],
		Foes = petsIn(battle, foeOf(battle, player)),
		Spot = spot,
		Look = look,
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

-- Over: the result to both, EXP to every kaiju of theirs still out.
local function finish(battle: Battle, winner: string, reason: string?)
	if battle.Phase == "Over" then
		return
	end
	battle.Phase = "Over"
	battle.EndsAt = KaijuBattles.clock() + KaijuBattle.OverSeconds
	battle.Result = {}
	for _, player in { battle.A, battle.B } do
		local side = sideOf(battle, player)
		local result = if winner == "Draw" then "Draw" elseif winner == side then "Win" else "Lose"
		battle.Result[player] = result
		if player.Parent then
			KaijuServer.reward(player, KaijuBattle.Exp[result])
			local foe = foeOf(battle, player)
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

-- Gone: both free again, their kaiju back beside them.
local function close(battle: Battle)
	for _, player in { battle.A, battle.B } do
		if battleOf[player] == battle then
			battleOf[player] = nil
		end
		if player.Parent then
			player:SetAttribute("KaijuBattle", nil)
			Remotes.Social:FireClient(player, "KaijuBattle", nil)
		end
	end
end

-- Still fit to battle: here, in the Outpost, on their feet, near the field.
local function present(battle: Battle, player: Player): boolean
	if not player.Parent or player:GetAttribute("Outpost") ~= true then
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
		-- (Closed for you; the other still sees the result a moment.)
		battleOf[player] = nil
		player:SetAttribute("KaijuBattle", nil)
		Remotes.Social:FireClient(player, "KaijuBattle", nil)
	else
		finish(battle, sideOf(battle, foeOf(battle, player)), "Left")
	end
	return reply(true, "")
end

local function gone(player: Player)
	local battle = battleOf[player]
	if battle then
		-- (The other sees the result a moment, then it closes: step.)
		finish(battle, sideOf(battle, foeOf(battle, player)), "Left")
		battleOf[player] = nil
	end
	dropAsks(player)
	again[player], lastAsk[player] = nil, nil
	for _, waits in again do
		waits[player] = nil
	end
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
KaijuBattles._orders, KaijuBattles._gone, KaijuBattles._state = orders, gone, stateFor

return KaijuBattles
