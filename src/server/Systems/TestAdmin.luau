-- Temporary open testing access, explicitly enabled by the owner.
-- Turn OpenTesting off and set UserId to restore account-only access.
-- Never grant this based on display name, Studio mode, or client arguments.
local TestAdmin = {}
TestAdmin.UserId = 0
TestAdmin.OpenTesting = true
function TestAdmin.allowed(userId: number): boolean
	return TestAdmin.OpenTesting or (TestAdmin.UserId > 0 and userId == TestAdmin.UserId)
end
return TestAdmin
