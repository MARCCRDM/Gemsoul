-- Shared timing and reel sequence: every observer lands on the server's reward.
local GemConfig = require(script.Parent.GemConfig)
local GemRoller = require(script.Parent.GemRoller)
local Roll = {}
Roll.Duration = 2.8
Roll.Target = 23
Roll.Range = 180
Roll.MaxActive = 12

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
	for index = -1, Roll.Target + 2 do sequence[index] = GemRoller.rollRarity(rng) end
	sequence[Roll.Target] = packet.Gem and packet.Gem.Tier or "Empty"
	return sequence
end
return Roll
