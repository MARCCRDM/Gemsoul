--[[
	Menu sounds: hover, click, tab, confirm, back, window open and close,
	notifications, errors, coins, rewards, crafting, enchanting and equipping.

	UiSound.play("Click") plays one. Most of it is automatic:
	  UiSounds.client.luau  hover and click on every button (a button picks its
	                        sound with the "UiSound" attribute: "Confirm", "Tab",
	                        "Back", or "None" for no sound)
	  IronUi.window         open and close
	  UiKit.toast           notifications and errors
	  GemClient.request     coins, craft, enchant, equip and reward replies

	Roblox only plays uploaded audio, so the sounds in assets/sounds are not
	used until they are uploaded: in Creator Hub, Audio, upload each .mp3, copy
	its id and paste it below. Until an id is set, a built-in Roblox sound
	stands in so the menus are never silent. (tools/make_sounds.py rebuilds
	the files; assets/sounds/_preview_all.mp3 plays them all in turn.)
]]
local SoundService = game:GetService("SoundService")

local UiSound = {}

-- Roblox ids of the uploaded files (the number from rbxassetid://12345). 0 = not uploaded yet.
UiSound.Ids = {
	Hover = 0, -- hover.mp3
	Click = 0, -- click.mp3
	Tab = 0, -- tab.mp3
	Confirm = 0, -- confirm.mp3
	Back = 0, -- back.mp3
	Open = 0, -- open.mp3
	Close = 0, -- close.mp3
	Notify = 0, -- notify.mp3
	Error = 0, -- error.mp3
	Coin = 0, -- coin.mp3
	Reward = 0, -- reward.mp3
	Craft = 0, -- craft.mp3
	Enchant = 0, -- enchant.mp3
	Equip = 0, -- equip.mp3
}

-- 0 mutes every menu sound, 1 is full.
UiSound.Volume = 1

-- What plays until an id is set: { Roblox sound, speed, volume }.
local FALLBACK = {
	Hover = { "rbxasset://sounds/clickfast.wav", 2.4, 0.1 },
	Click = { "rbxasset://sounds/switch.wav", 1.4, 0.3 },
	Tab = { "rbxasset://sounds/clickfast.wav", 1.6, 0.22 },
	Confirm = { "rbxasset://sounds/electronicpingshort.wav", 1.25, 0.3 },
	Back = { "rbxasset://sounds/switch.wav", 0.85, 0.28 },
	Open = { "rbxasset://sounds/electronicpingshort.wav", 0.9, 0.25 },
	Close = { "rbxasset://sounds/switch.wav", 0.7, 0.22 },
	Notify = { "rbxasset://sounds/electronicpingshort.wav", 1.05, 0.28 },
	Error = { "rbxasset://sounds/switch.wav", 0.55, 0.3 },
	Coin = { "rbxasset://sounds/electronicpingshort.wav", 1.9, 0.28 },
	Reward = { "rbxasset://sounds/victory.wav", 1, 0.3 },
	Craft = { "rbxasset://sounds/electronicpingshort.wav", 0.7, 0.35 },
	Enchant = { "rbxasset://sounds/electronicpingshort.wav", 1.5, 0.3 },
	Equip = { "rbxasset://sounds/switch.wav", 1.1, 0.3 },
}

-- Shortest time between two plays of the same sound, so a flurry doesn't pile up.
local MIN_GAP = { Hover = 0.06, Error = 0.3, Notify = 0.2, Coin = 0.12 }
local DEFAULT_GAP = 0.03
local VOICES = 3 -- copies of each sound, so quick repeats can overlap

local group: SoundGroup? = nil
local pools: { [string]: { Index: number, Sounds: { Sound } } } = {}
local lastPlayed: { [string]: number } = {}

local function menuGroup(): SoundGroup
	if not group then
		local made = Instance.new("SoundGroup")
		made.Name = "MenuSounds"
		made.Parent = SoundService
		group = made
	end
	local current = group :: SoundGroup
	current.Volume = UiSound.Volume
	return current
end

local function makePool(name: string)
	local pool = { Index = 0, Sounds = {} :: { Sound } }
	local id = UiSound.Ids[name]
	local fallback = FALLBACK[name]
	for _ = 1, VOICES do
		local sound = Instance.new("Sound")
		sound.Name = name
		if id and id ~= 0 then
			sound.SoundId = "rbxassetid://" .. id
			sound.Volume = 1
		elseif fallback then
			sound.SoundId = fallback[1]
			sound.PlaybackSpeed = fallback[2]
			sound.Volume = fallback[3]
		end
		sound.SoundGroup = menuGroup()
		sound.Parent = menuGroup()
		table.insert(pool.Sounds, sound)
	end
	pools[name] = pool
	return pool
end

function UiSound.play(name: string)
	if UiSound.Volume <= 0 or (not UiSound.Ids[name] and not FALLBACK[name]) then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < (MIN_GAP[name] or DEFAULT_GAP) then
		return
	end
	lastPlayed[name] = now
	local pool = pools[name] or makePool(name)
	pool.Index = pool.Index % VOICES + 1
	local sound = pool.Sounds[pool.Index]
	menuGroup()
	pcall(function()
		sound.TimePosition = 0
		sound:Play()
	end)
end

-- Is this toast colour a warning (red)? Used to pick the error sound.
function UiSound.isAlert(color: Color3?): boolean
	return color ~= nil and color.R > 0.8 and color.G < 0.45 and color.B < 0.45
end

return UiSound
