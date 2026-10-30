--[[
	The loading screen between scenes (ReplicatedFirst.LoadingScreen): up
	before the view changes, down once what's behind it is ready to be seen.
	Without it, every change of place showed in pieces: the menu flashing
	between the title and the intro, the world half streamed in, the camera
	catching up, buildings and textures popping in.

	Covered (LoadingFlow.start watches for these):
	  ArenaExit   a fight ends: until you're back in the Outpost
	  Arena       a duel, raid or dungeon starts (the Arena's own drop has
	              its own screen, so not that)
	  Respawn     until you're back in the Outpost
	  Teleport    anything else that moves you far in one frame
	And by the scenes themselves: the title screen handing over (Splash),
	the starter intro closing (Intro), the Outpost and the mine.

	What's behind counts as ready once it's one of:
	  - a full-screen view of its own (the title, the intro once its images
	    are down, the Arena drop's screen), or
	  - the world: you're alive, in a scene (the Outpost, a fight, the mine),
	    where you were headed, on loaded ground, with the camera on you, not
	    still being moved, and its downloads finished (or AssetWait spent).
	Never shorter than Min, never longer than Max.

	  LoadingFlow.hold(reason, options) -> hold   cover until ready
	      options: Instant, FadeIn, Min, Max, Status, Force (cover even if a
	      full-screen view is up), Destination (() -> Vector3?), Until
	      (() -> boolean: not ready till it says so, e.g. the intro's cover
	      till the first fight starts; a full-screen view of its own still
	      takes over, and Max still ends it)
	      hold.cancel()   drop it now (a request that failed)
	  LoadingFlow.waitCovered(timeout?)   until the screen is fully up
	  LoadingFlow.waitClear(timeout?)     until it's gone
	  LoadingFlow.active()    the loading screen is wanted
	  LoadingFlow.home()      where you'll end up when free: the Outpost
	  LoadingFlow.ready(s)    pure: whether snapshot `s` is ready, and what
	                          to say while it isn't
	  LoadingFlow.step(now, look)   one frame of every hold (look(hold) ->
	                          snapshot; the game's own by default)
	  LoadingFlow.start()
	  LoadingFlow.progress(profile)  the screen's tips fit how far they've got
]]
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

-- The screen itself (ReplicatedFirst.LoadingScreen). The title, the lobby,
-- the Outpost and the mine all come through here, so this must never stop
-- them: if the screen is missing (a place synced without the new
-- ReplicatedFirst modules) or broken, the game carries on uncovered. (It
-- once waited for it forever, and the whole game sat there unstarted.)
local NO_SCREEN = {
	cover = function()
		return { Min = 0, release = function() end, status = function() end }
	end,
	active = function()
		return false
	end,
	covered = function()
		return true
	end,
	waitCovered = function() end,
	waitClear = function() end,
	progress = function() end,
	stage = function()
		return 1
	end,
	setStage = function() end,
}
local LoadingScreen = (function()
	local ok, loaded = pcall(function()
		-- (ReplicatedFirst arrives before any of this runs: a short wait is plenty.)
		local module = ReplicatedFirst:FindFirstChild("LoadingScreen")
			or ReplicatedFirst:WaitForChild("LoadingScreen", 2)
		return require(module :: ModuleScript)
	end)
	if ok and type(loaded) == "table" then
		return loaded
	end
	warn("[LoadingFlow] no loading screen (ReplicatedFirst.LoadingScreen missing or broken), carrying on without it")
	return NO_SCREEN
end)()

local LoadingFlow = {}

LoadingFlow.Min = 0.8 -- seconds a cover stays at least
LoadingFlow.Max = 12 -- and at most
LoadingFlow.AssetWait = 2.5 -- seconds, once all else is ready, for downloads to finish
LoadingFlow.SettleJump = 20 -- studs in one frame: being moved, not walking
LoadingFlow.Settle = 0.3 -- seconds after the last such move
LoadingFlow.TeleportJump = 100 -- studs in one frame: a jump nothing covered
LoadingFlow.ArriveRange = 80 -- studs from where you were headed
LoadingFlow.CameraRange = 80 -- studs between the camera and you
LoadingFlow.FullScreenWait = 3 -- seconds for a full-screen view's images

LoadingFlow.Statuses = {
	Title = "Entering the Outpost",
	Intro = "Getting your kit ready",
	Outpost = "Heading to the Outpost",
	ArenaExit = "Back to the Outpost",
	Arena = "Entering the arena",
	Respawn = "Respawning",
	Mine = "Descending into the mine",
	MineExit = "Back to the Outpost",
	Teleport = "Loading the area",
}

export type Snapshot = {
	Owned: boolean, -- a full-screen view of its own is up
	Alive: boolean,
	Scene: boolean, -- somewhere you belong (the Outpost, a fight, the mine...)
	Arrived: boolean, -- where you were headed
	Grounded: boolean, -- standing on loaded ground (or seated)
	Camera: boolean, -- the camera's on you
	Settling: boolean, -- still being moved
	Queue: number, -- downloads waiting
}

-- Whether what's behind the cover can be seen, and what to say while not
-- (nil: what it already says). Downloads are waited on in step.
function LoadingFlow.ready(s: Snapshot): (boolean, string?)
	if s.Owned then
		return true, nil
	end
	if not s.Alive then
		return false, "Waiting for your miner"
	end
	if not s.Scene or not s.Arrived then
		return false, nil
	end
	if not s.Grounded then
		return false, "Loading the area"
	end
	if not s.Camera or s.Settling then
		return false, "Landing"
	end
	return true, nil
end

local player = Players.LocalPlayer
local lastJumpAt = -math.huge

local function rootOf(): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if root and root:IsA("BasePart") then root else nil, humanoid
end

-- Where you'll be once you're free: the Outpost (the lobby), unless you're
-- in a fight, a dungeon, a raid, a match or an expedition.
function LoadingFlow.home(): Vector3?
	if not Config.MenuOnly then
		return nil
	end
	for _, name in { "CombatSession", "DungeonId", "RaidId", "MatchId", "Expedition" } do
		if player:GetAttribute(name) ~= nil then
			return nil
		end
	end
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local spawn = landmarks and landmarks:GetAttribute("OutpostSpawn")
	return if typeof(spawn) == "CFrame" then spawn.Position else nil
end

-- A full-screen view of its own: the title, or the intro once its images
-- are down (or FullScreenWait spent). One that's closing doesn't count.
local preloads: { [Instance]: { Since: number, Done: boolean } } = setmetatable({}, { __mode = "k" }) :: any
local function fullScreen(now: number): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	local title = playerGui:FindFirstChild("Splash")
	if title and title:IsA("ScreenGui") and title.Enabled and not title:GetAttribute("Closing") then
		return true
	end
	local intro = playerGui:FindFirstChild("Intro")
	if intro and intro:IsA("ScreenGui") and intro.Enabled and not intro:GetAttribute("Closing") then
		local state = preloads[intro]
		if not state then
			local entry = { Since = now, Done = false }
			preloads[intro] = entry
			state = entry
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync({ intro })
				end)
				entry.Done = true
			end)
		end
		return state.Done or now - state.Since >= LoadingFlow.FullScreenWait
	end
	return false
