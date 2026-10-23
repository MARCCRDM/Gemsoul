-- lune run tests/wild_bars_cases.luau <repo>
-- A wild kaiju's plate over its head (client Modules/WildBars): its name,
-- its level and a health bar in its outline's colours, the trail of the
-- last blow behind it; gold for the vein guardian, a gold edge while it's
-- being caught; the nearest few within range shown, none knocked out. The
-- HUD hands it every wild kaiju, the catch words sit just over it, and
-- "Lv" is in Spanish. Run by tests/run_wild_bars.py.
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
local function source(path: string): string
	return fs.readFile(ROOT .. "/" .. path)
end
local function has(text: string, piece: string): boolean
	return text:find(piece, 1, true) ~= nil
end

local env = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Instance = roblox.Instance,
	ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
}, { __index = _G })
local BodyHealth = luau.load(source("src/client/Modules/BodyHealth.luau"), { debugName = "BodyHealth", environment = env })()
env.script = { Parent = { BodyHealth = BodyHealth } }
env.require = function(module)
	return module
end
local WildBars = luau.load(source("src/client/Modules/WildBars.luau"), { debugName = "WildBars", environment = env })()

-- Which show: the nearest Budget within Range, none knocked out ------------------------------------------
check(WildBars.Budget >= 3 and WildBars.Budget <= 10, "Too few or too many plates at once")
check(WildBars.Range >= 80 and WildBars.Range <= BodyHealth.Outline.WildRange, "A plate's range")
do
	local list = {}
	for i = 1, 10 do
		table.insert(list, { Distance = i * 10, Share = 1 })
	end
	local downed = { Distance = 1, Share = 0 }
	local far = { Distance = WildBars.Range + 1, Share = 1 }
	table.insert(list, downed)
	table.insert(list, far)
	local on = WildBars.choose(list, 4, WildBars.Range)
	local count = 0
	for _ in on do
		count += 1
	end
	check(count == 4, "Not the budget's worth shown: " .. count)
	for i = 1, 4 do
		check(on[list[i]], "The " .. i .. "th nearest isn't shown")
	end
	check(not on[list[5]] and not on[downed] and not on[far], "A far one, a fifth or a knocked-out one shown")
	check(next(WildBars.choose({ far, downed }, 4, WildBars.Range)) == nil, "Shown out of range or knocked out")
end

-- Its plate --------------------------------------------------------------------------------------------
local function wildKaiju(name: string, level: number, guardian: boolean?)
	local model = roblox.Instance.new("Model")
	model.Name = name
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = roblox.Vector3.new(4, 6, 4)
	root.CFrame = roblox.CFrame.new(0, 5, 0)
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("KaijuWild", true)
	model:SetAttribute("KaijuLevel", level)
	if guardian then
		model:SetAttribute("KaijuGuardian", true)
	end
	return model, root
end
local model, root = wildKaiju("Wild Frost Razorback", 7)
local plate = WildBars.plate(model)
check(plate.ClassName == "BillboardGui" and plate.Name == "WildBar", "No plate")
check(plate.Adornee == root, "The plate isn't over its kaiju")
check(plate.StudsOffsetWorldSpace.Y > root.Size.Y / 2, "The plate sits in its body: " .. plate.StudsOffsetWorldSpace.Y)
check(plate.AlwaysOnTop and plate.LightInfluence == 0 and plate.MaxDistance == WildBars.Range, "The plate's drawing")
check(plate.Enabled == false, "Shown before it's picked")
check(plate.Size.X.Offset == WildBars.Size.X and plate.Size.Y.Offset == WildBars.Size.Y, "The plate's size")
local name = plate:FindFirstChild("Title")
check(name and name.Text == "Wild Frost Razorback", "No name on the plate")
check(name.TextTruncate == roblox.Enum.TextTruncate.AtEnd, "A long name runs off the plate")
local fit = name:FindFirstChildOfClass("UITextSizeConstraint")
check(name.TextScaled and fit and fit.MaxTextSize == 14 and fit.MinTextSize >= 9, "A long name doesn't shrink to fit")
local level = plate:FindFirstChild("Level")
check(level and level:FindFirstChild("Text").Text == "Lv 7", "No level on the plate")
local back = plate:FindFirstChild("Back")
local fill, trail = back and back:FindFirstChild("Fill"), back and back:FindFirstChild("Trail")
local edge = back and back:FindFirstChild("Edge")
check(fill and trail and edge, "No health bar")
check(back.ClipsDescendants, "The bar spills out")
-- (The bar is drawn over its trail.)
check(table.find(back:GetChildren(), trail) < table.find(back:GetChildren(), fill), "The trail drawn over the bar")
-- (Everything inside the plate.)
for _, child in plate:GetDescendants() do
	if child:IsA("GuiObject") and child.Parent == plate then
		local right = child.Position.X.Offset + child.Size.X.Offset + child.Size.X.Scale * WildBars.Size.X
		local bottom = child.Position.Y.Offset + child.Size.Y.Offset + child.Size.Y.Scale * WildBars.Size.Y
		check(right <= WildBars.Size.X + 0.5 and bottom <= WildBars.Size.Y + 0.5, child.Name .. " spills off the plate")
	end
