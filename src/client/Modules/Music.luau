--[[
	Background music: "Neon Arena", a cyberpunk loop (made by
	tools/make_music.py into assets/music/arena_loop.mp3). It plays softly
	in the menus and turns up in Arena fights, fading between the two.

	Roblox only plays uploaded audio: run tools/upload_audio.py (or upload
	arena_loop.mp3 in Creator Hub, Audio) and put its id below. Until then
	there's no music.
]]
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Music = {}

-- Roblox ids of the uploaded tracks (the number from rbxassetid://12345). 0 = not uploaded yet.
Music.Ids = {
	Arena = 0, -- arena_loop.mp3
}

-- How loud it plays in the menus and in a fight (0 mutes it).
Music.MenuVolume = 0.22
Music.FightVolume = 0.42

local sound: Sound? = nil
local warned = false

local function track(): Sound?
	if sound then
		return sound
	end
	local id = Music.Ids.Arena
	if not id or id == 0 then
		if not warned then
			warned = true
			print(
				"[Music] No music yet: upload assets/music/arena_loop.mp3 (tools/upload_audio.py) and set Music.Ids.Arena."
			)
		end
		return nil
	end
	local made = Instance.new("Sound")
	made.Name = "ArenaMusic"
	made.SoundId = "rbxassetid://" .. id
	made.Looped = true
	made.Volume = 0
	made.Parent = SoundService
	sound = made
	return made
end

-- Fight or menus: fades to that level (starting the loop if needed).
function Music.setMood(fighting: boolean)
	local current = track()
	if not current then
		return
	end
	if not current.IsPlaying then
		current:Play()
	end
	local target = if fighting then Music.FightVolume else Music.MenuVolume
	TweenService:Create(current, TweenInfo.new(1.5, Enum.EasingStyle.Sine), { Volume = target }):Play()
end

return Music
