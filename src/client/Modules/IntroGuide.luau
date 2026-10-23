--[[
	After the intro's first fight (real player or bot), the yellow floor
	arrows (GroundGuide) walk a new player through the Outpost, once:

	  1. Mech     to the nearest free mech, until they're in one (MechPilot)
	  2. Mine     to the nearest common rock near the outpost, then the next,
	              until they've mined MineRocks of them
	  3. Out      outward from where they are, a stretch at a time, toward
	              the outskirts (Outskirts studs from the middle: past the
	              core, where the richer rocks start), fading as they get
	              there, and gone

	The server sets IntroGuide on them as the first fight ends (Server
	Duels); it's only ever set that once. Given up after GiveUp seconds.

	  IntroGuide.start()                   once (Lobby.client)
	  IntroGuide.step(state, view) -> (Vector3?, number)   where to lead now
	                                       and how bright; moves state.Stage
	                                       on (pure)
	  IntroGuide.outward(center, at, reach) -> Vector3     a stretch further
	                                       out from `center` past `at` (pure)
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Frontier = require(ReplicatedStorage.Shared.Frontier)
local Outpost = require(ReplicatedStorage.Shared.Outpost)

local IntroGuide = {}

IntroGuide.MineRocks = 3 -- rocks to mine before heading out
IntroGuide.Near = 120 -- the rocks it leads to are this close (studs)
IntroGuide.Hit = 24 -- a rock losing health this close to you (a mech is big): you mined it
IntroGuide.Outskirts = Frontier.Core + 30 -- where it leaves them
IntroGuide.Stretch = 35 -- how far ahead it leads each time, heading out
IntroGuide.FadeOver = 60 -- the last stretch, fading out
IntroGuide.GiveUp = 8 * 60
-- The plain rocks round the outpost.
IntroGuide.Commons = { Field = true, Common = true }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function IntroGuide.outward(center: Vector3, at: Vector3, reach: number): Vector3
	local away = flat(at - center)
	local dir = if away.Magnitude > 0.5 then away.Unit else Vector3.new(1, 0, 0)
	local r = math.min(away.Magnitude + IntroGuide.Stretch, reach)
	return Vector3.new(center.X, at.Y, center.Z) + dir * r
end

local function nearest(at: Vector3, spots: { Vector3 }, within: number?): Vector3?
	local best, bestDistance = nil, within or math.huge
	for _, spot in spots do
		local d = flat(spot - at).Magnitude
		if d < bestDistance then
			best, bestDistance = spot, d
		end
	end
	return best
end

--[[
	state  { Stage: "Mech" | "Mine" | "Out" | "Done", Mined: number }
	view   { At: Vector3, Center: Vector3, Piloting: boolean,
	         Mechs: { Vector3 } (free ones), Rocks: { Vector3 } (common ones
	         not yet mined) }
]]
function IntroGuide.step(state, view): (Vector3?, number)
	if state.Stage == "Mech" then
		if view.Piloting or #view.Mechs == 0 then
			state.Stage = "Mine"
		else
			return nearest(view.At, view.Mechs), 1
		end
	end
	if state.Stage == "Mine" then
		local rock = if state.Mined < IntroGuide.MineRocks then nearest(view.At, view.Rocks, IntroGuide.Near) else nil
		if rock then
			return rock, 1
		end
		state.Stage = "Out"
	end
	if state.Stage == "Out" then
		local r = flat(view.At - view.Center).Magnitude
		if r >= IntroGuide.Outskirts then
			state.Stage = "Done"
			return nil, 0
		end
		local strength = math.clamp((IntroGuide.Outskirts - r) / IntroGuide.FadeOver, 0, 1)
		return IntroGuide.outward(view.Center, view.At, IntroGuide.Outskirts + 10), strength
	end
	return nil, 0
end

-- In the game ---------------------------------------------------------------------------------------------

local started = false
function IntroGuide.start()
	if started then
		return
	end
	started = true
	local GroundGuide = require(script.Parent.GroundGuide)
	GroundGuide.start()
	local me = Players.LocalPlayer
	local state = nil
	local since = 0
	local mined: { [Instance]: boolean } = {}
	local watching: { [Instance]: RBXScriptConnection } = {}
	local center = Outpost.Location.Position
	local mechs: { Vector3 }, rocks: { Vector3 } = {}, {}
	local rescanAt = 0

	local function rootPart(): BasePart?
		local character = me.Character
		return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	local function rockAt(rock: Instance): Vector3?
		local part = if rock:IsA("Model") then rock.PrimaryPart else nil
		return part and part.Position
	end
	-- A rock you take a swing at counts as mined.
	local function watch(rock: Instance)
		if watching[rock] then
			return
		end
		local last = rock:GetAttribute("Hp")
		watching[rock] = rock:GetAttributeChangedSignal("Hp"):Connect(function()
			local hp = rock:GetAttribute("Hp")
			local root, at = rootPart(), rockAt(rock)
			if
				state
				and (state.Stage == "Mine" or state.Stage == "Mech")
				and not mined[rock]
				and type(hp) == "number"
				and type(last) == "number"
				and hp < last
				and root
				and at
				and (root.Position - at).Magnitude < IntroGuide.Hit
			then
				mined[rock] = true
				state.Mined += 1
				rescanAt = 0
			end
			last = hp
		end)
	end
	local function stop()
		state = nil
		for _, connection in watching do
			connection:Disconnect()
		end
		table.clear(watching)
		GroundGuide.clear("Intro")
	end

	local said = {}
	local function say(stage: string)
		if said[stage] then
			return
		end
		said[stage] = true
		local line = if stage == "Mech"
			then "Hop in a mech: follow the arrows."
			elseif stage == "Mine" then "Mine a few rocks: drive into them."
			elseif stage == "Out" then "Richer rocks lie further out. Head out."
			else nil
		if line then
			require(script.Parent.UiKit).toast(line)
		end
	end

	GroundGuide.set("Intro", function()
		if not state or me:GetAttribute("Outpost") ~= true or me:GetAttribute("FirstFight") then
			return nil
		end
		if os.clock() - since > IntroGuide.GiveUp then
			stop()
			return nil
		end
		local root = rootPart()
		if not root then
			return nil
		end
		-- (The free mechs and the rocks, looked over twice a second.)
		local now = os.clock()
		if now >= rescanAt then
			rescanAt = now + 0.5
			mechs, rocks = {}, {}
			for _, model in CollectionService:GetTagged("OutpostMech") do
				if model:IsA("Model") and model:GetAttribute("MechPilotId") == nil and model.Parent then
					table.insert(mechs, model:GetPivot().Position)
				end
			end
			for rock, connection in watching do
				if not rock.Parent then
					connection:Disconnect()
					watching[rock] = nil
				end
			end
			if state.Stage == "Mine" or state.Stage == "Mech" then
				for _, rock in CollectionService:GetTagged("OutpostNode") do
					local at = rockAt(rock)
					if at and not mined[rock] and IntroGuide.Commons[rock:GetAttribute("Zone") or ""] then
						watch(rock)
						table.insert(rocks, at)
					end
				end
			end
		end
		local to, strength = IntroGuide.step(state, {
			At = root.Position,
			Center = center,
			Piloting = me:GetAttribute("MechPilot") ~= nil,
			Mechs = mechs,
			Rocks = rocks,
		})
		say(state.Stage)
		if state.Stage == "Done" then
			stop()
		end
		return to, strength
	end, 0)

	local function begin()
		if state or me:GetAttribute("IntroGuide") ~= true then
			return
		end
		state = { Stage = "Mech", Mined = 0 }
		since = os.clock()
	end
	me:GetAttributeChangedSignal("IntroGuide"):Connect(begin)
	begin()
end

return IntroGuide
