-- Compatibility name for the station exchange. Only gem sales remain.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Economy = require(ReplicatedStorage.Shared.Crafting)
local GemClient = require(script.Parent.GemClient)
local InventoryUI = require(script.Parent.InventoryUI)
local UiKit = require(script.Parent.UiKit)
local Exchange = {}
function Exchange.open(_which: string?, _market: boolean?)
	InventoryUI.open({
		Title = "STATION GEM EXCHANGE",
		ActionText = "Sell this gem for coins",
		Empty = "Mine for naturally cut gems, then sell the ones you do not need.",
		OnPick = function(gem)
			local price = Economy.marketPrice(gem)
			-- The pouch picker provides a separate action button after inspecting a gem.
			local result = GemClient.request("MarketSell", { gem.Id })
			UiKit.toast(
				if result.Ok then GemConfig.displayName(gem) .. " sold for " .. price .. " coins." else result.Message
			)
		end,
	})
end
function Exchange.close()
	InventoryUI.close()
end
return Exchange
