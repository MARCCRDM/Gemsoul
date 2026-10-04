-- Server chat channels beyond Roblox's General: Trade and LFG (everyone is
-- added on join), private whisper channels for each pair of players, /roll,
-- and server-wide announcements (rare loot, rolls) for the chat frame.
-- Messages still go through TextChatService, so they're filtered by Roblox.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local ChatRules = require(ReplicatedStorage.Shared.ChatRules)
local Remotes = require(script.Parent.Remotes)
local Shop = require(script.Parent.Shop)

local ChatChannels = {}

local public: { [string]: TextChannel } = {}
local whispers: { [string]: { Channel: TextChannel, Users: { number } } } = {}
local lastWhisper: { [Player]: number } = {}
local lastRoll: { [Player]: number } = {}

local WHISPER_GAP = 0.5 -- seconds between opening whisper channels
local ROLL_GAP = 2

-- A line for every player's chat frame: kind is a ChatRules channel id.
function ChatChannels.announce(kind: string, text: string)
	Remotes.Social:FireAllClients("Chat", kind, text)
end

local function join(player: Player)
	for _, channel in public do
		pcall(function()
			channel:AddUserAsync(player.UserId)
		end)
	end
end

local function openWhisper(a: Player, b: Player): TextChannel?
	local name = ChatRules.whisperName(a.UserId, b.UserId)
	local existing = whispers[name]
	if existing and existing.Channel.Parent then
		return existing.Channel
	end
	local ok, channel = pcall(function()
		local made = Instance.new("TextChannel")
		made.Name = name
		made.Parent = TextChatService
		made:AddUserAsync(a.UserId)
		made:AddUserAsync(b.UserId)
		return made
	end)
	if not ok then
		return nil
	end
	whispers[name] = { Channel = channel, Users = { a.UserId, b.UserId } }
	return channel
end

function ChatChannels.start()
	for id, name in ChatRules.TextChannels do
		local channel = Instance.new("TextChannel")
		channel.Name = name
		channel.Parent = TextChatService
		public[id] = channel
	end
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(player)
		lastWhisper[player] = nil
		lastRoll[player] = nil
		for name, entry in whispers do
			if table.find(entry.Users, player.UserId) then
				entry.Channel:Destroy()
				whispers[name] = nil
			end
		end
	end)

	-- Opens (or reuses) the private channel with another player.
	Shop.register("ChatWhisper", function(player, targetId)
		local target = if typeof(targetId) == "number" and targetId == targetId
			then Players:GetPlayerByUserId(targetId)
			else nil
		if not target or target == player then
			return Shop.reply(false, "That miner isn't in this server.")
		end
		local now = os.clock()
		if lastWhisper[player] and now - lastWhisper[player] < WHISPER_GAP then
			return Shop.reply(false, "")
		end
		lastWhisper[player] = now
		local channel = openWhisper(player, target)
		if not channel then
			return Shop.reply(false, "Whispers aren't available right now.")
		end
		return Shop.reply(true, "", { Channel = channel.Name, Name = target.DisplayName, UserId = target.UserId })
	end)

	-- A fair roll everyone sees, like settling who gets the loot.
	Shop.register("ChatRoll", function(player, max)
		local now = os.clock()
		if lastRoll[player] and now - lastRoll[player] < ROLL_GAP then
			return Shop.reply(false, "")
		end
		lastRoll[player] = now
		local top = ChatRules.rollMax(if typeof(max) == "number" then tostring(max) else nil)
		local result = math.random(1, top)
		ChatChannels.announce("System", string.format("%s rolls %d (1-%d)", player.DisplayName, result, top))
		return Shop.reply(true, "")
	end)
end

return ChatChannels
