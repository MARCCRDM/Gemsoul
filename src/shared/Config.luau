-- Game-wide settings shared by server and client.
local Config = {
	-- Mining
	GemValue = 1,
	VipGemValue = 3,
	MineHoldSeconds = 1,
	DailyQuota = 10,

	-- VIP: set this to your game pass id once you create one.
	VipGamePassId = 0,
	-- Treat everyone as VIP while testing in Studio so you can walk through the gate.
	VipInStudio = true,
}

return Config
