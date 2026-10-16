-- Mech controls must start even if the lobby's inventory/art modules are
-- still loading. Requiring this again from OutpostScene reuses the same module.
require(script.Parent.Modules.VehicleDrive)
