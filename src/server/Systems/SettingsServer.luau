--[[
	A player's settings (Shared.GameSettings), saved with their profile.

	  "SaveSettings", settings   cleaned (GameSettings.clean), kept as
	                             profile.Settings, sent back with the profile
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameSettings = require(ReplicatedStorage.Shared.GameSettings)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local SettingsServer = {}

function SettingsServer.save(player: Player, settings: any)
	local profile = PlayerData.get(player)
	if not profile then
		return Shop.reply(false, "Your profile is still loading.")
	end
	;(profile :: any).Settings = GameSettings.clean(settings)
	return Shop.reply(true, "", { Settings = (profile :: any).Settings })
end

function SettingsServer.start()
	Shop.register("SaveSettings", SettingsServer.save)
end

return SettingsServer
