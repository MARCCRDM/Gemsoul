--[[
	Promo codes: post them in Discord, on social media, or for like and
	visit milestones. Anyone can redeem each code once. They live here on
	the server, so nobody can read the list out of the game's files.

	To add one: a new line in Codes.List, in CAPITALS, letters and numbers
	only (players can type it any way: "launch" or "Launch!" both work).

	  Reward   any Store.Reward: Coins,
	           Cosmetics = { "TitleFounder" }, XPBoostMinutes, ...
	  Expires  optional: os.time() after which it stops working
	           (os.time({ year = 2026, month = 12, day = 1 }))
	  For      optional: a gift for certain players only, by username or
	           UserId ({ "kingreen113" } or { 123456 }); to anyone else it's
	           a code that doesn't exist
	  Note     for you: where it was posted
]]
local Codes = {}

Codes.List = {
	LAUNCH = {
		Reward = { Cosmetics = { "TitleFounder" }, Coins = 500 },
		Note = "Launch day: Discord announcement",
	},
	CRUSADERS = {
		Reward = { Coins = 500 },
		Note = "Discord welcome message",
	},
	GEMRUSH = {
		Reward = { Coins = 750, XPBoostMinutes = 30 },
		Note = "Like milestone",
	},
	-- Gifts --------------------------------------------------------------
	REAPERGIFT113 = {
		-- The Reaper's Harvest bundle (Store "ReaperHarvest"), all of it.
		Reward = { Cosmetics = { "SuitStealth", "SkinVoid", "HelmetGrimReaper", "VisorTwilight", "PickVoid" } },
		For = { "kingreen113" },
		Note = "Gift: kingreen113, for the boss lock-on feedback",
	},
}

-- Whether `player` may redeem `entry` (a gift's For list, by username or UserId).
function Codes.allowed(entry, player): boolean
	if not entry.For then
		return true
	end
	if not player then
		return false
	end
	local name = string.lower(tostring(player.Name or ""))
	for _, who in entry.For do
		if (type(who) == "number" and who == player.UserId) or (type(who) == "string" and string.lower(who) == name) then
			return true
		end
	end
	return false
end

-- The entry for a normalized code, if it's live at `now` (and, a gift,
-- for `player`).
function Codes.find(code: string?, now: number, player: any?)
	local entry = code and Codes.List[code]
	if not entry or not Codes.allowed(entry, player) then
		return nil
	end
	if entry.Expires and now > entry.Expires then
		return nil, "That code has expired."
	end
	return entry
end

return Codes
