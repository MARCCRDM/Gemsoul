-- The tutorial is off here: these checks drive the starter picker it replaces.
local Tutorial = { Enabled = false }
local now=0
local os={clock=function() return now end}
local function signal()
 local listeners={}
 local event={}
 function event:Connect(fn)
  local connection={Connected=true}
  function connection:Disconnect() self.Connected=false end
  table.insert(listeners,{Fn=fn,Connection=connection})
  return connection
 end
 function event.Fire(...) for _,entry in listeners do if entry.Connection.Connected then entry.Fn(...) end end end
 return event
end
local v2mt={}
v2mt.__add=function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y},v2mt) end
v2mt.__sub=function(a,b) return setmetatable({X=a.X-b.X,Y=a.Y-b.Y},v2mt) end
local Vector2={new=function(x,y) return setmetatable({X=x,Y=y},v2mt) end}
Vector2.zero=Vector2.new(0,0)
local UDim={new=function(scale,offset) return {Scale=scale or 0,Offset=offset or 0} end}
local UDim2={new=function(xs,xo,ys,yo) return {X={Scale=xs or 0,Offset=xo or 0},Y={Scale=ys or 0,Offset=yo or 0}} end}
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
UDim2.fromOffset=function(x,y) return UDim2.new(0,x,0,y) end
local ColorSequence={new=function(...) return {...} end}
local NumberSequence={new=function(...) return {...} end}
local NumberSequenceKeypoint={new=function(...) return {...} end}
local TweenInfo={new=function() return {} end}
-- task.delay keeps its calls: they run only when a test runs them, in time
-- order, up to a time (runDelayed).
local delayed={}
local task={delay=function(seconds,fn,...) table.insert(delayed,{At=now+seconds,Fn=fn,Args={...}}) end}
local function runDelayed(upTo)
 while true do
  local first,at=nil,nil
  for i,d in delayed do if d.At<=upTo and (first==nil or d.At<delayed[first].At) then first=i end end
  if not first then return end
  at=table.remove(delayed,first)
  now=math.max(now,at.At)
  at.Fn(table.unpack(at.Args))
 end
end
local objects={}
local function new(class,props,parent)
 local object={ClassName=class,children={},signals={},Activated=signal(),Destroying=signal(),MouseEnter=signal(),MouseLeave=signal(),AbsoluteSize=Vector2.new(1000,700),AbsolutePosition=Vector2.zero,CanvasPosition=Vector2.zero}
 function object:GetChildren() return table.clone(self.children) end
 function object:GetPropertyChangedSignal(key) self.signals[key]=self.signals[key] or signal(); return self.signals[key] end
 function object:IsA(key) return self.ClassName==key end
 function object:SetAttribute(key,value) self["@"..key]=value end
 function object:Destroy()
  if self.Destroyed then return end
  self.Destroyed=true
  self.Destroying.Fire()
  for _,child in self.children do child:Destroy() end
  self.Parent=nil
 end
 for k,v in props or {} do object[k]=v end
 object.Parent=parent
 if parent then table.insert(parent.children,object) end
 table.insert(objects,object)
 return object
end
local run={RenderStepped=signal()}
local input={InputBegan=signal()}
local tween={Create=function(_,obj,_,props) return {Play=function() for k,v in props do obj[k]=v end end} end}
-- No splash intro in the test: the launch intro starts straight away.
local players={LocalPlayer={PlayerGui={FindFirstChild=function() return nil end}}}
-- The onboarding funnel's remote: the steps the picker reports.
local funnelSteps={}
local funnelRemote={FireServer=function(_,step) table.insert(funnelSteps,step) end}
local remoteFolder={FindFirstChild=function(_,name) return if name=="Funnel" then funnelRemote else nil end}
local replicated={FindFirstChild=function(_,name) return if name=="Remotes" then remoteFolder else nil end}
local services={RunService=run,TweenService=tween,UserInputService=input,ReplicatedStorage=replicated,Players=players}
local game={GetService=function(_,id) return services[id] end}
local UiKit={gui=function(name) return new("ScreenGui",{Name=name}) end,round=function() end,toast=function() end}
local IronUi={new=new}
local Icons={apply=function(target,move) target.IconMove=move.Name; return true end}
local sounds={}
local UiSound={play=function(name) table.insert(sounds,name) end}
local humming=false
local LotterySound={
 stop=function() end,
 play=function(name) table.insert(sounds,"Lottery:"..name) end,
 tick=function() table.insert(sounds,"Lottery:Tick") end,
 reveal=function(rank) table.insert(sounds,"Lottery:Reveal"..rank) end,
 hum=function(on) humming=on end,
}
local drawn={}
local Art={}
function Art.show(parent,gem,slot)
 for _,child in parent:GetChildren() do if child:IsA("ViewportFrame") then child:Destroy() end end
 local view=new("ViewportFrame",{},parent)
 if slot then table.insert(drawn,{Slot=slot,Card=parent.Parent.ClassName=="TextButton"}) end
 return {View=view,Camera=new("Camera",{FieldOfView=34}),Gem=gem}
