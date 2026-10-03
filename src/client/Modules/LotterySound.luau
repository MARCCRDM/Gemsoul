--[[
	The launch lottery's sound: a sci-fi vault opening, not a slot machine.

	  SealBreak   the capsule unlocks: clamps release, air hisses, energy swells
	  hum(on)     a reactor throb while the reels run (rises as cards lock)
	  tick(rise)  a soft data blip as a reel steps, climbing as it slows
	  Lock        a reel locks: a hydraulic clamp
	  reveal(n)   crystal resonance by rarity: one note (Common), a fifth
	              (Uncommon), a rising arpeggio (Rare), a swell into a bright
	              chord with a boom (Ultra Rare), a cinematic hit with a
	              choir-like chord and a crystal cascade (Legendary)
	  Attune      the loadout attunes: a resonant chord, instead of a fanfare

	The files in assets/sounds/lottery come from tools/make_lottery_sounds.py
	and play once uploaded (python tools/upload_audio.py --key KEY --user ID
	fills in the ids below). Until then soft crystal chords built from
	Roblox's own tones stand in, and the reels tick very quietly.
]]
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local LotterySound = {}

-- Roblox ids of the uploaded files (the number from rbxassetid://12345). 0 = not uploaded yet.
LotterySound.Ids = {
	SealBreak = 0, -- seal_break.mp3
	SpinHum = 0, -- spin_hum.ogg
	Tick = 0, -- tick.mp3
	Lock = 0, -- lock.mp3
	Reveal1 = 0, -- reveal_1.mp3
	Reveal2 = 0, -- reveal_2.mp3
	Reveal3 = 0, -- reveal_3.mp3
	Reveal4 = 0, -- reveal_4.mp3
	Reveal5 = 0, -- reveal_5.mp3
	Attune = 0, -- attune.mp3
}

LotterySound.Volume = 0.8

-- Stand-ins until uploaded: layers of { sound, speed, volume, delay? }.
-- Speeds 1 / 1.26 / 1.5 / 2 make a major chord of one crystal tone.
local PING = "rbxasset://sounds/electronicpingshort.wav"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local RING = "rbxasset://sounds/unsheath.wav"
local FALLBACK = {
	SealBreak = {
		{ THUD, 0.7, 0.35 },
		{ "rbxasset://sounds/swordlunge.wav", 0.45, 0.25, 0.05 },
		{ PING, 0.5, 0.15, 0.3 },
	},
	Tick = { { PING, 3.2, 0.035 } },
	Lock = { { THUD, 1.5, 0.3 }, { RING, 0.85, 0.18 } },
	Reveal1 = { { PING, 1, 0.22 } },
	Reveal2 = { { PING, 1, 0.22 }, { PING, 1.5, 0.18, 0.07 } },
	Reveal3 = { { PING, 1, 0.22 }, { PING, 1.26, 0.2, 0.07 }, { PING, 1.5, 0.2, 0.14 }, { THUD, 0.8, 0.2 } },
	Reveal4 = {
		{ THUD, 0.6, 0.45 },
		{ PING, 1, 0.24 },
		{ PING, 1.26, 0.22 },
		{ PING, 1.5, 0.22 },
		{ PING, 2, 0.16, 0.05 },
		{ RING, 1.8, 0.15, 0.04 },
	},
	Reveal5 = {
		{ THUD, 0.45, 0.6 },
		{ PING, 1, 0.26 },
		{ PING, 1.26, 0.24 },
		{ PING, 1.5, 0.24 },
		{ PING, 2, 0.2, 0.06 },
		{ PING, 2.52, 0.14, 0.12 },
		{ PING, 3, 0.12, 0.18 },
		{ RING, 2.2, 0.2, 0.05 },
	},
	Attune = { { THUD, 0.6, 0.35 }, { PING, 0.5, 0.2 }, { PING, 0.75, 0.2, 0.05 }, { PING, 1, 0.2, 0.1 } },
}

local group: SoundGroup? = nil
local function bus(): SoundGroup
	if not group or not group.Parent then
		local made = Instance.new("SoundGroup")
		made.Name = "LotterySounds"
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime, reverb.Density, reverb.Diffusion, reverb.DryLevel, reverb.WetLevel = 1.8, 0.9, 0.9, 0, -12
		reverb.Parent = made
		made.Parent = SoundService
		group = made
	end
	local current = group :: SoundGroup
	current.Volume = LotterySound.Volume
	return current
end

local function emit(soundId: string, speed: number, volume: number, delay: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.SoundGroup = bus()
	sound.Parent = bus()
	local function start()
		pcall(function()
			sound:Play()
		end)
	end
	if delay and delay > 0 then
		task.delay(delay, start)
	else
		start()
	end
	Debris:AddItem(sound, 5 + (delay or 0))
end

-- `pitch` multiplies the speed (ticks climb as a reel slows).
function LotterySound.play(name: string, pitch: number?, volume: number?)
	if LotterySound.Volume <= 0 then
		return
	end
	local id = LotterySound.Ids[name]
	if id and id ~= 0 then
		emit("rbxassetid://" .. id, pitch or 1, volume or 1)
		return
	end
	for _, layer in FALLBACK[name] or {} do
		emit(layer[1], layer[2] * (pitch or 1), layer[3] * (volume or 1), layer[4])
	end
end

-- A reel steps; `rise` 0..1 climbs the blip as the reel slows to a stop.
function LotterySound.tick(rise: number?)
	local r = math.clamp(rise or 0, 0, 1)
	LotterySound.play("Tick", 1 + r * 0.45 + (math.random() - 0.5) * 0.04, 0.6 + r * 0.4)
end

-- A card is revealed: its rarity (1 Common .. 5 Legendary).
function LotterySound.reveal(rank: number)
	LotterySound.play("Reveal" .. math.clamp(math.floor(rank), 1, 5))
end

-- The reactor hum under the spinning reels (uploaded only: it loops).
local hum: Sound? = nil
function LotterySound.hum(on: boolean, level: number?)
	local id = LotterySound.Ids.SpinHum
	if not on then
		if hum then
			hum:Destroy()
			hum = nil
		end
		return
	end
	if not id or id == 0 then
		return
	end
	if not hum then
		local made = Instance.new("Sound")
		made.SoundId = "rbxassetid://" .. id
		made.Looped = true
		made.Volume = 0.5
		made.SoundGroup = bus()
		made.Parent = bus()
		pcall(function()
			made:Play()
		end)
		hum = made
	end
	-- It rises as the cards lock in.
	local current = hum :: Sound
	current.PlaybackSpeed = 1 + math.clamp(level or 0, 0, 1) * 0.25
end

return LotterySound
