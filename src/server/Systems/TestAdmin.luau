-- Who gets the test-admin tools (e.g. regenerating gear): only the UserIds
-- listed in Config.Playtest (Owners, Testers) and UserId below. Never granted
-- by a switch for everyone, display name, Studio mode or client arguments.
local TestAdmin = {}
TestAdmin.UserId = 0
-- Config.Playtest ({ Owners, Testers }); closed if it can't load.
TestAdmin.Playtest = (function()
	local ok, config = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.Config)
	end)
	return if ok and config.Playtest then config.Playtest else {}
end)()
function TestAdmin.allowed(userId: number): boolean
	local playtest = TestAdmin.Playtest or {}
	return (TestAdmin.UserId > 0 and userId == TestAdmin.UserId)
		or table.find(playtest.Testers or {}, userId) ~= nil
		or table.find(playtest.Owners or {}, userId) ~= nil
end
return TestAdmin
