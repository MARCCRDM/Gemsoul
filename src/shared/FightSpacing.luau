--[[
	Fighters keep their footing: in a fight nobody jumps, and nobody ends up
	standing on (or inside) their opponent.

	Bodies don't collide with one another (Server.FighterBodies puts them in
	collision groups that pass through each other), so a body can never be
	stepped onto or climbed by a hop. Instead each client keeps its own body
	a body's width away from everyone else's (Client.FighterSpacing), a soft
	push that holds the gap without shoving anyone around.

	  FightSpacing.inFight(player)   in a fight: an Arena session, a duel, a raid
	                                 or a friendly spar in the lobby (Spar)
	  FightSpacing.gap(otherRoot)    how far apart two bodies' centres stay
	  FightSpacing.push(mine, other, gap, facing)
	      pure: how far to move my body (flat) to keep `gap` from `other`
]]
local FightSpacing = {}

FightSpacing.Radius = 0.9 -- your body's share of the gap: close enough to trade blows face to face
FightSpacing.Range = 14 -- bodies further off are left alone

function FightSpacing.inFight(player: Player): boolean
	return player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
		or player:GetAttribute("Spar") == true
end

-- A bigger body (a raid boss) keeps you further off. Measured by its
-- narrower side (a root box is often wider than the creature you see, and
-- its widest side made an invisible wall well out from it).
FightSpacing.Least = 0.5 -- the other body's share, at the least
function FightSpacing.gap(otherRoot: BasePart): number
	local size = otherRoot.Size
	return FightSpacing.Radius + math.max(FightSpacing.Least, math.min(size.X, size.Z) / 2)
end

function FightSpacing.push(mine: Vector3, other: Vector3, gap: number, facing: Vector3?): Vector3
	local offset = Vector3.new(mine.X - other.X, 0, mine.Z - other.Z)
	local distance = offset.Magnitude
	if distance >= gap then
		return Vector3.zero
	end
	-- Right on top of it: step back the way you came (or anywhere).
	local away = if distance > 0.05
		then offset / distance
		elseif facing and Vector3.new(facing.X, 0, facing.Z).Magnitude > 0.05 then -Vector3.new(
			facing.X,
			0,
			facing.Z
		).Unit
		else Vector3.new(1, 0, 0)
	return away * (gap - distance)
end

return FightSpacing
