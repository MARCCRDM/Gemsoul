--[[
	Swing restores: once your pick's free charge (Outpost.Picks.Survey) runs
	low, the other modes bring swings back, a share of the full charge each
	time. A restore never goes past full, and gives nothing if you're full
	already (a refill can take you past full; a restore can't).

	  The arena tournament   ranked 1v1 (and casual solo duels: a streak of
	                         their own): a run of wins in a row, one
	                         tournament. The 1st win restores 10%, the 5th
	                         25%, the 10th 50%, and ten in a row wins the
	                         tournament (with its winning roll: the Arena
	                         Cache, ArenaStreak). A loss ends the run; the
	                         11th win starts the next tournament. Queued
	                         duels only (a challenge between friends doesn't
	                         count), and beating the same player twice
	                         running doesn't add to the run.
	  A dungeon cleared      25%
	  A Swings coupon        50% (Shared.Coupons: from inviting friends)

	Pure, for the server (Systems/Restores), the client and tests.

	  SwingRestore.Tournament          wins in a row that win a tournament (10)
	  SwingRestore.Streak[n]           the share for the nth win of a run
	  SwingRestore.Dungeon / Coupon    the shares for a dungeon and a coupon
	  SwingRestore.round(streak)       -> which win of this tournament (1..10)
	  SwingRestore.streakShare(streak) -> the share a win at `streak` restores (0 for most)
	  SwingRestore.won(streak)         -> did this win take the tournament?
	  SwingRestore.next(streak)        -> the next win that restores, and its share
	  SwingRestore.apply(swings, share, full) -> new swings, swings added
	  SwingRestore.casual(duel, won, foeId) -> streak, counted: a casual solo
	                                   duel's result on its run (duel.CasualStreak)
]]
local SwingRestore = {}

SwingRestore.Tournament = 10
SwingRestore.Streak = { [1] = 0.10, [5] = 0.25, [10] = 0.50 }
SwingRestore.Dungeon = 0.25
SwingRestore.Coupon = 0.50

function SwingRestore.round(streak: number): number
	streak = math.max(1, math.floor(streak or 1))
	return (streak - 1) % SwingRestore.Tournament + 1
end

function SwingRestore.streakShare(streak: number): number
	if type(streak) ~= "number" or streak < 1 then
		return 0
	end
	return SwingRestore.Streak[SwingRestore.round(streak)] or 0
end

function SwingRestore.won(streak: number): boolean
	return type(streak) == "number" and streak >= 1 and SwingRestore.round(streak) == SwingRestore.Tournament
end

-- The next win (a streak count) that restores swings after `streak` wins,
-- and its share.
function SwingRestore.next(streak: number): (number, number)
	local at = math.max(0, math.floor(streak or 0))
	for step = 1, SwingRestore.Tournament do
		local share = SwingRestore.streakShare(at + step)
		if share > 0 then
			return at + step, share
		end
	end
	return at + 1, 0
end

-- A casual solo duel's result on its own run (Ranked's is ArenaStreak's
-- RankedStreak): a win adds one unless it's the same player beaten last
-- time; a loss ends the run. Returns the run and whether this win added.
function SwingRestore.casual(duel, won: boolean, foeId: number?): (number, boolean)
	duel.CasualStreak = duel.CasualStreak or 0
	if not won then
		duel.CasualStreak, duel.CasualLastBeaten = 0, nil
		return 0, false
	end
	if foeId ~= nil and duel.CasualLastBeaten == foeId then
		return duel.CasualStreak, false
	end
	duel.CasualStreak += 1
	duel.CasualLastBeaten = foeId
	return duel.CasualStreak, true
end

function SwingRestore.apply(swings: number, share: number, full: number): (number, number)
	swings = swings or 0
	if share <= 0 or swings >= full then
		return swings, 0
	end
	local total = math.min(full, swings + math.floor(full * share + 0.5))
	return total, total - swings
end

return SwingRestore
