-- lune run tests/kennel_sale_cases.luau <repo>
-- Wren's sales window (Client KennelSale), as specials: it builds with real
-- instances (every property and class checked), the KAIJU SPECIALS banner,
-- three offer cards each with a ribbon, a sticker and a big button (or the
-- line saying it's yours), the daily one's time left, and it pops in.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local Instance = roblox.Instance
local checks = 0
local function check(value, message)
	checks += 1
	if not value then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(message) .. "\n")
		process.exit(1)
	end
end
local function signal()
	local list = {}
	return {
		Connect = function(_, fn) table.insert(list, fn) return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, fn in list do fn(...) end end,
	}
end
local signals, ids = {}, 0
local function signalOf(instance, name)
	local id = instance:GetAttribute("_id")
	if not id then
		ids += 1
		id = ids
		instance:SetAttribute("_id", id)
	end
	local key = id .. name
	signals[key] = signals[key] or signal()
	return signals[key]
end
roblox.implementProperty("GuiButton", "Activated", function(i) return signalOf(i, "Activated") end)
roblox.implementProperty("GuiObject", "MouseEnter", function(i) return signalOf(i, "MouseEnter") end)
roblox.implementProperty("GuiObject", "MouseLeave", function(i) return signalOf(i, "MouseLeave") end)
roblox.implementProperty("Instance", "AncestryChanged", function(i) return signalOf(i, "AncestryChanged") end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(i, p) return signalOf(i, "Changed:" .. p) end)

local playerGui = Instance.new("Folder")
playerGui.Name = "PlayerGui"
local tweens = 0
local function new(class, props, parent)
	local object = Instance.new(class)
	for key, value in props or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local Gilt = {
	Gold = roblox.Color3.fromRGB(255, 196, 64), Bright = roblox.Color3.fromRGB(255, 226, 140),
	Ink = roblox.Color3.fromRGB(238, 242, 250), Faded = roblox.Color3.fromRGB(150, 162, 188),
	Dusk = roblox.Color3.fromRGB(98, 110, 138), Green = roblox.Color3.fromRGB(92, 228, 142),
	Red = roblox.Color3.fromRGB(255, 92, 92), Display = roblox.Enum.Font.GothamBlack, Serif = roblox.Enum.Font.GothamBold,
}
function Gilt.words(parent, value, size, color)
	return new("TextLabel", { BackgroundTransparency = 1, Text = value, TextSize = size, TextColor3 = color, Size = roblox.UDim2.new(1, 0, 0, size + 6) }, parent)
end
function Gilt.well(frame, edge)
	return new("UIStroke", { Color = edge or Gilt.Gold }, frame)
end
function Gilt.button(parent, label, primary, order, onClick, tall, size)
	local b = new("TextButton", { Name = "Button", Text = label, TextSize = size or 16, LayoutOrder = order, Size = roblox.UDim2.new(1, 0, 0, tall or 40) }, parent)
	if onClick then b.Activated:Connect(onClick) end
	return b
end
function Gilt.frame(holder, width)
	local frame = new("Frame", { Name = "Window", Size = roblox.UDim2.fromOffset(width, 600) }, holder)
	local body = new("Frame", { Name = "Body", Size = roblox.UDim2.fromScale(1, 1) }, frame)
	new("UIListLayout", { SortOrder = roblox.Enum.SortOrder.LayoutOrder }, body)
	return body
