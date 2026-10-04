--[[
	Combat sounds: swings, hits, crits, blocks, parries, dodges, element casts
	and impacts, blasts, stuns and more.

	CombatSound.play("Hit", position) plays one in 3D at that spot (louder
	when close); without a position it plays flat, for your own feedback
	(hurt, warnings). Each play picks one of the sound's takes at random
	(Hit1, Hit2, Hit3...), never the same take twice running, and is pitched
	slightly differently, so repeats never sound robotic.
	CombatSound.element("Impact", element, position) plays an element's own
	layer (fire roar, ice shatter, electric crackle, acid fizz).

	Everything runs through one mix: a compressor for punch, a touch of EQ
	and a little arena reverb, with a cap on how many play at once.

	Roblox only plays uploaded audio, so the files in assets/sounds/combat
	(made by tools/make_combat_sounds.py; _preview_all.mp3 plays them all)
	aren't used until they're uploaded. Run
	  python tools/upload_audio.py --key YOUR_API_KEY --user YOUR_USER_ID
	which uploads them all and fills in the ids below. Until then built-in
	Roblox sounds stand in, layered so combat still has weight.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)

local CombatSound = {}

-- Roblox ids of the uploaded files (the number from rbxassetid://12345). 0 = not uploaded yet.
-- Numbered names are takes of one sound: Hit1, Hit2 and Hit3 all play as "Hit".
CombatSound.Ids = {
	Swing1 = 0, -- swing_1.mp3
	Swing2 = 0, -- swing_2.mp3
	Swing3 = 0, -- swing_3.mp3
	HeavySwing1 = 0, -- heavy_swing_1.mp3
	HeavySwing2 = 0, -- heavy_swing_2.mp3
	Hit1 = 0, -- hit_1.mp3
	Hit2 = 0, -- hit_2.mp3
	Hit3 = 0, -- hit_3.mp3
	HeavyHit1 = 0, -- heavy_hit_1.mp3
	HeavyHit2 = 0, -- heavy_hit_2.mp3
	Crit1 = 0, -- crit_1.mp3
	Crit2 = 0, -- crit_2.mp3
	Block1 = 0, -- block_1.mp3
	Block2 = 0, -- block_2.mp3
	GuardBreak = 0, -- guard_break.mp3
	Parry = 0, -- parry.mp3
	Hop1 = 0, -- hop_1.mp3
	Hop2 = 0, -- hop_2.mp3
	Roll = 0, -- roll.mp3
	CastFire = 0, -- cast_fire.mp3
	CastFrost = 0, -- cast_frost.mp3
	CastShock = 0, -- cast_shock.mp3
	CastPoison = 0, -- cast_poison.mp3
	ImpactFire = 0, -- impact_fire.mp3
	ImpactFrost = 0, -- impact_frost.mp3
	ImpactShock = 0, -- impact_shock.mp3
	ImpactPoison = 0, -- impact_poison.mp3
	Cast = 0, -- cast.mp3
	Bolt = 0, -- bolt.mp3
	Beam = 0, -- beam.mp3
	NovaWarn = 0, -- nova_warn.mp3
	Blast = 0, -- blast.mp3
	Zap = 0, -- zap.mp3
	Burn = 0, -- burn.mp3
	Freeze = 0, -- freeze.mp3
	Corrode = 0, -- corrode.mp3
	Heal = 0, -- heal.mp3
	Shield = 0, -- shield.mp3
	Hurt1 = 0, -- hurt_1.mp3
	Hurt2 = 0, -- hurt_2.mp3
	Stun = 0, -- stun.mp3
	Winded = 0, -- winded.mp3
	Combo = 0, -- combo.mp3
	Death = 0, -- death.mp3
	Warn = 0, -- warn.mp3
	Kill = 0, -- kill.mp3
}

-- 0 mutes combat, 1 is full.
CombatSound.Volume = 0.85

-- The mix: each sound's level against the others.
local LEVEL = {
	Swing = 0.75,
	HeavySwing = 0.9,
	Hit = 1,
	HeavyHit = 1,
	Crit = 1,
	Block = 0.9,
	GuardBreak = 1,
	Parry = 0.95,
	Hop = 0.6,
	Roll = 0.7,
	Blast = 1,
	NovaWarn = 0.8,
	Hurt = 0.9,
	Stun = 0.8,
	Winded = 0.7,
	Combo = 0.55,
	Warn = 0.6,
}

-- Built-in stand-ins until a sound is uploaded: layers of { sound, speed,
-- volume, delay? }, stacked so a hit is a slash plus a thump, a blast a
-- boom plus a crash.
local S = "rbxasset://sounds/"
local FALLBACK = {
	Swing = { { S .. "swordslash.wav", 1.15, 0.45 } },
	HeavySwing = { { S .. "swordlunge.wav", 0.75, 0.6 }, { S .. "swordslash.wav", 0.7, 0.25 } },
	Shot = { { S .. "electronicpingshort.wav", 2.2, 0.35 } },
	Hit = { { S .. "swordslash.wav", 0.6, 0.45 }, { S .. "action_jump_land.mp3", 1.4, 0.55 } },
	HeavyHit = { { S .. "swordlunge.wav", 0.55, 0.55 }, { S .. "action_jump_land.mp3", 0.8, 0.8 } },
	Crit = {
		{ S .. "swordlunge.wav", 1.3, 0.55 },
		{ S .. "action_jump_land.mp3", 1.1, 0.7 },
		{ S .. "unsheath.wav", 1.8, 0.3, 0.02 },
	},
	Block = { { S .. "unsheath.wav", 1.2, 0.55 }, { S .. "action_jump_land.mp3", 1.6, 0.4 } },
	GuardBreak = { { S .. "unsheath.wav", 0.6, 0.7 }, { S .. "action_jump_land.mp3", 0.6, 0.8 } },
	Parry = { { S .. "unsheath.wav", 1.6, 0.6 }, { S .. "unsheath.wav", 2.1, 0.35, 0.03 } },
	Hop = { { S .. "action_jump.mp3", 1.2, 0.4 } },
	Roll = { { S .. "swordlunge.wav", 0.55, 0.35 }, { S .. "action_jump_land.mp3", 1.2, 0.35, 0.25 } },
	Cast = { { S .. "electronicpingshort.wav", 0.6, 0.35 } },
	CastFire = { { S .. "swordlunge.wav", 0.45, 0.5 }, { S .. "electronicpingshort.wav", 0.5, 0.25 } },
	CastFrost = { { S .. "electronicpingshort.wav", 1.8, 0.35 }, { S .. "unsheath.wav", 2.2, 0.2, 0.05 } },
	CastShock = { { S .. "electronicpingshort.wav", 3, 0.4 }, { S .. "electronicpingshort.wav", 2.4, 0.3, 0.06 } },
	CastPoison = { { S .. "switch.wav", 0.55, 0.45 }, { S .. "electronicpingshort.wav", 0.45, 0.25 } },
	ImpactFire = { { S .. "swordlunge.wav", 0.5, 0.45 } },
	ImpactFrost = { { S .. "unsheath.wav", 2.4, 0.3 } },
	ImpactShock = { { S .. "electronicpingshort.wav", 3.2, 0.35 } },
	ImpactPoison = { { S .. "switch.wav", 0.6, 0.4 } },
	Bolt = { { S .. "swordlunge.wav", 1.5, 0.45 } },
	Beam = { { S .. "electronicpingshort.wav", 1.4, 0.3 } },
	NovaWarn = { { S .. "electronicpingshort.wav", 0.45, 0.4 } },
	Blast = {
		{ S .. "action_jump_land.mp3", 0.45, 1 },
		{ S .. "swordlunge.wav", 0.4, 0.6 },
		{ S .. "action_jump_land.mp3", 0.7, 0.6, 0.06 },
	},
	Zap = { { S .. "electronicpingshort.wav", 3, 0.35 } },
	Burn = { { S .. "swordlunge.wav", 0.45, 0.4 } },
	Freeze = { { S .. "electronicpingshort.wav", 1.8, 0.35 } },
	Corrode = { { S .. "switch.wav", 0.6, 0.4 } },
	Heal = { { S .. "electronicpingshort.wav", 1.3, 0.35 } },
	Shield = { { S .. "electronicpingshort.wav", 0.8, 0.35 } },
	Hurt = { { S .. "action_jump_land.mp3", 0.9, 0.6 } },
	Stun = { { S .. "electronicpingshort.wav", 2.6, 0.25 }, { S .. "action_jump_land.mp3", 0.6, 0.5 } },
	Winded = { { S .. "action_jump.mp3", 0.5, 0.35 } },
	Combo = { { S .. "unsheath.wav", 2.4, 0.2 } },
	Death = { { S .. "swordlunge.wav", 0.4, 0.6 }, { S .. "action_jump_land.mp3", 0.5, 0.7, 0.05 } },
	Warn = { { S .. "clickfast.wav", 0.8, 0.5 } },
	Kill = { { S .. "victory.wav", 1, 0.35 } },
}

-- Shortest gap between two plays of the same sound, so a flurry doesn't pile up.
local MIN_GAP =
	{ Hit = 0.04, Burn = 0.25, Corrode = 0.25, Freeze = 0.25, Zap = 0.08, Warn = 0.4, Hurt = 0.08, Combo = 0.05 }
local DEFAULT_GAP = 0.03
local MAX_VOICES = 28
local CRITICAL = { Parry = true, GuardBreak = true, Hurt = true, NovaWarn = true, Warn = true }
local lastPlayed: { [string]: number } = {}
local lastTake: { [string]: string } = {}
local voices = 0

-- The mix bus: punch from a compressor, a little EQ, a touch of arena reverb.
local group: SoundGroup? = nil
local function combatGroup(): SoundGroup
	if not group or not group.Parent then
		local made = Instance.new("SoundGroup")
		made.Name = "CombatSounds"
		local compressor = Instance.new("CompressorSoundEffect")
		compressor.Threshold, compressor.Ratio, compressor.Attack, compressor.Release, compressor.GainMakeup =
			-16, 3, 0.006, 0.14, 1.5
		compressor.Priority = 2
		compressor.Parent = made
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain, eq.MidGain, eq.HighGain = 1.5, -1.5, 0.5
		eq.Priority = 1
		eq.Parent = made
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime, reverb.Density, reverb.Diffusion, reverb.DryLevel, reverb.WetLevel = 0.55, 0.7, 0.7, 0, -22
		reverb.Priority = 0
		reverb.Parent = made
		made.Parent = SoundService
		group = made
	end
	local current = group :: SoundGroup
	current.Volume = CombatSound.Volume
	return current
end

-- The uploaded takes of a sound: its own id, or its numbered takes.
local function takes(name: string): { string }
	local found = {}
	local own = CombatSound.Ids[name]
	if own and own ~= 0 then
		table.insert(found, name)
	end
	for i = 1, 9 do
		local id = CombatSound.Ids[name .. i]
		if id == nil then
			break
		end
		if id ~= 0 then
			table.insert(found, name .. i)
		end
	end
	return found
end

local function emit(
	soundId: string,
	speed: number,
	volume: number,
	position: Vector3?,
	delay: number?,
	critical: boolean?
)
	if voices >= (if critical then MAX_VOICES else MAX_VOICES - 6) then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.SoundGroup = combatGroup()
	local holder: Instance
	if position then
		-- In the world, at the spot: louder close up, gone past 160 studs.
		local spot = Instance.new("Attachment")
		spot.Name = "CombatSound"
		spot.Parent = workspace.Terrain
		spot.WorldPosition = position
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = 160
		sound.Parent = spot
		holder = spot
	else
		sound.Parent = combatGroup()
		holder = sound
	end
	voices += 1
	local released = false
	local function release()
		if released then
			return
		end
		released = true
		voices -= 1
		holder:Destroy()
	end
	sound.Ended:Once(release)
	holder.Destroying:Once(function()
		if not released then
			released = true
			voices -= 1
		end
	end)
	local function start()
		if released then
			return
		end
		pcall(function()
			sound:Play()
		end)
	end
	if delay and delay > 0 then
		task.delay(delay, start)
	else
		start()
	end
	Debris:AddItem(holder, 6 + (delay or 0))
end

-- `options`: Volume (multiplier), Pitch (multiplier).
function CombatSound.play(name: string, position: Vector3?, options: { Volume: number?, Pitch: number? }?)
	if CombatSound.Volume <= 0 then
		return
	end
	-- Ignore inaudible remote fights before allocating emitters or consuming cooldowns.
	local camera = workspace.CurrentCamera
	if position and camera and (position - camera.CFrame.Position).Magnitude > 160 then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < (MIN_GAP[name] or DEFAULT_GAP) then
		return
	end
	lastPlayed[name] = now
	local volume = (LEVEL[name] or 0.85) * (options and options.Volume or 1)
	local pitch = (options and options.Pitch or 1) * (0.94 + math.random() * 0.12)
	local found = takes(name)
	if #found > 0 then
		-- A take at random, never the same one twice running.
		local pick = found[math.random(1, #found)]
		if #found > 1 and pick == lastTake[name] then
			pick = found[(table.find(found, pick) :: number) % #found + 1]
		end
		lastTake[name] = pick
		emit("rbxassetid://" .. CombatSound.Ids[pick], pitch, volume, position, nil, CRITICAL[name])
		return
	end
	for _, layer in FALLBACK[name] or {} do
		emit(layer[1], layer[2] * pitch, layer[3] * volume, position, layer[4], CRITICAL[name])
	end
end

-- Which element a colour is (the game's element colours), if any.
function CombatSound.elementOf(color: Color3?): string?
	return GemConfig.elementOfColor(color)
end

-- An element's own layer: "Cast" or "Impact" for Fire, Frost, Shock or Poison.
function CombatSound.element(
	kind: string,
	element: string?,
	position: Vector3?,
	options: { Volume: number?, Pitch: number? }?
)
	if element == "Fire" or element == "Frost" or element == "Shock" or element == "Poison" then
		CombatSound.play(kind .. element, position, options)
	end
end

return CombatSound
