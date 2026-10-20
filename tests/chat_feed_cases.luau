-- ChatFeed, the windowless chat at the bottom left: lines stack up and fade,
-- / opens a line to type in and Enter sends to the server's General channel;
-- it shows only on a computer in the Outpost (Roblox's own chat everywhere
-- else) and stays off while the MMO chat box (Config.Features.ChatBox) is
-- on. Stand-ins for TextChatService, the player and the screen; no Roblox
-- rendering is claimed. Run by tests/run_chat_feed.py (needs lune).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

-- Values ------------------------------------------------------------------------------------------------
local Color3 = {
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
local Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
Vector2.zero = Vector2.new(0, 0)
local UDim = {
	new = function(s, o)
		return { Scale = s, Offset = o }
	end,
}
local UDim2 = {
	new = function(xs, xo, ys, yo)
		return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }
	end,
}
UDim2.fromScale = function(x, y)
	return UDim2.new(x, 0, y, 0)
end
UDim2.fromOffset = function(x, y)
	return UDim2.new(0, x, 0, y)
end
local Enum = setmetatable({}, {
	__index = function(self, key)
		local t = setmetatable({}, { __index = function(_, name)
			return key .. "." .. name
		end })
		rawset(self, key, t)
		return t
	end,
})
local function hex(color)
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end

local function signal()
	local listeners = {}
	local event = {}
	function event:Connect(fn)
		local c = { Connected = true }
		function c:Disconnect()
			c.Connected = false
		end
		table.insert(listeners, { fn, c })
		return c
	end
	function event:Fire(...)
		for _, l in table.clone(listeners) do
			if l[2].Connected then
				l[1](...)
			end
		end
	end
	return event
end

