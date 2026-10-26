--[[
	The team's HYPERBEAM (rules: Shared.KaijuBeam; the button: Client.
	KaijuBeamHud; the show: Client.KaijuBeamFx).

	The charge: one meter for your whole team, its own (KaijuBeam.Charge),
	kept on your profile (Kaiju.roster(profile).BeamCharge) so it isn't lost
	when the team's put away. It fills, slowly, while your team's out
	(mining or not), faster while any of them fights, and with every blow
	of theirs that lands (KaijuServer's onStrike hook). Their Q / E / R cost
	it nothing. SAVE CHARGE (your switch, on your profile:
	Kaiju.roster(profile).SaveCharge): your fighters cast none of their
	moves, blows alone (KaijuServer's holding hook, KaijuFighter.hold), and
	it fills faster; your support's heals still go out.

	The blast ("KaijuBeam", { X, Z }: where you aim): the charge full and
	your team out, they're yours for KaijuBeam.timeline().Done: they leap into
	formation in front of you one after another (Gather: held where they stand
	till their turn, clients draw the leap, KaijuBeam.Leap, and each is put
	in its place as it lands), roar together, stand facing
	your aim and pour their element into the focus (Charge: each one's cast
	charge-up at its mouth, ActionKind "Bolt" on its model, released as the
	beam fires), and the beam fires from the focus (Fire: Pulses pulses on
	every creature in it, each pulse dealt by the next of them in turn, so
	the kill is yours and their colours come up by turns); then a beat to
	recover and they're back to themselves. It takes the creatures in reach
	and the ones in a fight with you or your team (Engaged), the biggest
	threat first (KaijuBeam.order), holds on it, then swings onto the rest
	in turn (KaijuBeam.direction: each pulse hits along where it's turned
	then); with nothing in front of you it turns to face the biggest. Not
	in a kaiju battle, nor with the team put away. Everyone near sees it
	(CombatFx "KaijuBeam", with its Targets in turn), from their own view:
	no cinematic camera.

	On your player, for the HUD: KaijuCharge (0..100, the team's charge; nil
	with none out), KaijuSave (true while saving), and KaijuBeamAt (server
	time a blast of yours started; nil after).

	  KaijuBeamServer.start()
	  KaijuBeamServer._fire(player, aim, now) -> reply    (tests)
	  KaijuBeamServer._step(now)    the blasts under way, one frame (tests)
	  KaijuBeamServer._charge(dt)   the charge, one tick (tests)
	  KaijuBeamServer._aimed(cast, p) -> Vector3   where it's turned `p` of
	                                the way through (tests)
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

-- The team's charge, on your profile (0 with none loaded).
local function chargeOf(player: Player): number
	local profile = PlayerData.get(player)
	return if profile then tonumber(Kaiju.roster(profile).BeamCharge) or 0 else 0
end
local function setCharge(player: Player, value: number)
	local profile = PlayerData.get(player)
	if profile then
		Kaiju.roster(profile).BeamCharge = value
	end
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

-- What the HUD shows: the team's charge (with any of them out), saving or not.
local function publish(player: Player, team)
	local charge = nil
	if #team > 0 then
		local _, share = KaijuBeam.ready(chargeOf(player))
		charge = math.floor(share * 100 + 1e-6)
	end
	if player:GetAttribute("KaijuCharge") ~= charge then
		player:SetAttribute("KaijuCharge", charge)
	end
	local save = saving(player) or nil
	if player:GetAttribute("KaijuSave") ~= save then
		player:SetAttribute("KaijuSave", save)
	end
end

-- One tick of the charge: a trickle with your team out, a little more
-- while any of them fights (blows landing add theirs as they land:
-- onStrike). Not while they're blasting.
function KaijuBeamServer._charge(dt: number)
	local rules = KaijuBeam.Charge
	for _, player in Players:GetPlayers() do
		local team = standing(player)
		if #team > 0 and not casts[player] then
			local fighting = false
			for _, pet in team do
				fighting = fighting or pet.Target ~= nil
			end
			local rate = rules.Trickle + (if fighting then rules.Fight else 0)
			setCharge(player, KaijuBeam.gain(chargeOf(player), rate * dt, saving(player)))
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
	local ready, share = KaijuBeam.ready(chargeOf(player))
	if not ready then
		return reply(false, string.format("Your kaiju aren't charged yet: %d%%.", math.floor(share * 100)))
	end
	-- Where: in front of you, along your aim (else where you face). What: the
	-- creatures in reach and the ones in a fight with you or your team, the
	-- biggest threat first, then round the rest (KaijuBeam.order); with
	-- all of them off behind you, it turns to face the biggest.
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
	local length = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / length, dz / length
	local origin = root.Position
	local b = KaijuBeam.Beam
	local engaged = {}
	for _, pet in team do
		local target = pet.Target
		if type(target) == "table" and target.Enemy then
			engaged[target.Enemy] = true
		end
	end
	local candidates, foes = {}, {}
	local function take(foe, fighting: boolean)
		for _, had in candidates do
			if had.Enemy == foe.Enemy then
				return
			end
		end
		local enemy = foe.Enemy :: any
		local offset = foe.Root.Position - origin
		local humanoid = enemy and enemy.Humanoid
		table.insert(candidates, foe)
		table.insert(foes, {
			X = offset.X,
			Z = offset.Z,
			Health = humanoid and humanoid.Health,
			MaxHealth = humanoid and humanoid.MaxHealth,
			Engaged = fighting or engaged[foe.Enemy] == true or (type(enemy.Engaged) == "table" and enemy.Engaged[player] ~= nil),
		})
	end
	for _, foe in KaijuServer.creaturesNear(origin, b.Reach, player) do
		take(foe, false)
	end
	-- (In a fight with your team further off, up to the beam's length.)
	for _, foe in KaijuServer.creaturesNear(origin, b.Length, player) do
		if engaged[foe.Enemy] then
			take(foe, true)
		end
	end
	local order = KaijuBeam.order(foes, dx, dz)
	if #order == 0 and #foes > 0 then
		local best, top = -math.huge, nil
		for _, foe in foes do
			local threat = KaijuBeam.threat(foe)
			if threat > best then
				best, top = threat, foe
			end
		end
		local reach = math.sqrt(top.X * top.X + top.Z * top.Z)
		dx, dz = top.X / reach, top.Z / reach
		order = KaijuBeam.order(foes, dx, dz)
	end
	local targets = {}
	for _, index in order do
		local foe = candidates[index]
		table.insert(targets, { Root = foe.Root, At = foe.Root.Position })
	end
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
		Targets = targets,
		Pulses = 0,
		Charged = false,
		Damage = 0,
		Units = {},
	}
	local damages, models, elements, places, froms, ends, leaps = {}, {}, {}, {}, {}, {}, {}
	for i, pet in order do
		local place = placeOf(ground, forward, spots[i])
		local takeoff, land = KaijuBeam.leap(i)
		local from = pet.Root.CFrame -- (its pivot)
		pet.BeamUntil = now + at.Done
		pet.Target = nil
		-- Held where it stands till its turn to leap; clients draw the leap
		-- (KaijuBeamFx) and it's put in its place as it lands (_step).
		table.insert(cast.Units, { Pet = pet, Place = place, Land = land, WasAnchored = pet.Root.Anchored == true })
		pet.Root.Anchored = true
		table.insert(damages, pet.Stats.Damage)
		table.insert(models, pet.Model)
		table.insert(elements, pet.Element)
		table.insert(places, place)
		table.insert(froms, from)
		table.insert(ends, KaijuServer.spot(pet.Model, place, place + forward))
		table.insert(leaps, takeoff)
		-- Its leap and landing posed (CreatureAnimation: BeamLeapAt,
		-- BeamLandAt), the team's roar together once they're all down (a
		-- breath apart, so it's a chorus), its cast's charge-up at its mouth
		-- over the Charge (ActionKind, set as it starts: a mood waits for no
		-- move) let go as the beam fires, and its name on its cast bar.
		local model = pet.Model
		model:SetAttribute("BeamLeapAt", start + takeoff)
		model:SetAttribute("BeamLandAt", start + land)
		model:SetAttribute("KaijuMood", "Roar")
		model:SetAttribute("KaijuMoodAt", start + KaijuBeam.Leap.Roar + 0.05 * (i - 1))
		model:SetAttribute("ActionKind", nil)
		model:SetAttribute("ActionStart", start + at.Charge)
		model:SetAttribute("ActionAt", start + at.Fire)
		model:SetAttribute("ActionName", "HYPERBEAM")
		model:SetAttribute("ActionElement", pet.Element)
	end
	cast.Damage = KaijuBeam.damage(damages)
	local roots = {}
	for _, target in targets do
		table.insert(roots, target.Root)
	end
	casts[player] = cast
	setCharge(player, 0)
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
		Froms = froms,
		Ends = ends,
		Leaps = leaps,
		Targets = roots,
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
			pcall(pet.Root.SetNetworkOwner, pet.Root, nil) -- (the server's again: let go, it would fall to a client)
		end
		local model = pet.Model
		if model.Parent and model:GetAttribute("ActionName") == "HYPERBEAM" then
			model:SetAttribute("ActionKind", nil)
			model:SetAttribute("ActionName", nil)
			model:SetAttribute("ActionElement", nil)
			model:SetAttribute("BeamLeapAt", nil)
			model:SetAttribute("BeamLandAt", nil)
			if model:GetAttribute("KaijuMood") == "Roar" then
				model:SetAttribute("KaijuMood", nil)
			end
		end
	end
	if cast.Player:GetAttribute("KaijuBeamAt") then
		cast.Player:SetAttribute("KaijuBeamAt", nil)
	end
end

-- Where the beam's turned `p` of the way through the blast: from the focus
-- onto its targets in turn (each where it is, or where it was last seen).
local function aimed(cast, p: number): Vector3
	local points = {}
	for _, target in cast.Targets do
		if target.Root and target.Root.Parent then
			target.At = target.Root.Position
		end
		table.insert(points, { X = target.At.X, Z = target.At.Z })
	end
	local focus, forward = cast.Focus, cast.Forward
	local dx, dz = KaijuBeam.direction(p, focus.X, focus.Z, forward.X, forward.Z, points)
	return Vector3.new(dx, 0, dz)
end
KaijuBeamServer._aimed = aimed
KaijuBeamServer._casts = casts

-- One pulse of the beam on every creature in it, `p` of the way through.
local function pulse(cast, p: number)
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
	local focus = cast.Focus
	local forward = aimed(cast, p)
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
			-- Each one down in its place, facing your aim, as its leap lands.
			for _, unit in cast.Units do
				local pet = unit.Pet
				if not unit.Landed and t >= unit.Land and up(pet) then
					unit.Landed = true
					KaijuServer.place(pet.Model, unit.Place, unit.Place + cast.Forward)
				end
			end
		elseif phase == "Charge" or phase == "Fire" then
			if not cast.Charged then
				-- All in their places (any still in the air too), held still,
				-- winding up their charge.
				cast.Charged = true
				for _, unit in cast.Units do
					local pet = unit.Pet
					if up(pet) then
						if not unit.Landed then
							unit.Landed = true
							KaijuServer.place(pet.Model, unit.Place, unit.Place + cast.Forward)
						end
						pet.Root.Anchored = true
						pet.Model:SetAttribute("ActionKind", "Bolt")
					end
				end
			end
			if phase == "Fire" then
				local due = math.min(KaijuBeam.Beam.Pulses, math.floor(progress * KaijuBeam.Beam.Pulses) + 1)
				while cast.Pulses < due do
					local before = cast.Pulses
					pulse(cast, math.min(progress, (cast.Pulses + 0.5) / KaijuBeam.Beam.Pulses))
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
						pcall(unit.Pet.Root.SetNetworkOwner, unit.Pet.Root, nil) -- (the server's again: let go, it would fall to a client)
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
	local rules = KaijuBeam.Charge
	-- A blow of a pet's landing: the team's charge (not in the blast
	-- itself). Its moves cost the charge nothing.
	KaijuServer.onStrike = function(pet, outcome: string, heavy: boolean?)
		local owner = pet.Owner
		if (outcome == "Hit" or outcome == "Broken") and not inBeam(pet) and owner and not casts[owner] then
			local amount = rules.Hit * (if heavy then rules.Heavy else 1)
			setCharge(owner, KaijuBeam.gain(chargeOf(owner), amount, saving(owner)))
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
