--[[
	How you level up: your level (Shared.AugmentTree's XP, the level on
	your card in the lobby) comes mostly from beating things. A Rift's or a
	dungeon's boss, a raid's wave, an arena rival, another player in a duel
	or a kaiju battle: each is worth a share of a level at your own level
	(Share), more the higher the foe's level is over yours and less the
	further under (Gap). So it's the higher bosses and the stronger players
	that level you, at any level, and farming easy ones doesn't. The same
	player beaten again soon is worth less each time (Again).

	Mining gives a little, less and less the more you've mined lately
	(Mine): something on the way, never the way to level. It's yours alone:
	your kaiju get nothing for your rocks (they level by fighting).

	  Levelling.Mine         { Base, Half, Floor, Rest }: a rock is worth
	                         Base * Half / (Half + mined) XP, never under
	                         Floor, `mined` the rocks you've broken lately,
	                         which halves for every Rest seconds since
	  Levelling.rested(mined, seconds) -> mined, `seconds` later
	  Levelling.mineXP(mined) -> XP for the next rock
	  Levelling.Share        a win's worth by kind, as a share of a level at
	                         your own level
	  Levelling.Gap          { Per, Min, Max }: x Per for each level the foe
	                         is over you (÷ Per for each under), kept between
	                         Min and Max
	  Levelling.gap(level, foe) -> that factor
	  Levelling.Again        { Factor, Window }: x Factor for each time you've
	                         beaten the same player in the last Window seconds
	  Levelling.winXP(kind, level, foe, need, again?) -> XP, `need` what your
	                         next level takes (AugmentTree.xpToNext(level))

	Pure rules, for the server (Server.Progress) and tests.
]]
local Levelling = {}

-- A rock: 10 XP when you haven't mined in a while (Season.XP.Mine), 5
-- after 20 rocks, 1 or 2 after a full charge (about 130), never under 1;
-- what you've mined lately halves every half hour. A full charge comes to
-- about 400 XP all told (it was 1,950 at 15 a rock), and mining on and on
-- settles at 1 a rock.
Levelling.Mine = { Base = 10, Half = 20, Floor = 1, Rest = 1800 }

function Levelling.rested(mined: number?, seconds: number?): number
	local count = math.max(0, tonumber(mined) or 0)
	local since = math.max(0, tonumber(seconds) or 0)
	if count ~= count or since ~= since then
		return 0
	end
	return count * 0.5 ^ (since / Levelling.Mine.Rest)
end

function Levelling.mineXP(mined: number?): number
	local rule = Levelling.Mine
	local count = math.max(0, tonumber(mined) or 0)
	if count ~= count then
		count = 0
	end
	return math.max(rule.Floor, math.floor(rule.Base * rule.Half / (rule.Half + count) + 0.5))
end

-- A win against a foe at your own level, as a share of what your next
-- level takes: a Rift boss over half a level, a dungeon's boss half, a
-- duel won a third, an arena rival a tenth.
Levelling.Share = {
	RiftBoss = 0.6, -- a Rift's boss beaten (RiftServer)
	DungeonBoss = 0.5, -- a dungeon cleared, its boss down (Dungeons)
	RaidWave = 0.15, -- a party raid's wave cleared (Duelist)
	Rival = 0.1, -- an arena rival beaten (Duelist)
	DuelWin = 0.3, -- a duel won against players (Duels)
	DuelPlay = 0.04, -- a duel lost or drawn
	KaijuWin = 0.15, -- a kaiju battle won (KaijuBattles)
	KaijuPlay = 0.02, -- a kaiju battle lost or drawn
}

-- About 1.15x for each level a foe is over you: 2x five over, the most
-- (3x) eight over; half five under, the least (a fifth) a dozen under.
Levelling.Gap = { Per = 1.15, Min = 0.2, Max = 3 }

function Levelling.gap(level: number, foe: number?): number
	local rule = Levelling.Gap
	local mine, theirs = tonumber(level) or 1, tonumber(foe) or tonumber(level) or 1
	if mine ~= mine or theirs ~= theirs then
		return 1
	end
	return math.clamp(rule.Per ^ (theirs - mine), rule.Min, rule.Max)
end

-- The same player beaten again within the hour: half, then a quarter...
Levelling.Again = { Factor = 0.5, Window = 3600 }

function Levelling.winXP(kind: string, level: number, foe: number?, need: number, again: number?): number
	local share = Levelling.Share[kind]
	local cost = tonumber(need) or 0
	if not share or cost ~= cost or cost <= 0 or cost == math.huge then
		return 0
	end
	local repeats = math.max(0, math.floor(tonumber(again) or 0))
	local amount = share * cost * Levelling.gap(level, foe) * Levelling.Again.Factor ^ repeats
	return math.max(1, math.floor(amount + 0.5))
end

return Levelling
