--[[
	Plays the menu sounds for every button on screen: a soft tick on hover and
	a press sound on click. A button picks its own sound with the "UiSound"
	attribute ("Confirm", "Tab", "Back", ...), or "None" to stay silent (the
	Mine's rocks have their own sounds). See Modules/UiSound for the rest.
]]
local Players = game:GetService("Players")

local UiSound = require(script.Parent.Modules.UiSound)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function hook(object: Instance)
	if hooked[object] or not object:IsA("GuiButton") then
		return
	end
	hooked[object] = true
	local button = object :: GuiButton
	button.MouseEnter:Connect(function()
		if button:GetAttribute("UiSound") ~= "None" then
			UiSound.play("Hover")
		end
	end)
	button.Activated:Connect(function()
		local kind = button:GetAttribute("UiSound")
		if kind ~= "None" then
			UiSound.play(if typeof(kind) == "string" then kind else "Click")
		end
	end)
end

playerGui.DescendantAdded:Connect(hook)
for _, object in playerGui:GetDescendants() do
	hook(object)
end
