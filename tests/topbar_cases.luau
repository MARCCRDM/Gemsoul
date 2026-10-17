-- lune run tests/topbar_cases.luau <repo>
-- Roblox's own buttons along the top of the screen (UiKit.topbar,
-- UiKit.clearTopbar): a window that reaches the top moves beside them or
-- shrinks below them, never under them or under our DEV button, on every
-- common screen, before Roblox has drawn them (TopbarInset reads empty) and
-- after; and whatever lays itself out around them hears when they change.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector2, UDim2 = roblox.Vector2, roblox.UDim2
local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- Roblox's GuiService, as a test double: TopbarInset reads empty until set.
local inset = { Min = Vector2.zero, Max = Vector2.zero }
local insetChanged = {}
local GuiService = {
	GetPropertyChangedSignal = function(_, name)
		assert(name == "TopbarInset", "UiKit listens for an unexpected property: " .. tostring(name))
		return {
			Connect = function(_, fn)
				table.insert(insetChanged, fn)
				return { Disconnect = function() end }
			end,
		}
	end,
}
setmetatable(GuiService, {
	__index = function(_, key)
		if key == "TopbarInset" then
			return inset
		end
		return nil
	end,
})
local function setInset(minX, maxX, maxY)
	inset = { Min = Vector2.new(minX, 0), Max = Vector2.new(maxX, maxY) }
	for _, fn in insetChanged do
		fn()
	end
end
local services = { GuiService = GuiService, Players = { LocalPlayer = {} }, TweenService = {} }
local env = setmetatable({
	game = {
		GetService = function(_, name)
			return services[name] or {}
		end,
	},
	script = { Parent = { UiSound = "UiSound" } },
	require = function()
		return {}
	end,
	task = {
		spawn = function(fn, ...)
			fn(...)
		end,
	},
	Vector2 = Vector2,
	UDim2 = UDim2,
	UDim = roblox.UDim,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	Instance = roblox.Instance,
}, { __index = _G })
local UiKit =
	luau.load(fs.readFile(ROOT .. "/src/client/Modules/UiKit.luau"), { debugName = "UiKit", environment = env })()

-- Where a box of `size` lands for a scale and Position (AnchorPoint 0.5, 0.5).
local function placed(screen, size, scale, at)
	local w, h = size.X * scale, size.Y * scale
	local cx = screen.X * at.X.Scale + at.X.Offset
	local cy = screen.Y * at.Y.Scale + at.Y.Offset
	return { X = cx - w / 2, Y = cy - h / 2, W = w, H = h }
end
local function overlaps(a, x0, y0, x1, y1)
	return math.min(a.X + a.W, x1) - math.max(a.X, x0) > 0.5 and math.min(a.Y + a.H, y1) - math.max(a.Y, y0) > 0.5
end

-- Phones on their side (a notched phone's safe area, an older phone), a small
-- tablet and a desktop; boxes from a small dialog to a full-screen window,
-- each first fitted to the screen as the windows do.
local SCREENS = { { 726, 390 }, { 844, 390 }, { 667, 375 }, { 932, 430 }, { 1024, 768 }, { 1366, 768 } }
local BOXES = { { 420, 260 }, { 620, 266 }, { 620, 370 }, { 900, 420 }, { 1040, 600 }, { 1360, 720 }, { 1600, 840 } }
local function sweep(label, left, top, reserved)
	for _, s in SCREENS do
		local screen = Vector2.new(s[1], s[2])
		for _, b in BOXES do
			local fit = math.min(1, (screen.X - 24) / b[1], (screen.Y - 16) / b[2])
			local size = Vector2.new(b[1], b[2]) * fit
			local scale, at = UiKit.clearTopbar(screen, size)
			local box = placed(screen, size, scale, at)
			local name = string.format("%s %dx%d box %dx%d", label, s[1], s[2], b[1], b[2])
			check(scale > 0.4 and scale <= 1, name .. ": shrank to nothing (" .. scale .. ")")
			check(box.X >= -0.5 and box.Y >= -0.5, name .. ": off the screen's top or left")
			check(box.X + box.W <= screen.X + 0.5 and box.Y + box.H <= screen.Y + 0.5, name .. ": off the screen")
			check(not overlaps(box, 0, 0, left, top), name .. ": under Roblox's buttons")
			if reserved > 0 then
				check(not overlaps(box, screen.X - reserved, 0, screen.X, top), name .. ": under the DEV button")
			end
		end
	end
end

-- 1. Before Roblox has drawn its buttons: the usual ones are assumed.
local assumedTop, assumedLeft, assumedRight = UiKit.topbar(844)
check(assumedTop >= 58 and assumedLeft >= 270 and assumedRight == 844, "No room kept for buttons not yet drawn")
sweep("not drawn yet", assumedLeft, assumedTop, 0)

-- 2. Our own listeners hear when Roblox draws them (and can stop listening).
local heard, stoppedHeard = 0, 0
UiKit.onTopbar(function()
	heard += 1
end)
local stop = UiKit.onTopbar(function()
	stoppedHeard += 1
end)
stop()
setInset(262, 832, 58)
check(heard == 1 and stoppedHeard == 0, "A listener missed the top bar arriving, or one still heard after stopping")
local top, left = UiKit.topbar(844)
check(top == 58 and left == 262, "The drawn top bar isn't read")
sweep("drawn", 262, 58, 0)

-- 3. The DEV button keeps its end of the strip: windows stop short of it.
UiKit.reserveTopbar(70)
check(heard == 2, "Reserving the DEV button's room didn't re-fit the windows")
local _, _, right = UiKit.topbar(844)
check(right == 832 - 70, "The DEV button's room isn't kept")
sweep("with DEV", 262, 58, 70)

-- 4. Roblox's menu opened (its buttons widen): still clear of them.
setInset(520, 832, 58)
sweep("menu open", 520, 58, 70)
setInset(262, 832, 58)

-- 5. A box that's already clear stays as it was.
local scale, at = UiKit.clearTopbar(Vector2.new(1366, 768), Vector2.new(900, 600))
check(scale == 1 and at == UDim2.fromScale(0.5, 0.5), "A desktop window clear of the top bar moved")
scale, at = UiKit.clearTopbar(Vector2.new(844, 390), Vector2.new(420, 260))
check(scale == 1 and at == UDim2.fromScale(0.5, 0.5), "A small phone dialog clear of the top bar moved")
scale = UiKit.clearTopbar(Vector2.zero, Vector2.new(420, 260))
check(scale == 1, "A screen not yet sized broke the fit")

print(
	string.format(
		"PASS: %d top bar checks (Roblox's buttons and DEV kept clear on %d screens, before and after they're drawn)",
		checks,
		#SCREENS
	)
)
