-- lune run tests/body_poses_cases.luau <repo>
-- BodyPoses settling bodies after a fight, yours and everyone else's, on
-- stand-ins for players, animation tracks and the clock:
--   * your own: the animations stop, and the Animate script restarts only
--     once those stops have finished (restarted in the same frame, the stock
--     Animate destroyed them mid-stop, and on other screens the body went on
--     playing them: a fall, arms up and out);
--   * another player's, on your screen: joints back to rest, and an animation
--     left playing from before their own screen's second settle is stopped,
--     while the ones their restarted Animate plays carry on.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local ROOT = process.args[1] or "."

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- The clock and task scheduler.
local now = 0
local queue = {}
local fakeTask = {
	delay = function(seconds, fn)
		table.insert(queue, { At = now + seconds, Fn = fn })
	end,
	defer = function(fn)
		table.insert(queue, { At = now, Fn = fn })
	end,
}
local function advance(seconds)
	local target = now + seconds
	while true do
		table.sort(queue, function(a, b)
			return a.At < b.At
		end)
		local nextTask = queue[1]
		if not nextTask or nextTask.At > target then
			break
		end
		table.remove(queue, 1)
		now = math.max(now, nextTask.At)
		nextTask.Fn()
	end
	now = target
end

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end

-- Bodies: a humanoid with an Animator and its tracks, and an Animate script.
local function track(name)
	return {
		Name = name,
		IsPlaying = true,
		Stop = function(self, fade)
			self.IsPlaying = false
			self.StoppedAt, self.Fade = now, fade
		end,
	}
end
local function body(name)
	local character = { Name = name }
	local tracks = {}
	local animator = {
		Tracks = tracks,
		GetPlayingAnimationTracks = function()
			local playing = {}
			for _, t in tracks do
				if t.IsPlaying then
					table.insert(playing, t)
				end
			end
			return playing
		end,
	}
	local humanoid = {
		Health = 100,
		PlatformStand = false,
		Sit = false,
		SeatPart = nil,
		StateChanges = 0,
		GetState = function()
			return roblox.Enum.HumanoidStateType.Running
		end,
		ChangeState = function(self)
			self.StateChanges += 1
		end,
		FindFirstChildOfClass = function(_, class)
			return if class == "Animator" then animator else nil
		end,
	}
	local log = {}
	local animateState = { Enabled = true, Parent = character }
	local animate = setmetatable({
		Log = log,
		IsA = function(_, class)
			return class == "LocalScript"
		end,
	}, {
		__index = animateState,
		__newindex = function(_, key, value)
			if key == "Enabled" then
				table.insert(log, { At = now, Enabled = value })
			end
			animateState[key] = value
		end,
	})
	character.Humanoid, character.Animator, character.Animate, character.Tracks = humanoid, animator, animate, tracks
	character.FindFirstChildOfClass = function(_, class)
		return if class == "Humanoid" then humanoid else nil
	end
	character.FindFirstChild = function(_, child)
		return if child == "Animate" then animate else nil
	end
	return character
end
local function play(character, name)
	local t = track(name)
	table.insert(character.Tracks, t)
	return t
end

-- Players.
local players = {}
local playerAdded = signal()
local function player(name)
	local attributes, changed = {}, {}
	local p = { Name = name }
	function p:GetAttribute(key)
		return attributes[key]
	end
	function p:SetAttribute(key, value)
		attributes[key] = value
		if changed[key] then
			changed[key]:Fire()
		end
	end
	function p:GetAttributeChangedSignal(key)
		changed[key] = changed[key] or signal()
		return changed[key]
	end
	p.Character = body(name .. "Body")
	return p
end
local me = player("Me")
local volver = player("Volver")
players = { me, volver }
local Players = {
	LocalPlayer = me,
	PlayerAdded = playerAdded,
	GetPlayers = function()
		return players
	end,
	GetPlayerByUserId = function()
		return nil
	end,
}

-- RivalPose and Matchmaking stand-ins: resets are counted per body.
local resets = {}
local FakeRivalPose = {
	reset = function(model)
		resets[model] = (resets[model] or 0) + 1
	end,
	update = function() end,
	holdGuards = function() end,
}
local services = {
	Players = Players,
	ReplicatedStorage = { Shared = { RivalPose = "RivalPose", Matchmaking = "Matchmaking" } },
	RunService = { PreSimulation = signal() },
}
local BodyPoses = luau.load(fs.readFile(ROOT .. "/src/client/Modules/BodyPoses.luau"), {
	debugName = "BodyPoses",
	environment = setmetatable({
		game = {
			GetService = function(_, name)
				return services[name]
			end,
		},
		require = function(module)
			return if module == "RivalPose" then FakeRivalPose else {}
		end,
		Enum = roblox.Enum,
		task = fakeTask,
		workspace = {
			GetServerTimeNow = function()
				return now
			end,
			FindFirstChild = function()
				return nil
			end,
		},
	}, { __index = _G }),
})()
BodyPoses.start()

