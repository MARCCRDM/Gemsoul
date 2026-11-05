-- lune run tests/main_menu_cases.luau <repo>
-- The main menu (Client Modules/MainMenu, Shared.MainMenuContent) on the
-- title screen (Client Splash): two matching panels, PLAY and the four, the
-- banners on by themselves (held after a touch), their buttons (codes
-- redeemed there and then, a page, or in and then the board / the picker /
-- the booth), the pages (GUIDE, UPDATES, FEEDBACK, CREDITS) and BACK, the
-- phone's layout. Driven on a clock of its own with Lune's instances.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local Instance, Vector2 = roblox.Instance, roblox.Vector2
local checks = 0
local function check(value, message)
	checks += 1
	if not value then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(message) .. "\n")
		process.exit(1)
	end
end

-- Roblox's events Lune's instances lack.
local handlers, nextId = {}, 0
local function idOf(instance)
	local id = instance:GetAttribute("_test")
	if not id then
		nextId += 1
		id = nextId
		instance:SetAttribute("_test", id)
	end
	return id
end
local function signalFor(instance, name)
	local key = idOf(instance) .. ":" .. name
	handlers[key] = handlers[key] or {}
	local list = handlers[key]
	return {
		Connect = function(_, fn)
			table.insert(list, fn)
			return { Disconnect = function() end }
		end,
	}
end
local function fire(instance, name, ...)
	for _, fn in handlers[idOf(instance) .. ":" .. name] or {} do
		fn(...)
	end
end
roblox.implementProperty("GuiButton", "Activated", function(instance)
	return signalFor(instance, "Activated")
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(instance, prop)
	return signalFor(instance, "Changed:" .. prop)
end)
local function signal()
	local list = {}
	return {
		Connect = function(_, fn)
			table.insert(list, fn)
			return { Disconnect = function()
				local at = table.find(list, fn)
				if at then
					table.remove(list, at)
				end
			end }
		end,
		Fire = function(_, ...)
			for _, fn in table.clone(list) do
				fn(...)
			end
		end,
		Count = function()
			return #list
		end,
	}
end

-- A clock; task.spawn and task.defer run at once, task.delay / wait on it.
local now = 0
local later = {}
local fakeTask = {
	spawn = function(fn, ...)
		fn(...)
	end,
	defer = function(fn, ...)
		fn(...)
	end,
	delay = function(seconds, fn, ...)
		table.insert(later, { At = now + seconds, Fn = fn, Args = { ... } })
	end,
	wait = function()
		return 0
	end,
}
local heartbeat, inputBegan = signal(), signal()
local function step(seconds)
	local stop = now + seconds
	while now < stop - 1e-9 do
		now += 0.1
		for i = #later, 1, -1 do
			if later[i].At <= now then
				local entry = table.remove(later, i)
				entry.Fn(table.unpack(entry.Args))
			end
		end
		heartbeat:Fire(0.1)
	end
end

