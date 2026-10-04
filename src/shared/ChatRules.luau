-- Chat rules shared by the chat frame and the server: the channels, their
-- colours and numbers, and how a typed line (slash commands included) is read.
local ChatRules = {}

export type Channel = {
	Id: string,
	Label: string, -- shown in brackets before each line
	Number: string?, -- typed as /1, /2 ... to switch to it
	Color: Color3,
	Speak: boolean, -- players can type into it
}

-- Classic MMO colours: peach public channels, blue party, pink whispers,
-- orange LFG, green loot and yellow system lines.
ChatRules.Channels = {
	General = {
		Id = "General",
		Label = "1. General",
		Number = "1",
		Color = Color3.fromRGB(255, 196, 160),
		Speak = true,
	},
	Trade = { Id = "Trade", Label = "2. Trade", Number = "2", Color = Color3.fromRGB(255, 176, 120), Speak = true },
	LFG = { Id = "LFG", Label = "3. LFG", Number = "3", Color = Color3.fromRGB(255, 150, 64), Speak = true },
	Party = { Id = "Party", Label = "Party", Color = Color3.fromRGB(150, 170, 255), Speak = true },
	Whisper = { Id = "Whisper", Label = "Whisper", Color = Color3.fromRGB(255, 128, 255), Speak = true },
	Loot = { Id = "Loot", Label = "Loot", Color = Color3.fromRGB(64, 230, 96), Speak = false },
	System = { Id = "System", Label = "System", Color = Color3.fromRGB(255, 230, 80), Speak = false },
} :: { [string]: Channel }

-- The tabs along the top of the chat frame and what each one shows.
-- ALL is the classic main tab: everything except the noisy Trade channel.
ChatRules.Tabs = {
	{
		Id = "All",
		Label = "ALL",
		Shows = { General = true, LFG = true, Party = true, Whisper = true, Loot = true, System = true },
	},
	{ Id = "Trade", Label = "TRADE", Shows = { Trade = true } },
	{ Id = "Party", Label = "PARTY", Shows = { Party = true } },
	{ Id = "LFG", Label = "LFG", Shows = { LFG = true } },
	{ Id = "Whisper", Label = "WHISPERS", Shows = { Whisper = true } },
	{ Id = "Loot", Label = "LOOT", Shows = { Loot = true } },
}

-- The TextChannel names the server creates for the public custom channels.
ChatRules.TextChannels = { Trade = "GemsoulTrade", LFG = "GemsoulLFG" }

-- Which chat channel a tab types into by default.
ChatRules.TabSpeaks =
	{ All = "General", Trade = "Trade", Party = "Party", LFG = "LFG", Whisper = "Whisper", Loot = "General" }

-- One-tap Looking For Group posts.
ChatRules.LfgPosts = {
	{ "RAID", "LFG Party Raid: need 2 more, all levels welcome!" },
	{ "DUNGEON", "LF3 for a Dungeon run, meet at the dashboard." },
	{ "DUEL", "LF Duel: friendly 1v1 in the Arena, anyone?" },
	{ "MINE", "Mining at the Outpost, come break geodes with me!" },
}

ChatRules.MaxLength = 200
ChatRules.RollMax = 1000000

ChatRules.Help = {
	"/1 /s  General   ·   /2 /t  Trade   ·   /3 /lfg  Looking for group",
	"/p  Party   ·   /w name  Whisper   ·   /r  Reply to last whisper",
	"/roll [max]   ·   /invite name   ·   /duel name   ·   /trade name",
	"/who  Miners here   ·   /clear  Clear this tab",
}

-- The private channel for two players, the same whoever starts it.
function ChatRules.whisperName(a: number, b: number): string
	return "Whisper_" .. math.min(a, b) .. "_" .. math.max(a, b)
end

-- A roll's upper bound from what was typed ("/roll", "/roll 20").
function ChatRules.rollMax(arg: string?): number
	local n = tonumber(arg or "")
	if not n or n ~= n then
		return 100
	end
	return math.clamp(math.floor(n), 2, ChatRules.RollMax)
end