-- 1. Your own fight ends: everything playing stops, Animate is switched
-- off, and switched back on only after the stops have finished.
local myBody = me.Character
local myFall = play(myBody, "Fall")
local myIdle = play(myBody, "Idle")
me:SetAttribute("CombatSession", "Duel")
me:SetAttribute("CombatSession", nil)
check(not myFall.IsPlaying and not myIdle.IsPlaying, "your animations stop as your fight ends")
check(resets[myBody] == 1, "your joints go back to rest as your fight ends")
local log = myBody.Animate.Log
check(#log == 1 and log[1].Enabled == false, "your Animate script is switched off")
advance(0) -- (deferred work runs)
check(myBody.Animate.Enabled == false, "Animate isn't back on in the same frame as the stops")
advance(BodyPoses.RestartDelay)
check(myBody.Animate.Enabled == true, "Animate is back on after RestartDelay")
check(log[2].At - log[1].At >= myFall.Fade + 0.1, "the restart waits out the stops' fade, and then some")
advance(1)
check(resets[myBody] == 2 and #log == 4, "settled again once the move back has landed")
check(log[4].Enabled == true, "and Animate ends up running")

-- 2. Another player's fight ends, seen from your screen. Their own screen
-- stops everything twice (as it ends, and 0.6 s on) and restarts Animate;
-- here one stop (their fall) never arrived.
local theirs = volver.Character
local stuckFall = play(theirs, "Fall")
local oldIdle = play(theirs, "OldIdle")
volver:SetAttribute("CombatSession", "Duel")
advance(1)
volver:SetAttribute("CombatSession", nil)
check(resets[theirs] == 1, "their joints go back to rest here as their fight ends")
advance(0.3)
local firstIdle = play(theirs, "IdleAfterFirstSettle") -- (their first restart, arriving)
advance(0.4)
oldIdle:Stop(0.1) -- (their second settle's stops arrive: the fall's doesn't)
firstIdle:Stop(0.1)
advance(0.3)
local newIdle = play(theirs, "IdleAfterSecondSettle") -- (their second restart, arriving)
check(stuckFall.IsPlaying, "nothing is cut short before the check")
advance(BodyPoses.OrphanCheck)
check(not stuckFall.IsPlaying, "the fall left playing here is stopped")
check(newIdle.IsPlaying, "the idle their restarted Animate plays carries on")
check(resets[theirs] == 2, "their joints are rested again with the snapshot")
check(#theirs.Animate.Log == 0, "their Animate script is never touched here")
check(theirs.Humanoid.StateChanges == 0, "their body's state is never touched here")

-- 3. Back in a fight before the check: nothing is stopped.
local fightFall = play(theirs, "Fall")
volver:SetAttribute("CombatSession", "Duel")
volver:SetAttribute("CombatSession", nil)
advance(BodyPoses.OrphanSnapshot + 0.05)
volver:SetAttribute("CombatSession", "Duel")
advance(BodyPoses.OrphanCheck)
check(fightFall.IsPlaying, "a body back in a fight keeps its animations")

-- 4. A new body by the check (they respawned): the old one isn't touched.
volver:SetAttribute("CombatSession", nil)
local oldBody = volver.Character
local leftover = play(oldBody, "Fall")
advance(0.1)
volver.Character = body("VolverBody2")
advance(BodyPoses.OrphanCheck)
check(leftover.IsPlaying, "a body they've left behind isn't settled")
fightFall:Stop(0)

-- 5. Someone who never fought: their animations are their own.
local walker = player("Walker")
table.insert(players, walker)
playerAdded:Fire(walker)
local walk = play(walker.Character, "Walk")
walker:SetAttribute("Outpost", true)
advance(3)
check(walk.IsPlaying and resets[walker.Character] == nil, "a body out of any fight is left alone")

-- 6. Someone who joined later is settled too.
local stuck = play(walker.Character, "Fall")
walker:SetAttribute("CombatSession", "Duel")
walker:SetAttribute("CombatSession", nil)
advance(BodyPoses.OrphanCheck + 0.1)
check(not stuck.IsPlaying and resets[walker.Character] == 2, "a player who joined later is settled as well")

print(
	string.format(
		"PASS: %d body settle checks (your Animate restarts after its stops; other bodies rested and leftover animations stopped)",
		checks
	)
)
