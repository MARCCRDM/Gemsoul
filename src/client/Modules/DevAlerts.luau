--[[
	For the game's Owners only (Config.Playtest.Owners): someone joined the
	game, in any server (Server.DevAlerts). A notification in the corner and
	a toast, and a voice saying it: Roblox's text-to-speech (AudioTextToSpeech
	wired to your speakers), else a chime.

	  "New player! Sam just joined."      (their first join, just now)
	  "Sam joined."                       (someone coming back)

	  DevAlerts.start()                once (Lobby.client); nothing for anyone else
	  DevAlerts.line(data) -> string   what's said (pure)

	And an idle alarm, so an owner keeping the lobby company isn't kicked
	(Roblox disconnects anyone idle 20 minutes). No input for IdleWarn (16
	minutes: no mouse moving, no key, no touch, no pad; Roblox's own Idled
	count too): a notification, a toast and the voice, "Attention captain
	hunchies!", with a chime, again every IdleRepeat till they move.

	  DevAlerts.idleLine(seconds) -> string   what the alarm says (pure)
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

DevAlerts.IdleWarn = 16 * 60 -- seconds without input before the alarm
DevAlerts.IdleRepeat = 60 -- and again this often till they move
DevAlerts.IdleKick = 20 * 60 -- (Roblox's own idle disconnect)

function DevAlerts.idleLine(seconds: number): string
	local idle = math.floor(seconds / 60)
	local left = math.max(1, math.ceil((DevAlerts.IdleKick - seconds) / 60))
	return string.format(
		"Attention captain hunchies! You've been idle %d minutes. Move or you'll be kicked in %d minute%s.",
		idle,
		left,
		if left == 1 then "" else "s"
	)
end

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

-- The idle alarm: input resets it; Roblox's Idled tells it the real count.
local function idleAlarm()
	local UserInputService = game:GetService("UserInputService")
	local lastInput = os.clock()
	local nextAlarm = DevAlerts.IdleWarn
	local function moved()
		lastInput = os.clock()
		nextAlarm = DevAlerts.IdleWarn
	end
	UserInputService.InputBegan:Connect(moved)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.Gamepad1
			or input.UserInputType == Enum.UserInputType.MouseWheel
		then
			moved()
		end
	end)
	-- (Roblox's own count, which is what kicks: never less idle than it says)
	player.Idled:Connect(function(seconds: number)
		if type(seconds) == "number" then
			lastInput = math.min(lastInput, os.clock() - seconds)
		end
	end)
	task.spawn(function()
		while player.Parent do
			task.wait(5)
			local idle = os.clock() - lastInput
			if idle >= nextAlarm then
				nextAlarm = idle + DevAlerts.IdleRepeat
				local line = DevAlerts.idleLine(idle)
				pcall(function()
					StarterGui:SetCore("SendNotification", { Title = "ATTENTION CAPTAIN HUNCHIES", Text = line, Duration = 20 })
				end)
				UiKit.toast(line, Color3.fromRGB(255, 120, 90))
				local chime = Instance.new("Sound")
				chime.SoundId = DevAlerts.Chime
				chime.Volume = 1
				SoundService:PlayLocalSound(chime)
				say(line)
			end
		end
	end)
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
	pcall(idleAlarm)
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
