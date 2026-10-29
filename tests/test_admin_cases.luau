local TestAdmin = require("../src/server/Systems/TestAdmin")
local configured, playtest = TestAdmin.UserId, TestAdmin.Playtest
TestAdmin.UserId = 0
-- There's no switch that opens the tools to everyone (an old OpenAdmin flag does nothing).
TestAdmin.Playtest = { OpenAdmin = true }
assert(not TestAdmin.allowed(456), "A flag must never open the test tools to everyone")
TestAdmin.Playtest = { OpenAdmin = false }
TestAdmin.UserId = 0
assert(not TestAdmin.allowed(0) and not TestAdmin.allowed(123), "Unconfigured access must fail closed")
TestAdmin.UserId = 123
assert(TestAdmin.allowed(123), "Exact owner must be allowed")
for _, id in { 0, -1, 124, 456 } do
	assert(not TestAdmin.allowed(id), "Other players must be rejected")
end
TestAdmin.UserId = 0
TestAdmin.Playtest = { OpenAdmin = false, Testers = { 77 }, Owners = { 88 } }
assert(TestAdmin.allowed(77) and TestAdmin.allowed(88) and not TestAdmin.allowed(99), "Listed testers and owners only")
TestAdmin.UserId, TestAdmin.Playtest = configured, playtest
print("PASS: test admin: listed owners, testers and the exact owner only; no open-to-everyone switch; fails closed otherwise")