end
function Art.pose(record) assert(record.View.Parent,"Animating a destroyed preview") end
-- The starter roll's card effects (ElementCardFX).
local CardFX={Themes={},create=function() return {} end,update=function() end}
-- The kaiju starter roll after the gem roll (KaijuRoll): straight on here.
local KaijuRoll={play=function(after) if after then after() end end}
-- The loading screen the intro hands over to when it closes (LoadingFlow).
local held={}
local LoadingFlow={home="Outpost",hold=function(name) table.insert(held,name) end}
-- The starter reel's 3D gems (GemArt): a model, its view's camera, its pose.
local reelModels=0
local GemArt={
 model=function(gem) reelModels+=1; local m=new("Model",{Name="Gem",Gem=gem}); function m:PivotTo() end; return m,1 end,
 pose=function() return CFrame.new() end,
 setupViewport=function(view) return new("Camera",{},view) end,
 cardDistance=function(radius) return radius*3 end,
}
local Slots={Definitions={},SurgeDefinitions={}}
local class={}
local character={Class="Warrior",GearRolls={}}
for _,slot in Lottery.GearOrder do
 Slots.Definitions[slot]={Label=slot,Kind=slot.."s"}
 class[slot.."s"]={{Name=slot.." Gear",Id=slot.."Gear"}}
 character[slot]=slot.."Gear"
end
for i=1,3 do Slots.SurgeDefinitions["Surge"..i]={Label="Gem Surge "..i} end
local Classes={get=function() return class end,gear=function(_,_,id) return {Name=id,ArmorFamily="Prospector"} end}
local color=Color3.new(0.3,0.7,0.9)
local GearRolls={Rarities={{Name="Rare",Color=color}}}
local GemConfig={Elements={"Fire","Frost","Shock","Poison"},ElementLabels={Fire="Thermal",Frost="Cryo",Shock="Ion",Poison="Corrosive"},ElementColors={Fire=color,Frost=color,Shock=color,Poison=color},TierLabels={Common="Common",Uncommon="Uncommon"},TierColors={Common=color,Uncommon=color},shade=function(gem) return {Name=gem.Element.." gem"} end}
function GemConfig.elementName(element) return GemConfig.ElementLabels[element] or element end
-- Every rarity, each its own colour, and a shade name per element and rarity
-- (the starter roll's reel shows them all).
GemConfig.TierOrder={"Common","Uncommon","Rare","UltraRare","Legendary"}
GemConfig.Shades={}
for i,tier in GemConfig.TierOrder do
 GemConfig.TierLabels[tier]=GemConfig.TierLabels[tier] or tier
 GemConfig.TierColors[tier]=Color3.new(i/5,1-i/5,0.5)
end
for _,element in GemConfig.Elements do
 GemConfig.Shades[element]={}
 for _,tier in GemConfig.TierOrder do table.insert(GemConfig.Shades[element],{Tier=tier,Name=element.." "..tier}) end
end
local profile={Intro={Done=false},Character=character,Gems={}}
local count=0
local reward=nil
local requests,prepareArgs={},nil
local failPrepare,failFinish=false,false
local GemClient={Profile=profile,Changed=signal()}
-- The real server keeps the first choice; a retry never rerolls it.
function GemClient.request(action,...)
 table.insert(requests,action)
 if action=="PrepareStarterLottery" then
  prepareArgs={...}
  if failPrepare then return {Ok=false,Message="Retry"} end
  prepareArgs={...}
  reward=Lottery.prepareChoice(profile,prepareArgs[1],prepareArgs[2],function(element) count+=1; return {Id="g"..count,Element=element,Tier="Common"} end)
  return {Ok=reward~=nil,Message="Retry",Lottery=reward}
 end
 if failFinish then return {Ok=false,Message="Retry claim"} end
 return {Ok=Lottery.finish(profile,200)}
end
local function find(className,text)
 for _,obj in objects do if not obj.Destroyed and obj.ClassName==className and (text==nil or obj.Text==text) then return obj end end
 error("Missing "..className.." / "..tostring(text))
end
local checks=0
local function check(ok,message) checks+=1; assert(ok,message) end
local function step(seconds)
 for _=1,math.ceil(seconds*10) do now+=0.1; run.RenderStepped.Fire(0.1) end
end