end

-- The Arena drop's own screen (ArenaDrop.client): its veil while the pod
-- is readied, then the drop itself.
local function dropping(): boolean
	local now = workspace:GetServerTimeNow()
	local preparing = player:GetAttribute("ArenaDropPreparing")
	local requested = player:GetAttribute("LocalInsertionPending")
	local ends = player:GetAttribute("ArenaDropUntil")
	return (type(preparing) == "number" and preparing > now)
		or (type(requested) == "number" and requested > now and type(ends) ~= "number")
		or (type(ends) == "number" and ends > now)
end

local function inScene(): boolean
	for _, name in { "CombatSession", "DungeonId", "RaidId", "MatchId", "Expedition" } do
		if player:GetAttribute(name) ~= nil then
			return true
		end
	end
	-- (The mine counts the Outpost too. Required here, not above: both of
	-- them require this.)
	local ok, active = pcall(function()
		return require(script.Parent.MineScene).isActive()
	end)
	return ok and active == true
end

local function grounded(root: BasePart, humanoid: Humanoid): boolean
	if humanoid.SeatPart then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	return workspace:Raycast(root.Position, Vector3.new(0, -60, 0), params) ~= nil
end

local function owned(now: number): boolean
	return fullScreen(now) or dropping()
end

-- The game, as a hold sees it.
function LoadingFlow.snapshot(hold: any?, now: number?): Snapshot
	local at = now or os.clock()
	local s: Snapshot = {
		Owned = owned(at),
		Alive = false,
		Scene = false,
		Arrived = false,
		Grounded = false,
		Camera = false,
		Settling = at - lastJumpAt < LoadingFlow.Settle,
		Queue = ContentProvider.RequestQueueSize,
	}
	local root, humanoid = rootOf()
	if not root or not humanoid or humanoid.Health <= 0 then
		return s
	end
	s.Alive = true
	s.Scene = inScene()
	local destination = hold and hold.Destination and hold.Destination()
	s.Arrived = destination == nil or (root.Position - destination).Magnitude <= LoadingFlow.ArriveRange
	s.Grounded = grounded(root, humanoid)
	local camera = workspace.CurrentCamera
	s.Camera = camera ~= nil and (camera.CFrame.Position - root.Position).Magnitude <= LoadingFlow.CameraRange
	return s
