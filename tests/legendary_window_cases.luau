-- A Legendary mined (Client LegendaryWindow): its window's timeline (the
-- line drawing across, opening with a pop, LEGENDARY! and the gem popping
-- in, held, folding shut, gone), and that it's played for your own find
-- (MinerLoot, as the card lands, whatever folds it) and for someone else's
-- (MiningWorldReveal, whose box steps aside), with its own sound slot and
-- stand-in. Run by tests/run_legendary_window.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

-- The module on stand-ins: only its timeline is run here.
local function stub()
	return setmetatable({}, {
		__index = function(t, k)
			local v = stub()
			rawset(t, k, v)
			return v
		end,
	})
end
local source = fs.readFile(ROOT .. "/src/client/Modules/LegendaryWindow.luau")
local env = setmetatable({
	game = { GetService = function() return stub() end },
	script = stub(),
	require = function() return stub() end,
	Color3 = { fromRGB = function(r, g, b) return { r, g, b } end, new = function() return {} end },
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
}, { __index = _G })
local W = luau.load(source, { debugName = "LegendaryWindow", environment = env })()

local opened = W.Line + W.Open
local closing = opened + W.Hold
local total = closing + W.Close

local s = W.at(0)
check(s.Width == 0 and s.Height <= 0.06 and not s.Done, "It starts as nothing")
s = W.at(W.Line * 0.5)
check(s.Width > 0.3 and s.Width < 1 and s.Height <= 0.06, "The line doesn't draw across first")
s = W.at(W.Line)
check(math.abs(s.Width - 1) < 1e-6 and s.Height <= 0.06, "The line isn't across before it opens")
-- Opening: a pop past full and back.
local peak = 0
for i = 0, 40 do
	peak = math.max(peak, W.at(W.Line + W.Open * i / 40).Height)
end
check(peak > 1.02, "The window doesn't pop open: " .. peak)
s = W.at(opened + 0.6)
check(math.abs(s.Height - 1) < 1e-6 and math.abs(s.Width - 1) < 1e-6, "It isn't open")
check(math.abs(s.Title - 1) < 0.01 and math.abs(s.Gem - 1) < 0.01, "LEGENDARY! and the gem aren't in")
check(W.at(opened - 0.2).Gem == 0, "The gem's in before it's open")
check(W.Hold >= 3, "Not up long enough to read")
-- The shine sweeps across again and again.
local a, b = W.at(opened + 0.3).Shine, W.at(opened + 0.9).Shine
check(a > -1 and b > a and b < 1, "No shine sweeping")
-- Folding: back to the line, then gone.
s = W.at(closing + W.Close * 0.55)
check(s.Height < 0.2 and s.Width > 0.9 and s.Fade > 0.4, "It doesn't fold back into the line")
s = W.at(total - 0.01)
check(s.Width < 0.1, "The line doesn't go")
check(W.at(total + 0.01).Done, "It's never done")
check(total < 5.5, "Up too long: " .. total)

-- Played for your find, and for someone else's.
local loot = fs.readFile(ROOT .. "/src/client/Modules/MinerLoot.luau")
check(loot:find('Tier == "Legendary"', 1, true) and loot:find("LegendaryWindow.play(", 1, true) and loot:find("item.LandAt - item.At", 1, true),
	"Your own Legendary doesn't open its window as the card lands")
local reveal = fs.readFile(ROOT .. "/src/client/Modules/MiningWorldReveal.luau")
check(reveal:find('gem.Tier == "Legendary"', 1, true) and reveal:find("LegendaryWindow.play(miner and miner.Character, gem, packet.MinerName)", 1, true),
	"Someone else's Legendary doesn't open its window over them")
check(reveal:find("entry.Board.Enabled = false", 1, true), "Their box doesn't step aside for the window")
-- Its sound: a slot for the file, and a stand-in till it's uploaded.
local sound = fs.readFile(ROOT .. "/src/client/Modules/CombatSound.luau")
check(sound:find("LegendaryWindow = 0, -- legendary_window.mp3", 1, true) and sound:find("\tLegendaryWindow = {", 1, true), "No LegendaryWindow sound")
check(fs.isFile(ROOT .. "/assets/sounds/combat/legendary_window.mp3"), "No legendary_window.mp3")
check(source:find('CombatSound.play("LegendaryWindow"', 1, true), "The window plays no sound")

print(string.format("PASS: %d legendary window checks (the line, the pop open, LEGENDARY! and the gem, the shine, held, folding, gone; your find and another's, their box aside; its sound)", checks))
