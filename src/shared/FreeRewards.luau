--[[
	Free cosmetics for things that grow the game, each earned one way only
	(never sold, so they show you did it). Pure, for the server
	(Systems/FreeRewards, PlayerData's daily streak), the Shop's Free tab and
	tests. Bringing friends has its own ladder (Shared.Referrals.Tiers).

	  FreeRewards.Group          joining the game's Roblox group (Config.GroupId,
	                             0 = off): { Reward }
	  FreeRewards.Streak         logging in so many days running: { Days, Reward }
	  FreeRewards.normalizeCode(text) -> the code as stored ("launch " -> "LAUNCH"),
	                             or nil if it can't be one
	  FreeRewards.streakEarned(streak) -> has the streak reached it?

	Promo codes themselves live on the server (Systems/Codes), out of the
	client's reach. Post them in Discord, on social media, for like
	milestones: anyone can redeem one, once. (Roblox doesn't allow rewards
	for joining an off-platform server, so codes are how Discord pays off.)
]]
local Config = require(script.Parent.Config)

local FreeRewards = {}

FreeRewards.Group = { Id = Config.GroupId, Reward = "SkinStarforged" }
FreeRewards.Streak = { Days = 7, Reward = "SkinDaybreak" }
FreeRewards.CodeLength = 24

function FreeRewards.groupEnabled(): boolean
	return type(FreeRewards.Group.Id) == "number" and FreeRewards.Group.Id > 0
end

function FreeRewards.streakEarned(streak: number?): boolean
	return (streak or 0) >= FreeRewards.Streak.Days
end

function FreeRewards.normalizeCode(text: any): string?
	if type(text) ~= "string" then
		return nil
	end
	local code = string.upper((string.gsub(text, "[^%w]", "")))
	if #code == 0 or #code > FreeRewards.CodeLength then
		return nil
	end
	return code
end

return FreeRewards
