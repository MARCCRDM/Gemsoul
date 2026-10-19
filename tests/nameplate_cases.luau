-- lune run tests/nameplate_cases.luau <repo>
-- The names and bars over creatures (client Modules/Nameplates): your own
-- kaiju without names (a bar only while hurt), another's kaiju named, wild
-- ones and critters only while wanted; on a phone from closer and smaller;
-- and a board set to its rule (only what differs).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local Nameplates = luau.load(fs.readFile(ROOT .. "/src/client/Modules/Nameplates.luau"), {
	debugName = "Nameplates",
})()
local checks = 0
local function check(ok: any, message: string)
	checks += 1
	assert(ok, message)
end

-- Your own kaiju: never named; a bar only while hurt; as far off either way.
local mineWhole, mineHurt = Nameplates.rule("Mine", false, false), Nameplates.rule("Mine", true, true)
check(not mineWhole.Show and not mineWhole.Named, "Your whole kaiju shows a plate, or its name")
check(mineHurt.Show and not mineHurt.Named, "Your hurt kaiju shows no bar, or shows its name")
-- Another player's kaiju: named; on a phone only from close by.
local other, otherPhone = Nameplates.rule("Other", false), Nameplates.rule("Other", true)
check(other.Show and other.Named and otherPhone.Show and otherPhone.Named, "Another's kaiju lost its name")
check(
	otherPhone.Distance < other.Distance and otherPhone.Distance <= 30,
	"Another's kaiju shows from as far on a phone"
)
-- Wild kaiju and critters: only while wanted (not hunting, the strip up);
-- on a phone from much closer than a computer's 160 and 90 studs.
for _, kind in { "Wild", "Critter" } do
	check(not Nameplates.rule(kind, false, nil, false).Show, kind .. " shown while not wanted")
	local desk, phone = Nameplates.rule(kind, false, nil, true), Nameplates.rule(kind, true, nil, true)
	check(desk.Show and phone.Show and desk.Named and phone.Named, kind .. " not shown and named while wanted")
	check(phone.Distance <= desk.Distance * 0.5, kind .. " shows from more than half as far on a phone")
	check(phone.Text < desk.Text, kind .. "'s name isn't smaller on a phone")
end
check(Nameplates.rule("Wild", false, nil, true).Distance == 160, "A computer's wild plate distance changed")
check(Nameplates.rule("Critter", false, nil, true).Distance == 90, "A computer's critter plate distance changed")
check(Nameplates.rule("Wild", true, nil, true).Distance <= 60, "A phone's wild plate shows from too far")

-- A board set to a rule, and set again with nothing changed.
local board = roblox.Instance.new("BillboardGui")
board.MaxDistance = 160
local label = roblox.Instance.new("TextLabel")
label.TextSize = 13
label.Parent = board
local bar = roblox.Instance.new("Frame")
bar.Parent = board
Nameplates.apply(board, Nameplates.rule("Wild", true, nil, true))
check(
	board.Enabled and board.MaxDistance == 60 and label.Visible and label.TextSize == 11,
	"A phone's wild board wasn't set"
)
Nameplates.apply(board, Nameplates.rule("Mine", true, true))
check(board.Enabled and not label.Visible and bar.Visible, "Your hurt kaiju's board kept its name or lost its bar")
Nameplates.apply(board, Nameplates.rule("Mine", true, false))
check(not board.Enabled, "Your whole kaiju's board stayed up")
-- (Only what differs is set: a board already as its rule is left alone.)
local writes = 0
local state = { Enabled = false, MaxDistance = 70, Visible = false, TextSize = 11 }
local fakeLabel = setmetatable({}, {
	__index = function(_, key)
		return state[key]
	end,
	__newindex = function(_, key, value)
		writes += 1
		state[key] = value
	end,
})
local fakeBoard = setmetatable({}, {
	__index = function(_, key)
		if key == "FindFirstChildOfClass" then
			return function()
				return fakeLabel
			end
		end
		return state[key]
	end,
	__newindex = function(_, key, value)
		writes += 1
		state[key] = value
	end,
})
Nameplates.apply(fakeBoard :: any, Nameplates.rule("Mine", true, false))
check(writes == 0, "Setting a board to the rule it has changed it: " .. writes .. " writes")

print("PASS: " .. checks .. " nameplate checks")
