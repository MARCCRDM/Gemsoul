--[[
	The narrator (George, recorded: assets/sounds/narration): a line read out
	at a few moments of a new player's first steps, its words along the bottom
	of the screen while it plays (so a player with the sound off reads it).

	  "TrainingBegins"  the first intro round starts
	  "Controls"        right after it: the ability keys and combat buttons
	  "FirstDungeon"    arriving in the first dungeon
	  "KaijuTeam"       the starter kaiju roll (the spin waits for it)
	  "Basics..."       the first fight's lesson on its LED (Client.BasicsScreen):
	                    Attack, Block, Abilities, Dodge, Resources

	  Narration.play(name, quiet?) -> seconds   reads it (once a visit), returns how
	                                    long it takes (0: already read)
	  Narration.say(name)               the same, and waits till it's done
	  Narration.stop()
	  Narration.voiced(name) -> bool     its voice is uploaded (Ids)
	  Narration.elapsed() -> seconds     into the line being read (the sound's
	                                    own place while it plays)
	  Narration.Phrases, .Cues          a line read phrase by phrase: its
	                                    caption follows them (the basics)

	Roblox only plays uploaded audio: tools/upload_audio.py uploads the
	files and writes each id below. Until a line's id is set, only its
	words show, for as long as the line would take.
]]
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.UiKit)

local Narration = {}