end
local UiKit = {
	gui = function(name)
		local g = playerGui:FindFirstChild(name) or new("ScreenGui", { Name = name }, playerGui)
		return g
	end,
	round = function(i, r) new("UICorner", { CornerRadius = roblox.UDim.new(0, math.min(r, 999)) }, i) end,
	list = function(parent, gap) return new("UIListLayout", { Padding = roblox.UDim.new(0, gap), SortOrder = roblox.Enum.SortOrder.LayoutOrder }, parent) end,
	short = function() return false end,
	toast = function() end,
}
local IronUi = { new = new, juice = function() end, Body = roblox.Enum.Font.Gotham }
local now = 1730000000 + 3600 * 5
local profile = {}
local names = setmetatable({}, { __index = function(_, k) return k end })
local shared = {}
local function loadShared(name)
	if shared[name] then return shared[name] end
	local env = setmetatable({
		Color3 = roblox.Color3, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Enum = roblox.Enum,
		UDim2 = roblox.UDim2, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
		script = { Parent = names },
		game = { GetService = function() return { Shared = names } end },
		require = function(n) return loadShared(n) end,
	}, { __index = _G })
	shared[name] = luau.load(fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau"), { debugName = name, environment = env })()
	return shared[name]
end
local purchases = {}
local stubs = {
	GemClient = { Profile = profile, request = function() return { Ok = true } end },
	GiltUi = Gilt,
	IronUi = IronUi,
	UiKit = UiKit,
	Showcase = {
		stage = function(parent) return new("Frame", { Name = "Stage", Size = roblox.UDim2.fromScale(1, 1) }, parent) end,
		model = function() end,
		group = function() end,
	},
}
local source = fs.readFile(ROOT .. "/src/client/Modules/KennelSale.luau")
source = source:gsub("IsDescendantOf%(game%)", "IsDescendantOf(__root)")
local finished = signal()
local Sale = luau.load(source, {
	debugName = "KennelSale",
	environment = setmetatable({
		__root = playerGui,
		game = {
			GetService = function(_, name)
				if name == "Players" then
					return { LocalPlayer = { UserId = 1 } }
				elseif name == "ReplicatedStorage" then
					return { WaitForChild = function() return { WaitForChild = function(_, n) return n end } end }
				elseif name == "TweenService" then
					return { Create = function() tweens += 1 return { Play = function() end, Cancel = function() end } end }
				elseif name == "MarketplaceService" then
					return { PromptProductPurchase = function(_, _, id) table.insert(purchases, id) end, PromptProductPurchaseFinished = finished }
				end
				return {}
			end,
		},
		workspace = { GetServerTimeNow = function() return now end },
		script = { Parent = names },
		require = function(n)
			if type(n) == "string" and stubs[n] then
				return stubs[n]
			elseif n == "KaijuModels" then
				return { build = function() return Instance.new("Model") end, forPortrait = function(m) return m end }
			end
			return loadShared(n)
		end,
		-- (a loop's wait ends it here: each loop runs once)
		task = {
			spawn = function(fn, ...) pcall(fn, ...) end,
			delay = function(_, fn, ...) fn(...) end,
			defer = function() end, -- (the fit to the screen: no screen here)
			wait = function() error("(end of the loop)") end,
		},
		Instance = Instance, Color3 = roblox.Color3, UDim2 = roblox.UDim2, UDim = roblox.UDim, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, CFrame = roblox.CFrame,
		Enum = roblox.Enum, ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, TweenInfo = { new = function(...) return { ... } end },
	}, { __index = _G }),
})()

-- Shopping/test stores use stub names: the window's own require names.
stubs["GemClient"] = stubs.GemClient
local ok, problem = pcall(Sale.open)
check(ok, "The sales window didn't build: " .. tostring(problem))
local gui = playerGui:FindFirstChild("KennelSale")
local function find(name)
	return gui and gui:FindFirstChild(name, true)
end
local function texts()
	local all = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			table.insert(all, d.Text)
		end
	end
	return table.concat(all, " | ")
end
local words = texts()
check(string.find(words, "KAIJU SPECIALS", 1, true), "No KAIJU SPECIALS banner")
for _, name in { "Rare", "Premium", "Daily" } do
	local card = find(name)
	check(card and card:FindFirstChild("Ribbon", true) and card:FindFirstChild("Sticker", true), name .. " has no ribbon or sticker")
	check(card:FindFirstChild("Button", true) ~= nil, name .. " has no button")
	check(card:FindFirstChild("Pop") ~= nil, name .. " doesn't pop in")
	check(card:FindFirstChildOfClass("UIStroke") ~= nil, name .. " has no glowing edge")
end
for _, ribbon in { "ONCE ONLY", "BEST VALUE", "TODAY ONLY" } do
	check(string.find(words, ribbon, 1, true), "No " .. ribbon .. " ribbon")
end
local ends = find("Ends")
check(ends and string.find(ends.Text, "ENDS IN", 1, true), "The daily sale doesn't say when it ends")
check(find("Shine") ~= nil and tweens > 0, "Nothing shines or moves")
-- Owned: the line says so, no button.
profile[shared.Kaiju.Sale.Rare.Once] = true
Sale.open()
local rare = find("Rare")
check(rare and rare:FindFirstChild("Button", true) == nil and string.find(texts(), "Claimed", 1, true), "The rare roll's offered again once it's claimed")
print(string.format("PASS: %d kennel sale checks (the specials look: banner, ribbons, stickers, glowing cards, time left, owned)", checks))
process.exit(0)
