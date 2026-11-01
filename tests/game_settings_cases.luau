-- lune run tests/game_settings_cases.luau <repo>
-- A player's settings (Shared.GameSettings): anything cleaned to known keys
-- in range, defaults for the rest, and what music and effects play at.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."
local checks = 0
local function check(v, m) checks += 1; assert(v, m) end
local G = luau.load(fs.readFile(ROOT .. "/src/shared/GameSettings.luau"))()
local d = G.clean(nil)
check(d.Music == 1 and d.MusicOn == true and d.Effects == 1 and d.EffectsOn == true, "Defaults wrong")
local c = G.clean({ Music = 7, Effects = -2, MusicOn = "yes", Junk = true, EffectsOn = false })
check(c.Music == 1 and c.Effects == 0 and c.MusicOn == true and c.EffectsOn == false and c.Junk == nil, "Not cleaned")
check(G.clean({ Music = 0 / 0 }).Music == 1, "NaN kept")
check(G.clean({ Music = 0.333333 }).Music == 0.33, "Not rounded to a percent")
check(G.music({ Music = 0.5, MusicOn = false }) == 0 and G.music({ Music = 0.5 }) == 0.5, "Music level wrong")
check(G.effects({ Effects = 0.25, EffectsOn = true }) == 0.25 and G.effects({ EffectsOn = false }) == 0, "Effects level wrong")
print(string.format("PASS: %d game settings checks", checks))
