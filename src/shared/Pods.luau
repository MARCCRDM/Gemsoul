--[[
	Personal pods (Server.PodServer): everyone in the server has a pod on one
	of the settlement's pads (Shared.Outpost.Settlement), landed from orbit
	when they join and lifted off when they leave. You start at the foot of
	its ramp, and come back there: a respawn, a duel, the Rift.

	  Pods.choose(pads, taken, near, rng) -> index?
	      a free pad: next to a friend's (`near`: their pads) if one has
	      one, else any free pad on the inner tier, then the outer
	  Pods.spawnAt(pad: CFrame) -> CFrame   the foot of the ramp, facing the Heart
	  Pods.colorFor(userId) -> Color3        the beacon's colour (always the same)
	  Pods.altitude(t) / Pods.lift(t)       the landing and lift-off, height over the pad
]]
local Pods = {}

Pods.Landing = {
	Height = 240, -- studs over the pad it starts from
	Fall = 3.2, -- seconds down
	Failsafe = 6, -- seconds: it's on its pad by then whatever happens
	LiftOff = 2.6, -- seconds up and gone when you leave
}
-- The pod: its hull's radius and how far in front its ramp reaches.
Pods.Hull = 5.5
Pods.Ramp = 7
-- Beacons: a colour each, kept for a player (by their UserId).
Pods.Colors = {
	Color3.fromRGB(110, 220, 255),
	Color3.fromRGB(255, 184, 72),
	Color3.fromRGB(150, 255, 140),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(190, 140, 255),
	Color3.fromRGB(255, 110, 90),
	Color3.fromRGB(255, 240, 120),
	Color3.fromRGB(120, 255, 220),
}

function Pods.colorFor(userId: number): Color3
	return Pods.Colors[math.abs(math.floor(userId)) % #Pods.Colors + 1]
end

-- `pads`: { { Index, Tier, CFrame } }; `taken`: { [index] = anything };
-- `near`: the pads of friends already here.
function Pods.choose(pads, taken, near: { number }, rng: Random): number?
	local byIndex = {}
	for _, pad in pads do
		byIndex[pad.Index] = pad
	end
	-- Next to a friend: the free pad closest to any of theirs.
	local best, bestDistance = nil, math.huge
	for _, index in near do
		local theirs = byIndex[index]
		if theirs then
			for _, pad in pads do
				if not taken[pad.Index] then
					local d = (pad.CFrame.Position - theirs.CFrame.Position).Magnitude
					if d < bestDistance then
						best, bestDistance = pad.Index, d
					end
				end
			end
		end
	end
	if best then
		return best
	end
	-- Otherwise any free pad, the inner tier first (closest to the Heart).
	local tier = math.huge
	for _, pad in pads do
		if not taken[pad.Index] and pad.Tier < tier then
			tier = pad.Tier
		end
	end
	local free = {}
	for _, pad in pads do
		if not taken[pad.Index] and pad.Tier == tier then
			table.insert(free, pad.Index)
		end
	end
	if #free == 0 then
		return nil
	end
	return free[rng:NextInteger(1, #free)]
end

-- The pad's frame faces the Heart (its -Z): the ramp runs out that way.
function Pods.spawnAt(pad: CFrame): CFrame
	return pad * CFrame.new(0, 3, -(Pods.Hull + Pods.Ramp + 2))
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
-- Coming down: fast at first, braking hard onto the pad.
function Pods.altitude(t: number): number
	local left = 1 - math.clamp(t / Pods.Landing.Fall, 0, 1)
	return Pods.Landing.Height * left * left * left
end
-- Going up: slow off the pad, then gone.
function Pods.lift(t: number): number
	local x = math.clamp(t / Pods.Landing.LiftOff, 0, 1)
	return Pods.Landing.Height * x * x * smooth(x)
end

return Pods
