--[[
	Voice chat, louder. Roblox's voice (VoiceChatService with the audio API)
	puts an AudioDeviceInput under each player who talks and an AudioEmitter
	on their character, heard through each listener: by default it's quiet
	beside the game's music and fades fast with distance. Here every voice's
	input is turned up (Boost) and its emitter fades gently (Curve: distance
	in studs -> volume).

	Only voice's own objects are touched; anything that isn't there (voice
	off, the older voice without the audio API) is left alone, and nothing
	here can stop a script. Started on the server (Main) and on each client
	(Lobby.client): whichever side the voice objects answer to, both set them.

	  VoiceVolume.Boost, VoiceVolume.Curve
	  VoiceVolume.start()
]]
local Players = game:GetService("Players")

local VoiceVolume = {}

VoiceVolume.Boost = 2 -- each voice's input volume (Roblox's default: 1)
VoiceVolume.Curve = { -- studs -> volume: full volume near, still heard across a room
	[0] = 1,
	[30] = 1,
	[80] = 0.75,
	[150] = 0.4,
	[240] = 0,
}

local function boost(input: Instance)
	if input:IsA("AudioDeviceInput") then
		pcall(function()
			(input :: any).Volume = VoiceVolume.Boost
		end)
	end
end

local function soften(emitter: Instance)
	if emitter:IsA("AudioEmitter") then
		pcall(function()
			(emitter :: any):SetDistanceAttenuation(VoiceVolume.Curve)
		end)
	end
end

local function watch(player: Player)
	for _, child in player:GetChildren() do
		boost(child)
	end
	player.ChildAdded:Connect(boost)
	local function character(model: Model)
		for _, d in model:GetDescendants() do
			soften(d)
		end
		model.DescendantAdded:Connect(soften)
	end
	if player.Character then
		character(player.Character)
	end
	player.CharacterAdded:Connect(character)
end

local started = false
function VoiceVolume.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
end

return VoiceVolume
