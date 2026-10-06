--[[
	What a player just did in a fight, for systems that follow along (combat
	training: Duelist's sparring partner counts each lesson).

	  CombatEvents.fire(player, kind)   CombatServer: "Hit" (a quick swing
	                                    landed), "Heavy" (a heavy one landed),
	                                    "Dodge" (a dodge or hop), "Surge" (a
	                                    surge cast)
	  CombatEvents.listen(fn)           fn(player, kind) for each one
]]
local CombatEvents = {}

local listeners = {}

function CombatEvents.listen(fn: (Player, string) -> ())
	table.insert(listeners, fn)
end

function CombatEvents.fire(player: Player, kind: string)
	for _, fn in listeners do
		task.spawn(fn, player, kind)
	end
end

return CombatEvents
