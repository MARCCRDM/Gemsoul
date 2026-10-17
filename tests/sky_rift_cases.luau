-- The rift in the Outpost's sky (SkyRift): it hangs high in the north,
-- behind the planets and the stars and clear of every one; its ripples grow
-- out of the rim and fade before they restart; its sparks leak out of the
-- rim and fade inside the picture; it surges every few seconds; its cracks
-- only flicker.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

local function length(v)
	return math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
end
local function degrees(a, b)
	local dot = (a[1] * b[1] + a[2] * b[2] + a[3] * b[3]) / (length(a) * length(b))
	return math.deg(math.acos(math.clamp(dot, -1, 1)))
end

-- Where it is, seen from the middle of the quarry at eye height.
local eye = { 0, 6, 0 }
local rift = { SkyRift.Offset[1] - eye[1], SkyRift.Offset[2] - eye[2], SkyRift.Offset[3] - eye[3] }
local distance = length(rift)
local up = math.deg(math.asin(rift[2] / distance))
check(rift[3] < 0 and up > 25 and up < 45, "The rift isn't high in the north sky: " .. up)
-- Its opening, in degrees across from there.
local opening = math.deg(math.atan(SkyRift.Size * SkyRift.Void / 2 / distance))
check(opening > 3 and opening < 8, "The opening is too small or too big to read: " .. opening)

-- The sky's bodies (OutpostWorld's sky; the gas giant's size is its rings):
-- the rift's opening clears them all, and any its ripples reach passes in
-- front of it.
local reach = math.deg(math.atan(SkyRift.Size / 2 / distance))
local bodies = {
	{ "gas giant", "CFrame.new(-900, 520, -1500)", { -900, 520, -1500 }, 700 },
	{ "home world", "CFrame.new(1100, 380, -1300)", { 1100, 380, -1300 }, 136 },
	{ "red moon", "CFrame.new(300, 700, -1700)", { 300, 700, -1700 }, 45 },
}
local overlapped = 0
for _, body in bodies do
	check(string.find(WorldSource, body[2], 1, true) ~= nil, "The " .. body[1] .. " moved: update these checks")
	local at = { body[3][1] - eye[1], body[3][2] - eye[2], body[3][3] - eye[3] }
	local apart = degrees(at, rift)
	local radius = math.deg(math.asin(body[4] / length(at)))
	check(apart > radius + opening + 1, "The rift's opening sits on the " .. body[1] .. ": " .. apart)
	if apart < radius + reach then
		overlapped += 1
		check(length(at) + body[4] < distance, "The " .. body[1] .. " is behind the rift's ripples")
	end
end
check(overlapped >= 1, "The ripples don't pass behind the red moon any more")
-- The star dome is 1,700 studs out: the rift is beyond it too.
check(distance - SkyRift.Size / 2 > 1700, "The rift reaches in front of the stars")

-- Ripples: each grows from the rim toward the edge, sagging a little, stays
-- inside the picture, and fades in and out, so its restart never shows;
-- there are always a few on their way out.
for i = 1, SkyRift.Rings do
	local last, lastDrop, faintest = nil, nil, 1
	for step = 0, 599 do
		local t = (step / 600 + (1 - (i - 1) / SkyRift.Rings)) * SkyRift.RingPeriod
		local scale, fade, drop = SkyRift.ripple(t, i)
		check(scale >= SkyRift.Void - 1e-9 and scale / 2 + drop <= 0.5 + 1e-9, "A ripple outside the rift")
		check(last == nil or (scale >= last - 1e-9 and drop >= lastDrop - 1e-9), "A ripple shrank or rose")
		if step <= 3 or step >= 594 then
			check(fade > 0.9, "A ripple pops in or out: " .. fade)
		end
		last, lastDrop, faintest = scale, drop, math.min(faintest, fade)
	end
	check(faintest < 0.35, "A ripple never shows")
end
for step = 0, 299 do
	local t = step / 300 * SkyRift.RingPeriod
	local showing = 0
	for i = 1, SkyRift.Rings do
		local _, fade = SkyRift.ripple(t, i)
		if fade < 0.9 then
			showing += 1
		end
	end
	check(showing >= 3, "Too few ripples at once at " .. t)
end

-- Sparks: each leaves the rim, stays inside the picture, and fades in and out.
for k = 1, SkyRift.Motes do
	for step = 0, 999 do
		local t = step * 0.031
		local x, y, size, fade = SkyRift.mote(t, k)
		check(x > 0.05 and x < 0.95 and y > 0.05 and y < 0.97, "A spark leaves the picture")
		check(size >= 3 and size <= 5, "A spark's size")
		local r = math.sqrt((x - 0.5) ^ 2 + (y - 0.5) ^ 2)
		check(r >= SkyRift.Void / 2 - 1e-6, "A spark inside the opening")
		if r < SkyRift.Void / 2 + 0.003 then
			check(fade > 0.8, "A spark shows on the rim before it leaves: " .. fade)
		end
	end
end

-- The surge: full as it starts, gone within 1.1 seconds, every SurgeEvery.
check(SkyRift.surge(0) == 1 and SkyRift.surge(SkyRift.SurgeEvery) == 1, "No surge at the start of a cycle")
check(SkyRift.surge(1.2) == 0 and SkyRift.surge(SkyRift.SurgeEvery - 0.1) == 0, "The surge lingers")

-- Cracks flicker: each is lit now and then, never most of the time.
for k = 1, SkyRift.Cracks do
	local lit = 0
	for step = 0, 419 do
		if SkyRift.crack(step / 7, k) then
			lit += 1
		end
	end
	check(lit > 420 * 0.05 and lit < 420 * 0.3, "Crack " .. k .. " is lit " .. lit .. " of 420")
end

print(
	string.format(
		"PASS: %d sky rift checks (placement behind and clear of the planets, ripples, sparks, surge, cracks)",
		checks
	)
)
