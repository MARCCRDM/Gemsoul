--[[
	A voice reading a line out loud, on this screen only: Roblox's
	text-to-speech (AudioTextToSpeech) wired to your speakers. Quiet if it
	can't (the line is always on screen too). One line at a time: a new one
	cuts the last off.

	  VoiceOver.say(text)   reads it
	  VoiceOver.stop()      stops the line being read
]]
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local VoiceOver = {}
VoiceOver.Voice = "1" -- AudioTextToSpeech.VoiceId
VoiceOver.Volume = 1

local current: Instance? = nil

function VoiceOver.stop()
	if current then
		pcall(function()
			(current :: any):Destroy()
		end)
		current = nil
	end
end

function VoiceOver.say(text: string)
	VoiceOver.stop()
	pcall(function()
		local voice = Instance.new("AudioTextToSpeech")
		voice.Text = text
		voice.VoiceId = VoiceOver.Voice
		voice.Volume = VoiceOver.Volume
		local out = Instance.new("AudioDeviceOutput")
		out.Player = Players.LocalPlayer
		local wire = Instance.new("Wire")
		wire.SourceInstance = voice
		wire.TargetInstance = out
		voice.Parent = SoundService
		out.Parent = voice
		wire.Parent = voice
		current = voice
		pcall(function()
			voice:LoadAsync()
		end)
		if current == voice then
			voice:Play()
			task.delay(30, function()
				if voice.Parent then
					voice:Destroy()
				end
				if current == voice then
					current = nil
				end
			end)
		end
	end)
end

return VoiceOver
