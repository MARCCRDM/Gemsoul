-- Deterministic doubles for the duel system: a hand-driven clock, players
-- with attributes and humanoids, and recording stand-ins for the systems
-- Duels talks to. The rules (Shared.Matchmaking, Shared.Season) and Duels
-- itself are the production modules.
local vmt = {}
local Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt)
end
vmt.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vmt.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vmt.__mul = function(a, b)
	return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
vmt.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	end
	return nil
end
local CFrame = {
	lookAt = function(at, target)
		return { Position = at, Target = target }
	end,
}
local function typeof(v)
	if getmetatable(v) == vmt then
		return "Vector3"
	end
	return type(v)
end
local Color3 = {
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
Color3.fromRGB = Color3.new

local function signal()
	local callbacks = {}
	local event = {}
	function event:Connect(fn)
		table.insert(callbacks, fn)
		return {
			Disconnect = function()
				local i = table.find(callbacks, fn)
				if i then
					table.remove(callbacks, i)
				end
			end,
		}
	end
	function event.Fire(...)
		for _, fn in table.clone(callbacks) do
			fn(...)
		end
	end
	return event
end

local now = 1000
local os = {
	clock = function()
		return now
	end,
	time = function()
		return 0
	end,
}
local delayed = {}
local task = {
	delay = function(seconds, fn, ...)
		table.insert(delayed, { now + seconds, fn, table.pack(...) })
	end,
	spawn = function(fn, ...)
		fn(...)
	end,
	defer = function(fn, ...)
		fn(...)
	end,
	wait = function() end,
}
local Instance = {
	new = function(className)
		local object = { ClassName = className }
		function object:Destroy()
			self.Destroyed = true
			self.Parent = nil
		end
		return object
	end,
}
local workspace = {
	GetServerTimeNow = function()
		return now
	end,
}

local playerList = {}
local Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return playerList
	end,
	GetPlayerByUserId = function(_, id)
		for _, p in playerList do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
}
local FLOOR = Vector3.new(600, 0, 0)
local landmarks = {
	GetAttribute = function(_, key)
		return if key == "ArenaFloor" then FLOOR else nil
	end,
}
local ReplicatedStorage = {
	FindFirstChild = function(_, key)
		return if key == "Landmarks" then landmarks else nil
	end,
}
local RunService = { Heartbeat = signal() }
local Debris = { AddItem = function() end }
local game = {
	GetService = function(_, name)
		return ({ Players = Players, ReplicatedStorage = ReplicatedStorage, RunService = RunService, Debris = Debris })[name]
	end,
}

-- Recording stand-ins ----------------------------------------------------------
local sent = {} -- [player] = { { kind, ... } }
local Remotes = {
	Social = {
		FireClient = function(_, p, ...)
			table.insert(sent[p], table.pack(...))
		end,
		FireAllClients = function(_, ...)
			for _, p in playerList do
				table.insert(sent[p], table.pack(...))
			end
		end,
	},
	Notify = {
		FireClient = function(_, p, message)
			table.insert(sent[p], table.pack("Notify", message))
		end,
	},
}
local handlers = {}
local Shop = {
	register = function(name, fn)
		handlers[name] = fn
	end,
	reply = function(ok, message)
		return { Ok = ok, Message = message }
	end,
}
local profiles, xp = {}, {}
local taskEvents = {}
local PlayerData = {
 training = function(p,event) taskEvents[p]=taskEvents[p] or {};taskEvents[p][event]=(taskEvents[p][event] or 0)+1 end,
	get = function(p)
		return profiles[p]
	end,
	addCoins = function(p, n)
		profiles[p].Coins += n
	end,
	sync = function() end,
	character = function(p)
		return profiles[p] and profiles[p].Character
	end,
}
-- Gear presets: what each player wore through Presets.wear (the pivot).
local worn = {}
local Presets = {
	list = function(p, part)
		local all = profiles[p] and profiles[p].Presets
		return all and all[part] or {}
	end,
	wear = function(p, part, slot)
		worn[p] = worn[p] or {}
		worn[p][part] = slot
		local preset = profiles[p].Presets[part][slot]
		if preset.Element then
			profiles[p].Character = { WeaponGem = { Element = preset.Element } }
		end
		return true, preset.Name, 1
	end,
}
-- The XP reason each player last earned.
local Progress = {
	addXP = function(p, reason)
		xp[p] = reason
	end,
}
-- Party Raids: the boss is the Duelist's (recorded here); ids are fixed.
local HttpService = {
	GenerateGUID = function()
		return "abcdef1234567890"
	end,
}
local raidsStarted = {}
local Duelist = {
	startRaid = function(members, id)
		table.insert(raidsStarted, { Members = members, Id = id })
	end,
}
local resets = {}
local lethalHook
local CombatServer = {
	reset = function(p)
		resets[p] = (resets[p] or 0) + 1
	end,
	onLethal = function(hook)
		lethalHook = hook
	end,
}
-- A blow that would kill `p`, as CombatServer's damage applies it.
local function lethalBlow(p)
	if lethalHook and lethalHook(p, p.Humanoid) then
		return
	end
	p.Humanoid.Health = 0
	p.Humanoid.Died.Fire()
