--[[
	Background music: cuts of the game's theme song (made by
	tools/cut_song.py into assets/music/), one seamless loop per mood:

	  Menu     the breakdown       menus and the dashboard
	  Outpost  the first verse     exploring and mining at the Outpost
	  Dungeon  the second drop     squad dungeons
	  Fight    the final drop      Arena fights, duels and raids

	Changing mood crossfades between them. Roblox only plays uploaded audio:
	run tools/upload_audio.py (or upload the .ogg files in Creator Hub,
	Audio) and put the ids below. A mood with no id stays silent.
]]
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Music = {}

-- Roblox ids of the uploaded tracks (the number from rbxassetid://12345). 0 = not uploaded yet.
Music.Ids = {
	Menu = 0, -- menu_theme.ogg
	Outpost = 0, -- outpost_theme.ogg
	Dungeon = 0, -- dungeon_theme.ogg
	Fight = 0, -- fight_theme.ogg
}

-- How loud each mood plays (0 mutes it).
Music.Volumes = { Menu = 0.3, Outpost = 0.32, Dungeon = 0.42, Fight = 0.45 }
Music.FadeSeconds = 2

local sounds: { [string]: Sound } = {}
local current: string? = nil
local warned = false

local function track(mood: string): Sound?
	if sounds[mood] then
		return sounds[mood]
	end
	local id = Music.Ids[mood]
	if not id or id == 0 then
		if not warned then
			warned = true
			print("[Music] No music yet: upload assets/music/*.ogg (tools/upload_audio.py) and set Music.Ids.")
		end
		return nil
	end
	local made = Instance.new("Sound")
	made.Name = mood .. "Music"
	made.SoundId = "rbxassetid://" .. id
	made.Looped = true
	made.Volume = 0
	made.Parent = SoundService
	sounds[mood] = made
	return made
end

-- Fades to `mood`'s loop, fading every other one out (and pausing it once silent).
function Music.play(mood: string)
	if mood == current then
		return
	end
	current = mood
	local fade = TweenInfo.new(Music.FadeSeconds, Enum.EasingStyle.Sine)
	for name, sound in sounds do
		if name ~= mood then
			local out = TweenService:Create(sound, fade, { Volume = 0 })
			out.Completed:Connect(function()
				if current ~= name and sound.Volume <= 0.001 then
					sound:Pause()
				end
			end)
			out:Play()
		end
	end
	local sound = track(mood)
	if not sound then
		return
	end
	if not sound.IsPlaying then
		-- Pick up where it left off (a paused loop), or start it.
		if sound.TimePosition > 0 then
			sound:Resume()
		else
			sound:Play()
		end
	end
	TweenService:Create(sound, fade, { Volume = Music.Volumes[mood] or 0.3 }):Play()
end

-- Which mood fits what the player is doing (from their attributes).
function Music.moodFor(attributes: { [string]: any }): string
	if attributes.DungeonId ~= nil then
		return "Dungeon"
	elseif attributes.CombatSession ~= nil then
		return "Fight"
	elseif attributes.Outpost == true then
		return "Outpost"
	end
	return "Menu"
end

-- Kept for older callers: a fight or the menus.
function Music.setMood(fighting: boolean)
	Music.play(if fighting then "Fight" else "Menu")
end

return Music
