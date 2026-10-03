-- Clock, physics and remotes are deterministic; rules/handlers are the production modules.
local now = 100
local os = { clock = function() return now end }
local math = table.clone(math)
math.random = function() return 1 end -- disable random crit/stagger except when explicitly tested
local function typeof(v)
	if getmetatable(v) == vmt then return "Vector3" end
	return type(v)
end
vmt.__add = function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmt.__sub = function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__div = function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
vmt.__index = function(v,key)
	if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
	if key=="Unit" then return v/v.Magnitude end
	if key=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
Vector3.zero=Vector3.new(0,0,0)
local messages, playerList, registered, listeners = {}, {}, {}, {}
local function signal()
	local callbacks={}
	local event={Connect=function(_,fn) table.insert(callbacks,fn); return {Disconnect=function() end} end}
	function event.Fire(...) for _,fn in callbacks do fn(...) end end
	return event
end
local Players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function() return playerList end}
local arena=Vector3.new(600,0,0)
local landmarks={GetAttribute=function(_,key) return if key=="ArenaFloor" then arena elseif key=="ArenaRadius" then 30 else nil end}
local ReplicatedStorage={FindFirstChild=function(_,key) return if key=="Landmarks" then landmarks else nil end}
local RunService={Heartbeat=signal()}
local Debris={AddItem=function(_,obj,seconds) table.insert(listeners,{Object=obj,Seconds=seconds}) end}
local services={Players=Players,ReplicatedStorage=ReplicatedStorage,RunService=RunService,Debris=Debris}
local game={GetService=function(_,name) assert(services[name],name); return services[name] end}
local wallBlocks, wallDistance = false, nil
local workspace={
	FindFirstChild=function() return nil end,
	FindFirstChildWhichIsA=function() return nil end,
	Raycast=function() return if wallBlocks then {Distance=2} else nil end,
	Blockcast=function() return if wallDistance then {Distance=wallDistance} else nil end,
	GetServerTimeNow=function() return os.clock() end,
}
CFrame.lookAt=function(position) return {Position=position} end
local RaycastParams={new=function() return {} end}
local Remotes={
	CombatInput={OnServerEvent=signal()},
	CombatFx={FireAllClients=function(_,...) table.insert(messages,{...}) end,FireClient=function(_,player,...) table.insert(messages,{Player=player,...}) end},
}
local Shop={register=function(name,fn) registered[name]=fn end,reply=function(ok,message) return {Ok=ok,Message=message} end}
local Config={MaxGems=200,MarketSellRate=0.5}
local enemyList={}
local Enemies={
	all=function() return enemyList end,
	damage=function(enemy,amount) enemy.Humanoid.Health-=amount; enemy.Hits=(enemy.Hits or 0)+1 end,
	addStatus=function(enemy,kind,amount,seconds) enemy.Status={kind,amount,seconds} end,
	addDot=function(enemy,amount) enemy.Burn=amount end,
}
