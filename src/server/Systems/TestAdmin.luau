-- Who gets the test-admin tools (e.g. regenerating gear): everyone while
-- Config.Playtest.OpenAdmin is on, otherwise the listed testers and owners
-- (and UserId below). Never granted by display name, Studio mode or
-- client arguments.
local TestAdmin = {}
TestAdmin.UserId = 0
-- Config.Playtest ({ OpenAdmin, Testers, Owners }); closed if it can't load.
TestAdmin.Playtest = (function()
	local ok, config = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.Config)
	end)
	return if ok and config.Playtest then config.Playtest else { OpenAdmin = false }
end)()
function TestAdmin.allowed(userId: number): boolean
	local playtest = TestAdmin.Playtest or {}
	return playtest.OpenAdmin == true
		or (TestAdmin.UserId > 0 and userId == TestAdmin.UserId)
		or table.find(playtest.Testers or {}, userId) ~= nil
		or table.find(playtest.Owners or {}, userId) ~= nil
end
return TestAdmin
