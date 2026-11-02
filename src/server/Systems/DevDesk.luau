--[[
	The DEV desk in the Shelter (World OutpostWorld's devDesk): lit while one
	of the game's Owners (Config.Playtest.Owners: DevAlerts.owner) is in the
	server, its sign saying who; dark, DEV · OFFLINE, when none is. Every
	part marked DevGlow takes its lit colour (the attribute) and neon, or
	goes dark plastic; the DevLight lights go on and off with it. The desk's
	DevOnline attribute says which.

	  DevDesk.apply(desk, name?)   lit for `name` (an Owner's display name),
	                               or dark with none
	  DevDesk.start()
]]
local Players = game:GetService("Players")

local DevAlerts = require(script.Parent.DevAlerts)

local DevDesk = {}

DevDesk.Off = Color3.fromRGB(44, 46, 56)
DevDesk.OnInk = Color3.fromRGB(120, 255, 170)
DevDesk.OffInk = Color3.fromRGB(110, 114, 126)

function DevDesk.apply(desk: Instance, name: string?)
	local online = name ~= nil
	for _, d in desk:GetDescendants() do
		if d:IsA("BasePart") then
			local lit = d:GetAttribute("DevGlow")
			if typeof(lit) == "Color3" then
				d.Color = if online then lit else DevDesk.Off
				d.Material = if online then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		elseif d:IsA("Light") and d.Name == "DevLight" then
			d.Enabled = online
		end
	end
	local sign = desk:FindFirstChild("DevSign", true)
	local word = sign and sign:FindFirstChild("Letters") and sign.Letters:FindFirstChild("Word")
	if word and word:IsA("TextLabel") then
		word.Text = if online then "DEV ONLINE · " .. string.upper(name :: string) else "DEV · OFFLINE"
		word.TextColor3 = if online then DevDesk.OnInk else DevDesk.OffInk
	end
	desk:SetAttribute("DevOnline", online)
end

-- The Owner in the server (not `leaving`), if any: their display name.
local function ownerHere(leaving: Player?): string?
	for _, player in Players:GetPlayers() do
		if player ~= leaving and DevAlerts.owner(player.UserId) then
			return player.DisplayName
		end
	end
	return nil
end

local started = false
function DevDesk.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		-- (the Outpost's built a moment after the server starts)
		local desk = nil
		for _ = 1, 120 do
			desk = workspace:FindFirstChild("DevDesk", true)
			if desk then
				break
			end
			task.wait(1)
		end
		if not desk then
			warn("[DevDesk] no desk in the world")
			return
		end
		DevDesk.apply(desk, ownerHere())
		Players.PlayerAdded:Connect(function()
			DevDesk.apply(desk, ownerHere())
		end)
		Players.PlayerRemoving:Connect(function(player)
			DevDesk.apply(desk, ownerHere(player))
		end)
	end)
end

return DevDesk
