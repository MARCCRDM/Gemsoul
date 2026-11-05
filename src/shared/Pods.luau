--[[
	Personal pods (Server.PodServer): everyone in the server has a pad on the
	settlement (Shared.Outpost.Settlement); their pod lands on it, them
	inside, the first time they come into the Outpost, and lifts off when
	they leave. You start at the foot of
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
	Lead = 1.6, -- seconds parked overhead first (the loading cover lifts)
	Height = 240, -- studs over the pad it starts from
	Fall = 3.2, -- seconds down
	Deploy = 2.2, -- seconds opening up on the pad (legs, wings, doors, stair, stall)
	Failsafe = 9, -- seconds: down and open by then whatever happens
	LiftOff = 2.6, -- seconds up and gone when you leave
}
-- The pod (a habitat module), drawn Scale times its model's size: its
-- width, half its depth (door to centre), the skirt it stands on and how
-- far in front its stair reaches (studs, at that scale).
Pods.Scale = 1.35
Pods.Width = 11 * Pods.Scale
Pods.Hull = 3.8 * Pods.Scale
Pods.Base = 1.6 * Pods.Scale
Pods.Ramp = 3.2 * Pods.Scale
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
