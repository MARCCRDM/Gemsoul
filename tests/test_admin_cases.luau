local TestAdmin = require("../src/server/Systems/TestAdmin")
local configured = TestAdmin.UserId
local openTesting = TestAdmin.OpenTesting
assert(TestAdmin.allowed(456), "Temporary testing access must be enabled")
TestAdmin.OpenTesting = false
TestAdmin.UserId = 0
assert(not TestAdmin.allowed(0) and not TestAdmin.allowed(123), "Unconfigured access must fail closed")
TestAdmin.UserId = 123
assert(TestAdmin.allowed(123), "Exact owner must be allowed")
for _, id in { 0, -1, 124, 456 } do
	assert(not TestAdmin.allowed(id), "Other players must be rejected")
end
TestAdmin.UserId = configured
TestAdmin.OpenTesting = openTesting
print("PASS: test admin allows only exact configured account when open testing is off; temporary access works")