end

-- On a phone: a smaller plate (it was a big slab over every kaiju), fewer
-- at once, everything inside still on it and still readable.
check(WildBars.PhoneSize.X <= WildBars.Size.X * 0.65 and WildBars.PhoneSize.Y <= WildBars.Size.Y * 0.65, "The phone plate isn't smaller")
check(WildBars.PhoneBudget >= 2 and WildBars.PhoneBudget < WildBars.Budget, "As many plates on a phone")
local small = WildBars.plate(model, true)
local PW, PH = WildBars.PhoneSize.X, WildBars.PhoneSize.Y
check(small.Size.X.Offset == PW and small.Size.Y.Offset == PH, "The phone plate's size")
for _, child in small:GetDescendants() do
	if child:IsA("GuiObject") and child.Parent == small then
		local right = child.Position.X.Offset + child.Size.X.Offset + child.Size.X.Scale * PW
		local bottom = child.Position.Y.Offset + child.Size.Y.Offset + child.Size.Y.Scale * PH
		check(right <= PW + 0.5 and bottom <= PH + 0.5, child.Name .. " spills off the phone plate")
	end
	if child:IsA("TextLabel") then
		check(child.TextSize >= 8, child.Name .. " too small to read on a phone")
	end
end
local smallBack = small:FindFirstChild("Back")
check(smallBack.Size.Y.Offset >= 5 and smallBack.Size.Y.Offset < back.Size.Y.Offset, "The phone bar's height")
WildBars.draw(small, 0.5, 0.8)
check(math.abs(smallBack:FindFirstChild("Fill").Size.X.Scale - 0.5) < 1e-6, "The phone bar doesn't fill")

-- Filled in --------------------------------------------------------------------------------------------
local function near(a, b)
	return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
end
WildBars.draw(plate, 1, 1)
check(fill.Size.X.Scale == 1 and near(fill.BackgroundColor3, BodyHealth.outlineColor(1)), "Full, the bar isn't full and green")
WildBars.draw(plate, 0.5, 0.8)
check(math.abs(fill.Size.X.Scale - 0.5) < 1e-6, "Half its health, the bar isn't half")
check(near(fill.BackgroundColor3, BodyHealth.outlineColor(0.5)), "The bar isn't its outline's colour")
check(math.abs(trail.Size.X.Scale - 0.8) < 1e-6, "The last blow's trail isn't behind the bar")
WildBars.draw(plate, 0.2, 0.2)
check(near(fill.BackgroundColor3, BodyHealth.Outline.Bad), "Nearly done, the bar isn't red")
WildBars.draw(plate, 0.6, 0.1)
check(math.abs(trail.Size.X.Scale - 0.6) < 1e-6, "The trail under the bar")
WildBars.draw(plate, -1, 2)
check(fill.Size.X.Scale == 0 and trail.Size.X.Scale == 1, "Past empty or full")
local plainEdge = edge.Color
WildBars.draw(plate, 1, 1, false, true)
check(not near(edge.Color, plainEdge) and edge.Thickness == 2, "Being caught, no gold edge")
WildBars.draw(plate, 1, 1)
check(near(edge.Color, plainEdge) and edge.Thickness == 1, "Still edged gold once it's let go")
local guard = WildBars.plate((wildKaiju("Vein Guardian Fire Bulwark", 18, true)))
WildBars.draw(guard, 1, 1, true)
local guardEdge = guard:FindFirstChild("Back"):FindFirstChild("Edge")
check(not near(guard:FindFirstChild("Title").TextColor3, name.TextColor3) and not near(guardEdge.Color, plainEdge), "The guardian's plate isn't gold")

-- Wired in ---------------------------------------------------------------------------------------------
local hud = source("src/client/Modules/KaijuHud.luau")
check(has(hud, "WildBars.watch(model)") and has(hud, "WildBars.start()"), "The HUD doesn't hand it the wild kaiju")
local module = source("src/client/Modules/WildBars.luau")
check(has(module, 'model:GetAttribute("KaijuWild") == nil then\n\t\treturn'), "A plate over something not wild")
check(has(module, "entry.Plate.Parent = playerGui"), "The plate's not in PlayerGui (no Spanish)")
local foes = source("src/client/Modules/FoeBars.luau")
check(has(foes, 'model:GetAttribute("KaijuWild") ~= nil'), "FoeBars draws its bar over a wild kaiju too")
local taming = source("src/client/Modules/KaijuTaming.luau")
check(has(taming, "SizeOffset = Vector2.new(0, 1.3)"), "The catch words sit on the plate")
local es = source("src/shared/LangEs.luau")
check(has(es, '["Lv {1}"] = "Nv {1}"'), "No Spanish for the level")

print(string.format("PASS: %d wild kaiju plate checks (which show, the plate, its bar and trail, the guardian, being caught, wired in)", checks))
