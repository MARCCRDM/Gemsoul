--[[
	The team's HYPERBEAM (rules: Shared.KaijuBeam; the button: Client.
	KaijuBeamHud; the show: Client.KaijuBeamFx).

	Mana: each kaiju out fills as it fights and, slowly, as it follows you
	about (mining or not); its blows landing add more, its Q / E / R cost
	some (KaijuServer's onStrike and onCast hooks). SAVE CHARGE (your
	switch, on your profile: Kaiju.roster(profile).SaveCharge): your
	fighters cast none of their moves, blows alone (KaijuServer's holding
	hook, KaijuFighter.hold), and fill faster; your support's heals still go
	out. Each kaiju's mana is kept on its record (Mana), so it isn't lost
	when the team's put away.

	The blast ("KaijuBeam", { X, Z }: where you aim): with every kaiju out
	full, they're yours for KaijuBeam.timeline().Done: they run into
	formation round you (Gather; one too far is put there), stand facing
	your aim and pour their element into the focus (Charge: each one's cast
	charge-up at its mouth, ActionKind "Bolt" on its model, released as the
	beam fires), and the beam fires from the focus (Fire: Pulses pulses on
	every creature in it, each pulse dealt by the next of them in turn, so
	the kill is yours and their colours come up by turns); then a beat to
	recover and they're back to themselves. It aims at the nearest creature
	near your aim (KaijuBeam.aim). Not in a kaiju battle, nor with the team
	put away. Everyone near sees it (CombatFx "KaijuBeam"); you get the
	cinematic.

	On your player, for the HUD: KaijuCharge (0..100, the emptiest of your
	team's mana; nil with none out), KaijuSave (true while saving), and
	KaijuBeamAt (server time a blast of yours started; nil after). On each
	kaiju out: Mana (0..100).

	  KaijuBeamServer.start()
	  KaijuBeamServer._fire(player, aim, now) -> reply    (tests)
	  KaijuBeamServer._step(now)    the blasts under way, one frame (tests)
	  KaijuBeamServer._charge(dt)   the mana, one tick (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuBeam = require(ReplicatedStorage.Shared.KaijuBeam)
local KaijuServer = require(script.Parent.KaijuServer)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

local KaijuBeamServer = {}

-- The blasts under way, by player.
local casts = {}

local UP = Vector3.new(0, 1, 0)

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function saving(player: Player): boolean
	local profile = PlayerData.get(player)
	return profile ~= nil and type(profile.Kaiju) == "table" and profile.Kaiju.SaveCharge == true
end

local function manaOf(pet): number
	return tonumber(pet.Record.Mana) or 0
end

local function inBeam(pet, now: number?): boolean
	return pet.BeamUntil ~= nil and (now or os.clock()) < pet.BeamUntil
end

local function up(pet): boolean
	return pet.Model.Parent ~= nil and pet.Humanoid.Health > 0
end

-- Your team out and standing.
local function standing(player: Player)
	local list = {}
	for _, pet in KaijuServer.team(player) do
		if up(pet) then
			table.insert(list, pet)
		end
	end
	return list
end

-- What the HUD shows: each kaiju's mana, the emptiest, saving or not.
local function publish(player: Player, team)
	local manas = {}
	for _, pet in team do
		local mana = math.floor(manaOf(pet))
		table.insert(manas, mana)
		if pet.Model:GetAttribute("Mana") ~= mana then
			pet.Model:SetAttribute("Mana", mana)
		end
	end
	local charge = nil
	if #manas > 0 then
		local _, least = KaijuBeam.team(manas)
		charge = math.floor(least * 100 + 1e-6)
	end
	if player:GetAttribute("KaijuCharge") ~= charge then
		player:SetAttribute("KaijuCharge", charge)
	end
	local save = saving(player) or nil
	if player:GetAttribute("KaijuSave") ~= save then
		player:SetAttribute("KaijuSave", save)
	end
end

-- One tick of the mana: out of a fight a trickle, in one a little more
-- (blows landing add theirs as they land: onStrike).
function KaijuBeamServer._charge(dt: number)
	local rules = KaijuBeam.Mana
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local team = standing(player)
		local save = saving(player)
		for _, pet in team do
			if not inBeam(pet, now) then
				local rate = rules.Trickle + (if pet.Target then rules.Fight else 0)
				pet.Record.Mana = KaijuBeam.gain(manaOf(pet), rate * dt, save)
			end
		end
		publish(player, team)
	end
end

-- Its world spot in the formation (`spot`: KaijuBeam.formation's), from
-- `origin` facing `forward`.
local function placeOf(origin: Vector3, forward: Vector3, spot): Vector3
	local right = forward:Cross(UP)
	local at = origin + right * spot.Side - forward * spot.Back
	local ground = KaijuServer.ground(at, nil)
	return ground + UP * (spot.Up or 0)
end

-- The blast: checks, aim, the team's places, and the show for everyone.
function KaijuBeamServer._fire(player: Player, aim: any, now: number)
	local root = rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return reply(false, "")
	end
	if casts[player] then
		return reply(false, "Your kaiju are already blasting!")
	end
	if KaijuServer.battling(player) then
		return reply(false, "Not in a kaiju battle.")
	end
	local team = standing(player)
	if #team == 0 then
		return reply(false, "You need your kaiju out for a HYPERBEAM.")
	end
	local manas = {}
	for _, pet in team do
		table.insert(manas, manaOf(pet))
	end
	local ready, least = KaijuBeam.team(manas)
	if not ready then
		return reply(false, string.format("Your kaiju aren't charged yet: %d%%.", math.floor(least * 100)))
	end
	-- Where: your aim (else where you face), onto the nearest creature near it.
	local dx, dz = 0, 0
	if type(aim) == "table" then
		dx, dz = tonumber(aim.X) or 0, tonumber(aim.Z) or 0
	elseif typeof(aim) == "Vector3" then
		dx, dz = aim.X, aim.Z
	end
	if dx ~= dx or dz ~= dz or dx * dx + dz * dz < 1e-6 then
		local look = root.CFrame.LookVector
		dx, dz = look.X, look.Z
	end
	local origin = root.Position
	local foes = {}
	for _, foe in KaijuServer.creaturesNear(origin, KaijuBeam.Beam.Reach, player) do
		local offset = foe.Root.Position - origin
		table.insert(foes, { X = offset.X, Z = offset.Z })
	end
	dx, dz = KaijuBeam.aim(dx, dz, foes)
	local forward = Vector3.new(dx, 0, dz)
	local ahead, high = KaijuBeam.focus()
	local ground = KaijuServer.ground(origin, nil)
	local focus = ground + forward * ahead + UP * high
	-- Their places: the fighters in the V, the support up behind you.
	local fighters, supports = {}, {}
	for _, pet in team do
		table.insert(if Kaiju.isSupport(pet.Record.Species) then supports else fighters, pet)
	end
	local spots = KaijuBeam.formation(#fighters, #supports > 0)
	local order = table.clone(fighters)
	if supports[1] then
		table.insert(order, supports[1])
	end
	local at = KaijuBeam.timeline()
	local start = serverNow()
	local cast = {
		Player = player,
		Start = now,
		Origin = origin,
		Forward = forward,
		Focus = focus,
		Pulses = 0,
		Charged = false,
		Damage = 0,
		Units = {},
	}
	local damages, models, elements, places = {}, {}, {}, {}
	for i, pet in order do
		local place = placeOf(ground, forward, spots[i])
		pet.Record.Mana = 0
		pet.BeamUntil = now + at.Done
		pet.Target = nil
		table.insert(cast.Units, { Pet = pet, Place = place })
		table.insert(damages, pet.Stats.Damage)
		table.insert(models, pet.Model)
		table.insert(elements, pet.Element)
		table.insert(places, place)
		-- Its cast's charge-up at its mouth over the Charge, let go as the
		-- beam fires (CreatureAnimation, KaijuMotionFx); and its name on its
		-- cast bar.
		local model = pet.Model
		model:SetAttribute("ActionKind", "Bolt")
		model:SetAttribute("ActionStart", start + at.Charge)
		model:SetAttribute("ActionAt", start + at.Fire)
		model:SetAttribute("ActionName", "HYPERBEAM")
		model:SetAttribute("ActionElement", pet.Element)
		model:SetAttribute("Mana", 0)
	end
	cast.Damage = KaijuBeam.damage(damages)
	casts[player] = cast
	player:SetAttribute("KaijuBeamAt", start)
	player:SetAttribute("KaijuCharge", 0)
	Remotes.CombatFx:FireAllClients("KaijuBeam", {
		Owner = player,
		Start = start,
		Origin = origin,
		Forward = forward,
		Focus = focus,
		Models = models,
		Elements = elements,
		Places = places,
	})
	return reply(true, "", { Start = start })
end

-- Lets its kaiju go: their own thinking back, their cast bars cleared.
local function release(cast)
	for _, unit in cast.Units do
		local pet = unit.Pet
		pet.BeamUntil = nil
		if pet.Root and pet.Root.Parent and unit.WasAnchored ~= nil then
			pet.Root.Anchored = unit.WasAnchored
		end
		local model = pet.Model
		if model.Parent and model:GetAttribute("ActionName") == "HYPERBEAM" then
			model:SetAttribute("ActionKind", nil)
			model:SetAttribute("ActionName", nil)
			model:SetAttribute("ActionElement", nil)
		end
	end
	if cast.Player:GetAttribute("KaijuBeamAt") then
		cast.Player:SetAttribute("KaijuBeamAt", nil)
	end
end

-- One pulse of the beam on every creature in it.
local function pulse(cast)
	local b = KaijuBeam.Beam
	local units = {}
	for _, unit in cast.Units do
		if up(unit.Pet) then
			table.insert(units, unit)
		end
	end
	if #units == 0 then
		return
	end
	cast.Pulses += 1
	local dealer = units[(cast.Pulses - 1) % #units + 1].Pet
	local focus, forward = cast.Focus, cast.Forward
	local middle = focus + forward * (b.Length / 2)
	for _, foe in KaijuServer.creaturesNear(middle, b.Length / 2 + b.Width, cast.Player) do
		local at = foe.Root.Position
		local radius = math.max(foe.Root.Size.X, foe.Root.Size.Z) / 2
		if KaijuBeam.hits(focus.X, focus.Z, forward.X, forward.Z, at.X, at.Z, radius) then
			KaijuServer.strike(dealer, foe.Enemy, cast.Damage, nil, true)
		end
	end
end

-- The blasts under way, one frame.
function KaijuBeamServer._step(now: number)
	for player, cast in casts do
		local t = now - cast.Start
		local phase, progress = KaijuBeam.phase(t)
		if phase == "Gather" then
			for _, unit in cast.Units do
				local pet = unit.Pet
				if up(pet) then
					if (pet.Root.Position - unit.Place).Magnitude > KaijuBeam.Beam.Far then
						KaijuServer.place(pet.Model, unit.Place, unit.Place + cast.Forward)
					else
						pet.Humanoid:MoveTo(unit.Place)
					end
				end
			end
		elseif phase == "Charge" or phase == "Fire" then
			if not cast.Charged then
				-- In their places, facing your aim, held still.
				cast.Charged = true
				for _, unit in cast.Units do
					local pet = unit.Pet
					if up(pet) then
						KaijuServer.place(pet.Model, unit.Place, unit.Place + cast.Forward)
						unit.WasAnchored = pet.Root.Anchored == true
						pet.Root.Anchored = true
					end
				end
			end
			if phase == "Fire" then
				local due = math.min(KaijuBeam.Beam.Pulses, math.floor(progress * KaijuBeam.Beam.Pulses) + 1)
				while cast.Pulses < due do
					local before = cast.Pulses
					pulse(cast)
					if cast.Pulses == before then
						break -- (none of them standing)
					end
				end
			end
		elseif phase == "Recover" then
			if cast.Charged and not cast.Freed then
				cast.Freed = true
				for _, unit in cast.Units do
					if unit.Pet.Root and unit.Pet.Root.Parent and unit.WasAnchored ~= nil then
						unit.Pet.Root.Anchored = unit.WasAnchored
						unit.WasAnchored = nil
					end
				end
			end
		else
			release(cast)
			casts[player] = nil
		end
	end
end

local function fire(player: Player, aim: any)
	return KaijuBeamServer._fire(player, aim, os.clock())
end

local function setSave(player: Player, on: any)
	if type(on) ~= "boolean" then
		return reply(false, "")
	end
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	Kaiju.roster(profile).SaveCharge = on
	player:SetAttribute("KaijuSave", on or nil)
	return reply(
		true,
		if on
			then "Saving charge: your kaiju fight with blows alone and charge their HYPERBEAM faster."
			else "Your kaiju use their moves again."
	)
end

function KaijuBeamServer.start()
	local rules = KaijuBeam.Mana
	-- A blow of a pet's landing: mana (not in the blast itself).
	KaijuServer.onStrike = function(pet, outcome: string, heavy: boolean?)
		if (outcome == "Hit" or outcome == "Broken") and not inBeam(pet) then
			local amount = rules.Hit * (if heavy then rules.Heavy else 1)
			pet.Record.Mana = KaijuBeam.gain(manaOf(pet), amount, saving(pet.Owner))
		end
	end
	-- One of its moves: that costs (saving, its support's heals are free).
	KaijuServer.onCast = function(pet)
		if not inBeam(pet) and not saving(pet.Owner) then
			pet.Record.Mana = KaijuBeam.spend(manaOf(pet))
		end
	end
	-- Saving: its fighters hold their moves (the support heals regardless).
	KaijuServer.holding = function(pet): boolean
		return saving(pet.Owner) and not Kaiju.isSupport(pet.Record.Species)
	end
	Shop.register("KaijuBeam", fire)
	Shop.register("KaijuSaveCharge", setSave)
	Players.PlayerRemoving:Connect(function(player)
		local cast = casts[player]
		if cast then
			release(cast)
			casts[player] = nil
		end
	end)
	local tick = 0
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(KaijuBeamServer._step, os.clock())
		if not ok then
			warn("[KaijuBeam] step:", err)
		end
		tick += dt
		if tick >= 0.25 then
			ok, err = pcall(KaijuBeamServer._charge, tick)
			tick = 0
			if not ok then
				warn("[KaijuBeam] charge:", err)
			end
		end
	end)
end

return KaijuBeamServer
