--[[
	Puts the game in the player's language (Shared.Lang): every label and
	text box placeholder in PlayerGui, and the action prompts in the world,
	as their text is set. Screens keep writing English. Nothing runs for a
	player in English.

	The language is Roblox's (LocalizationService.RobloxLocaleId); the DEV
	panel can switch it for the session (the player's Language attribute).
	A GUI with the NoTranslate attribute keeps its text, and so does
	everything inside it: chat, players' names, test tools.
]]
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Lang"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Per object and property: the English it was last given (to put back on a
-- switch to English), and what this script wrote (so its own write isn't
-- taken for new English).
local english: { [Instance]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any
local written: { [Instance]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any
local watched: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any

local function apply(object: Instance, property: string)
	local text = (object :: any)[property]
	local mine = written[object]
	if mine and mine[property] == text then
		return
	end
	english[object] = english[object] or {}
	english[object][property] = text
	local out = Lang.translate(text)
	written[object] = written[object] or {}
	if out ~= text then
		written[object][property] = out;
		(object :: any)[property] = out
	else
		written[object][property] = nil
	end
end

local function skipped(object: Instance): boolean
	local at: Instance? = object
	while at and at ~= playerGui do
		if at:GetAttribute("NoTranslate") then
			return true
		end
		at = at.Parent
	end
	return false
end

local function watch(object: Instance)
	if watched[object] then
		return
	end
	local property = if object:IsA("TextLabel") or object:IsA("TextButton")
		then "Text"
		elseif object:IsA("TextBox") then "PlaceholderText"
		else nil
	if not property or skipped(object) then
		return
	end
	watched[object] = property
	object:GetPropertyChangedSignal(property):Connect(function()
		if Lang.active() then
			apply(object, property)
		end
	end)
	if Lang.active() then
		apply(object, property)
	end
end

-- Action prompts ("Mine", "Duel"): Roblox draws them, so they're translated
-- as they show.
local function prompt(object: ProximityPrompt)
	if Lang.active() then
		apply(object, "ActionText")
		apply(object, "ObjectText")
	end
end

local started = false
local function start()
	if started then
		return
	end
	started = true
	playerGui.DescendantAdded:Connect(watch)
	for _, object in playerGui:GetDescendants() do
		watch(object)
	end
	ProximityPromptService.PromptShown:Connect(prompt)
end

local function chosen(): string?
	local override = player:GetAttribute("Language")
	if type(override) == "string" and override ~= "" then
		return override
	end
	local ok, id = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	if ok and type(id) == "string" and id ~= "" then
		return id
	end
	return player.LocaleId
end

local function update()
	Lang.setLocale(chosen())
	if Lang.active() then
		start()
		for object, property in watched do
			apply(object, property)
		end
	else
		-- Back to English: every label as the game last wrote it.
		for object, properties in english do
			for property, text in properties do
				local mine = written[object]
				if mine and mine[property] ~= nil and (object :: any)[property] == mine[property] then
					mine[property] = nil;
					(object :: any)[property] = text
				end
			end
		end
	end
end

player:GetAttributeChangedSignal("Language"):Connect(update)
update()
