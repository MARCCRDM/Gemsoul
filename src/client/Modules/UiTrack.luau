--[[
	Micro-interactions, the client's half (the server's: Server.UiTrack):
	every button you press (its window and its name, or its words when it
	has a generic name) and every window you open (a ScreenGui turned on and
	off again): how long it was up, and how long before your first tap in it
	(hesitation). Sent in a batch every Every seconds (Remotes.UiTrack); the
	server keeps them out of the numbers for dev and test accounts.

	  UiTrack.start()
	  UiTrack.key(button) -> "<window>/<button>"?   (what a press counts as)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiTrack = {}

UiTrack.Every = 20 -- seconds between batches
UiTrack.Generic = { Button = true, TextButton = true, ImageButton = true, [""] = true }
UiTrack.Skip = { Chat = true, BubbleChat = true, TouchGui = true, Freecam = true }

local player = Players.LocalPlayer

local function windowOf(object: Instance): ScreenGui?
	local gui = object:FindFirstAncestorWhichIsA("ScreenGui")
	return gui
end

-- What a press of `button` counts as: its window and its name (or its
-- words, or its parent's name, when its own is a generic one).
function UiTrack.key(button: GuiButton): string?
	local gui = windowOf(button)
	if not gui or UiTrack.Skip[gui.Name] then
		return nil
	end
	local name = button.Name
	if UiTrack.Generic[name] then
		local text = if button:IsA("TextButton") then button.Text else ""
		local words = button:FindFirstChild("Words")
		if text == "" and words and words:IsA("TextLabel") then
			text = words.Text
		end
		name = if text ~= "" then string.upper(string.sub(text, 1, 32)) else (if button.Parent then button.Parent.Name .. "." .. name else name)
	end
	return gui.Name .. "/" .. name
end

local taps: { [string]: number } = {}
local windows = {}
local openAt: { [ScreenGui]: { At: number, FirstTap: number? } } = setmetatable({}, { __mode = "k" }) :: any

local function hook(object: Instance)
	if object:IsA("GuiButton") then
		object.Activated:Connect(function()
			local key = UiTrack.key(object)
			if not key then
				return
			end
			taps[key] = (taps[key] or 0) + 1
			local gui = windowOf(object)
			local open = gui and openAt[gui]
			if open and not open.FirstTap then
				open.FirstTap = os.clock() - open.At
			end
		end)
	elseif object:IsA("ScreenGui") and not UiTrack.Skip[object.Name] then
		local gui = object :: ScreenGui
		-- (one that starts up on counts once it's been shut and opened again)
		gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if gui.Enabled then
				openAt[gui] = { At = os.clock() }
			else
				local open = openAt[gui]
				openAt[gui] = nil
				if open then
					table.insert(windows, { Name = gui.Name, Seconds = os.clock() - open.At, FirstTap = open.FirstTap })
				end
			end
		end)
	end
end

local started = false
function UiTrack.start()
	if started then
		return
	end
	started = true
	local playerGui = player:WaitForChild("PlayerGui")
	for _, object in playerGui:GetDescendants() do
		hook(object)
	end
	playerGui.DescendantAdded:Connect(hook)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UiTrack", 30)
	if not remote then
		return
	end
	task.spawn(function()
		while true do
			task.wait(UiTrack.Every)
			if next(taps) or #windows > 0 then
				local batch = { Taps = taps, Windows = windows }
				taps, windows = {}, {}
				pcall(function()
					(remote :: RemoteEvent):FireServer(batch)
				end)
			end
		end
	end)
end

return UiTrack
