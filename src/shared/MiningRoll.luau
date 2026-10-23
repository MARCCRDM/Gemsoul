-- Shared timing and reel sequence: every observer lands on the server's reward.
local GemConfig = require(script.Parent.GemConfig)
local GemRoller = require(script.Parent.GemRoller)
local Roll = {}
Roll.Duration = 2.8
Roll.Target = 23
Roll.Range = 180
Roll.MaxActive = 12

-- Pixel-sized public cards stay readable at normal viewing distances.
-- Cap their footprint on short landscape phones and shrink gently at range.
function Roll.displaySize(screen, distance, touch, notice)
	local cap = math.min(if touch then 320 else 344, screen.X * 0.8, screen.Y * 0.5 / 0.6)
	local floor = math.min(cap, if touch then 260 else 240)
	local width = math.floor(math.clamp(cap - math.max(0, distance - 35) * 0.8, floor, cap))
	return width, math.floor(width * (if notice then 0.29 else 0.6))
end

function Roll.rank(packet)
	return packet.Gem and GemConfig.TierRank[packet.Gem.Tier] or 0
end
function Roll.lifetime(packet)
	return Roll.Duration + 3.2 + Roll.rank(packet) * 0.4 + 0.6
end
function Roll.sample(packet, now)
	local elapsed = math.max(0, now - packet.StartedAt)
	local progress = math.clamp(elapsed / Roll.Duration, 0, 1)
	return {
		Elapsed = elapsed,
		Position = Roll.Target * (1 - (1 - progress) ^ 3),
		Landed = elapsed >= Roll.Duration,
		Fade = math.clamp((elapsed - Roll.lifetime(packet) + 0.6) / 0.6, 0, 1),
		Done = elapsed >= Roll.lifetime(packet),
	}
end
function Roll.sequence(packet)
	local rng, sequence = Random.new(packet.Seed), {}
	for index = -1, Roll.Target + 2 do
		sequence[index] = GemRoller.rollRarity(rng, 0, GemRoller.MiningWeights)
	end
	sequence[Roll.Target] = packet.Gem and packet.Gem.Tier or "Empty"
	return sequence
end
return Roll
