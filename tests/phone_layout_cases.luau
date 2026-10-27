-- A phone is a phone either way up (UiKit.short): the game turns phones
-- sideways (first.Orientation), but the screens built as it starts can see
-- one still upright, tall and narrow. Judged by its height, that phone was
-- "a computer", and the Store (and the others that choose at start) laid
-- out for a computer and shrank it to a third: the tiny Store on a phone.
-- Judged by its shorter side, a phone is one before it turns and after; a
-- tablet and a computer never are. Then the Store's phone layout fills a
-- phone near full size, its small print a size up. Run by tests/run_phone_layout.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector2 = roblox.Vector2
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

-- The camera's screen and the device's input, as test doubles.
local viewport = Vector2.new(844, 390)
local input = { TouchEnabled = true, KeyboardEnabled = false }
local camera = setmetatable({}, {
	__index = function(_, key)
		if key == "ViewportSize" then
			return viewport
		end
		return nil
	end,
})
local env = setmetatable({
	game = {
		GetService = function(_, name)
			if name == "UserInputService" then
				return input
			end
			return {}
		end,
	},
	workspace = { CurrentCamera = camera },
	script = { Parent = {} },
	require = function()
		return {}
	end,
	Vector2 = Vector2,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	Instance = roblox.Instance,
}, { __index = _G })
local UiKit = luau.load(fs.readFile(ROOT .. "/src/client/Modules/UiKit.luau"), { debugName = "UiKit", environment = env })()

local function short(x, y, touch, keyboard)
	viewport = Vector2.new(x, y)
	input.TouchEnabled, input.KeyboardEnabled = touch, keyboard
	return UiKit.short()
end
-- Phones, on their side and still upright as the game starts.
for _, size in { { 844, 390 }, { 667, 375 }, { 932, 430 }, { 915, 412 }, { 568, 320 } } do
	check(short(size[1], size[2], true, false), "A phone on its side isn't a phone: " .. size[1] .. "x" .. size[2])
	check(short(size[2], size[1], true, false), "A phone still upright isn't a phone: " .. size[2] .. "x" .. size[1])
end
-- Tablets either way up, and computers, are not.
for _, size in { { 1024, 768 }, { 768, 1024 }, { 1133, 744 }, { 744, 1133 }, { 1366, 768 }, { 1920, 1080 }, { 1280, 720 } } do
	check(not short(size[1], size[2], true, false), "A tablet counts as a phone: " .. size[1] .. "x" .. size[2])
	check(not short(size[1], size[2], false, true), "A computer counts as a phone: " .. size[1] .. "x" .. size[2])
end
-- Before the camera knows the screen: a touch screen without a keyboard is
-- a phone; with one, it's not.
check(short(1, 1, true, false), "A touch screen before the camera knows it isn't a phone")
check(not short(1, 1, false, true), "A computer before the camera knows it counts as a phone")
check(UiKit.PhoneSide == 500, "The phone line moved: " .. tostring(UiKit.PhoneSide))

-- The screens that choose their layout as they're built ask UiKit, never
-- the screen's height on their own.
for _, name in { "ShopUI", "MarketBoardUI", "KaijuHud", "SurgeArrayUI", "SeasonUI", "SocialUI" } do
	local source = fs.readFile(ROOT .. "/src/client/Modules/" .. name .. ".luau")
	check(source:find("local SHORT = UiKit.short()", 1, true) ~= nil, name .. " doesn't ask UiKit whether it's a phone")
end

-- The Store on a phone: the whole screen (MobileLayout.store, checked in
-- mobile_layout_cases), fitted from the screen whichever way up the window
-- last saw it (a window built while the phone was upright kept that size
-- while hidden, and the Store came out fitted to an upright phone, under
-- half its size), and the opening's little grow never has the last word
-- over a fit.
local shop = fs.readFile(ROOT .. "/src/client/Modules/ShopUI.luau")
check(shop:find("MobileLayout.store(screen, top, right - (whole - screen.X) / 2)", 1, true) ~= nil, "The Store on a phone isn't the whole screen")
check(shop:find("local function screenSize(): Vector2", 1, true) ~= nil, "The Store doesn't read the screen itself")
check(
	shop:find("(view.X > view.Y) ~= (screen.X > screen.Y)", 1, true) ~= nil,
	"The Store trusts a window size from an upright phone"
)
check(shop:find("camera:GetPropertyChangedSignal(\"ViewportSize\"):Connect(fit)", 1, true) ~= nil, "The Store isn't fitted again when the screen turns")
check(shop:find("gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets", 1, true) ~= nil, "The Store on a phone runs under the notch")
check(shop:find("pop:Cancel()", 1, true) ~= nil, "The opening's grow can undo a fit")
check(shop:find("scale.Scale *= 0.96", 1, true) == nil, "The opening's grow scales whatever was there")
check(shop:find("task.defer(fit)", 1, true) ~= nil, "The Store isn't fitted again once it's up")
check(shop:find("local UP = if SHORT then 1 else 0", 1, true) ~= nil, "The Store's small print isn't a size up on a phone")
for _, piece in {
	"9 + UP)", -- a card's rarity
	"14 + UP, C.Text, BOLD", -- its name
	"11 + UP, C.Dim, MEDIUM", -- its kind
	"17 + UP, C.Text, BLACK", -- its price
	"TextSize = 12 + UP", -- the sorting
	"text(list, title, 11 + UP", -- a section's head
} do
	check(shop:find(piece, 1, true) ~= nil, "A size up missing on a phone: " .. piece)
end

print(string.format("PASS: %d phone layout checks (a phone either way up, never a tablet or a computer; the Store the whole screen on a phone, fitted whichever way up, its small print up)", checks))
