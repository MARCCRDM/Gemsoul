local function signal()
	local callbacks = {}
	return { Connect=function(_,fn)
		local entry={fn,true}; table.insert(callbacks,entry)
		return {Disconnect=function() entry[2]=false end}
	end, Fire=function(_,...)
		for _,entry in callbacks do if entry[2] then entry[1](...) end end
	end }
end
local v2mt = {}
local Vector2 = {new=function(x,y) return setmetatable({X=x,Y=y},v2mt) end}
v2mt.__sub=function(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end
v2mt.__add=function(a,b) return Vector2.new(a.X+b.X,a.Y+b.Y) end
v2mt.__index=function(a,k) if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y) end end
Vector2.zero=Vector2.new(0,0)
local UDim2={fromOffset=Vector2.new,fromScale=Vector2.new,new=function(...) return {...} end}
local UDim={new=function(...) return {...} end}
local ColorSequence={new=function(...) return {...} end}
colorMt.__index.ToHex=function() return "ffffff" end
local allUI={}
local function new(kind,props,parent)
	local o=props or {}
	o.Parent,o.Kind,o.Children=parent,kind,{}
	if o.Visible==nil then o.Visible=true end
	o.Activated,o.InputBegan=signal(),signal()
	o.MouseEnter,o.MouseLeave=signal(),signal()
	if parent then table.insert(parent.Children,o) end
	function o:IsA(k) return k==kind or (k=="GuiObject" and (kind=="Frame" or kind=="TextButton" or kind=="TextLabel" or kind=="ScrollingFrame")) end
	function o:GetChildren() local out={}; for _,c in self.Children do if c.Parent==self then table.insert(out,c) end end; return out end
	function o:Destroy() for _,c in self:GetChildren() do c:Destroy() end; self.Parent=nil end
	function o:SetAttribute() end
	function o:FindFirstChildOfClass() return nil end
	table.insert(allUI,o)
	return o
end
local IronUi={new=new,cross=function() return {} end}
local RunService={RenderStepped=signal()}
local game={GetService=function(_,name) return if name=="RunService" then RunService else {} end}
local GemArt={viewport=function() end}
local SurgeIcons={}
local Tech={Traits={traitsOf=function() return nil end}}
local GemRoller={levelLabel=function() return "T1 I" end}
local GemConfig={TierColors={},ElementColors={},TierLabels={},value=function(g) return g.Value or 1 end,
 shade=function(g) return {Name=g.Id} end,elementName=function(e) return e end}
local function gem(id) return {Id=id,Cut=5,Size=5,Clarity=5,Tier="Common",Element="Frost"} end
local loose, worn, core, spare, other, rough = gem("loose"),gem("worn"),gem("core"),gem("spare"),gem("other"),gem("rough")
rough.Cut=nil
local profile={Gems={loose,worn,core,spare,other,rough,loose},Character={Helmet="Helm",HelmetGem=worn,Surge2Gem=core,ItemGems={Boots={Spare=spare}}},
 Miners={Active=1,Slots={{Character={HelmetGem=loose}},{Character={ShieldGem=other}}}}}
