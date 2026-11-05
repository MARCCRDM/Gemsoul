-- The Outpost's day and night (Shared.DayNight): one clock from the
-- server's time, mostly day, a dawn and a dusk. Run by tests/run_day_night.py
-- (needs lune).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."
local DayNight = luau.load(fs.readFile(ROOT .. "/src/shared/DayNight.luau"), { debugName = "DayNight" })()

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local cycle = DayNight.Cycle
check(cycle >= 10 * 60 and cycle <= 40 * 60, "A day's far too short or long")
-- The clock: from 6:00 at the start of each cycle, round through 24 hours, the same for everyone.
check(math.abs(DayNight.clock(0) - 6) < 1e-6 and math.abs(DayNight.clock(cycle) - 6) < 1e-6, "The day doesn't start at dawn")
check(math.abs(DayNight.clock(1234.5) - DayNight.clock(1234.5 + cycle * 7)) < 1e-6, "The clock isn't the same every cycle")
local last, wraps, dayTime, nightTime = DayNight.clock(0), 0, 0, 0
local steps = 2400
for i = 1, steps do
	local t = i / steps * cycle
	local h = DayNight.clock(t)
	check(h >= 0 and h < 24, "An hour off the clock: " .. h)
	if h < last then
		wraps += 1
		check(last > 23.9 and h < 0.1, "The clock jumped back")
	else
		check(h - last < 0.5, "The clock jumped ahead")
	end
	last = h
	if DayNight.isNight(h) then
		nightTime += 1
	else
		dayTime += 1
	end
end
check(wraps == 1, "The clock didn't go round once a cycle")
-- Mostly day: nights are short.
check(dayTime / steps > 0.6 and nightTime / steps > 0.15, "Day and night aren't shared out (day " .. dayTime / steps .. ")")
-- Daylight: full at noon, none at midnight, rising through dawn and falling through dusk.
check(DayNight.daylight(12) == 1 and DayNight.daylight(0) == 0 and DayNight.daylight(23) == 0, "Noon isn't light or midnight dark")
local up, down = 0, 1
for h = DayNight.Dawn[1], DayNight.Dawn[2], 0.1 do
	local d = DayNight.daylight(h)
	check(d >= up - 1e-9, "The light dips at dawn")
	up = d
end
for h = DayNight.Dusk[1], DayNight.Dusk[2], 0.1 do
	local d = DayNight.daylight(h)
	check(d <= down + 1e-9, "The light rises at dusk")
	down = d
end
check(DayNight.isNight(2) and not DayNight.isNight(10) and not DayNight.isNight(16), "Night and day the wrong way round")

print("PASS: " .. checks .. " day and night checks (one clock for everyone, mostly day, dawn and dusk)")
