--[[
	The Kaiju Daycare: a pen out in the quarry by the Shelter's main door
	where you board kaiju you aren't using (Server.DaycareServer; its pen, where
	everyone in the server sees them, and its desk: Client.DaycarePen; its
	window: Client.DaycareUI).

	Two ways to board one:
	  STORE   kept safe, out of your roster (not counted in Kaiju.MaxOwned),
	          for Store.PerHour coins an hour, at most Store.Max a stay
	  TRAIN   trained for the hours you pick (Stays): each hour, Train.Share
	          of what its level needs (Kaiju.expToNext), up to level
	          Train.Cap; for Train.PerHour + Train.PerLevel coins an hour (at
	          its level when it came in). Once it's done (its hours up, or at
	          the cap), it's kept as STORE until you collect it.
	You pay when you collect it (it comes back at full health); short of
	coins, it waits, safe. Slots at once: Slots. Nothing ticks on the
	server: it's all worked out from when it came in (os.time()).

	Pure, for the server, the client and tests.

	  Daycare.Slots, Stays, Store, Train
	  Daycare.trainRate(level) -> coins an hour
	  Daycare.quote(level, mode, hours?) -> coins   at most, for a stay
	  Daycare.result(entry, now) -> { Level, Exp, Trained, Stored, Fee, Done, Left }
	      `entry`: { Mode, Hours?, At, Record = { Level, Exp } }
	  Daycare.canBoard(profile, id) -> reason?   (Shared.Market's rule for a
	      kaiju leaving the roster, and a free slot)
]]
local Kaiju = require(script.Parent.Kaiju)

local Daycare = {}

Daycare.Slots = 3
Daycare.Stays = { 1, 4, 12, 24 } -- hours of training to pick from
Daycare.Store = { PerHour = 25, Max = 3000 }
Daycare.Train = { PerHour = 60, PerLevel = 12, Share = 0.15, Cap = 20 }
Daycare.Modes = { Store = true, Train = true }
-- The pen, in the quarry's frame (Shared.Outpost.Location): out on the
-- floor south-west of the Shelter's main door, between its legs and the
-- pumpkin patch, inside the core (no rifts), clear of the ramp, the roads
-- and the landing pad (Server.OutpostWorld keeps rocks and wild kaiju out
-- of Clear studs round it, and the land flat). Laid out like the Kennel's
-- Pen (Shared.KaijuKennel) so its residents wander the same way. Its gate
-- faces east (+X, Gate), to the door's ramp; the keeper's desk in front of
-- it (Desk), the barn behind it (Barn).
Daycare.Pen = {
	Middle = Vector3.new(-70, 0, 102),
	Inner = 4.5,
	Outer = 11,
	Fence = 16,
	Gate = 0,
	Desk = Vector3.new(-47, 0, 102),
	Barn = Vector3.new(-93, 0, 102),
	Clear = 32,
}
Daycare.Scale = 1 -- its kaiju's size (the Kennel's are 0.75)
Daycare.Shown = 12 -- kaiju drawn in it at most

-- Coins an hour of training a kaiju of `level`.
function Daycare.trainRate(level: number): number
	return Daycare.Train.PerHour + Daycare.Train.PerLevel * level
end

-- The most a stay can cost: STORE's cap, or TRAIN's `hours` at its rate.
function Daycare.quote(level: number, mode: string, hours: number?): number
	if mode == "Train" then
		return Daycare.trainRate(level) * (hours or 1)
	end
	return Daycare.Store.Max
end

-- Where a boarded kaiju stands `now`: its level and EXP (trained hour by
-- hour, the last hour in part), the hours it trained and the hours it's been
-- kept since, what's owed, whether its training's over, and the seconds of
-- training left.
function Daycare.result(entry, now: number)
	local record = entry.Record or {}
	local level, exp = record.Level or 1, record.Exp or 0
	local elapsed = math.max(0, (now - (entry.At or now)) / 3600)
	local trained, fee = 0, 0
	if entry.Mode == "Train" then
		local hours = math.min(elapsed, entry.Hours or 0)
		local rate = Daycare.trainRate(level)
		local left = hours
		while left > 0 and level < Daycare.Train.Cap and level < Kaiju.MaxLevel do
			local step = math.min(1, left)
			exp += Kaiju.expToNext(level) * Daycare.Train.Share * step
			while level < Daycare.Train.Cap and level < Kaiju.MaxLevel and exp >= Kaiju.expToNext(level) do
				exp -= Kaiju.expToNext(level)
				level += 1
			end
			trained += step
			left -= step
		end
		if level >= Daycare.Train.Cap then
			exp = math.min(exp, Kaiju.expToNext(level) - 1)
		end
		fee += math.ceil(trained * rate)
	end
	-- Kept (STORE, or TRAIN once it's done): by the hour, up to its cap.
	local done = entry.Mode ~= "Train" or trained >= (entry.Hours or 0) - 1e-9 or level >= Daycare.Train.Cap
	local stored = if entry.Mode == "Train" then (if done then math.max(0, elapsed - trained) else 0) else elapsed
	fee += math.min(Daycare.Store.Max, math.ceil(stored * Daycare.Store.PerHour))
	local leftSeconds = if done then 0 else math.max(0, ((entry.Hours or 0) - trained) * 3600)
	return {
		Level = level,
		Exp = math.floor(exp),
		Trained = trained,
		Stored = stored,
		Fee = fee,
		Done = done,
		Left = leftSeconds,
	}
end

-- Why `id` (one of the profile's kaiju) can't be boarded, or nil.
function Daycare.canBoard(profile, id: any): string?
	local entries = profile and profile.Daycare and profile.Daycare.Entries or {}
	local count = 0
	for _ in entries do
		count += 1
	end
	if count >= Daycare.Slots then
		return string.format("The Daycare has room for %d of yours: collect one first.", Daycare.Slots)
	end
	local Market = require(script.Parent.Market)
	return Market.whyNot(profile, "Kaiju", nil, id)
end

return Daycare
