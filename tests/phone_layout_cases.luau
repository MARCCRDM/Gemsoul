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

-- The Store on a phone: its phone layout near full size, where a computer's
-- would be a third (ShopUI's own fit: the screen less a margin, then below
-- Roblox's buttons, about 58 tall on a phone).
local shop = fs.readFile(ROOT .. "/src/client/Modules/ShopUI.luau")
local phoneW, deskW, phoneH, deskH = shop:match("local W, H = if SHORT then (%d+) else (%d+), if SHORT then (%d+) else (%d+)")
check(phoneW ~= nil, "The Store's sizes moved: update this test")
local function fit(w, h, screen)
	local s = math.min(1, (screen.X - 24) / w, (screen.Y - 12) / h)
	-- (below Roblox's buttons: what's left under them, at most)
	return math.min(s, (screen.Y - 58 - 6) / h)
end
local phone = Vector2.new(844, 390)
check(fit(tonumber(phoneW), tonumber(phoneH), phone) >= 0.85, "The Store's phone layout is shrunk on a phone")
check(fit(tonumber(deskW), tonumber(deskH), phone) < 0.5, "(a computer's layout on a phone isn't the small one it was)")
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

print(string.format("PASS: %d phone layout checks (a phone either way up, never a tablet or a computer; the Store's phone layout near full size, its small print up)", checks))
