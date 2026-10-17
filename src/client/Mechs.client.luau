-- Mech controls must start even if the lobby's inventory/art modules are
-- still loading. Requiring this again from OutpostScene reuses the same module.
require(script.Parent.Modules.VehicleDrive)
print(string.format("[Mech] Controller 2 ready; place %s version %s", tostring(game.PlaceId), tostring(game.PlaceVersion)))
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
remotes:WaitForChild("MechReport").OnClientEvent:Connect(function(detail)
	if type(detail) == "string" then warn(detail) end
end)
