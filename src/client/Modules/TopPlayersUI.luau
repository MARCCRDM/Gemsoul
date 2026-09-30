--[[
	Top Players [L]: leaderboards for the best gem ever owned, monsters
	slain in the Wilds, and Season level. Global when data stores are
	available, otherwise the players in this server.
]]
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local P = IronUi.Colors
local BOLD = IronUi.Bold
local new, text, box, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.clear

local WIDTH, HEIGHT = 620, 560
local BOARDS = {
	{ "Gem", "Best Gem", "coins" },
	{ "Slain", "Wilds Slayer", "slain" },
	{ "Level", "Season Level", "" },
}
local MEDALS = { "🥇", "🥈", "🥉" }

local TopPlayersUI = {}

local window = IronUi.window("TopPlayers", 10, WIDTH, HEIGHT, "🏆")
local gui, panel = window.Gui, window.Panel
window.Title.Text = "TOP PLAYERS"

local board = "Gem"
local data = nil
local tabBar = new(
	"Frame",
	{ BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 76), Size = UDim2.fromOffset(560, 32) },
	panel
)
local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 122),
	Size = UDim2.fromOffset(WIDTH - 48, HEIGHT - 146),
}, panel)
UiKit.list(body, 8)

local function draw()
	clear(tabBar)
	local entries = {}
	for _, b in BOARDS do
		table.insert(entries, { b[1], b[2] })
	end
	IronUi.tabs(tabBar, entries, board, function(id)
		board = id
		draw()
	end)
	clear(body)
	if not data then
		text(body, "Loading…", 16, P.Dim)
		return
	end
	window.Subtitle.Text = if data.Global then "All players, everywhere" else "Players in this server"
	local unit = ""
	for _, b in BOARDS do
		if b[1] == board then
			unit = b[3]
		end
	end
	local rows = data.Boards and data.Boards[board] or {}
	if #rows == 0 then
		text(body, "No one on the board yet. Be the first!", 15, P.Dim)
	end
	for rank, row in rows do
		local line = box(
			body,
			UDim2.new(),
			UDim2.new(1, 0, 0, 40),
			if rank <= 3 then Color3.fromRGB(44, 36, 24) else P.Inset,
			20
		)
		line.LayoutOrder = rank
		local place = text(line, MEDALS[rank] or ("#" .. rank), 18, P.Gold, BOLD)
		place.Position = UDim2.fromOffset(14, 0)
		place.Size = UDim2.fromOffset(44, 40)
		place.AutomaticSize = Enum.AutomaticSize.None
		place.TextYAlignment = Enum.TextYAlignment.Center
		local name = text(line, row.Name, 16, P.Text, BOLD)
		name.Position = UDim2.fromOffset(64, 0)
		name.Size = UDim2.new(1, -220, 0, 40)
		name.AutomaticSize = Enum.AutomaticSize.None
		name.TextYAlignment = Enum.TextYAlignment.Center
		local value = text(line, string.format("%d %s", row.Value, unit), 16, P.Gold, BOLD)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -16, 0, 0)
		value.Size = UDim2.fromOffset(150, 40)
		value.AutomaticSize = Enum.AutomaticSize.None
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextYAlignment = Enum.TextYAlignment.Center
	end
end

function TopPlayersUI.open()
	gui.Enabled = true
	window.Fit()
	draw()
	task.spawn(function()
		local result = GemClient.request("TopPlayers")
		if result.Ok then
			data = result
		end
		if gui.Enabled then
			draw()
		end
	end)
end

function TopPlayersUI.close()
	gui.Enabled = false
end

function TopPlayersUI.toggle()
	if gui.Enabled then
		TopPlayersUI.close()
	else
		TopPlayersUI.open()
	end
end

window.Close.Activated:Connect(TopPlayersUI.close)
window.Shade.Activated:Connect(TopPlayersUI.close)

return TopPlayersUI