end

type Hold = {
	Reason: string,
	Cover: any,
	Started: number,
	Min: number,
	Max: number,
	Destination: (() -> Vector3?)?,
	Until: (() -> boolean)?,
	ReadyAt: number?,
	Done: boolean,
	cancel: () -> (),
}
local holds: { Hold } = {}

local function finish(hold: Hold)
	hold.Done = true
	hold.Cover.Min = 0 -- (the hold kept its own minimum)
	pcall(hold.Cover.release)
end

-- One frame of every hold: each comes down once it's been up Min and what's
-- behind it is ready (downloads too, up to AssetWait), or right away once a
-- full-screen view of its own has taken over; none stays past Max.
function LoadingFlow.step(now: number, look: ((Hold, number) -> Snapshot)?)
	for i = #holds, 1, -1 do
		local hold = holds[i]
		if hold.Done then
			table.remove(holds, i)
			continue
		end
		local read, s = pcall(look or LoadingFlow.snapshot, hold, now)
		if not read then
			-- (Can't tell: better the world than a screen stuck up.)
			finish(hold)
			table.remove(holds, i)
			continue
		end
		local ok, say = LoadingFlow.ready(s)
		if ok and not s.Owned and hold.Until then
			local fine, done = pcall(hold.Until)
			if fine and not done then
				ok = false
			end
		end
		if ok and not s.Owned then
			hold.ReadyAt = hold.ReadyAt or now
			if s.Queue > 0 and now - hold.ReadyAt < LoadingFlow.AssetWait then
				ok, say = false, "Loading the area"
			end
		elseif not ok then
			hold.ReadyAt = nil
		end
		if say then
			pcall(hold.Cover.status, say)
		end
		if s.Owned or (ok and now - hold.Started >= hold.Min) or now - hold.Started >= hold.Max then
			finish(hold)
			table.remove(holds, i)
		end
	end
end

local stepping = false
local function ensureStepping()
	if stepping then
		return
	end
	stepping = true
	RunService:BindToRenderStep("LoadingFlowHolds", Enum.RenderPriority.First.Value, function()
		LoadingFlow.step(os.clock())
		if #holds == 0 then
			stepping = false
			RunService:UnbindFromRenderStep("LoadingFlowHolds")
		end
	end)
end

function LoadingFlow.hold(reason: string, options: { [string]: any }?): Hold
	local o = options or {}
	local now = os.clock()
	local hold = {
		Reason = reason,
		Started = now,
		Min = o.Min or LoadingFlow.Min,
		Max = o.Max or LoadingFlow.Max,
		Destination = o.Destination,
		Until = o.Until,
		ReadyAt = nil,
		Done = false,
	} :: any
	-- Something of its own already covers the screen: nothing to do. (Nor
	-- if the screen won't go up: never in the way of what asked for it.)
	local covered, cover = false, nil
	local seen, ownView = pcall(owned, now)
	if LoadingScreen ~= NO_SCREEN and (o.Force or not (seen and ownView)) then
		covered, cover = pcall(LoadingScreen.cover, reason, {
			Status = o.Status or LoadingFlow.Statuses[reason] or "Loading",
			Instant = o.Instant,
			FadeIn = o.FadeIn,
			Min = 0,
			Max = hold.Max,
		})
	end
	if not covered or type(cover) ~= "table" then
		hold.Done = true
		hold.Cover = NO_SCREEN.cover()
		hold.cancel = function() end
		return hold
	end
	hold.Cover = cover
	function hold.cancel()
		if not hold.Done then
			finish(hold)
		end
	end
	table.insert(holds, hold)
	ensureStepping()
	return hold
end

function LoadingFlow.waitCovered(timeout: number?)
	pcall(LoadingScreen.waitCovered, timeout)
end

function LoadingFlow.waitClear(timeout: number?)
	pcall(LoadingScreen.waitClear, timeout)
end

-- How far the player has got, from their save, so the loading screen's tips
-- fit them (LoadingScreen.stage).
function LoadingFlow.progress(profile)
	if type(profile) ~= "table" then
		return
	end
	local outpost, duel = profile.Outpost, profile.Duel
	local level = 0
	pcall(function()
		local Tree = require(ReplicatedStorage.Shared.AugmentTree)
		level = Tree.level(profile.Augments and profile.Augments.XP or 0)
	end)
	pcall(function()
		LoadingScreen.setStage(LoadingScreen.stage({
			Mined = profile.Milestones and profile.Milestones.Mined == true,
			Rocks = outpost and outpost.Rocks or 0,
			Level = level,
			Fights = duel and duel.Played or 0,
		}))
	end)
end

function LoadingFlow.active(): boolean
	local ok, up = pcall(LoadingScreen.active)
	return ok and up == true
end

local started = false
function LoadingFlow.start()
	if started then
		return
	end
	started = true
	-- Fights: their start (unless the Arena drop has its own screen up) and
	-- their end, the way back to the Outpost.
	local fighting = player:GetAttribute("CombatSession") ~= nil
	player:GetAttributeChangedSignal("CombatSession"):Connect(function()
		local now = player:GetAttribute("CombatSession") ~= nil
		if now and not fighting then
			LoadingFlow.hold("Arena", { Instant = true })
		elseif fighting and not now then
			LoadingFlow.hold("ArenaExit", { Instant = true, Destination = LoadingFlow.home })
		end
		fighting = now
	end)
	-- A new body (not the first: joining has its own screen).
	local seenFirst = player.Character ~= nil
	player.CharacterAdded:Connect(function()
		if not seenFirst then
			seenFirst = true
			return
		end
		LoadingFlow.hold("Respawn", { Instant = true, Destination = LoadingFlow.home })
	end)
	-- The intro gone (Intro.client covers it as it closes; this is the
	-- backstop).
	local playerGui = player:WaitForChild("PlayerGui")
	playerGui.ChildRemoved:Connect(function(child)
		if child.Name == "Intro" and not LoadingFlow.active() then
			LoadingFlow.hold("Intro", { Instant = true, Destination = LoadingFlow.home })
		end
	end)
	-- Moved far in one frame with nothing covering it: cover it now, before
	-- the frame is drawn.
	local lastRoot: BasePart? = nil
	local lastAt = Vector3.zero
	RunService:BindToRenderStep("LoadingFlowJumps", Enum.RenderPriority.First.Value - 1, function()
		local root = rootOf()
		if root ~= lastRoot then
			lastRoot = root
			lastAt = if root then root.Position else Vector3.zero
			return
		end
		if not root then
			return
		end
		local at = root.Position
		local jump = (at - lastAt).Magnitude
		lastAt = at
		if jump > LoadingFlow.SettleJump then
			lastJumpAt = os.clock()
		end
		if jump > LoadingFlow.TeleportJump and not LoadingFlow.active() then
			LoadingFlow.hold("Teleport", { Instant = true })
		end
	end)
end

return LoadingFlow