local sold={}
local GemClient={Profile=profile,Changed=signal(),request=function(...) table.insert(sold,{...}); return {Ok=true,Message="Sold"} end}
local Crafting={marketPrice=function(g) return g.Value or 3 end}
local UiKit={toast=function() end}
local task={delay=function() end,spawn=function(fn,...) fn(...) end}
local checks=0
local function check(ok,message) checks+=1; assert(ok,message) end
check(#GemInventory.available(profile)==2,"Socketed or duplicate stones appeared in pouch")
check(GemInventory.find(profile,"loose")==loose,"Stale active miner snapshot hid unsocketed gem")
check(GemInventory.find(profile,"other")==nil,"Other miner's stone offered again")
check(#GemInventory.available(nil)==0,"Missing profile failed")
-- VAULT MODULE
local gui=new("ScreenGui",{Enabled=true,IgnoreGuiInset=true})
local canvas=new("Frame",{},gui)
local beginFromVault
GemVault.open(canvas,nil,function(g,input) beginFromVault(g,input) end)
check(#GemVault.entries()==2,"Vault listed enchanted stones")
local function liveUI(name)
	for i=#allUI,1,-1 do local o=allUI[i]; if o.Parent and o.Name==name then return o end end
end
local function hasText(value)
	for _,o in allUI do if o.Parent and o.Text==value then return true end end
	return false
end
check(hasText("2 AVAILABLE STONES"),"Available count is wrong")
-- SELL COMMONS: every spare Common (loose, no loadout naming it), its worth,
-- sold on a second tap.
check(#GemInventory.spare(profile,"Common")==2 and #GemInventory.spare(profile,"Rare")==0,"Spare Commons wrong")
profile.Presets={Weapon={{Surges={Q="loose"}}},Armor={}}
check(#GemInventory.spare(profile,"Common")==1,"A loadout's gem counted as spare")
profile.Presets=nil
local sellButton
for _,o in allUI do if o.Parent and o.Text=="SELL 2 COMMONS · ◆ 6" then sellButton=o end end
check(sellButton~=nil and sellButton.Visible,"No SELL COMMONS button with the count and worth")
sellButton.Activated:Fire()
check(#sold==0 and sellButton.Text=="TAP AGAIN: SELL 2","One tap sold, or didn't ask again")
sellButton.Activated:Fire()
check(#sold==1 and sold[1][1]=="SellSpare" and sold[1][2]=="Common","The second tap didn't sell the Commons")
local ui={Grid=new("ScrollingFrame",{ScrollingEnabled=true},canvas),List=new("Frame",{},canvas),Detail=new("Frame",{Visible=false},canvas)}
local C={Ink=Color3.new(0,0,0),Gold=Color3.new(1,1,0)}
local state={Active=true,Detail=nil}
local InventoryV2={}
local UserInputService={InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
local mouse=Vector2.new(10,10)
function UserInputService:GetMouseLocation() return mouse end
local GuiService={GetGuiInset=function() return Vector2.zero end}
local now=10
local os={clock=function() return now end}
local function profileNow() return profile end
local function loadoutNow() return profile.Character end
local Traits={active=function() return true end,traitFor=function(g,key) return if g.Cut then key else nil end,KeyOfSocket={Weapon="Q",Armor="E",Shield="R"}}
local KEY_COLORS={Q=Color3.new(1,0.5,0.3),E=Color3.new(0.5,0.7,1),R=Color3.new(0.5,0.9,0.6)}
local HEAVY=Enum.Font.GothamBlack
local KEYS={"Q","E","R"}
local requests={}
local function request(...) table.insert(requests,{...}) end
local dropTargets={}
-- SOCKET RULES
local function round() end
local function stroke() return {} end
local function gemArt() end
local function frame(parent) return new("Frame",{},parent) end
local function draw() end
-- DRAG HANDLERS
beginFromVault=InventoryV2.beginGemDrag
for i,slot in {"Helmet","Armor","Gloves","Boots","Weapon","Shield","Q","E","R"} do
	if not table.find(KEYS,slot) then profile.Character[slot]="Gear" end
	local target=new("Frame",{AbsolutePosition=Vector2.new(i*100,100),AbsoluteSize=Vector2.new(90,70)},canvas)
	table.insert(dropTargets,{Frame=target,Stroke={Color=C.Gold,Transparency=1,Thickness=1},
	 Accepts=function(item) return if table.find(KEYS,slot) then acceptsKey(slot,item) else acceptsSlot(slot,item) end,
	 Drop=function(item) socketInto(slot,item) end})
end
local function start(g)
	now+=1; mouse=Vector2.new(10,10)
	InventoryV2.beginGemDrag(g or loose,{UserInputType=Enum.UserInputType.MouseButton1})
end
local function move(x,y)
	mouse=Vector2.new(x,y); UserInputService.InputChanged:Fire({UserInputType=Enum.UserInputType.MouseMovement})
end
local function finish(cancelled)
	UserInputService.InputEnded:Fire({UserInputType=Enum.UserInputType.MouseButton1,UserInputState=if cancelled then Enum.UserInputState.Cancel else nil})
end
-- Actual vault cell press goes through the public bridge; rough gems cannot start a drag.
local grid=liveUI("GemList")
local cells={}; for _,o in grid:GetChildren() do if o.Name=="GemCell" then table.insert(cells,o) end end
cells[1].InputBegan:Fire({UserInputType=Enum.UserInputType.MouseButton1})
check(drag~=nil,"Vault input did not begin gem drag")
move(130,130)
check(not GemVault.isOpen() and ui.List.Visible and not ui.Detail.Visible,"Vault hid drop targets during drag")
check(drag.Active and not ui.Grid.ScrollingEnabled,"Drag did not lift stone/lock scroll")
finish()
check(#requests==1 and requests[1][1]=="SocketGem" and requests[1][3]=="Helmet","Vault drag did not socket helmet")
check(ui.Grid.ScrollingEnabled and drag==nil,"Release failed cleanup")
for i,target in dropTargets do
	start(); move(i*100+20,120); finish()
	check(#requests==i+1,"Equipment/key drop was lost")
	check(requests[#requests][1]==(if i<=6 then "SocketGem" else "SocketSurge"),"Wrong socket action")
end
local before=#requests
start(); finish(); check(#requests==before,"Click enchanted without drag")
start(); move(13,12); finish(); check(#requests==before,"Pointer jitter enchanted")
start(rough); check(drag==nil,"Uncut stone draggable")
start(worn); check(drag==nil,"Already enchanted stone draggable")
start(); move(20,600); finish(); check(#requests==before,"Drop outside gear enchanted")
dropTargets[1].Frame.Visible=false
start(); move(120,120); finish(); check(#requests==before,"Hidden equipment accepted a drop")
dropTargets[1].Frame.Visible=true
local originalPosition,originalSize=dropTargets[1].Frame.AbsolutePosition,dropTargets[1].Frame.AbsoluteSize
dropTargets[1].Frame.AbsolutePosition,dropTargets[1].Frame.AbsoluteSize=Vector2.new(50,50),Vector2.new(45,35)
check(targetAt(Vector2.new(60,60),{Kind="Gem",Gem=loose})==dropTargets[1],"Scaled UI missed target")
check(targetAt(Vector2.new(96,60),{Kind="Gem",Gem=loose})==nil,"Scaled UI accepted outside target")
dropTargets[1].Frame.AbsolutePosition,dropTargets[1].Frame.AbsoluteSize=originalPosition,originalSize
start(); move(120,120); finish(true); check(#requests==before,"Cancelled input enchanted")
start(); move(120,120); UserInputService.WindowFocusReleased:Fire(); finish(); check(#requests==before,"Lost focus enchanted")
start(); move(120,120); profile.Character.WeaponGem=loose; finish(); check(#requests==before,"Stale stone enchanted twice")
profile.Character.WeaponGem=nil
start(); move(120,120); gui.Enabled=false; finish(); check(#requests==before,"Hidden inventory enchanted")
gui.Enabled=true
local touch={UserInputType=Enum.UserInputType.Touch,Position=Vector2.new(10,10)}
InventoryV2.beginGemDrag(loose,touch)
local otherTouch={UserInputType=Enum.UserInputType.Touch,Position=Vector2.new(120,120)}
UserInputService.InputChanged:Fire(otherTouch); UserInputService.InputEnded:Fire(otherTouch)
check(drag~=nil and not drag.Active,"Second finger stole drag")
touch.Position=Vector2.new(120,120)
UserInputService.InputChanged:Fire(touch); UserInputService.InputEnded:Fire(touch)
check(#requests==before+1,"Touch drag did not socket")
-- A successful socket disappears; removing it makes it available again.
GemVault.open(canvas)
profile.Character.WeaponGem=loose
GemClient.Changed:Fire()
check(#GemVault.entries()==1 and hasText("1 AVAILABLE STONES"),"Socketed stone stayed in vault after update")
profile.Character.WeaponGem=nil
GemClient.Changed:Fire()
check(#GemVault.entries()==2,"Removed stone failed to return")
profile.Gems={worn,core,spare,other}
GemClient.Changed:Fire()
check(#GemVault.entries()==0 and hasText("0 AVAILABLE STONES"),"All-socketed inventory did not empty")
check(hasText("No loose stones. Equipped stones stay on your gear."),"Empty inventory lacks useful guidance")
GemVault.close()
-- Render the actual equipment row in empty, filled and unworn states.
local RIGHT_W,HEADING=420,Enum.Font.GothamBold
C.Faint,C.Text,C.Line=Color3.new(.3,.3,.3),Color3.new(1,1,1),Color3.new(1,1,1)
local NumberSequence={new=function(...) return {...} end}
local function place(o,x,y,w,h) o.Position=UDim2.fromOffset(x,y); o.Size=UDim2.fromOffset(w,h); return o end
local function text(parent,value) return new("TextLabel",{Text=value},parent) end
local function openDetail() end
local function gearOf(loadout,slot) return if loadout[slot] then {Name="Frontier Scout Helm"} else nil end
local function rarityOf() return 1 end
local function rarityColor() return C.Text end
local function rarityName() return "COMMON" end
local function perkOf() return nil end
local function triadOn() return false end
local function gemColor() return C.Gold end
local function gearArt() end
local function clear(o) for _,c in o:GetChildren() do c:Destroy() end end
local SLOT_NAME={Helmet="HELMET"}
local TweenInfo={new=function() end}
local TweenService={Create=function() return {Play=function() end} end}
local task={delay=function() end}
-- ROW BUILD
-- ROW DRAW
ui.Rows={Helmet=buildRow(ui.List,"Helmet",26)}
local row=ui.Rows.Helmet
drawRows({Helmet="Helm"})
check(row.Enchant.Visible and row.Halo.Visible and row.Plus.Visible,"Empty socket missing enchant/glow cues")
check(row.Enchant.Text=="ADD STONE TO ENCHANT  ·  DRAG & DROP","Missing drag instructions")
check(row.Edge.Transparency<1 and row.Ring.Color==C.Gold,"Empty equipment not highlighted")
check(row.Name.Position.Y<row.Meta.Position.Y and row.Meta.Position.Y<row.Enchant.Position.Y,"Empty row text overlaps")
drawRows({Helmet="Helm",HelmetGem=worn})
check(not row.Enchant.Visible and not row.Halo.Visible and not row.Plus.Visible,"Filled socket still asks for enchantment")
drawRows({})
check(not row.Enchant.Visible and not row.Halo.Visible,"Missing equipment advertised an unavailable socket")
print("PASS: "..checks.." available gem, vault and inventory drag checks")