-- The screen, the player, the server and the DEV desk.
local SCREEN = Vector2.new(1920, 1080)
local playerGui = Instance.new("Folder")
playerGui.Name = "PlayerGui"
local player = { PlayerGui = playerGui, Character = nil }
local requests = {}
local replies = {}
local GemClient = {
	Profile = { Intro = { Done = true } },
	request = function(action, ...)
		table.insert(requests, { action, ... })
		local reply = replies[action]
		if type(reply) == "function" then
			return reply(...)
		end
		return reply or { Ok = false, Message = "?" }
	end,
}
local deskOnline = false
local desk = {
	GetAttribute = function(_, name)
		return if name == "DevOnline" then deskOnline else nil
	end,
	IsA = function(_, class)
		return class == "Model"
	end,
	GetPivot = function()
		return roblox.CFrame.new(10, 0, 10)
	end,
	FindFirstChildWhichIsA = function()
		return nil
	end,
}
local after = {}
local stubs = {
	GemClient = GemClient,
	IronUi = {
		new = function(class, props, parent)
			local object = Instance.new(class)
			for key, value in props or {} do
				object[key] = value
			end
			object.Parent = parent
			return object
		end,
		clear = function(parent)
			for _, child in parent:GetChildren() do
				if not child:IsA("UIComponent") then
					child:Destroy()
				end
			end
		end,
		juice = function() end,
		animate = function() end,
	},
	UiKit = { round = function() end },
	LoadingFlow = { waitClear = function() end },
	RiftClient = { openGate = function(which) table.insert(after, "Board:" .. which) end },
	LobbyUI = { openPicker = function() table.insert(after, "Picker") end },
	GroundGuide = {
		set = function(key) table.insert(after, "Guide:" .. key) end,
		clear = function() end,
	},
	SettingsUI = { open = function() table.insert(after, "Settings") end },
}
local sharedEnv = setmetatable({ Color3 = roblox.Color3, os = { time = function() return 0 end } }, { __index = _G })
local Content = luau.load(fs.readFile(ROOT .. "/src/shared/MainMenuContent.luau"), {
	debugName = "MainMenuContent",
	environment = setmetatable({ Color3 = roblox.Color3 }, { __index = _G }),
})()
local _ = sharedEnv
local TODAY = os.time({ year = 2026, month = 11, day = 5, hour = 12 })
local names = setmetatable({}, { __index = function(_, k) return k end })
local function loadMenu()
	local source = fs.readFile(ROOT .. "/src/client/Modules/MainMenu.luau")
	source = string.gsub(source, "([%w_]+)%.AbsoluteSize", "__absSize(%1)")
	return luau.load(source, {
		debugName = "MainMenu",
		environment = setmetatable({
			game = {
				GetService = function(_, name)
					if name == "Players" then
						return { LocalPlayer = player }
					elseif name == "ReplicatedStorage" then
						return { Shared = names }
					elseif name == "RunService" then
						return { Heartbeat = heartbeat }
					elseif name == "TweenService" then
						return { Create = function() return { Play = function() end } end }
					elseif name == "UserInputService" then
						return {
							TouchEnabled = false,
							KeyboardEnabled = true,
							InputBegan = inputBegan,
							GetFocusedTextBox = function() return nil end,
						}
					end
					return {}
				end,
			},
			workspace = { FindFirstChild = function(_, name) return if name == "DevDesk" then desk else nil end },
			script = { Parent = names },
			require = function(name)
				if name == "Config" then
					return { Playtest = { Build = "1.10 · 2026-11-04 narration" } }
				elseif name == "MainMenuContent" then
					return Content
				end
				return stubs[name] or error("no stub for " .. tostring(name))
			end,
			task = fakeTask,
			os = { clock = function() return now end, time = function() return TODAY end, date = os.date },
			Instance = Instance,
			Vector2 = Vector2,
			UDim = roblox.UDim,
			UDim2 = roblox.UDim2,
			Color3 = roblox.Color3,
			Enum = roblox.Enum,
			NumberSequence = roblox.NumberSequence,
			ColorSequence = roblox.ColorSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			TweenInfo = { new = function() return {} end },
			__absSize = function()
				return SCREEN
			end,
		}, { __index = _G }),
	})()
end

local function find(parent, name)
	for _, d in parent:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end
local function texts(parent)
	local list = {}
	for _, d in parent:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
			local shown, at = true, d
			while at and at ~= parent do
				if at:IsA("GuiObject") and not at.Visible then
					shown = false
				end
				at = at.Parent
			end
			if shown then
				table.insert(list, d.Text)
			end
		end
	end
	return table.concat(list, "\n")
end

