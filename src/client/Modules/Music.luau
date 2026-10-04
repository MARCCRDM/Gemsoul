--[[
	Background music: cuts of the game's theme song (made by
	tools/cut_song.py into assets/music/), one seamless loop per mood:

	  Menu     the breakdown       menus and the dashboard
	  Outpost  the first verse     exploring and mining at the Outpost
	  Dungeon  the second drop     squad dungeons
	  Fight    the final drop      raids (and fights, until Arena has an id)
	  Arena    its own song        1v1s: the rival, PvP and duels; starts at
	                               StartAt (0:39) every match and loops back there

	Changing mood crossfades between them. Roblox only plays uploaded audio:
	run tools/upload_audio.py (or upload the .ogg files in Creator Hub,
	Audio) and put the ids below. A mood with no id stays silent.
]]
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Music = {}

-- Roblox ids of the uploaded tracks (the number from rbxassetid://12345). 0 = not uploaded yet.
Music.Ids = {
	Menu = 82248033426754, -- menu_theme.ogg
	Outpost = 71113976425409, -- outpost_theme.ogg
	Dungeon = 75260701190300, -- dungeon_theme.ogg
	Fight = 83708484138750, -- fight_theme.ogg
	Intro = 74920383589616, -- intro_sting.ogg (the splash's music when there's no video yet)
	Arena = 129649283919546, -- Capt Hunchines - Imminent DAY1 instr 5.mp3 (1v1 Arena song)
}

-- Moods that start part-way into their song each time they come on, in seconds.
Music.StartAt = { Arena = 39 } -- 0:39

-- How loud each mood plays (0 mutes it).
Music.Volumes = { Menu = 0.3, Outpost = 0.32, Dungeon = 0.42, Fight = 0.45, Arena = 0.45 }
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
	made.Volume = 0
	local startAt = Music.StartAt[mood]
	-- A song that starts part-way loops back to that point, not to its intro.
	made.Looped = startAt == nil
	if startAt then
		made.Ended:Connect(function()
			if current == mood then
				made.TimePosition = startAt
				made:Play()
			end
		end)
	end
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
	local startAt = Music.StartAt[mood]
	if startAt then
		-- Every match starts the song at the same moment (once it has loaded,
		-- or the jump is ignored).
		sound.TimePosition = startAt
		sound:Play()
		task.spawn(function()
			if not sound.IsLoaded then
				sound.Loaded:Wait()
			end
			if current == mood and sound.TimePosition < startAt then
				sound.TimePosition = startAt
			end
		end)
	elseif not sound.IsPlaying then
		-- Pick up where it left off (a paused loop), or start it.
		if sound.TimePosition > 0 then
			sound:Resume()
		else
			sound:Play()
		end
	end
	-- A song with a start point comes in right away, so its start point is heard at once.
	local fadeIn = if startAt then TweenInfo.new(0.25, Enum.EasingStyle.Sine) else fade
	TweenService:Create(sound, fadeIn, { Volume = Music.Volumes[mood] or 0.3 }):Play()
end

-- Which mood fits what the player is doing (from their attributes).
function Music.moodFor(attributes: { [string]: any }): string
	if attributes.DungeonId ~= nil then
		return "Dungeon"
	elseif attributes.CombatSession ~= nil then
		-- 1v1s (the rival, Arena PvP and duels) have their own song.
		local session = attributes.CombatSession
		if
			(session == "Training" or session == "PvP" or session == "Duel")
			and Music.Ids.Arena
			and Music.Ids.Arena ~= 0
		then
			return "Arena"
		end
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
