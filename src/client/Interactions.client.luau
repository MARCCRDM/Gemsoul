-- Client side of the town's terminals: keeps the quota terminal showing this
-- player's progress, and answers station prompts whose systems aren't built yet.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local player = Players.LocalPlayer

local COMING_SOON = {
	[Tags.CuttingStation] = { "Cutting Station", "Manual QTE gem cutting is coming soon." },
	[Tags.LaserCutter] = { "Laser Cutter", "Automated laser cutting is coming soon." },
	[Tags.TradeKiosk] = { "Trade Kiosk", "Player trading is coming soon." },
	[Tags.EnchantAltar] = { "Enchanting Altar", "Gem fusing is coming soon." },
	[Tags.PvPQueue] = { "PvP Duels", "Collateral duels are coming soon." },
	[Tags.PvETerminal] = { "PvE Combat", "PvE combat is coming soon." },
}

local function notify(title: string, text: string)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 4 })
	end)
end

local function quota(): (number, number)
	return player:GetAttribute("GemsMinedToday") or 0, player:GetAttribute("DailyQuota") or Config.DailyQuota
end

local function refreshTerminals()
	local mined, target = quota()
	local status = if mined >= target then "QUOTA MET" else "KEEP MINING"
	for _, terminal in CollectionService:GetTagged(Tags.QuotaTerminal) do
		local label = terminal:FindFirstChild("Display", true)
		if label then
			label.Text = string.format("DAILY QUOTA\n%d / %d\n> %s_", mined, target, status)
		end
	end
end

player:GetAttributeChangedSignal("GemsMinedToday"):Connect(refreshTerminals)
player:GetAttributeChangedSignal("DailyQuota"):Connect(refreshTerminals)
CollectionService:GetInstanceAddedSignal(Tags.QuotaTerminal):Connect(refreshTerminals)
refreshTerminals()

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local part = prompt.Parent
	if not part then
		return
	end
	if CollectionService:HasTag(part, Tags.QuotaTerminal) then
		local mined, target = quota()
		if mined >= target then
			notify("Daily Quota", string.format("Quota met! %d / %d gems mined today.", mined, target))
		else
			notify("Daily Quota", string.format("%d / %d gems mined today. %d to go.", mined, target, target - mined))
		end
		return
	end
	for tag, message in COMING_SOON do
		if CollectionService:HasTag(part, tag) then
			notify(message[1], message[2])
			return
		end
	end
end)
