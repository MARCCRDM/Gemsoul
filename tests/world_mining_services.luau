-- Lifecycle/replication doubles, not an in-engine rendering test.
local now, objects, debris = 100, {}, {}
local function signal()
	local callbacks={}
	return {Connect=function(_,fn)
		local c={Connected=true}; function c:Disconnect() self.Connected=false end
		table.insert(callbacks,{fn,c}); return c
	end,Fire=function(_,...)
		for _,e in callbacks do if e[2].Connected then e[1](...) end end
	end}
end
vmt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__index=function(a,k) if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end end
Vector3.zero=Vector3.new(0,0,0)
CFrame.new=function(a,b,c) return setmetatable({Position=if type(a)=="table" then a else Vector3.new(a or 0,b or 0,c or 0),RightVector=Vector3.new(1,0,0)},cmt) end
CFrame.Angles=function() return CFrame.new() end
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local UDim2={new=function(...) return {...} end,fromScale=function(...) return {...} end}
local UDim={new=function(...) return {...} end}
local NumberRange={new=function(...) return {...} end}
local NumberSequence={new=function(...) return {...} end}
local ColorSequence={new=function(...) return {...} end}
local Random={new=function(seed)
	local value=seed
	return {NextNumber=function() value=value*48271%2147483647; return value/2147483647 end}
end}
local methods={}
local function new(kind)
	local data={ClassName=kind,Children={},Transparency=0}
	local o=setmetatable({}, {__index=function(_,k) return methods[k] or data[k] end,
	 __newindex=function(self,k,v)
		assert(not data.Destroyed or k=="Parent","Wrote destroyed "..kind)
		if k=="Parent" and v then table.insert(v.Children,self) end
		data[k]=v
	 end})
	table.insert(objects,o); return o
end
function methods:IsA(kind) return self.ClassName==kind or kind=="BasePart" and (self.ClassName=="Part" or self.ClassName=="WedgePart") end
function methods:GetChildren() local out={}; for _,c in self.Children do if c.Parent==self and not c.Destroyed then table.insert(out,c) end end; return out end
function methods:GetDescendants()
	local out={}; for _,c in self:GetChildren() do table.insert(out,c); for _,d in c:GetDescendants() do table.insert(out,d) end end; return out
end
function methods:Destroy()
	if self.Destroyed then return end
	for _,c in self:GetChildren() do c:Destroy() end
	self.Parent=nil; self.Destroyed=true
end
function methods:Clone()
	local clone=new(self.ClassName)
	for _,k in {"Name","Gem","Transparency","Scale","CanQuery","CanCollide","CanTouch","Anchored"} do clone[k]=self[k] end
	for _,c in self:GetChildren() do c:Clone().Parent=clone end
	return clone
end
function methods:ScaleTo(scale) self.Scale=scale end
function methods:PivotTo(cf) self.CFrame=cf end
function methods:Play() self.Played=true end
function methods:Emit(count) self.Emitted=count end
local Instance={new=new}
local workspace=new("Workspace")
workspace.CurrentCamera={CFrame=CFrame.new()}
function workspace:GetServerTimeNow() return now end
local attrs,attrsSignals={Outpost=true},{}
local player={UserId=42,DisplayName="Observer"}
local playerGui=new("PlayerGui")
function player:WaitForChild(name) assert(name=="PlayerGui"); return playerGui end
local root={Position=Vector3.zero}
player.Character={FindFirstChild=function() return root end}
function player:GetAttribute(k) return attrs[k] end
function player:GetAttributeChangedSignal(k) attrsSignals[k]=attrsSignals[k] or signal(); return attrsSignals[k] end
function player:SetAttribute(k,v) attrs[k]=v; if attrsSignals[k] then attrsSignals[k]:Fire() end end
local packets={}
local Remotes={MiningRoll={OnClientEvent=signal()}}
function Remotes.MiningRoll:FireAllClients(packet) table.insert(packets,packet); self.OnClientEvent:Fire(packet) end
function Remotes:WaitForChild(k) return self[k] end
local services={Players={LocalPlayer=player},ReplicatedStorage={WaitForChild=function() return Remotes end},RunService={RenderStepped=signal()},
 Debris={AddItem=function(_,o,t) table.insert(debris,{o,now+t}) end}}
local remotePlayers={}
function services.Players:GetPlayerByUserId(id) return remotePlayers[id] end
local game={GetService=function(_,k) return services[k] end}
local GemArt={model=function(gem)
	local model,part=new("Model"),new("Part")
	model.Gem=gem; part.Parent=model
	return model,1
end,pose=function() return CFrame.new() end}
function GemArt.setupViewport(viewport)
	local camera=new("Camera"); camera.Parent=viewport; viewport.CurrentCamera=camera
	return camera
end
local function step(seconds)
	now+=seconds
	services.RunService.RenderStepped:Fire(seconds)
	for i=#debris,1,-1 do if debris[i][2]<=now then debris[i][1]:Destroy(); table.remove(debris,i) end end
end
local function live(name)
	local found={}; for _,o in objects do if not o.Destroyed and o.Name==name then table.insert(found,o) end end; return found
end
local function liveClass(kind)
	local found={}; for _,o in objects do if not o.Destroyed and o.ClassName==kind then table.insert(found,o) end end; return found
end
local function textContains(fragment)
	for _,o in liveClass("TextLabel") do if string.find(o.Text,fragment,1,true) then return true end end
	return false
end
