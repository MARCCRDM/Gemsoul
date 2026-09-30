--[[
	Cutting from the menu: pick a rough stone from the pouch, then cut it by
	hand in the cutting minigame. CutFlow.open() starts it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local CuttingGame = require(script.Parent.CuttingGame)
local GemClient = require(script.Parent.GemClient)
local InventoryUI = require(script.Parent.InventoryUI)
local UiKit = require(script.Parent.UiKit)

local CutFlow = {}

local busy = false

local function isRough(gem): boolean
	return gem.Cut == nil
end

function CutFlow.open()
	InventoryUI.open({
		Title = "Choose a rough stone to cut",
		Filter = isRough,
		ActionText = "Cut this stone",
		Empty = "No rough stones yet. Dig some up in the Mine (press M)!",
		OnPick = function(gem)
			if busy then
				return
			end
			busy = true
			task.spawn(function()
				local before = GemConfig.value(gem)
				local start = GemClient.request("StartCut", gem.Id)
				if not start.Ok then
					UiKit.toast(start.Message, UiKit.Colors.Bad)
					busy = false
					return
				end
				local times = CuttingGame.play(gem, start)
				if times then
					local result = GemClient.request("FinishCut", times)
					if result.Ok and result.Gem then
						UiKit.toast(
							string.format(
								"%s  Value %d -> %d coins.",
								result.Message:match("^[^%.!]*[%.!]") or "Cut!",
								before,
								GemConfig.value(result.Gem)
							),
							UiKit.Colors.Gold
						)
					else
						UiKit.toast(result.Message, UiKit.Colors.Bad)
					end
				end
				busy = false
			end)
		end,
	})
end

return CutFlow
