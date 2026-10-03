--[[
	Session locking for saved profiles: only one server may own a player's
	save at a time, so hopping between servers (or rejoining while the old
	server is still saving) can't roll progress back or duplicate items.

	The saved record carries Session = { JobId, Time }. A server claims it on
	load, refreshes Time with every save and clears it when the player leaves.
	A lock older than Stale (a server that crashed without releasing) may be
	taken over. Studio sessions never block one another.

	All pure, for use inside DataStore UpdateAsync transforms:
	  SessionLock.claim(saved, jobId, now)   -> ok, reason
	      may this server take the save? (sets saved.Session when ok)
	  SessionLock.mayWrite(saved, jobId)     -> boolean
	      is the save still ours to write?
	  SessionLock.stamp(profile, jobId, now)  mark a profile as ours
	  SessionLock.release(profile)            clear our mark (on leave)
]]
local SessionLock = {}

SessionLock.Stale = 300 -- seconds; longer than the autosave interval

local function studio(jobId: string?): boolean
	return type(jobId) == "string" and string.sub(jobId, 1, 7) == "studio-"
end

function SessionLock.claim(saved, jobId: string, now: number): (boolean, string?)
	local session = type(saved) == "table" and saved.Session or nil
	if type(session) == "table" and session.JobId ~= jobId then
		local fresh = now - (tonumber(session.Time) or 0) < SessionLock.Stale
		if fresh and not (studio(session.JobId) and studio(jobId)) then
			return false, "locked"
		end
	end
	if type(saved) == "table" then
		saved.Session = { JobId = jobId, Time = now }
	end
	return true, nil
end

function SessionLock.mayWrite(saved, jobId: string): boolean
	local session = type(saved) == "table" and saved.Session or nil
	return type(session) ~= "table" or session.JobId == jobId
end

function SessionLock.stamp(profile, jobId: string, now: number)
	profile.Session = { JobId = jobId, Time = now }
end

function SessionLock.release(profile)
	profile.Session = nil
end

return SessionLock
