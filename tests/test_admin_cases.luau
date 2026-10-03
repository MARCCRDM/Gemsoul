local TestAdmin = require("../src/server/Systems/TestAdmin")
local configured, playtest = TestAdmin.UserId, TestAdmin.Playtest
TestAdmin.Playtest = { OpenAdmin = true }
assert(TestAdmin.allowed(456), "Open playtest access must let everyone in")
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
print("PASS: test admin: open playtest access, exact owner, listed testers and owners; fails closed otherwise")
