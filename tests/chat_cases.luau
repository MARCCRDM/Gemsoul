-- Chat: the shared rules (Shared.ChatRules: commands, names, rolls) and the
-- real server ChatChannels with stand-ins for TextChatService, players and the
-- request plumbing. Run by tests/run_chat.py (needs lune).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local function loadModule(path, env)
	local source = fs.readFile(ROOT .. "/" .. path)
	return luau.load(source, { debugName = path, environment = setmetatable(env or {}, { __index = _G }) })()
end

-- Color3 for the shared module outside Roblox.
local Color3 = { fromRGB = function(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end }
local Rules = loadModule("src/shared/ChatRules.luau", { Color3 = Color3 })

-- Typed lines ---------------------------------------------------------------------------
local function parse(line, speaking)
	return Rules.parse(line, speaking)
end
check(parse("   ") == nil, "An empty line did something")
local plain = parse("hello miners", "Trade")
check(plain.Kind == "Send" and plain.Channel == "Trade" and plain.Text == "hello miners", "Plain text didn't go to the current channel")
check(parse("/2 WTS [Eclipse Sunderblade]").Channel == "Trade", "/2 isn't Trade")
check(parse("/1 hi").Channel == "General" and parse("/s hi").Channel == "General", "/1 and /s aren't General")
check(parse("/3 LF raid").Channel == "LFG" and parse("/lfg LF raid").Channel == "LFG", "/3 and /lfg aren't LFG")
check(parse("/p ready?").Channel == "Party", "/p isn't Party")
local switch = parse("/2")
check(switch.Kind == "Switch" and switch.Channel == "Trade", "A bare /2 didn't switch to Trade")
local w = parse("/w Kade nice cleaver")
check(w.Kind == "Whisper" and w.Target == "Kade" and w.Text == "nice cleaver", "Whisper didn't parse")
check(parse("/w Kade").Kind == "Whisper" and parse("/w Kade").Text == "", "A bare /w name should open a whisper")
check(parse("/w").Kind == "Error", "/w with nobody should explain itself")
local r = parse("/r thanks!")
check(r.Kind == "Reply" and r.Text == "thanks!", "Reply didn't parse")
check(parse("/roll").Max == 100 and parse("/roll 20").Max == 20, "Roll ranges wrong")
check(parse("/roll 1").Max == 2 and parse("/roll 99999999").Max == Rules.RollMax and parse("/roll abc").Max == 100, "Roll range not clamped")
check(parse("/invite Mira").Kind == "Invite" and parse("/invite Mira").Target == "Mira", "Invite didn't parse")
check(parse("/duel Orrin").Kind == "Duel", "Duel didn't parse")
check(parse("/trade Vex").Kind == "Trade" and parse("/trade Vex").Target == "Vex", "/trade name should open the Market")
check(parse("/trade").Kind == "Trade" and parse("/trade").Target == nil, "Bare /trade should open the Market")
check(parse("/help").Kind == "Help" and parse("/who").Kind == "Who" and parse("/clear").Kind == "Clear", "Help/who/clear")
check(parse("/dance").Kind == "Error", "Unknown commands should say so")
check(parse("/W Kade hi").Kind == "Whisper", "Commands should ignore case")
check(#parse(string.rep("a", 400)).Text == Rules.MaxLength, "Long messages weren't cut to the limit")

-- Names -----------------------------------------------------------------------------------
local players = {
	{ Name = "KadeTheMiner", DisplayName = "Kade" },
	{ Name = "mira_99", DisplayName = "Mira" },
	{ Name = "MiraBelle", DisplayName = "Belle" },
	{ Name = "orrin", DisplayName = "Orrin" },
}
check(Rules.findPlayer("kade", players) == players[1], "Exact display name not found")
check(Rules.findPlayer("kadethe", players) == players[1], "Username prefix not found")
check(Rules.findPlayer("mira", players) == players[2], "An exact match should beat prefixes")
check(Rules.findPlayer("mir", players) == nil, "An ambiguous prefix picked someone")
check(Rules.findPlayer("or", players) == players[4], "A unique prefix wasn't found")
local nobody, why = Rules.findPlayer("zed", players)
check(nobody == nil and string.find(why, "zed") ~= nil, "Missing players should be named in the reason")
check(Rules.whisperName(9, 4) == "Whisper_4_9" and Rules.whisperName(4, 9) == "Whisper_4_9", "Whisper channel differs by who starts it")

-- Tabs ------------------------------------------------------------------------------------
local tabs = {}
for _, tab in Rules.Tabs do
	tabs[tab.Id] = tab
	check(Rules.TabSpeaks[tab.Id] ~= nil, "Tab " .. tab.Id .. " has nothing to type into")
	for channel in tab.Shows do
		check(Rules.Channels[channel] ~= nil, "Tab " .. tab.Id .. " shows a missing channel")
	end
end
check(tabs.All.Shows.General and tabs.All.Shows.Whisper and not tabs.All.Shows.Trade, "ALL should hold everything but Trade")
check(tabs.Trade.Shows.Trade and tabs.Whisper.Shows.Whisper and tabs.Loot.Shows.Loot, "Channel tabs miss their channel")

-- The server --------------------------------------------------------------------------------
local clock = 0
local handlers = {}
local fired = {}
local channels = {}
local function signal()
	local fns = {}
	return {
		Connect = function(_, fn)
			table.insert(fns, fn)
		end,
		Fire = function(_, ...)
			for _, fn in fns do
				fn(...)
			end
		end,
	}
end
local function fakePlayer(id, name)
	return { UserId = id, Name = name, DisplayName = name }
end
local ana, bo, cy = fakePlayer(1, "Ana"), fakePlayer(2, "Bo"), fakePlayer(3, "Cy")
local online = { ana, bo }
local Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return online
	end,
	GetPlayerByUserId = function(_, id)
		for _, p in online do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
}
local TextChatService = {}
local function newChannel()
	local c = { Users = {}, Parent = nil }
	function c:AddUserAsync(id)
		table.insert(self.Users, id)
		return {}
	end
	function c:Destroy()
		self.Parent = nil
		self.Destroyed = true
	end
	return setmetatable(c, {
		__newindex = function(t, k, v)
			rawset(t, k, v)
			if k == "Parent" and v == TextChatService then
				channels[t.Name] = t
			end
		end,
	})
end
local Shop = {
	register = function(name, fn)
		handlers[name] = fn
	end,
	reply = function(ok, message, extra)
		local result = { Ok = ok, Message = message }
		for k, v in extra or {} do
			result[k] = v
		end
		return result
	end,
}
local Remotes = { Social = { FireAllClients = function(_, ...)
	table.insert(fired, { ... })
end } }
local stubs = { ChatRules = Rules, Remotes = Remotes, Shop = Shop }
local services = { Players = Players, TextChatService = TextChatService, ReplicatedStorage = { Shared = { ChatRules = { __name = "ChatRules" } } } }
local Chat = loadModule("src/server/Systems/ChatChannels.luau", {
	game = { GetService = function(_, name)
		return services[name]
	end },
	script = { Parent = setmetatable({}, { __index = function(_, k)
		return { __name = k }
	end }) },
	require = function(m)
		return stubs[m.__name]
	end,
	Instance = { new = function(class)
		assert(class == "TextChannel", "Made a " .. class)
		local c = newChannel()
		rawset(c, "Name", "?")
		return setmetatable({}, {
			__index = c,
			__newindex = function(_, k, v)
				if k == "Name" then
					rawset(c, "Name", v)
				else
					c[k] = v
				end
			end,
		})
	end },
	task = { spawn = function(fn, ...)
		fn(...)
	end },
	os = { clock = function()
		return clock
	end },
	math = setmetatable({ random = function(a, b)
		return b
	end }, { __index = math }),
	typeof = function(v)
		return type(v)
	end,
})
Chat.start()
check(channels.GemsoulTrade and channels.GemsoulLFG, "Trade and LFG channels weren't made")
check(table.find(channels.GemsoulTrade.Users, 1) and table.find(channels.GemsoulLFG.Users, 2), "Players already here weren't added")
table.insert(online, cy)
Players.PlayerAdded:Fire(cy)
check(table.find(channels.GemsoulTrade.Users, 3) ~= nil, "A joining player wasn't added to Trade")

check(not handlers.ChatWhisper(ana, ana.UserId).Ok, "Whispered yourself")
check(not handlers.ChatWhisper(ana, 99).Ok, "Whispered someone who isn't here")
check(not handlers.ChatWhisper(ana, "2").Ok, "A non-number target was accepted")
local opened = handlers.ChatWhisper(ana, bo.UserId)
check(opened.Ok and opened.Channel == "Whisper_1_2" and opened.Name == "Bo", "Whisper channel wasn't opened")
local channel = channels.Whisper_1_2
check(channel and table.find(channel.Users, 1) and table.find(channel.Users, 2) and #channel.Users == 2, "Whisper channel has the wrong people")
clock += 1
check(handlers.ChatWhisper(bo, ana.UserId).Channel == "Whisper_1_2", "The pair got a second channel")
check(not handlers.ChatWhisper(bo, ana.UserId).Ok, "Whisper channels weren't rate limited")

handlers.ChatRoll(ana, 20)
check(#fired == 1 and fired[1][1] == "Chat" and fired[1][2] == "System" and fired[1][3] == "Ana rolls 20 (1-20)", "Roll wasn't announced")
handlers.ChatRoll(ana, 20)
check(#fired == 1, "Rolls weren't rate limited")
clock += 5
handlers.ChatRoll(ana, "lots")
check(#fired == 2 and string.find(fired[2][3], "%(1%-100%)") ~= nil, "A bad roll range didn't fall back to 100")
Chat.announce("Loot", "Bo unearthed [Legendary Thermal Shard]!")
check(fired[3][2] == "Loot", "Loot announcement went to the wrong channel")

Players.PlayerRemoving:Fire(bo)
check(channel.Destroyed, "A whisper channel outlived its player")

print("PASS: " .. checks .. " chat checks (slash commands, channels, names, tabs, whispers, rolls, announcements, cleanup)")
