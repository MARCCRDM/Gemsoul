-- lune run tests/voice_volume_cases.luau <repo>
-- Voice chat louder (Shared.VoiceVolume): each player's voice input turned
-- up, each voice emitter on a character fading gently; anything else left
-- alone, and an API that isn't there never stops it.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	if not value then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(message) .. "\n")
		process.exit(1)
	end
end
local function signal()
	local list = {}
	return {
		Connect = function(_, fn) table.insert(list, fn) return {} end,
		Fire = function(_, ...) for _, fn in list do fn(...) end end,
	}
end
local function thing(class)
	local t = { ClassName = class, Children = {}, ChildAdded = signal(), DescendantAdded = signal() }
	function t:IsA(c) return self.ClassName == c end
	function t:GetChildren() return self.Children end
	function t:GetDescendants() return self.Children end
	return t
end
local playerAdded = signal()
local list = {}
local env = setmetatable({
	game = { GetService = function() return { PlayerAdded = playerAdded, GetPlayers = function() return list end } end },
	task = { spawn = function(fn, ...) fn(...) end },
}, { __index = _G })
local Voice = luau.load(fs.readFile(ROOT .. "/src/shared/VoiceVolume.luau"), { debugName = "VoiceVolume", environment = env })()

-- One already in, with a voice; one joining after.
local function newPlayer()
	local p = thing("Player")
	p.CharacterAdded = signal()
	return p
end
local early = newPlayer()
local input = thing("AudioDeviceInput")
input.Volume = 1
table.insert(early.Children, input)
local character = thing("Model")
local emitter = thing("AudioEmitter")
function emitter:SetDistanceAttenuation(curve) self.Curve = curve end
table.insert(character.Children, emitter)
early.Character = character
table.insert(list, early)
Voice.start()
check(input.Volume == Voice.Boost and Voice.Boost > 1, "A voice already in wasn't turned up")
check(emitter.Curve == Voice.Curve, "A voice's emitter still fades the default way")
check(Voice.Curve[0] == 1 and Voice.Curve[80] > 0.5, "Voices fade too fast with distance")

local late = newPlayer()
playerAdded:Fire(late)
local later = thing("AudioDeviceInput")
later.Volume = 1
late.ChildAdded:Fire(later)
check(later.Volume == Voice.Boost, "A voice coming in later wasn't turned up")
local body = thing("Model")
late.CharacterAdded:Fire(body)
local e2 = thing("AudioEmitter")
function e2:SetDistanceAttenuation(curve) self.Curve = curve end
body.DescendantAdded:Fire(e2)
check(e2.Curve == Voice.Curve, "A respawned character's voice fades the default way")
-- Anything else left alone; an emitter without the method never stops it.
local sound = thing("Sound")
sound.Volume = 0.3
late.ChildAdded:Fire(sound)
check(sound.Volume == 0.3, "Something that isn't a voice was turned up")
local odd = thing("AudioEmitter")
local ok = pcall(function() body.DescendantAdded:Fire(odd) end)
check(ok, "An emitter without SetDistanceAttenuation stopped it")
print(string.format("PASS: %d voice volume checks", checks))
process.exit(0)
