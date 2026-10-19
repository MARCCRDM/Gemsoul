--[[
	How big the effect being drawn is (client only): 1 for yours and other
	players', a creature's own size for one it plays (the server wraps those
	as "Sized": KaijuAbilities, KaijuFighter, KaijuWilds), so a knee-high
	kaiju's blast is drawn, sounds and shakes your screen at its size, not
	yours. CombatFx (shakes, flashes, bursts), CombatSound, CombatVfx,
	MoveVfx, TriadVfx and ElementalDeath read it as they draw.

	  FxSize.get() -> number          the size now (1 outside a creature's)
	  FxSize.run(size, fn, ...)       fn(...) drawn at `size`
	  FxSize.keep(fn) -> fn           `fn`, when it runs later (a delay, a
	                                  spawned loop, a frame step), at the
	                                  size it was made at
	  FxSize.ofModel(model) -> number a body's size by its height next to a
	                                  player's

	The size belongs to the thread drawing (a coroutine), so a loop that
	waits keeps its own and never lends it to anyone else's effect.
]]
local FxSize = {}

FxSize.PlayerHeight = 5 -- studs: a player standing, the size 1 is
FxSize.Least, FxSize.Most = 0.2, 3

local sizes: { [thread]: number } = setmetatable({}, { __mode = "k" }) :: any

function FxSize.get(): number
	return sizes[coroutine.running()] or 1
end

function FxSize.run(size: number, fn: (...any) -> (), ...)
	local co = coroutine.running()
	local before = sizes[co]
	size = math.clamp(tonumber(size) or 1, FxSize.Least, FxSize.Most)
	sizes[co] = if size == 1 then nil else size
	local ok, err = pcall(fn, ...)
	sizes[co] = before
	if not ok then
		warn("FxSize: " .. tostring(err))
	end
end

function FxSize.keep<A...>(fn: (A...) -> ()): (A...) -> ()
	local size = FxSize.get()
	if size == 1 then
		return fn
	end
	return function(...)
		FxSize.run(size, fn :: any, ...)
	end
end

function FxSize.ofModel(model: Model?): number
	if not model then
		return 1
	end
	local ok, extents = pcall(function()
		return model:GetExtentsSize()
	end)
	if not ok or typeof(extents) ~= "Vector3" or extents.Y <= 0 then
		return 1
	end
	return math.clamp(extents.Y / FxSize.PlayerHeight, FxSize.Least, FxSize.Most)
end

return FxSize
