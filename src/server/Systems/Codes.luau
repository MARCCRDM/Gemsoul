--[[
	Promo codes: post them in Discord, on social media, or for like and
	visit milestones. Anyone can redeem each code once. They live here on
	the server, so nobody can read the list out of the game's files.

	To add one: a new line in Codes.List, in CAPITALS, letters and numbers
	only (players can type it any way: "launch" or "Launch!" both work).

	  Reward   any Store.Reward: Coins, Crates = { GeodeCrate = 2 },
	           Cosmetics = { "TitleFounder" }, XPBoostMinutes, ...
	  Expires  optional: os.time() after which it stops working
	           (os.time({ year = 2026, month = 12, day = 1 }))
	  Note     for you: where it was posted
]]
local Codes = {}

Codes.List = {
	LAUNCH = {
		Reward = { Cosmetics = { "TitleFounder" }, Coins = 500 },
		Note = "Launch day: Discord announcement",
	},
	CRUSADERS = {
		Reward = { Crates = { GeodeCrate = 2 } },
		Note = "Discord welcome message",
	},
	GEMRUSH = {
		Reward = { Coins = 750, XPBoostMinutes = 30 },
		Note = "Like milestone",
	},
}

-- The entry for a normalized code, if it's live at `now`.
function Codes.find(code: string?, now: number)
	local entry = code and Codes.List[code]
	if not entry then
		return nil
	end
	if entry.Expires and now > entry.Expires then
		return nil, "That code has expired."
	end
	return entry
end

return Codes