-- A world: a fresh screen, player and chat service for one load of the module.
local function boot(options)
	options = options or {}
	local now = 0
	local sleeping, deferred = {}, {}
	local fakeTask = {
		spawn = function(fn, ...)
			local thread = coroutine.create(fn)
			assert(coroutine.resume(thread, ...))
			return thread
		end,
		defer = function(fn, ...)
			table.insert(deferred, { fn, { ... } })
		end,
		wait = function(seconds)
			table.insert(sleeping, { coroutine.running(), now + (seconds or 0) })
			coroutine.yield()
		end,
	}
	local fakeOs = setmetatable({ clock = function()
		return now
	end }, { __index = os })

	local methods = {}
	local function new(class, props, parent)
		local values = {
			ClassName = class,
			Children = {},
			Attributes = {},
			Signals = {},
			Visible = true,
			Enabled = true,
			FocusLost = signal(),
			Activated = signal(),
		}
		local object
		object = setmetatable({}, {
			__index = function(_, key)
				return methods[key] or values[key]
			end,
			__newindex = function(_, key, value)
				if key == "Parent" and value then
					table.insert(value.Children, object)
				end
				values[key] = value
				local s = values.Signals[key]
				if s then
					s:Fire()
				end
			end,
		})
		for key, value in props or {} do
			object[key] = value
		end
		if parent then
			object.Parent = parent
		end
		return object
	end
	function methods:GetChildren()
		local out = {}
		for _, child in self.Children do
			if child.Parent == self and not child.Destroyed then
				table.insert(out, child)
			end
		end
		return out
	end
	function methods:FindFirstChild(name)
		for _, child in self:GetChildren() do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods:FindFirstChildOfClass(class)
		for _, child in self:GetChildren() do
			if child.ClassName == class then
				return child
			end
		end
		return nil
	end
	function methods:IsA(class)
		return self.ClassName == class
	end
	function methods:Destroy()
		self.Destroyed = true
		self.Parent = nil
	end
	function methods:GetAttribute(name)
		return self.Attributes[name]
	end
	function methods:SetAttribute(name, value)
		self.Attributes[name] = value
	end
	function methods:GetPropertyChangedSignal(key)
		self.Signals[key] = self.Signals[key] or signal()
		return self.Signals[key]
	end
	function methods:CaptureFocus()
		self.Focused = true
	end
	function methods:ReleaseFocus()
		self.Focused = false
	end

	local player = new("Player", { Name = "KadeTheMiner", DisplayName = "Kade", UserId = 7 })
	local playerGui = new("PlayerGui", { Name = "PlayerGui" }, player)
	player:SetAttribute("Outpost", true)
	local others = { [9] = new("Player", { Name = "mira_99", DisplayName = "Mira", UserId = 9 }) }
	local Players = {
		LocalPlayer = player,
		GetPlayerByUserId = function(_, id)
			return if id == 7 then player else others[id]
		end,
	}

	local sent = {}
	local channels = new("Folder", { Name = "TextChannels" })
	local general = new("TextChannel", { Name = "RBXGeneral" }, channels)
	general.SendAsync = function(_, text)
		if options.sendFails then
			error("throttled")
		end
		table.insert(sent, text)
	end
	local TextChatService = new("TextChatService", {
		MessageReceived = signal(),
		ChatWindowConfiguration = { Enabled = true },
		ChatInputBarConfiguration = { Enabled = true },
		BubbleChatConfiguration = { Enabled = false },
	})
	if not options.noChannels then
		channels.Parent = TextChatService
	end
	local UserInputService = {
		TouchEnabled = options.phone == true,
		KeyboardEnabled = options.phone ~= true,
		InputBegan = signal(),
	}
	local services = {
		Players = Players,
		ReplicatedStorage = { Shared = { Config = "Config", Lang = "Lang" } },
		TextChatService = TextChatService,
		UserInputService = UserInputService,
	}
	local short = false
	local screen = { X = 1366, Y = 710 }
	local UiKit = {
		gui = function(name, order)
			return new("ScreenGui", { Name = name, DisplayOrder = order, AbsoluteSize = screen }, playerGui)
		end,
		round = function() end,
		short = function()
			return short
		end,
	}
	local IronUi = { new = new, Bold = "GothamBold" }
	local spanish = { ["Chat isn't ready yet."] = "El chat aún no está listo." }
	local Lang = {
		translate = function(text)
			return spanish[text] or text
		end,
	}
	local Config = { Features = { ChatBox = options.chatBox == true } }
	local MobileLayout = luau.load(fs.readFile(ROOT .. "/src/client/Modules/MobileLayout.luau"), {
		debugName = "MobileLayout",
		environment = setmetatable({ Vector2 = Vector2, UDim2 = UDim2 }, { __index = _G }),
	})()
	local modules = {
		Config = Config,
		Lang = Lang,
		IronUi = IronUi,
		MobileLayout = MobileLayout,
		UiKit = UiKit,
	}
	local script = { Parent = { IronUi = "IronUi", MobileLayout = "MobileLayout", UiKit = "UiKit" } }
	local env = setmetatable({
		game = {
			GetService = function(_, name)
				return assert(services[name], "No service " .. name)
			end,
		},
		script = script,
		require = function(id)
			return assert(modules[id], "No module " .. tostring(id))
		end,
		task = fakeTask,
		os = fakeOs,
		Color3 = Color3,
		Vector2 = Vector2,
		UDim = UDim,
		UDim2 = UDim2,
		Enum = Enum,
	}, { __index = _G })
	local ChatFeed = luau.load(fs.readFile(ROOT .. "/src/client/Modules/ChatFeed.luau"), {
		debugName = "ChatFeed",
		environment = env,
	})()

	local world = { ChatFeed = ChatFeed, player = player, playerGui = playerGui, chat = TextChatService, sent = sent, new = new }
	function world.step(seconds)
		local target = now + seconds
		repeat
			now = math.min(target, now + 0.05)
			for _, job in table.clone(deferred) do
				table.remove(deferred, table.find(deferred, job))
				job[1](table.unpack(job[2]))
			end
			for _, sleeper in table.clone(sleeping) do
				if sleeper[2] <= now then
					table.remove(sleeping, table.find(sleeping, sleeper))
					assert(coroutine.resume(sleeper[1]))
				end
			end
		until now >= target
	end
	function world.gui()
		return playerGui:FindFirstChild("ChatFeed")
	end
	function world.holder()
		return world.gui():FindFirstChild("Feed")
	end
	function world.part(name)
		return world.holder():FindFirstChild(name)
	end
	function world.lines()
		local out = {}
		for _, label in world.part("Lines"):GetChildren() do
			if label.ClassName == "TextLabel" then
				table.insert(out, label)
			end
		end
		table.sort(out, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		return out
	end
	function world.shown()
		local out = {}
		for _, label in world.lines() do
			if label.Visible then
				table.insert(out, label)
			end
		end
		return out
	end
	function world.say(userId, name, text, channel)
		TextChatService.MessageReceived:Fire({
			Text = text,
			TextChannel = { Name = channel or "RBXGeneral" },
			TextSource = if userId then { UserId = userId, Name = name } else nil,
		})
	end
	function world.key(code, processed)
		UserInputService.InputBegan:Fire({ KeyCode = code }, processed == true)
	end
	function world.resize(x, y, isShort)
		screen.X, screen.Y = x, y
		short = isShort == true
		world.gui().AbsoluteSize = { X = x, Y = y }
	end
	return world
end

-- A computer in the Outpost: up, Roblox's window and bar off, bubbles on ----------------------------------
local w = boot()
w.step(0.3)
local gui = w.gui()
check(gui ~= nil and gui.Enabled, "The feed isn't up in the Outpost")
check(w.ChatFeed.Enabled and w.ChatFeed.Shown(), "Enabled/Shown wrong")
check(not w.chat.ChatWindowConfiguration.Enabled and not w.chat.ChatInputBarConfiguration.Enabled, "Roblox's chat window still up under the feed")
check(w.chat.BubbleChatConfiguration.Enabled, "Bubbles over heads are off")
check(gui.IgnoreGuiInset == false, "The feed ignores the top bar inset")
-- Windowless: no background anywhere but the line you type in.
check(w.holder().BackgroundTransparency == 1 and w.part("Lines").BackgroundTransparency == 1, "The feed has a window")
check(w.part("Lines"):GetAttribute("NoTranslate") == true, "Players' words would be translated")
-- Bottom left, above the kaiju card and its CATCH button, under the PLAY stack.
local holder = w.holder()
check(holder.AnchorPoint.X == 0 and holder.AnchorPoint.Y == 1, "Not anchored at its bottom left")
check(holder.Position.X.Offset == 24 and holder.Position.Y.Scale == 1 and holder.Position.Y.Offset == -(24 + 62 + 8 + 62 + 12), "Not above the kaiju card")
check(holder.Size.Y.Offset == 710 - 168 - 340, "Height doesn't fit between the kaiju card and the PLAY stack: " .. holder.Size.Y.Offset)
w.resize(1920, 1080)
check(holder.Size.Y.Offset == 230, "A tall screen didn't cap the height")
w.resize(1024, 560)
check(holder.Size.Y.Offset == 70, "A low screen squeezed it under 70")
w.resize(1366, 710)
check(w.part("Hint").Visible and w.part("Hint").Text == "Press / to chat", "No / hint")
check(not w.part("Input").Visible, "The typing line shows before you press /")

-- Lines: the server's General chat, names coloured, your own green -----------------------------------------
w.say(9, "mira_99", "anyone selling <b>frost</b> gems?")
w.say(7, "KadeTheMiner", "me")
local lines = w.lines()
check(#lines == 2, "Two lines expected, got " .. #lines)
check(string.find(lines[1].Text, "Mira:", 1, true) ~= nil, "The speaker's display name is missing: " .. lines[1].Text)
check(string.find(lines[1].Text, "&lt;b&gt;frost&lt;/b&gt;", 1, true) ~= nil, "Players' markup wasn't escaped: " .. lines[1].Text)
check(string.find(lines[1].Text, hex(w.ChatFeed.nameColor("Mira")), 1, true) ~= nil, "Name colour missing")
check(w.ChatFeed.nameColor("Mira") == w.ChatFeed.nameColor("Mira"), "Name colours aren't stable")
check(string.find(lines[2].Text, hex(Color3.fromRGB(155, 231, 183)), 1, true) ~= nil, "Your own name isn't green")
check(lines[1].RichText and lines[1].TextWrapped and lines[1].BackgroundTransparency == 1, "A line isn't bare wrapped rich text")
-- Other channels stay out; Roblox's system lines come plain and grey.
w.say(9, "mira_99", "WTS cleaver", "Trade")
check(#w.lines() == 2, "A Trade line came into the feed")
w.say(nil, nil, '<font color="#ff0000">Mira joined the server.</font>', "RBXSystem")
lines = w.lines()
check(#lines == 3 and string.find(lines[3].Text, "<i>Mira joined the server.</i>", 1, true) ~= nil, "A system line wasn't plain: " .. lines[3].Text)
w.ChatFeed.loot("Kade found a Mythic Ion gem!")
lines = w.lines()
check(string.find(lines[4].Text, hex(Color3.fromRGB(255, 205, 90)), 1, true) ~= nil, "A loot line isn't gold")

-- Fading: a while in full, then gone; ten at most on screen, sixty kept --------------------------------------
w.step(10)
check(#w.shown() == 4 and w.shown()[1].TextTransparency == 0, "Lines faded too soon")
w.step(12.6)
local fading = w.lines()[1].TextTransparency
check(fading > 0 and fading < 1, "No fade: " .. fading)
w.step(1)
check(#w.shown() == 0, "Old lines stayed on screen")
for i = 1, 70 do
	w.say(9, "mira_99", "line " .. i)
end
w.step(0.3)
check(#w.lines() == 60, "Not sixty lines kept: " .. #w.lines())
check(#w.shown() == 10 and string.find(w.shown()[10].Text, "line 70", 1, true) ~= nil, "Not the ten newest on screen")

-- Typing: / opens the line and brings the recent lines back; Enter sends ---------------------------------------
w.step(30)
check(#w.shown() == 0, "Lines didn't fade before typing")
w.key(Enum.KeyCode.Slash, true)
w.step(0.1)
check(not w.part("Input").Visible, "A / typed into something else opened the feed")
w.key(Enum.KeyCode.Slash)
check(not w.part("Input").Visible, "Opened in the same frame (the / would be typed in)")
w.step(0.1)
local input = w.part("Input")
check(input.Visible and input.Focused and not w.part("Hint").Visible, "/ didn't open the typing line")
check(#w.shown() == 10 and w.shown()[1].TextTransparency == 0, "The recent lines didn't come back while typing")
input.Text = "   wts frost gems  "
input.FocusLost:Fire(true)
check(#w.sent == 1 and w.sent[1] == "wts frost gems", "Enter didn't send the trimmed line to General")
check(not input.Visible and w.part("Hint").Visible and input.Text == "", "The typing line stayed up after sending")
w.step(3)
check(#w.shown() == 10, "Lines you just saw vanished straight away")
w.step(2.5)
check(#w.shown() == 0, "Lines you just saw never faded again")
-- Escape (focus lost without Enter) and empty lines send nothing.
w.part("Hint").Activated:Fire()
check(input.Visible, "Clicking the hint didn't open the line")
input.Text = "never mind"
input.FocusLost:Fire(false)
w.part("Hint").Activated:Fire()
input.Text = "    "
input.FocusLost:Fire(true)
check(#w.sent == 1, "Escape or an empty line sent something")

-- Where it shows: out of the Outpost, under a menu, in the intro, on a short screen --------------------------
w.part("Hint").Activated:Fire()
w.player:SetAttribute("Outpost", false)
w.step(0.3)
check(not gui.Enabled, "The feed stayed up out of the Outpost")
check(not input.Focused and not input.Visible, "The typing line stayed focused out of the Outpost")
check(w.chat.ChatWindowConfiguration.Enabled and w.chat.ChatInputBarConfiguration.Enabled, "No chat at all out of the Outpost")
w.key(Enum.KeyCode.Slash)
w.step(0.1)
check(not input.Visible, "/ opened a hidden feed")
w.player:SetAttribute("Outpost", true)
-- A menu: the Dashboard screen enabled over the world.
local dashboard = w.new("ScreenGui", { Name = "Dashboard", Enabled = false }, w.playerGui)
local function openMenu(on)
	dashboard.Enabled = on
end
openMenu(true)
w.step(0.3)
check(not gui.Enabled, "The feed showed over a menu")
check(not w.chat.ChatWindowConfiguration.Enabled, "Roblox's chat window came up over a menu")
openMenu(false)
w.step(0.3)
check(gui.Enabled and not w.chat.ChatWindowConfiguration.Enabled, "The feed didn't come back after the menu")
w.resize(1100, 500, true)
check(holder.Position.X.Offset == 12 and holder.Position.Y.Offset == -12, "A short screen didn't take the corner")
check(holder.Size.Y.Offset == 200 and holder.Size.X.Offset >= 180 and holder.Size.X.Offset <= 420, "A short screen's size is off")
w.resize(1366, 710)
check(holder.Position.X.Offset == 24 and holder.Position.Y.Offset == -168, "The computer fit didn't come back")
-- The game's own words in the feed go through the translator.
local quiet = boot({ noChannels = true })
quiet.step(0.3)
quiet.part("Hint").Activated:Fire()
quiet.part("Input").Text = "hello?"
quiet.part("Input").FocusLost:Fire(true)
check(string.find(quiet.lines()[1].Text, "El chat aún no está listo.", 1, true) ~= nil, "No 'not ready' line (translated): " .. quiet.lines()[1].Text)
local failing = boot({ sendFails = true })
failing.step(0.3)
failing.part("Hint").Activated:Fire()
failing.part("Input").Text = "hello?"
failing.part("Input").FocusLost:Fire(true)
check(string.find(failing.lines()[1].Text, "Couldn't send that message.", 1, true) ~= nil, "A failed send said nothing")
-- In the intro: Roblox's chat, no feed.
local intro = boot()
intro.new("ScreenGui", { Name = "Intro" }, intro.playerGui)
intro.step(0.3)
check(not intro.gui().Enabled and intro.chat.ChatWindowConfiguration.Enabled, "The feed showed in the intro")

-- Phones and the chat box: Roblox's chat on phones; nothing at all from the feed while the box is on -----------
local phone = boot({ phone = true })
phone.step(0.3)
check(not phone.gui().Enabled, "The feed showed on a phone")
check(phone.chat.ChatWindowConfiguration.Enabled and phone.chat.ChatInputBarConfiguration.Enabled, "A phone lost Roblox's chat")
local boxed = boot({ chatBox = true })
boxed.chat.ChatWindowConfiguration.Enabled = false -- (the chat box's call)
boxed.step(0.3)
check(not boxed.ChatFeed.Enabled and not boxed.gui().Enabled, "The feed showed with the chat box on")
check(boxed.chat.ChatWindowConfiguration.Enabled == false, "The feed touched Roblox's chat while the box is on")

print(string.format("PASS: %d chat feed checks (windowless lines, fades, / to type, sends, where it shows, phones, the chat box switch)", checks))
