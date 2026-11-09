--[[
	Client script errors to the server's report log (Server Feedback: DEV >
	ERRORS), from the moment the player joins: before the menu, the lobby or
	anything else has loaded (an error there is what strands a player on the
	old base). A few a minute at most.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local sent = {}
ScriptContext.Error:Connect(function(message, trace)
	local now = os.clock()
	while sent[1] and now - sent[1] > 60 do
		table.remove(sent, 1)
	end
	if #sent >= 5 then
		return
	end
	table.insert(sent, now)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local report = folder and folder:FindFirstChild("Report")
	if report then
		report:FireServer("Error", string.sub(tostring(message), 1, 300), string.sub(tostring(trace), 1, 600))
	end
end)
