--[[
	Combat training: a new player's first spar, scripted. The sparring partner
	becomes a training dummy that plays along with each lesson, then fights for
	real once they've done each one.

	  CombatTutorial.Steps      the lessons, in order
	  CombatTutorial.step(i)    one lesson (nil past the end)
	  CombatTutorial.count()    how many lessons
	  CombatTutorial.text(step, touch)  what to do, in words for the device

	The server tracks progress on the player (attributes TutorialStep,
	TutorialCount, TutorialGoal; TutorialStep is 0 when the training's over)
	and moves on when a lesson is done; the client only shows it.

	A lesson's Event is what the server counts (Duelist's training partner):
	  Hit       a quick swing that lands on the partner
	  Heavy     a charged heavy blow that lands
	  Block     one of the partner's swings caught on your guard
	  Dodge     one of the partner's heavy blows slipped by dodging
	  Surge     a surge (Q / E / R) cast
	  Win       the partner beaten (the last lesson: a real spar)
	`Partner` is what the partner does meanwhile: Stand (a target), Swing (slow,
	easy-to-read swings), HeavyBlow (big telegraphed blows) or Fight (for real).
	`Highlight` names the control to point at (Combat's buttons: Basic, Heavy,
	Block, Dodge, Surge).
]]
local CombatTutorial = {}

CombatTutorial.Steps = {
	{
		Id = "Attack",
		Title = "Attack",
		Event = "Hit",
		Goal = 3,
		Partner = "Stand",
		Highlight = "Basic",
		Keys = "Walk up and click LEFT MOUSE to swing. Land 3 hits.",
		Touch = "Walk up and tap ATTACK to swing. Land 3 hits.",
	},
	{
		Id = "Heavy",
		Title = "Heavy attack",
		Event = "Heavy",
		Goal = 1,
		Partner = "Stand",
		Highlight = "Basic",
		Keys = "HOLD left mouse until it's charged, then let go for a heavy blow.",
		Touch = "HOLD ATTACK until it's charged, then let go for a heavy blow.",
	},
	{
		Id = "Block",
		Title = "Block",
		Event = "Block",
		Goal = 2,
		Partner = "Swing",
		Highlight = "Block",
		Keys = "Your partner swings back. HOLD RIGHT MOUSE as it winds up to block. Block 2.",
		Touch = "Your partner swings back. HOLD GUARD as it winds up to block. Block 2.",
	},
	{
		Id = "Dodge",
		Title = "Dodge",
		Event = "Dodge",
		Goal = 1,
		Partner = "HeavyBlow",
		Highlight = "Dodge",
		Keys = "A red ring means a heavy blow is coming. Press SPACE to dodge out of it.",
		Touch = "A red ring means a heavy blow is coming. Tap DODGE to get out of it.",
	},
	{
		Id = "Surge",
		Title = "Surges",
		Event = "Surge",
		Goal = 1,
		Partner = "Stand",
		Highlight = "Surge",
		Keys = "Your gems give you surges. Press Q, E or R to cast one at your partner.",
		Touch = "Your gems give you surges. Tap a Q, E or R button to cast one.",
	},
	{
		Id = "Spar",
		Title = "Spar",
		Event = "Win",
		Goal = 1,
		Partner = "Fight",
		Keys = "Now for real: beat your sparring partner. Hits are softened.",
		Touch = "Now for real: beat your sparring partner. Hits are softened.",
	},
}

function CombatTutorial.count(): number
	return #CombatTutorial.Steps
end

function CombatTutorial.step(index: number?)
	return if type(index) == "number" then CombatTutorial.Steps[index] else nil
end

function CombatTutorial.text(step, touch: boolean?): string
	return if touch then step.Touch else step.Keys
end

-- The lesson that comes after `index`, skipping any the player can't do
-- (`can(step)` false: no surge equipped, say). nil when there's none left.
function CombatTutorial.nextStep(index: number, can: ((any) -> boolean)?): number?
	for i = index + 1, #CombatTutorial.Steps do
		if not can or can(CombatTutorial.Steps[i]) then
			return i
		end
	end
	return nil
end

return CombatTutorial
