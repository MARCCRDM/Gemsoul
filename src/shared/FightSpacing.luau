--[[
	Fighters keep their footing: in a fight nobody jumps, and nobody ends up
	standing on (or inside) their opponent.

	Bodies don't collide with one another (Server.FighterBodies puts them in
	collision groups that pass through each other), so a body can never be
	stepped onto or climbed by a hop. Instead each client keeps its own body
	a body's width away from everyone else's (Client.FighterSpacing), a soft
	push that holds the gap without shoving anyone around.

	  FightSpacing.inFight(player)   in a fight: an Arena session, a duel or a raid
	  FightSpacing.gap(otherRoot)    how far apart two bodies' centres stay
	  FightSpacing.push(mine, other, gap, facing)
	      pure: how far to move my body (flat) to keep `gap` from `other`
]]
local FightSpacing = {}

FightSpacing.Radius = 1.3 -- a body's half-width, about the shoulders
FightSpacing.Range = 14 -- bodies further off are left alone

function FightSpacing.inFight(player: Player): boolean
	return player:GetAttribute("CombatSession") ~= nil or player:GetAttribute("MatchId") ~= nil
end

-- A bigger body (a raid boss) keeps you further off.
function FightSpacing.gap(otherRoot: BasePart): number
	local size = otherRoot.Size
	return FightSpacing.Radius + math.max(FightSpacing.Radius, math.max(size.X, size.Z) / 2 + 0.3)
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
