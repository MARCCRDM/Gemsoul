--[[
	Combat sounds: swings, hits, crits, blocks, parries, dodges, casts,
	blasts, burns, freezes, zaps, heals, shields and more.

	CombatSound.play("Hit", position) plays one in 3D at that spot (louder
	when close); without a position it plays flat, for your own feedback
	(hurt, warnings). Each play is pitched slightly differently so repeats
	don't sound robotic.

	Roblox only plays uploaded audio, so the files in assets/sounds/combat
	(made by tools/make_combat_sounds.py; _preview_all.mp3 plays them all)
	aren't used until they're uploaded: in Creator Hub, Audio, upload each
	.mp3, copy its id and paste it below. Until then a built-in Roblox sound
	stands in, so combat is never silent.
]]
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local CombatSound = {}

-- Roblox ids of the uploaded files (the number from rbxassetid://12345). 0 = not uploaded yet.
CombatSound.Ids = {
	Swing = 0, -- swing.mp3
	HeavySwing = 0, -- heavy_swing.mp3
	Shot = 0, -- shot.mp3
	Hit = 0, -- hit.mp3
	Crit = 0, -- crit.mp3
	Block = 0, -- block.mp3
	GuardBreak = 0, -- guard_break.mp3
	Parry = 0, -- parry.mp3
	Hop = 0, -- hop.mp3
	Roll = 0, -- roll.mp3
	Cast = 0, -- cast.mp3
	Bolt = 0, -- bolt.mp3
	NovaWarn = 0, -- nova_warn.mp3
	Blast = 0, -- blast.mp3
	Zap = 0, -- zap.mp3
	Burn = 0, -- burn.mp3
	Freeze = 0, -- freeze.mp3
	Corrode = 0, -- corrode.mp3
	Heal = 0, -- heal.mp3
	Shield = 0, -- shield.mp3
	Hurt = 0, -- hurt.mp3
	Death = 0, -- death.mp3
	Warn = 0, -- warn.mp3
	Kill = 0, -- kill.mp3
}

-- 0 mutes combat, 1 is full.
CombatSound.Volume = 0.8

-- Stand-ins until an id is set: { built-in Roblox sound, speed, volume }.
local FALLBACK = {
	Swing = { "rbxasset://sounds/swordslash.wav", 1.15, 0.45 },
	HeavySwing = { "rbxasset://sounds/swordlunge.wav", 0.8, 0.6 },
	Shot = { "rbxasset://sounds/electronicpingshort.wav", 2.2, 0.35 },
	Hit = { "rbxasset://sounds/swordslash.wav", 0.6, 0.5 },
	Crit = { "rbxasset://sounds/swordlunge.wav", 1.3, 0.6 },
	Block = { "rbxasset://sounds/unsheath.wav", 1.2, 0.55 },
	GuardBreak = { "rbxasset://sounds/unsheath.wav", 0.6, 0.7 },
	Parry = { "rbxasset://sounds/unsheath.wav", 1.6, 0.6 },
	Hop = { "rbxasset://sounds/action_jump.mp3", 1.2, 0.4 },
	Roll = { "rbxasset://sounds/swordlunge.wav", 0.55, 0.35 },
	Cast = { "rbxasset://sounds/electronicpingshort.wav", 0.6, 0.35 },
	Bolt = { "rbxasset://sounds/swordlunge.wav", 1.5, 0.45 },
	NovaWarn = { "rbxasset://sounds/electronicpingshort.wav", 0.45, 0.4 },
	Blast = { "rbxasset://sounds/action_jump_land.mp3", 0.5, 0.9 },
	Zap = { "rbxasset://sounds/electronicpingshort.wav", 3, 0.35 },
	Burn = { "rbxasset://sounds/swordlunge.wav", 0.45, 0.4 },
	Freeze = { "rbxasset://sounds/electronicpingshort.wav", 1.8, 0.35 },
	Corrode = { "rbxasset://sounds/switch.wav", 0.6, 0.4 },
	Heal = { "rbxasset://sounds/electronicpingshort.wav", 1.3, 0.35 },
	Shield = { "rbxasset://sounds/electronicpingshort.wav", 0.8, 0.35 },
	Hurt = { "rbxasset://sounds/action_jump_land.mp3", 0.9, 0.6 },
	Death = { "rbxasset://sounds/uuhhh.mp3", 1, 0.5 },
	Warn = { "rbxasset://sounds/clickfast.wav", 0.8, 0.5 },
	Kill = { "rbxasset://sounds/victory.wav", 1, 0.35 },
}

-- Shortest gap between two plays of the same sound, so a flurry doesn't pile up.
local MIN_GAP = { Hit = 0.04, Burn = 0.25, Corrode = 0.25, Freeze = 0.25, Zap = 0.08, Warn = 0.4, Hurt = 0.08 }
local DEFAULT_GAP = 0.03
local lastPlayed: { [string]: number } = {}

local group: SoundGroup? = nil
local function combatGroup(): SoundGroup
	if not group then
		local made = Instance.new("SoundGroup")
		made.Name = "CombatSounds"
		made.Parent = SoundService
		group = made
	end
	local current = group :: SoundGroup
	current.Volume = CombatSound.Volume
	return current
end

local function source(name: string): (string?, number, number)
	local id = CombatSound.Ids[name]
	if id and id ~= 0 then
		return "rbxassetid://" .. id, 1, 1
	end
	local fallback = FALLBACK[name]
	if fallback then
		return fallback[1], fallback[2], fallback[3]
	end
	return nil, 1, 1
end

-- `options`: Volume (multiplier), Pitch (multiplier).
function CombatSound.play(name: string, position: Vector3?, options: { Volume: number?, Pitch: number? }?)
	if CombatSound.Volume <= 0 then
		return
	end
	local soundId, speed, volume = source(name)
	if not soundId then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < (MIN_GAP[name] or DEFAULT_GAP) then
		return
	end
	lastPlayed[name] = now
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Volume = volume * (options and options.Volume or 1)
	sound.PlaybackSpeed = speed * (options and options.Pitch or 1) * (0.94 + math.random() * 0.12)
	sound.SoundGroup = combatGroup()
	local holder: Instance
	if position then
		-- In the world, at the spot: louder close up, gone past 140 studs.
		local spot = Instance.new("Attachment")
		spot.Name = "CombatSound"
		spot.Parent = workspace.Terrain
		spot.WorldPosition = position
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = 140
		sound.Parent = spot
		holder = spot
	else
		sound.Parent = combatGroup()
		holder = sound
	end
	pcall(function()
		sound:Play()
	end)
	Debris:AddItem(holder, 3)
end

return CombatSound
