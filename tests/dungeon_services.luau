local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
CFrame.new = function(v)
	return { Position = v }
end
local serial = 0
HttpService.GenerateGUID = function()
	serial += 1
	return tostring(serial)
end
local Random = {
	new = function(seed)
		local state = seed or 53
		return {
			NextNumber = function(_,a,b) state=(state*16807)%2147483647; return (a or 0)+state/2147483647*((b or 1)-(a or 0)) end,
			NextInteger = function(_, a, b)
				state = (state * 16807) % 2147483647
				return a + state % (b - a + 1)
			end,
		}
	end,
}
local GemConfig = {
	elementName = function(e)
		return e
	end,
}
local Raids = {
	busy = function(p)
		return if p:GetAttribute("CombatSession") or p.Humanoid.Health <= 0 then "Busy" else nil
	end,
}
local worlds, spawned, removed = {}, {}, {}
local World = {
	build = function(id, rooms, origin)
		local w = { Folder = {
			Destroy = function(self)
				self.Destroyed = true
			end,
		}, Centers = {}, Gates = {} }
		for i, r in rooms do
			w.Centers[i] = origin + Vector3.new(r.X * 90, 0, r.Z * 90)
			w.Gates[i] = {
				Destroy = function(self)
					self.Destroyed = true
				end,
			}
		end
		worlds[id] = w
		return w
	end,
}
local failSpawn = false
Duelist.spawnDungeon = function(members, id, encounter)
	if failSpawn then
		return nil
	end
	local e = { Id = id, Encounter = encounter, Members = members }
	table.insert(spawned, e)
	return e
end
Duelist.removeDungeon = function(id)
	removed[id] = true
end
ArenaSessions.leave = function(p)
	if ArenaSessions.onDungeonLeave then
		ArenaSessions.onDungeonLeave(p)
	end
	p:SetAttribute("CombatSession", nil)
	p:SetAttribute("RaidId", nil)
end
local function tick(seconds)
	now += seconds
	for i = #delayed, 1, -1 do
		local d = delayed[i]
		if now >= d[1] then
			table.remove(delayed, i)
			d[2](table.unpack(d[3], 1, d[3].n))
		end
	end
	RunService.Heartbeat.Fire(seconds)
end
local nextPlayer = 100
local function squad(n)
	local list = {}
	for i = 1, n do
		nextPlayer += 1
		table.insert(list, makePlayer(nextPlayer, "Miner" .. nextPlayer))
	end
	local party = { Id = tostring(nextPlayer), Leader = list[1], Members = list, Ready = {} }
	for _, p in list do
		p.Name=p.DisplayName
		parties[p] = party
		party.Ready[p] = true
	end
	return list, party
end

local studioMode=false
RunService.IsStudio=function() return studioMode end

local permittedTester=nil
local Feedback={isOwner=function(p) return studioMode or p==permittedTester end}
game={CreatorType="Group",CreatorId=-1}
Enum={CreatorType={User="User"}}

World.buildOpen=function(id,rooms,origin)
 local world=World.build(id,rooms,origin)
 world.Origin=origin;world.Arrival=origin+Vector3.new(0,0,-225);world.Radius=Rules.OpenRadius
 return world
end
local awarded={}
PlayerData.newGemId=function() serial+=1;return "gem"..serial end
PlayerData.addGem=function(p,g) table.insert(awarded,{Player=p,Gem=g});return true end
os.time=function() return 100000 end
