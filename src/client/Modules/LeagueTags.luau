--[[
	Each ranked player's league crest over their head (Shared.Leagues: the
	player attribute League, set once they've played a ranked 1v1), above
	their title, so the Outpost can see who's climbing. Built on each
	screen, for everyone (LeagueBadge: the crest image, or its stand-in).

	  LeagueTags.start()   once (Lobby.client)
]]
local Players = game:GetService("Players")

local LeagueBadge = require(script.Parent.LeagueBadge)

local LeagueTags = {}

LeagueTags.Size = 34 -- px
LeagueTags.Height = 4.2 -- studs over the head's middle (the title's at 2.9)
LeagueTags.MaxDistance = 70

local function tag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local step = player:GetAttribute("League")
	local board = head:FindFirstChild("LeagueTag")
	if type(step) ~= "number" then
		if board then
			board:Destroy()
		end
		return
	end
	if not board then
		board = Instance.new("BillboardGui")
		board.Name = "LeagueTag"
		board.Size = UDim2.fromOffset(LeagueTags.Size, LeagueTags.Size)
		board.StudsOffset = Vector3.new(0, LeagueTags.Height, 0)
		board.MaxDistance = LeagueTags.MaxDistance
		board.LightInfluence = 0
		board.Parent = head
		local badge = LeagueBadge.new(board, LeagueTags.Size)
		badge.Frame.Name = "Badge"
		board:SetAttribute("Step", 0)
	end
	local holder = board:FindFirstChild("Badge")
	if board:GetAttribute("Step") ~= step and holder then
		-- (rebuilt to the new step: a badge has no state worth keeping)
		holder:Destroy()
		local badge = LeagueBadge.new(board, LeagueTags.Size)
		badge.Frame.Name = "Badge"
		badge:set(step)
		board:SetAttribute("Step", step)
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("League"):Connect(function()
		tag(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		tag(player)
	end)
	tag(player)
end

function LeagueTags.start()
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
	Players.PlayerAdded:Connect(watch)
end

return LeagueTags
