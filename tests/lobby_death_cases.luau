-- Killed in the lobby (the Outpost): a critter's or a wild kaiju's finishing
-- blow kills you, it doesn't knock you down. FrontierServer marks it
-- (Killed): robbed out past the core, lying dead a moment in the core, back
-- at base after either way; SparServer never stands the killed up where
-- they fell, and a fresh knock-down clears an old kill; a spar's knock-down
-- is never a kill. The client says so (YOU WERE KILLED, BACK AT BASE), the
-- robbery's report too, all of it in Spanish. (The behaviour itself:
-- run_kaiju's robbed while down, run_spar's knock-downs.) Run by
-- tests/run_lobby_death.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function source(path)
	return fs.readFile(ROOT .. "/" .. path)
end
local function has(text, piece)
	return text:find(piece, 1, true) ~= nil
end

local Spar = luau.load(source("src/shared/Spar.luau"), { debugName = "Spar" })()
check(Spar.DeadSeconds >= 2 and Spar.DeadSeconds <= 8, "Dead too long, or too short, in the core")

-- The server ---------------------------------------------------------------------------------------

local frontier = source("src/server/Systems/FrontierServer.luau")
check(has(frontier, 'player:SetAttribute("Killed", true)'), "A creature's blow in the Outpost isn't a kill")
check(
	has(frontier, 'player:SetAttribute("SparDown", serverNow() + Spar.DeadSeconds)')
		and has(frontier, "task.delay(Spar.DeadSeconds, function()")
		and has(frontier, 'player:GetAttribute("Killed") ~= nil then\n\t\t\t\tsentHome(player)'),
	"Killed in the core, not sent home after a moment"
)
check(has(frontier, "Done = sentHome"), "Robbed out there, not sent home after")
check(
	has(frontier, 'local function sentHome(player: Player)\n\tFrontierServer.kitAway(player)\n\tplayer:SetAttribute("Killed", nil)'),
	"Still killed back at base, or the kit still out"
)
check(has(source("src/server/Main.server.luau"), "FrontierServer.kitAway = SparServer.unpair"), "Back at base, a spar not ended")
check(has(frontier, '"You were killed... the critters are coming for your gems!"'), "Not told they were killed")
-- (Not in a spar with another player, nor the Rift: still before the kill.)
do
	local at = frontier:find('player:SetAttribute("Killed", true)', 1, true)
	local guards = frontier:find('{ "CombatSession", "MatchId", "DungeonId", "Expedition", "SparWith", "KaijuBattle" }', 1, true)
	local rift = frontier:find('player:GetAttribute("RiftRun") ~= nil then\n\t\treturn nil', 1, true)
	check(guards and rift and at and guards < at and rift < at, "Killed in a spar, a match or the Rift")
end

local spar = source("src/server/Systems/SparServer.luau")
check(has(spar, 'or player:GetAttribute("Killed") ~= nil\n\tthen\n\t\treturn'), "The killed get up where they fell")
check(
	has(spar, '-- (A fresh knock-down: whether it\'s a kill is FrontierServer\'s to say.)\n\tplayer:SetAttribute("Killed", nil)'),
	"An old kill sticks to a fresh knock-down"
)
check(has(spar, 'player.CharacterAdded:Connect(function(character)\n\t\t\tplayer:SetAttribute("Killed", nil)'), "A new body is still killed")
check(has(spar, 'if not trip and player:GetAttribute("SparWith") == nil then'), "A spar's knock-down reaches the robbers")

-- The client ---------------------------------------------------------------------------------------

local kit = source("src/client/Modules/SparKit.luau")
check(has(kit, 'local killed = down and player:GetAttribute("Killed") ~= nil'), "The screen doesn't know you were killed")
check(
	has(kit, 'downTitle.Text = if killed then "YOU WERE KILLED" else "KNOCKED OUT"')
		and has(kit, 'downTitle.Text = "YOU WERE KILLED"\n\t\tdownBy.Text = "Your gems are safe in the Core."'),
	"Killed, the screen still says knocked down"
)
check(has(kit, 'CombatSound.play("Death")'), "No death sound")
check(has(kit, 'flash("BACK AT BASE"'), "Not told you're back at base")
check(has(kit, "downVeil.BackgroundTransparency = if killed then"), "Killed isn't darker")
local report = source("src/client/Modules/RobReport.luau")
check(
	has(report, '"You were killed out in the quarry and the critters went through your pouch."')
		and has(report, '"You were killed out in the quarry. The critters went through your pouch and found nothing worth taking."')
		and not has(report, "went down out in the quarry"),
	"The report still says you went down in the quarry"
)

-- In Spanish ---------------------------------------------------------------------------------------

local Lang = luau.load(source("src/shared/Lang.luau"), { debugName = "Lang" })()
local LangEs = luau.load(source("src/shared/LangEs.luau"), { debugName = "LangEs" })()
for _, text in {
	"YOU WERE KILLED",
	"Your gems are safe in the Core.",
	"BACK AT BASE",
	"On your feet, full health",
	"You were killed... the critters are coming for your gems!",
	"You were killed out in the quarry and the critters went through your pouch.",
	"You were killed out in the quarry. The critters went through your pouch and found nothing worth taking.",
	"Back to base in {1}",
	"The critters are going through your pouch!",
} do
	check(LangEs[(Lang.normalize(text))] ~= nil, "No Spanish for " .. text)
end
check(LangEs["You're down... the critters are coming for your gems!"] == nil, "The old knocked-down line is still in the Spanish")

print(string.format("PASS: %d lobby death checks (a creature's blow kills, robbed past the core, dead a moment in it, home after; never up where you fell; the screen, the report, in Spanish)", checks))
