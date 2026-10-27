-- Shared timing and reel sequence: every observer lands on the server's reward.
local GemConfig = require(script.Parent.GemConfig)
local GemRoller = require(script.Parent.GemRoller)
local Roll = {}
Roll.Duration = 2.8
Roll.Target = 23
Roll.Range = 180
Roll.MaxActive = 12

-- Someone else's find: a small tag over their head, not a window. Readable
-- up close, a little smaller further off, never much of the screen.
Roll.Tag = { Width = 200, TouchWidth = 176, Least = 150, TouchLeast = 140, Ratio = 0.42, NoticeRatio = 0.3 }
function Roll.displaySize(screen, distance, touch, notice)
	local tag = Roll.Tag
	local cap = math.min(if touch then tag.TouchWidth else tag.Width, screen.X * 0.4, screen.Y * 0.24 / tag.Ratio)
	local floor = math.min(cap, if touch then tag.TouchLeast else tag.Least)
	local width = math.floor(math.clamp(cap - math.max(0, distance - 30) * 0.6, floor, cap))
	return width, math.floor(width * (if notice then tag.NoticeRatio else tag.Ratio))
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
-- Each reel gem's element, from the same seed (so every onlooker sees the
-- same reel): any of the four alike, so every element shows at every rarity
-- (as GemRoller.reelGem); the found gem's own at Target.
function Roll.elements(packet)
	local rng, elements = Random.new((packet.Seed or 0) + 7919), {}
	local kinds = GemRoller.Elements
	for index = -1, Roll.Target + 2 do
		elements[index] = kinds[math.min(#kinds, 1 + math.floor(rng:NextNumber() * #kinds))]
	end
	elements[Roll.Target] = packet.Gem and packet.Gem.Element or nil
	return elements
end
return Roll