end
local ArenaSessions = {
	leave = function(p)
		p:SetAttribute("CombatSession", nil)
		p:SetAttribute("PvPEnabled", false)
	end,
}
local parties = {}
local Party = {
	of = function(p)
		return parties[p]
	end,
}

local function makePlayer(id, name)
	local p = { UserId = id, DisplayName = name, Parent = Players, Attributes = {}, Changed = {} }
	function p:GetAttribute(key)
		return self.Attributes[key]
	end
	function p:SetAttribute(key, value)
		local before = self.Attributes[key]
		self.Attributes[key] = value
		if before ~= value and self.Changed[key] then
			self.Changed[key].Fire()
		end
	end
	function p:GetAttributeChangedSignal(key)
		self.Changed[key] = self.Changed[key] or signal()
		return self.Changed[key]
	end
	local humanoid = { Health = 300, MaxHealth = 300, Died = signal() }
	local root = { Position = Vector3.new(0, 5, 0) }
	p.Character = {
		Humanoid = humanoid,
		FindFirstChildOfClass = function(_, class)
			return if class == "Humanoid" then humanoid else nil
		end,
		FindFirstChild = function(_, key)
			return if key == "HumanoidRootPart" then root else nil
		end,
		PivotTo = function(_, cframe)
			root.Position = cframe.Position
		end,
	}
	p.Humanoid, p.Root = humanoid, root
	profiles[p] = { Coins = 0, Season = { XP = 0 } }
	sent[p] = {}
	table.insert(playerList, p)
	Players.PlayerAdded.Fire(p)
	return p
end

-- Advance the clock, running anything due, then a Duels step.
local Duels
local function advance(seconds)
	now += seconds
	for i = #delayed, 1, -1 do
		local d = delayed[i]
		if now >= d[1] then
			table.remove(delayed, i)
			d[2](table.unpack(d[3], 1, d[3].n))
		end
	end
	Duels._step()
end
local function last(p, kind)
	for i = #sent[p], 1, -1 do
		if sent[p][i][1] == kind then
			return sent[p][i]
		end
	end
	return nil
end
local function kill(p)
	p.Humanoid.Health = 0
	p.Humanoid.Died.Fire()
end
-- Back on your feet, as a respawn would.
local function respawn(...)
	for _, p in { ... } do
		p.Humanoid.Health = p.Humanoid.MaxHealth
	end
end
-- The drop pod (ArenaDrop) is presentation; duels only need its timing.
local preparedDrops, encounterDrops = {}, {}
local ArenaDrop = {
	duration = function()
		return 0
	end,
	prepare = function(p)
		preparedDrops[p] = true
	end,
	begin = function() end,
	cancel = function() end,
	encounter = function(members, foes, includeParty, background, groundedFoes)
		table.insert(encounterDrops, {
			Members = members,
			Foes = foes,
			IncludeParty = includeParty,
			Background = background,
			GroundedFoes = groundedFoes,
		})
	end,
}
