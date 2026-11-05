--[[
	The Outpost's day and night: one clock for everyone, from the server's
	time (workspace:GetServerTimeNow()), so every player in every server sees
	the same hour. A day runs Cycle seconds: most of it daylight (DayShare:
	6:00 to 18:00), the rest night (18:00 to 6:00, quicker), with a dawn and
	a dusk between (Dawn, Dusk: the hours light comes up and goes down).
	Client.OutpostScene sets the light from it (Client.Scenes.outpostSky).

	  DayNight.clock(t) -> hours (0..24)   the Outpost's hour at server time `t`
	  DayNight.daylight(hours) -> 0..1     1 full day, 0 full night
	  DayNight.isNight(hours) -> boolean
]]
local DayNight = {}

DayNight.Cycle = 20 * 60 -- seconds: a whole day and night
DayNight.DayShare = 0.7 -- of the cycle: 6:00 to 18:00
DayNight.Dawn = { 5, 7 } -- hours: from dark to full light
DayNight.Dusk = { 17, 19 } -- hours: from full light to dark

function DayNight.clock(t: number): number
	local phase = (t / DayNight.Cycle) % 1
	local share = DayNight.DayShare
	if phase < share then
		return 6 + 12 * phase / share
	end
	return (18 + 12 * (phase - share) / (1 - share)) % 24
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function DayNight.daylight(hours: number): number
	local dawn, dusk = DayNight.Dawn, DayNight.Dusk
	if hours < 12 then
		return smooth((hours - dawn[1]) / (dawn[2] - dawn[1]))
	end
	return 1 - smooth((hours - dusk[1]) / (dusk[2] - dusk[1]))
end

function DayNight.isNight(hours: number): boolean
	return DayNight.daylight(hours) < 0.5
end

return DayNight
