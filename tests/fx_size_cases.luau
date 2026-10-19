-- lune run tests/fx_size_cases.luau <repo>
-- How big an effect is drawn (client Modules/FxSize): a creature's size held
-- while its effect draws, kept through its delays and frame loops (each its
-- own thread, so a waiting loop never lends its size to anyone else's
-- effect), clamped, and a body's size by its height.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local checks = 0
local function check(ok: any, message: string)
	checks += 1
	assert(ok, message)
end

-- A small scheduler: task.delay and task.wait on a virtual clock.
local now, queue = 0, {}
local task = {}
function task.spawn(fn, ...)
	local co = coroutine.create(fn)
	assert(coroutine.resume(co, ...))
	return co
end
function task.delay(seconds, fn, ...)
	local args = table.pack(...)
	table.insert(queue, {
		At = now + seconds,
		Fn = function()
			task.spawn(fn, table.unpack(args, 1, args.n))
		end,
	})
end
function task.wait(seconds)
	local co = coroutine.running()
	table.insert(queue, { At = now + (seconds or 0), Co = co })
	coroutine.yield()
end
local function run(stop: number)
	while true do
		table.sort(queue, function(a, b)
			return a.At < b.At
		end)
		local item = queue[1]
		if not item or item.At > stop then
			break
		end
		table.remove(queue, 1)
		now = item.At
		if item.Co then
			assert(coroutine.resume(item.Co))
		else
			item.Fn()
		end
	end
	now = stop
end

local warned = {}
local FxSize = luau.load(fs.readFile(ROOT .. "/src/client/Modules/FxSize.luau"), {
	debugName = "FxSize",
	environment = setmetatable({
		warn = function(message)
			table.insert(warned, message)
		end,
	}, { __index = _G }),
})()

-- Outside any creature's effect: a player's size.
check(FxSize.get() == 1, "Not 1 outside a creature's effect")

-- Held while it draws, and given back after.
local inside, nested
FxSize.run(0.5, function(a, b)
	inside = FxSize.get()
	check(a == "a" and b == 2, "Its arguments weren't passed on")
	FxSize.run(2, function()
		nested = FxSize.get()
	end)
	check(FxSize.get() == 0.5, "A size inside another's didn't give it back")
end, "a", 2)
check(inside == 0.5 and nested == 2, "The size wasn't held while it drew")
check(FxSize.get() == 1, "The size outlived its effect")

-- Clamped, and nonsense is a player's.
FxSize.run(100, function()
	check(FxSize.get() == FxSize.Most, "A huge size wasn't clamped")
end)
FxSize.run(0, function()
	check(FxSize.get() == FxSize.Least, "A zero size wasn't clamped")
end)
FxSize.run("big" :: any, function()
	check(FxSize.get() == 1, "A size that isn't a number wasn't a player's")
end)

-- A failing effect warns and doesn't leave its size behind.
FxSize.run(0.4, function()
	error("broken")
end)
check(#warned == 1 and FxSize.get() == 1, "A failing effect kept its size or didn't warn")

-- Kept: a delay made inside a kaiju's effect runs at its size, later, after
-- the effect is long done; one made outside is the same function.
local later
FxSize.run(0.44, function()
	task.delay(
		1,
		FxSize.keep(function()
			later = FxSize.get()
		end)
	)
end)
local plain = function() end
check(FxSize.keep(plain) == plain, "Keeping a player's size wrapped the function")
run(1)
check(later == 0.44, "A delay lost its kaiju's size")
check(FxSize.get() == 1, "A delay's size leaked out")

-- A frame loop that waits keeps its own size the whole way, and no one
-- else's effect sees it while it waits.
local seen, between = {}, nil
FxSize.run(0.55, function()
	task.spawn(FxSize.keep(function()
		for _ = 1, 3 do
			table.insert(seen, FxSize.get())
			task.wait(0.1)
		end
		table.insert(seen, FxSize.get())
	end))
end)
between = FxSize.get()
local other
task.delay(0.15, function()
	other = FxSize.get()
end)
run(now + 1)
check(between == 1, "A waiting loop lent its size to the caller")
check(other == 1, "A waiting loop lent its size to another effect")
check(#seen == 4, "The loop didn't run to its end")
for i, size in seen do
	check(size == 0.55, "The loop lost its size at step " .. i)
end

-- A body's size: its height next to a player's.
local small = {
	GetExtentsSize = function()
		return roblox.Vector3.new(2, FxSize.PlayerHeight * 0.44, 3)
	end,
}
check(math.abs(FxSize.ofModel(small :: any) - 0.44) < 1e-6, "A knee-high body wasn't its size")
check(FxSize.ofModel(nil) == 1, "No body wasn't a player's size")
local broken = {
	GetExtentsSize = function()
		error("gone")
	end,
}
check(FxSize.ofModel(broken :: any) == 1, "A body that can't be measured wasn't a player's size")
local huge = {
	GetExtentsSize = function()
		return roblox.Vector3.new(1, 1000, 1)
	end,
}
check(FxSize.ofModel(huge :: any) == FxSize.Most, "A huge body wasn't clamped")

print("PASS: " .. checks .. " effect size checks")
