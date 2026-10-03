local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local A, B = "job-a", "job-b"

-- A new player (nothing saved) and an unlocked save can always be claimed.
check(SessionLock.claim(nil, A, 1000), "A brand-new save was refused")
local saved = { Coins = 5 }
check(SessionLock.claim(saved, A, 1000) and saved.Session.JobId == A and saved.Session.Time == 1000, "Claim didn't mark the save")
-- Another server can't take a fresh lock, but the owner can reclaim it.
local ok, reason = SessionLock.claim(saved, B, 1060)
check(not ok and reason == "locked" and saved.Session.JobId == A, "A second server took a live save")
check(SessionLock.claim(saved, A, 1070), "The owner was locked out of its own save")
-- A lock left by a crashed server goes stale and can be taken over.
check(SessionLock.claim(saved, B, 1070 + SessionLock.Stale) and saved.Session.JobId == B, "A stale lock was never released")
-- Writing: only the owner, or anyone once the lock is released.
check(SessionLock.mayWrite(saved, B) and not SessionLock.mayWrite(saved, A), "The old owner could still overwrite the save")
local profile = { Coins = 9 }
SessionLock.stamp(profile, A, 2000)
check(profile.Session.JobId == A, "Stamp didn't mark the profile")
SessionLock.release(profile)
check(profile.Session == nil and SessionLock.mayWrite(profile, B), "Release didn't free the save")
-- Two Studio play sessions never block each other.
local studio = { Session = { JobId = "studio-1", Time = 5000 } }
check(SessionLock.claim(studio, "studio-2", 5001), "Studio sessions blocked each other")
check(SessionLock.Stale > Config.AutosaveSeconds, "Autosave doesn't refresh a lock before it goes stale")

print("PASS: " .. checks .. " session lock checks (claim, stale takeover, owner-only writes, release, Studio)")