-- Finds a player by display name or username: an exact match first, then a
-- unique prefix. Returns nil and a reason when nobody (or several) match.
function ChatRules.findPlayer(name: string, players: { any }): (any?, string?)
	local wanted = string.lower(name or "")
	if wanted == "" then
		return nil, "Type a name."
	end
	local prefix = {}
	for _, p in players do
		local display, user = string.lower(p.DisplayName), string.lower(p.Name)
		if display == wanted or user == wanted then
			return p
		end
		if string.sub(display, 1, #wanted) == wanted or string.sub(user, 1, #wanted) == wanted then
			table.insert(prefix, p)
		end
	end
	if #prefix == 1 then
		return prefix[1]
	end
	if #prefix > 1 then
		return nil, 'Several miners match "' .. name .. '". Type more of the name.'
	end
	return nil, 'No miner called "' .. name .. '" is in this server.'
end

local SWITCH = {
	["1"] = "General",
	s = "General",
	say = "General",
	g = "General",
	general = "General",
	["2"] = "Trade",
	t = "Trade",
	-- (/trade name opens the Market instead of switching to Trade.)
	["3"] = "LFG",
	lfg = "LFG",
	p = "Party",
	party = "Party",
}

local function trim(value: string): string
	return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

-- Reads one typed line. `speaking` is the channel the input is set to.
-- Returns a command table:
--   { Kind = "Send", Channel, Text }      a message for a channel
--   { Kind = "Switch", Channel }          a bare "/2": type in Trade from now on
--   { Kind = "Whisper", Target, Text }    "/w name text" (Text may be empty)
--   { Kind = "Reply", Text }              "/r text"
--   { Kind = "Roll", Max }
--   { Kind = "Invite" | "Duel" | "Trade", Target }
--   { Kind = "Help" | "Who" | "Clear" }
--   { Kind = "Error", Message }
--   nil for an empty line
function ChatRules.parse(line: string, speaking: string?): { [string]: any }?
	line = trim(string.sub(line or "", 1, ChatRules.MaxLength + 40))
	if line == "" then
		return nil
	end
	if string.sub(line, 1, 1) ~= "/" then
		return { Kind = "Send", Channel = speaking or "General", Text = string.sub(line, 1, ChatRules.MaxLength) }
	end
	local command, rest = string.match(line, "^/(%S*)%s*(.*)$")
	command = string.lower(command or "")
	rest = rest or ""
	if command == "w" or command == "whisper" or command == "tell" or command == "msg" then
		local target, text = string.match(rest, "^(%S+)%s*(.*)$")
		if not target then
			return { Kind = "Error", Message = "Whisper who? Try /w name hello" }
		end
		return { Kind = "Whisper", Target = target, Text = string.sub(text, 1, ChatRules.MaxLength) }
	elseif command == "r" or command == "reply" then
		return { Kind = "Reply", Text = string.sub(rest, 1, ChatRules.MaxLength) }
	elseif command == "roll" or command == "random" then
		return { Kind = "Roll", Max = ChatRules.rollMax(string.match(rest, "^(%S+)")) }
	elseif command == "invite" or command == "inv" then
		return if rest ~= ""
			then { Kind = "Invite", Target = (string.match(rest, "^(%S+)")) }
			else { Kind = "Error", Message = "Invite who? Try /invite name" }
	elseif command == "duel" then
		return if rest ~= ""
			then { Kind = "Duel", Target = (string.match(rest, "^(%S+)")) }
			else { Kind = "Error", Message = "Duel who? Try /duel name" }
	elseif command == "trade" then
		return { Kind = "Trade", Target = string.match(rest, "^(%S+)") }
	elseif command == "help" or command == "?" then
		return { Kind = "Help" }
	elseif command == "who" then
		return { Kind = "Who" }
	elseif command == "clear" then
		return { Kind = "Clear" }
	end
	local channel = SWITCH[command]
	if channel then
		if rest == "" then
			return { Kind = "Switch", Channel = channel }
		end
		return { Kind = "Send", Channel = channel, Text = string.sub(rest, 1, ChatRules.MaxLength) }
	end
	return { Kind = "Error", Message = "Unknown command /" .. command .. ". Type /help for the list." }
end

return ChatRules
