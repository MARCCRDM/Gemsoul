--[[
	Swing restores (Shared.SwingRestore) from the other modes: Duels (a win
	in an arena tournament run) and Dungeons (a clear) call Restores.give.
	The swings go on the free pick through Restores.swings
	(OutpostServer.restoreSwings, wired in by Main; while the Outpost is off
	it's nil and nothing is restored).

	  Restores.give(player, share) -> swings added (0 when the pick is full)
]]
local Restores = {}

Restores.swings = nil :: ((Player, number) -> number)?

function Restores.give(player: Player, share: number): number
	local swings = Restores.swings
	if not swings or type(share) ~= "number" or share <= 0 then
		return 0
	end
	local ok, added = pcall(swings, player, share)
	return if ok and type(added) == "number" then added else 0
end

return Restores
