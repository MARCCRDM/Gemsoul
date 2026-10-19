-- The rift in the Outpost's sky (SkyRift): it hangs high in the north,
-- behind the planets and the stars and clear of every one; it's a long,
-- jagged tear, pointed at both ends and torn ragged along both sides; its
-- sparks and shards leave its edges and fade outside it, never popping; it
-- surges every few seconds; its cracks only flash now and then.
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
-- Its size there, in degrees: long enough to read as a tear, not a sliver.
local long = 2 * math.deg(math.atan(SkyRift.Size * SkyRift.Length / 2 / distance))
local wide = 2 * math.deg(math.atan(SkyRift.Size * SkyRift.Width / 2 / distance))
check(long > 15 and long < 30, "The tear is too short or too long to read: " .. long)
check(wide > 2 and wide < 7, "The tear is too thin or too wide: " .. wide)

-- The tear: pointed at both ends, leaning like "/", inside the picture,
-- each side to its side of the middle and never wider than Width, and torn:
-- its width keeps changing, and the two sides differ.
local tear = SkyRift.tear()
local spine, left, right = tear.Spine, tear.Left, tear.Right
local n = #spine
check(n == SkyRift.Points and #left == n and #right == n, "The tear's edges and middle don't match")
local function apart(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
end
for _, i in { 1, n } do
	check(apart(left[i], spine[i]) < 1e-9 and apart(right[i], spine[i]) < 1e-9, "The tear isn't pointed at its ends")
end
check(spine[1][2] < spine[n][2] and spine[1][1] > spine[n][1], "The tear doesn't lean like /")
local a = math.rad(SkyRift.Tilt)
local across = { math.cos(a), math.sin(a) }
local turns, uneven, last, lastDiff = 0, 0, nil, nil
for i = 1, n do
	for _, p in { spine[i], left[i], right[i] } do
		check(p[1] > 0.08 and p[1] < 0.92 and p[2] > 0.08 and p[2] < 0.92, "The tear runs out of the picture")
	end
	if i > 1 and i < n then
		local l = -((left[i][1] - spine[i][1]) * across[1] + (left[i][2] - spine[i][2]) * across[2])
		local r = (right[i][1] - spine[i][1]) * across[1] + (right[i][2] - spine[i][2]) * across[2]
		check(l > 0.002 and r > 0.002, "A side of the tear crosses its middle")
		check(l + r <= SkyRift.Width + 1e-9, "The tear is wider than Width")
		if math.abs(l - r) > 0.004 then
			uneven += 1
		end
		if last then
			local diff = l - last
			if lastDiff and diff * lastDiff < 0 then
				turns += 1
			end
			lastDiff = diff
		end
		last = l
	end
end
check(turns >= n / 4, "The tear's edge isn't ragged: " .. turns .. " turns")
check(uneven >= n / 2, "The tear's two sides are torn alike")

-- Is a point (a share of the picture) inside the tear?
local outline = {}
for i = 1, n do
	table.insert(outline, left[i])
end
for i = n - 1, 2, -1 do
	table.insert(outline, right[i])
end
local function inside(x, y)
	local hit = false
	local j = #outline
	for i = 1, #outline do
		local p, q = outline[i], outline[j]
		if (p[2] > y) ~= (q[2] > y) and x < (q[1] - p[1]) * (y - p[2]) / (q[2] - p[2]) + p[1] then
			hit = not hit
		end
		j = i
	end
	return hit
end
check(inside(0.5, 0.5) and inside(spine[4][1], spine[4][2]), "The middle isn't inside the tear")
check(not inside(0.5, 0.05) and not inside(0.9, 0.5), "Far off counts as inside the tear")

-- The sky's bodies (OutpostWorld's sky; the gas giant's size is its rings),
-- as the rift's picture sees them from the quarry (the billboard faces you):
-- the tear and its cracks clear them all, and any the picture reaches passes
-- in front of it.
local function cross(u, v)
	return { u[2] * v[3] - u[3] * v[2], u[3] * v[1] - u[1] * v[3], u[1] * v[2] - u[2] * v[1] }
end
local function dot(u, v)
	return u[1] * v[1] + u[2] * v[2] + u[3] * v[3]
end
local forward = { rift[1] / distance, rift[2] / distance, rift[3] / distance }
local rightward = cross(forward, { 0, 1, 0 })
local r = length(rightward)
rightward = { rightward[1] / r, rightward[2] / r, rightward[3] / r }
local upward = cross(rightward, forward)
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
	local depth = dot(at, forward)
	-- (Where it is on the picture, and how big, in shares of it.)
	local x = 0.5 + dot(at, rightward) / depth * distance / SkyRift.Size
	local y = 0.5 - dot(at, upward) / depth * distance / SkyRift.Size
	local radius = body[4] / depth * distance / SkyRift.Size
	local nearest = math.huge
	for i = 1, n - 1 do
		for _, side in { left, right, spine } do
			for f = 0, 1, 0.1 do
				local px = side[i][1] + (side[i + 1][1] - side[i][1]) * f
				local py = side[i][2] + (side[i + 1][2] - side[i][2]) * f
				nearest = math.min(nearest, math.sqrt((px - x) ^ 2 + (py - y) ^ 2))
			end
		end
	end
	check(nearest > radius + 0.08, "The tear runs into the " .. body[1] .. ": " .. nearest - radius)
	local degreesApart = math.deg(math.acos(math.clamp(dot(at, forward) / length(at), -1, 1)))
	if degreesApart < math.deg(math.asin(body[4] / length(at))) + reach then
		overlapped += 1
		check(length(at) + body[4] < distance, "The " .. body[1] .. " is behind the rift's glow")
	end
end
check(overlapped >= 1, "The rift's glow doesn't pass behind the red moon any more")
-- The star dome is 1,700 studs out: the rift is beyond it too.
check(distance - SkyRift.Size / 2 > 1700, "The rift reaches in front of the stars")

-- Sparks and shards: each stays in the picture, never pops in or out (a
-- jump between frames only while it's all but gone), and once showing it's
-- outside the tear, leaving it.
local function leaves(name, sample, count)
	for k = 1, count do
		local px, py, pf = sample(0, k)
		for step = 1, 1500 do
			local t = step * 0.01
			local x, y, fade = sample(t, k)
			check(x > 0.03 and x < 0.97 and y > 0.03 and y < 0.97, "A " .. name .. " leaves the picture")
			if math.sqrt((x - px) ^ 2 + (y - py) ^ 2) > 0.01 then
				check(fade > 0.85 and pf > 0.85, "A " .. name .. " pops in or out: " .. math.min(fade, pf))
			end
			if fade < 0.6 then
				check(not inside(x, y), "A " .. name .. " shows inside the tear")
			end
			px, py, pf = x, y, fade
		end
	end
end
leaves("spark", function(t, k)
	local x, y, size, fade = SkyRift.mote(t, k)
	check(size >= 3 and size <= 5, "A spark's size")
	return x, y, fade
end, SkyRift.Motes)
local turned = 0
leaves("shard", function(t, k)
	local x, y, turn, size, fade = SkyRift.shard(t, k)
	check(size > 0.005 and size < 0.03, "A shard's size: " .. size)
	local _, _, before = SkyRift.shard(t - 0.1, k)
	if math.abs(turn - before) > 0.5 and math.abs(turn - before) < 30 then
		turned += 1
	end
	return x, y, fade
end, SkyRift.Shards)
check(turned > 1500 * SkyRift.Shards * 0.8, "The shards don't spin")

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
		"PASS: %d sky rift checks (placement behind and clear of the planets, the tear, sparks, shards, surge, cracks)",
		checks
	)
)
