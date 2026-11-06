--[[
	What the Outpost's LED screens show (Shared.Led's boards; Client.LedScreens
	lights them): every few seconds, each board's data for everyone, as JSON
	on ReplicatedStorage.LedBoards (an attribute a board).

	  Ranked    this server's players by rating, those who've fought ranked
	  Live      Arena Row's rings and who's in each (Server.PrivateArenas)
	  Miners    the most rocks mined (their Outpost record)
	  Hunters   the most Rift bosses beaten

	  Boards.start()
	  Boards.collect() -> { [board] = data }   (tests)
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local PrivateArenas = require(script.Parent.PrivateArenas)

local Boards = {}
Boards.Every = 5 -- seconds between updates
Boards.Rows = 12 -- the most a ladder shows

local turn = 0

-- The players with `value(profile)` over 0, the most first.
local function ladder(value: (any) -> number?)
	local rows = {}
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player) :: any
		local ok, n = pcall(value, profile)
		if profile and ok and type(n) == "number" and n > 0 then
			table.insert(rows, { Name = player.DisplayName, Value = math.floor(n) })
		end
	end
	table.sort(rows, function(a, b)
		return if a.Value == b.Value then a.Name < b.Name else a.Value > b.Value
	end)
	while #rows > Boards.Rows do
		table.remove(rows)
	end
	return rows
end

function Boards.collect()
	turn += 1
	return {
		Ranked = {
			Rows = ladder(function(profile)
				local duel = profile.Duel
				return if duel and ((duel.Wins or 0) + (duel.Losses or 0)) > 0 then duel.Rating else nil
			end),
		},
		Live = { Rings = PrivateArenas.rings() },
		Miners = {
			Turn = turn,
			Rows = ladder(function(profile)
				return profile.Outpost and profile.Outpost.Rocks
			end),
		},
		Hunters = {
			Rows = ladder(function(profile)
				local total = 0
				for _, times in profile.RiftBosses or {} do
					total += tonumber(times) or 0
				end
				return total
			end),
		},
	}
end

function Boards.start()
	local folder = ReplicatedStorage:FindFirstChild("LedBoards")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LedBoards"
		folder.Parent = ReplicatedStorage
	end
	task.spawn(function()
		while true do
			local ok, boards = pcall(Boards.collect)
			if ok then
				for board, data in boards do
					local encoded = HttpService:JSONEncode(data)
					if folder:GetAttribute(board) ~= encoded then
						folder:SetAttribute(board, encoded)
					end
				end
			end
			task.wait(Boards.Every)
		end
	end)
end

return Boards