-- Roblox ids of the uploaded files. 0 = not uploaded yet.
Narration.Ids = {
	TrainingBegins = 133370977482071, -- training_begins.mp3
	Controls = 89929747424764, -- controls.mp3
	FirstDungeon = 125560006550856, -- first_dungeon.mp3
	KaijuTeam = 133613092362157, -- kaiju_team.mp3
	RotMinions = 71254270011218, -- rot_minions.mp3
	BasicsAttack = 86694093254227, -- basics_attack.mp3
	BasicsBlock = 90769068160197, -- basics_block.mp3
	BasicsAbilities = 80319102339818, -- basics_abilities.mp3
	BasicsDodge = 114278772210482, -- basics_dodge.mp3
	BasicsResources = 119618357055313, -- basics_resources.mp3
}
Narration.Lines = {
	TrainingBegins = "Welcome, Miner. Your training begins now.",
	Controls = "Use your abilities to cast. Swing, block and dodge with your combat buttons.",
	FirstDungeon = "Miner... we don't know what these monsters are. But they come from a different dimension. And they are stealing our resources, and destroying our worlds.",
	KaijuTeam = "These are your kaiju. These powerful beasts will defend you, at all times. Train them... and heal them with gemsouls.",
	RotMinions = "These are rot minions. They still try to steal your gems. Your kaijus are trained to fight and defend you.",
	BasicsAttack = "First, attacking. Press attack to swing your weapon. Keep swinging to chain a combo. Hold it down, for a heavy blow.",
	BasicsBlock = "Blocking. Hold block to raise your guard. Block just before a hit lands... for a perfect block.",
	BasicsAbilities = "Abilities. Your gems give you three of them, on Q, E and R. Each one costs charge. Cast them, to turn a fight.",
	BasicsDodge = "Dodging. Press dodge to roll out of the way. Save it for the big attacks.",
	BasicsResources = "Charge, and stamina. Every hit you land fills your charge. The blue bar. Your abilities spend it. Swinging, blocking and dodging use stamina. The green bar. Ease off, and it refills. Your training begins now.",
}
-- How long each one plays (seconds, the files' lengths).
Narration.Seconds = { TrainingBegins = 3.5, Controls = 5.9, FirstDungeon = 9.7, KaijuTeam = 7.7, RotMinions = 7.5, BasicsAttack = 10.85, BasicsBlock = 8.94, BasicsAbilities = 11.07, BasicsDodge = 7.35, BasicsResources = 18.63 }
-- A line read phrase by phrase (the basics: Client.BasicsScreen), when each
-- phrase starts (seconds into it): its caption follows the phrase, and the
-- LED its cue.
Narration.Phrases = {
	BasicsAttack = { "First, attacking.", "Press attack to swing your weapon.", "Keep swinging to chain a combo.", "Hold it down, for a heavy blow." },
	BasicsBlock = { "Blocking.", "Hold block to raise your guard.", "Block just before a hit lands...", "for a perfect block." },
	BasicsAbilities = { "Abilities.", "Your gems give you three of them, on Q, E and R.", "Each one costs charge.", "Cast them, to turn a fight." },
	BasicsDodge = { "Dodging.", "Press dodge to roll out of the way.", "Save it for the big attacks." },
	BasicsResources = { "Charge, and stamina.", "Every hit you land fills your charge. The blue bar.", "Your abilities spend it.", "Swinging, blocking and dodging use stamina. The green bar.", "Ease off, and it refills.", "Your training begins now." },
}
Narration.Cues = {
	BasicsAttack = { 0.15, 2.34, 5.29, 8.01 },
	BasicsBlock = { 0.15, 1.56, 4.33, 6.93 },
	BasicsAbilities = { 0.15, 1.78, 6.08, 8.58 },
	BasicsDodge = { 0.15, 1.59, 4.9 },
	BasicsResources = { 0.15, 2.39, 6.55, 8.84, 13.47, 15.98 },
}
Narration.Volume = 1.2

local played: { [string]: boolean } = {}
local sound: Sound? = nil
local startedAt = 0
local gui: ScreenGui? = nil
local label: TextLabel? = nil
local shown = 0

local function caption(text: string?)
	if not gui then
		gui = UiKit.gui("Narration", 30)
		local l = Instance.new("TextLabel")
		l.Name = "Line"
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Position = UDim2.new(0.5, 0, 1, -150)
		l.Size = UDim2.new(0.7, 0, 0, 64)
		l.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
		l.BackgroundTransparency = 0.35
		l.Font = Enum.Font.GothamBold
		l.TextColor3 = Color3.fromRGB(240, 244, 250)
		l.TextScaled = true
		l.TextWrapped = true
		l.Text = ""
		l.Visible = false
		l.Parent = gui
		UiKit.round(l, 10)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
		pad.Parent = l
		local size = Instance.new("UITextSizeConstraint")
		size.MaxTextSize = 22
		size.Parent = l
		label = l
	end
	local l = label :: TextLabel
	l.Text = text or ""
	l.Visible = text ~= nil
	if text then
		l.TextTransparency, l.BackgroundTransparency = 1, 1
		TweenService:Create(l, TweenInfo.new(0.25), { TextTransparency = 0, BackgroundTransparency = 0.35 }):Play()
	end
end

function Narration.stop()
	shown += 1
	if sound then
		pcall(function()
			(sound :: Sound):Destroy()
		end)
		sound = nil
	end
	caption(nil)
end

-- (`quiet`: its voice only, where the scene has its own caption)
function Narration.play(name: string, quiet: boolean?): number
	local text = Narration.Lines[name]
	if not text or played[name] then
		return 0
	end
	played[name] = true
	Narration.stop()
	shown += 1
	local mine = shown
	local seconds = Narration.Seconds[name] or 5
	local id = Narration.Ids[name] or 0
	if id ~= 0 then
		pcall(function()
			local s = Instance.new("Sound")
			s.Name = "Narration"
			s.SoundId = "rbxassetid://" .. tostring(id)
			s.Volume = Narration.Volume
			s.Parent = SoundService
			s:Play()
			sound = s
		end)
	end
	startedAt = os.clock()
	local phrases = Narration.Phrases[name]
	if not quiet and phrases then
		-- (phrase by phrase, each as it's read)
		task.spawn(function()
			local at = 0
			while mine == shown do
				local t = Narration.elapsed()
				local now = 0
				for i, start in Narration.Cues[name] or {} do
					if t >= start - 0.05 then
						now = i
					end
				end
				if now ~= at and phrases[now] then
					at = now
					caption(phrases[now])
				end
				task.wait(0.05)
			end
		end)
	elseif not quiet then
		caption(text)
	end
	task.delay(seconds + 0.4, function()
		if mine == shown then
			Narration.stop()
		end
	end)
	return seconds
end

-- Seconds into the line being read: the sound's own place in it while it
-- plays (so what's timed off it keeps up with the voice, however late the
-- audio starts), else the clock since it began.
function Narration.elapsed(): number
	local s = sound
	if s and s.IsPlaying and s.TimePosition > 0 then
		return s.TimePosition
	end
	if s and not s.IsLoaded and os.clock() - startedAt < 3 then
		-- (still loading: the voice hasn't started, so nor has the line)
		startedAt = os.clock()
		return 0
	end
	return os.clock() - startedAt
end

-- Whether `name` has its voice uploaded (else only its words show).
function Narration.voiced(name: string): boolean
	return (Narration.Ids[name] or 0) ~= 0
end

-- Reads it and waits till it's done (or something else cuts it off).
function Narration.say(name: string)
	local seconds = Narration.play(name)
	if seconds <= 0 then
		return
	end
	local mine = shown
	local started = os.clock()
	while mine == shown and os.clock() - started < seconds + 0.3 do
		task.wait(0.1)
	end
end

-- (tests: forget what's been read)
function Narration._reset()
	table.clear(played)
	Narration.stop()
end
Narration._player = Players.LocalPlayer

return Narration