-- The content ------------------------------------------------------------------------------------------
do
	local codes = fs.readFile(ROOT .. "/src/server/Systems/Codes.luau")
	local menuSource = fs.readFile(ROOT .. "/src/shared/MainMenuContent.luau")
	for _, b in Content.Banners do
		check(b.Id and b.Tag and b.TagColor and b.Title and b.Line and b.Short and b.Button and b.Action, "A banner missing a part: " .. tostring(b.Id))
		check(#b.Title <= 26, "A banner's title too long for its panel: " .. b.Title)
		-- (its picture: in the upload folder, and its id line for the tool)
		local file = menuSource:match(b.Id .. " = %d+, %-%- ([%w_]+%.png)")
		check(file ~= nil and Content.Images[b.Id] ~= nil, "No picture line for " .. b.Id)
		check(fs.isFile(ROOT .. "/assets/images/menu/" .. file), "No picture file for " .. b.Id .. ": " .. tostring(file))
		-- (a code it offers: a real one, and the banner ends no later than it)
		for _, code in b.Codes or {} do
			local at = codes:find("\n\t" .. code .. " = {", 1, true)
			check(at ~= nil, b.Id .. " offers a code that doesn't exist: " .. code)
			local body = codes:sub(at, (codes:find("\n\t},", at, true)))
			local y, m, d = body:match("Expires = os.time%({ year = (%d+), month = (%d+), day = (%d+)")
			if y then
				local ends = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 23, min = 59 })
				local mine = if #b.Codes > 1 then b.CodeEnds and b.CodeEnds[code] else b.Ends
				check(mine ~= nil and mine <= ends + 60, b.Id .. " still offers " .. code .. " after it ends")
				check(b.Ends ~= nil and b.Ends >= mine, b.Id .. " goes before its code " .. code)
				-- (and its button with it)
				check(table.find(Content.codesOf(b, ends + 3600), code) == nil, b.Id .. " shows " .. code .. " after it ends")
			end
		end
		if b.Action.Kind == "Redeem" then
			check(table.find(b.Codes or {}, b.Action.Code) ~= nil, b.Id .. "'s button redeems a code it doesn't show")
		end
	end
	-- Taken down by themselves once ended.
	local late = os.time({ year = 2026, month = 11, day = 20 })
	for _, b in Content.live(late) do
		check(b.Id ~= "KaijuCodes", "The kaiju codes' banner still up after they end")
	end
	check(#Content.live(TODAY) == #Content.Banners, "A banner down before its time")
	check(Content.version("1.10 · 2026-11-04 x") == "v1.10" and Content.version(nil) == "", "The version isn't read off the build")
	check(#Content.Guide >= 4 and #Content.Updates >= 2 and #Content.Credits >= 2, "Thin pages")
end

-- The menu ---------------------------------------------------------------------------------------------
local MainMenu = loadMenu()
local name, scale = MainMenu.layout(Vector2.new(844, 390))
check(name == "Phone" and math.abs(scale - 1) < 0.01, "A phone doesn't get the phone layout")
name, scale = MainMenu.layout(Vector2.new(1920, 1080))
check(name == "Desk" and scale > 1.1, "A big screen isn't the desk layout, scaled up")
check(MainMenu.layout(Vector2.new(1024, 600), true) == "Phone", "A small tablet isn't the phone layout")

local screen = Instance.new("ScreenGui")
local parent = Instance.new("Frame")
parent.Parent = screen
local played = 0
local menu = MainMenu.build(parent, { OnPlay = function() played += 1 end })
local root = menu.Root
check(root and root.Name == "MainMenu", "No menu")
-- A title screen, no boxes: the night across it, the banner's art big on
-- the right (melting into it), the logo, PLAY and the list on the left.
local left, right = find(root, "Menu"), find(root, "Slides")
check(left and right and find(root, "Sky") ~= nil, "No night sky behind the menu")
local artFrame = find(right, "Art")
check(artFrame and artFrame.Size.X.Offset >= 900 and artFrame.Position.X.Offset > find(left, "Play").Position.X.Offset, "The banner's art isn't big on the right")
check(find(artFrame, "Picture"):FindFirstChildOfClass("UIGradient") ~= nil and find(artFrame, "Fade") ~= nil, "The art doesn't melt into the night")
do
	-- (cut out by share, whatever size Roblox keeps the art at: the words fill the frame)
	local frame = find(left, "Logo")
	local art = frame:FindFirstChild("Art")
	check(frame.ClipsDescendants and art and art.Image:find(tostring(MainMenu.LogoId), 1, true), "The logo isn't cut out of the title art")
	local rect = MainMenu.LogoRect
	local left_ = -art.Position.X.Offset / art.Size.X.Offset * MainMenu.LogoArt
	local top = -art.Position.Y.Offset / art.Size.Y.Offset * MainMenu.LogoArt
	check(math.abs(left_ - rect[1]) < 5 and math.abs(top - rect[2]) < 5, "The logo frame isn't on the art's words") -- (whole pixels on screen)
	check(math.abs(frame.Size.X.Offset / art.Size.X.Offset * MainMenu.LogoArt - rect[3]) < 8, "The logo frame isn't the words' width")
end
check(find(left, "PlayLip") ~= nil, "PLAY isn't the big plate") -- (station blue now, no shine: the Nov 4 restyle)
check(find(root, "Panel") == nil, "Still boxed panels")
for _, id in { "Play", "Guide", "Updates", "Feedback", "Credits", "Settings", "Logo", "News" } do
	check(find(left, id) ~= nil, "No " .. id .. " on the left")
end
check(find(left, "Version").Text == "v1.10", "No version along the bottom")

-- The first banner: the kaiju codes, a button for each code.
local slide = find(right, "Slide")
check(find(slide, "Title").Text == "3 LEGENDARY KAIJU CODES", "Not the first banner first")
check(not find(slide, "Action").Visible, "One button for a banner of three codes")
for i, code in { "TRISKULL", "BRIGHTSTEEL", "STEAMHIDE" } do
	local chip = find(slide, "Code" .. i)
	check(chip.Visible and chip.Text == code, "No button for code " .. code)
	check(chip.Size.X.Offset >= #code * 10, "Code " .. code .. "'s button squashed")
end
check(not fs.readFile(ROOT .. "/src/client/Modules/MainMenu.luau"):find("AutomaticSize = Enum.AutomaticSize.X", 1, true), "A button still sized by AutomaticSize")
-- (its uploaded picture, no stand-in)
check(find(slide, "Picture").Image == "rbxassetid://" .. Content.Images.KaijuCodes and not find(slide, "Fallback").Visible, "The banner's picture isn't shown")
-- (cropped above the code names baked into its bottom: the buttons say them)
check(find(slide, "Picture").ImageRectSize.Y == Content.Crops.KaijuCodes[4] and Content.Crops.KaijuCodes[4] < 500, "The codes banner's picture shows its baked-in code names")
for _, b in Content.Banners do
	check((Content.Images[b.Id] or 0) ~= 0, "No picture uploaded for " .. b.Id)
end
replies.RedeemCode = function(code)
	return { Ok = true, Message = "Code " .. code .. ": Legendary Triskull (#7 of 100)" }
end
fire(find(slide, "Code1"), "Activated")
local last = requests[#requests]
check(last[1] == "RedeemCode" and last[2] == "TRISKULL", "A code's button didn't redeem it")
check(find(slide, "Line").Text:find("Legendary Triskull", 1, true), "The answer isn't shown where the words were")
replies.RedeemCode = { Ok = false, Message = "Sold out! All 100 are gone." }
fire(find(slide, "Code2"), "Activated")
check(find(slide, "Line").Text == "Sold out! All 100 are gone.", "A refusal isn't shown")

-- Held after a touch, then on by themselves.
step(MainMenu.SlideSeconds + 1)
check(menu.current() == 1, "It moved on right after a touch")
-- (the hold ends HoldAfterTouch after the touch, then half a slide's wait)
step(MainMenu.HoldAfterTouch + MainMenu.SlideSeconds * 0.5 + 1 - now)
check(menu.current() == 2, "It never moved on by itself")
step(MainMenu.SlideSeconds)
check(menu.current() == 3, "It moved on once, then stopped")
menu.show(2)
check(texts(find(slide, "Tag")) == "DEV BOOTH", "The DEV banner says online with no dev in")
deskOnline = true
menu.show(2)
check(texts(find(slide, "Tag")) == "● DEV ONLINE", "The DEV banner doesn't say the dev's in")
-- Arrows and dots.
fire(find(slide, "Next"), "Activated")
check(menu.current() == 3, "› didn't go on")
fire(find(slide, "Back"), "Activated")
fire(find(slide, "Back"), "Activated")
check(menu.current() == 1, "‹ didn't go back")
fire(find(slide, "Back"), "Activated")
check(menu.current() == #menu.banners, "‹ from the first isn't the last")
fire(find(slide, "Dot3"), "Activated")
check(menu.current() == 3 and find(slide, "Title").Text == "THE LATEST UPDATES", "A dot didn't show its banner")
local lit = 0
for i = 1, 8 do
	local dot = find(slide, "Dot" .. i)
	if dot.Visible then
		lit += 1
	end
end
check(lit == #menu.banners, "Not a dot a banner")

-- A page from a banner, and BACK.
fire(find(slide, "Action"), "Activated")
local page = find(right, "Page")
check(page.Visible and not slide.Visible, "SEE ALL UPDATES didn't open the page")
check(texts(page):find("1.10", 1, true) and texts(page):find("UPDATES", 1, true), "The page isn't the updates")
step(30)
check(menu.current() == 3, "The banners went on behind a page")
fire(find(page, "Close"), "Activated")
check(slide.Visible and not page.Visible, "BACK didn't go back to the banners")

-- The four.
fire(find(left, "Guide"), "Activated")
check(texts(page):find("CONTROLS", 1, true) and texts(page):find("Space: dodge", 1, true), "GUIDE has no controls")
fire(find(left, "Credits"), "Activated")
check(texts(page):find("CREDITS", 1, true) and texts(page):find("Devvolver / Cpthunchies", 1, true) and texts(page):find("come say hi", 1, true), "No CREDITS")
fire(find(left, "Feedback"), "Activated")
local words = find(page, "Words")
check(words and words:IsA("TextBox"), "FEEDBACK has nowhere to write")
fire(find(page, "Idea"), "Activated")
words.Text = "More bosses please"
replies.SendFeedback = { Ok = true }
fire(find(page, "Send"), "Activated")
last = requests[#requests]
check(last[1] == "SendFeedback" and last[2] == "Idea" and last[3] == "More bosses please", "FEEDBACK didn't send an idea with its words")
check(find(page, "Status").Text:find("Thanks", 1, true) and words.Text == "", "No thanks after sending")
replies.SendFeedback = { Ok = false, Message = "Write a little more." }
fire(find(page, "Send"), "Activated")
check(find(page, "Status").Text == "Write a little more.", "A refusal isn't shown")
fire(find(left, "Settings"), "Activated")
check(after[#after] == "Settings", "SETTINGS didn't open the settings")

-- In: PLAY, Enter, and a banner that goes in and then opens its thing.
fire(find(left, "Play"), "Activated")
check(played == 1, "PLAY didn't go in")
inputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.Return }, false)
check(played == 2, "Enter didn't go in")
menu.page(nil)
check(#menu.banners == 4, "Not the four banners: " .. #menu.banners)
menu.show(4)
check(find(slide, "Title").Text == "FREE THUNDERCLAP PICKAXE", "Not the pickaxe banner")
-- (each button as wide as its words: never squashed to nothing)
local redeemButton = find(slide, "Action")
check(redeemButton.Visible and redeemButton.Size.X.Offset >= 120 and redeemButton.AutomaticSize == roblox.Enum.AutomaticSize.None, "REDEEM THUNDER's button isn't sized to its words: " .. redeemButton.Size.X.Offset)
check(find(slide, "Tag").Size.X.Offset >= 50, "The tag isn't sized to its words")
replies.RedeemCode = { Ok = true, Message = "Code THUNDER: Thunderclap (#3 of 100)" }
fire(redeemButton, "Activated")
last = requests[#requests]
check(last[1] == "RedeemCode" and last[2] == "THUNDER" and played == 2, "REDEEM THUNDER didn't redeem it there and then")
-- GO TO THE BOOTH: in, then the arrows to the DEV desk.
table.clear(after)
menu.show(2)
fire(find(slide, "Action"), "Activated")
check(played == 3 and after[1] == "Guide:MenuBooth", "GO TO THE BOOTH didn't go in and lead to the booth")
-- (still in the intro: in, nothing over it)
GemClient.Profile = { Intro = { Done = false } }
table.clear(after)
fire(find(slide, "Action"), "Activated")
check(played == 4 and #after == 0, "The booth's arrows came up in the middle of the intro")

-- A phone: drawn again in its own layout.
SCREEN = Vector2.new(844, 390)
fire(parent, "Changed:AbsoluteSize")
root = menu.Root
check(root.Size.X.Offset == 844 and root.Size.Y.Offset == 390, "Not redrawn for a phone")
local phoneSlide = find(root, "Slide")
check(phoneSlide and find(phoneSlide, "Title").Text ~= "", "The phone's banners are empty")
check(#root:GetChildren() > 0 and #(function()
	local n = {}
	for _, c in root:GetChildren() do
		if c:IsA("UIScale") then
			table.insert(n, c)
		end
	end
	return n
end)() == 1, "Two UIScales after a redraw")

-- Gone: its listeners with it.
local before = inputBegan.Count()
menu.destroy()
local gone = not pcall(function()
	return root.Parent
end) or root.Parent == nil
check(inputBegan.Count() == before - 1 and gone, "The menu left a listener or itself behind")

-- The title screen: the menu in place of CLICK TO ENTER, PLAY goes in, a
-- new miner never sees it.
do
	local splash = fs.readFile(ROOT .. "/src/client/Splash.client.luau")
	check(splash:find('require(script.Parent.Modules.MainMenu).build(back', 1, true) ~= nil, "The title screen has no menu")
	check(splash:find('"CLICK TO ENTER"', 1, true) == nil, "Still CLICK TO ENTER")
	check(splash:find("showTitle(true, true)", 1, true) ~= nil and splash:find("if quick then\n\t\treturn\n\tend", 1, true) ~= nil, "A new miner sees the menu")
	check(splash:find("menu.destroy()", 1, true) ~= nil, "The menu isn't put away on the way in")
	check(splash:find("local MENU_AT = DROP + 0.8", 1, true) ~= nil, "The menu still waits out the whole intro")
end

print(string.format("PASS: %d main menu checks (the banners, their buttons and pages, FEEDBACK, PLAY, a phone, the title screen)", checks))
process.exit(0)
