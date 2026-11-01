--[[
	For the game's Owners only (Config.Playtest.Owners): someone joined the
	game, in any server (Server.DevAlerts). A notification in the corner and
	a toast, and a voice saying it: Roblox's text-to-speech (AudioTextToSpeech
	wired to your speakers), else a chime.

	  "New player! Sam just joined."      (their first join, just now)
	  "Sam joined."                       (someone coming back)

	  DevAlerts.start()                once (Lobby.client); nothing for anyone else
	  DevAlerts.line(data) -> string   what's said (pure)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local UiKit = require(script.Parent.UiKit)

local DevAlerts = {}

DevAlerts.Voice = "1" -- AudioTextToSpeech.VoiceId
DevAlerts.Chime = "rbxasset://sounds/electronicpingshort.wav"

local player = Players.LocalPlayer

function DevAlerts.line(data): string
	local name = tostring(data.Name or data.User or "Someone")
	return if data.New then string.format("New player! %s just joined.", name) else string.format("%s joined.", name)
end

-- Says `text` out loud on this screen only; a chime if the voice can't.
local function say(text: string)
	local spoken = pcall(function()
		local voice = Instance.new("AudioTextToSpeech")
		voice.Text = text
		voice.VoiceId = DevAlerts.Voice
		local out = Instance.new("AudioDeviceOutput")
		out.Player = player
		local wire = Instance.new("Wire")
		wire.SourceInstance = voice
		wire.TargetInstance = out
		voice.Parent = SoundService
		out.Parent = voice
		wire.Parent = voice
		pcall(function()
			voice:LoadAsync()
		end)
		voice:Play()
		task.delay(12, function()
			voice:Destroy()
		end)
	end)
	if not spoken then
		local chime = Instance.new("Sound")
		chime.SoundId = DevAlerts.Chime
		chime.Volume = 0.8
		SoundService:PlayLocalSound(chime)
	end
end

local started = false
function DevAlerts.start()
	if started then
		return
	end
	started = true
	local owners = Config.Playtest and Config.Playtest.Owners or {}
	if not table.find(owners, player.UserId) then
		return
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DevAlert", 30)
	if not remote then
		return
	end
	remote.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		local line = DevAlerts.line(data)
		local detail = string.format("@%s  ·  %s in their server (%s)", tostring(data.User), tostring(data.Players or "?"), tostring(data.Server or "?"))
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = if data.New then "NEW PLAYER" else "Player joined",
				Text = line .. "\n" .. detail,
				Duration = 8,
			})
		end)
		UiKit.toast(line, if data.New then Color3.fromRGB(90, 220, 150) else nil)
		say(line)
	end)
end

return DevAlerts
