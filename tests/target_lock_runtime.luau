local now, bound, changed, lerps = 10, nil, nil, 0
local os = {clock=function() return now end}
vmt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__div=function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
vmt.__index=function(v,key)
 if key=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if key=="Unit" then return v/v.Magnitude end
 if key=="Dot" then return function(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
Enum.RenderPriority={Camera={Value=200}}
local function pose(position,look)
 return {Position=position,LookVector=look,Lerp=function(_,target,alpha) assert(alpha>0 and alpha<1); lerps+=1; return target end}
end
CFrame.lookAt=function(position,target) return pose(position,(target-position).Unit) end
local camera={CFrame=pose(Vector3.new(600,0,0),Vector3.new(0,0,-1)),WorldToViewportPoint=function(_,point) return {Z=10},true end}
local function model(position,enemy)
 local root={Position=position,Size=Vector3.new(2,2,2)}
 local hum={Health=100}
 local m={PrimaryPart=root,Root=root,Hum=hum,Enemy=enemy}
 function m:FindFirstChild(key) return if key=="HumanoidRootPart" then root else nil end
 function m:FindFirstChildOfClass(key) return if key=="Humanoid" then hum elseif key=="ForceField" and self.Protected then {} else nil end
 function m:GetAttribute(key) return if key=="Enemy" then self.Enemy else nil end
 function m:IsDescendantOf() return not self.Removed end
 return m
end
local own=model(Vector3.new(600,0,0),nil)
local dummy=model(Vector3.new(600,0,-8),"Dummy")
local player={Character=own,Neutral=true,GetAttribute=function() return true end,WaitForChild=function() return {} end}
local opponent={Character=model(Vector3.new(600,0,-4),nil),Neutral=true,GetAttribute=function(self) return self.OptedIn==true end}
local players={LocalPlayer=player,GetPlayers=function() return {player,opponent} end,GetPlayerFromCharacter=function(_,m) return if m==opponent.Character then opponent else nil end}
local blocked=false
local workspace={CurrentCamera=camera,FindFirstChild=function(_,key) return if key=="Enemies" then {GetChildren=function() return {dummy} end} else nil end,Raycast=function() return if blocked then {Instance={IsDescendantOf=function() return false end}} else nil end}
local input={MouseEnabled=true,Delta=Vector3.new(0,0,0),GetMouseDelta=function(self) return self.Delta end,InputChanged={Connect=function(_,fn) changed=fn end}}
local run={BindToRenderStep=function(_,name,priority,fn) assert(name=="SagaTargetLock" and priority==201); bound=fn end}
local ReplicatedStorage={}
local CollectionService={HasTag=function(_,m) return m.Vendor==true end}
local services={Players=players,RunService=run,UserInputService=input,ReplicatedStorage=ReplicatedStorage,CollectionService=CollectionService}
local game={GetService=function(_,name) return services[name] end}
local Combat={canFight=function() return true end,inArena=function() return true end}
local Actions={canPvP=function(_,_,a,b,c,d,sameTeam) return a and b and c==true and d==true and not sameTeam end}
local RaycastParams={new=function() return {} end}
