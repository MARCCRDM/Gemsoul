-- Mining and enchanting only. Uses real Outpost rocks and their normal click/E/tap input.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Tutorial = require(RS.Shared.Tutorial)
local ArmorSignatures = require(RS.Shared.ArmorSignatures)
local GemClient = require(script.Parent.Modules.GemClient)
local LobbyUI = require(script.Parent.Modules.LobbyUI)
local OutpostScene = require(script.Parent.Modules.OutpostScene)
local UiKit = require(script.Parent.Modules.UiKit)
local player = Players.LocalPlayer
if not Tutorial.Enabled then return end
local function current()
 local p = GemClient.Profile
 return p and Tutorial.beat(p)
end
local function new(kind, props, parent)
 local o = Instance.new(kind)
 for k,v in props do o[k]=v end
 o.Parent=parent
 return o
end
local GOLD = Color3.fromRGB(255,205,95)
local function run()
 local runId = GemClient.Profile.Tutorial.Run
 local gui = new("ScreenGui", {Name="Tutorial", ResetOnSpawn=false, IgnoreGuiInset=true, DisplayOrder=60}, player.PlayerGui)
 -- Four non-interactive masks leave the highlighted target clickable.
 local masks = {}
 for i=1,4 do masks[i]=new("Frame",{BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=0.3, BorderSizePixel=0, Active=false},gui) end
 local frame = new("Frame",{BackgroundTransparency=1, Visible=false},gui)
 new("UIStroke",{Color=GOLD,Thickness=3},frame)
 local card = new("Frame",{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,52),Size=UDim2.fromOffset(480,116),BackgroundColor3=Color3.fromRGB(12,18,29),ZIndex=3},gui)
 UiKit.round(card,12)
 local title = new("TextLabel",{Position=UDim2.fromOffset(14,10),Size=UDim2.new(1,-28,0,32),BackgroundTransparency=1,TextColor3=GOLD,TextSize=20,Font=Enum.Font.GothamBold,TextWrapped=true,ZIndex=4},card)
 local body = new("TextLabel",{Position=UDim2.fromOffset(14,46),Size=UDim2.new(1,-28,0,62),BackgroundTransparency=1,TextColor3=Color3.fromRGB(235,242,250),TextSize=15,Font=Enum.Font.Gotham,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,ZIndex=4},card)
 local nextButton = new("TextButton",{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-28),Size=UDim2.fromOffset(220,44),BackgroundColor3=GOLD,Text="GOT IT",TextSize=18,Font=Enum.Font.GothamBold,Visible=false,ZIndex=5},gui)
 UiKit.round(nextButton,10)
 local skip = new("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,12),Size=UDim2.fromOffset(90,30),Text="SKIP",TextSize=14,BackgroundColor3=Color3.fromRGB(25,32,44),TextColor3=GOLD,ZIndex=5},gui)
 UiKit.round(skip,8)
 local marker = new("Highlight",{FillColor=GOLD,FillTransparency=0.7,OutlineColor=GOLD,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop},workspace)
 local arrow = new("TextLabel",{AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(240,40),BackgroundTransparency=1,TextColor3=GOLD,TextStrokeTransparency=0.2,TextSize=19,Font=Enum.Font.GothamBold,Visible=false,ZIndex=2},gui)
 local busy=false
 local function advance(id)
  if busy then return end
  busy=true
  task.spawn(function() GemClient.request("TutorialStep",id);busy=false end)
 end
 nextButton.Activated:Connect(function() local beat=current();if beat and beat.Id=="GemIntro" then advance(beat.Id) end end)
 skip.Activated:Connect(function() GemClient.request("TutorialSkip") end)
 local function rectangle(o,x,y,w,h)
  o.Position=UDim2.fromOffset(x,y);o.Size=UDim2.fromOffset(math.max(0,w),math.max(0,h))
 end
 local function spot(x,y,w,h)
  local size=gui.AbsoluteSize
  x=math.clamp(x,0,size.X);y=math.clamp(y,0,size.Y)
  w=math.min(w,size.X-x);h=math.min(h,size.Y-y)
  rectangle(masks[1],0,0,size.X,y)
  rectangle(masks[2],0,y+h,size.X,size.Y-y-h)
  rectangle(masks[3],0,y,x,h)
  rectangle(masks[4],x+w,y,size.X-x-w,h)
  rectangle(frame,x,y,w,h);frame.Visible=true
 end
 local lastSocket=nil
 local elapsed=0
 local connection=RunService.RenderStepped:Connect(function(dt)
  elapsed+=dt;if elapsed<0.1 then return end;elapsed=0
  local beat=current()
  if not beat or GemClient.Profile.Tutorial.Run~=runId then return end
  local size=gui.AbsoluteSize
  card.Size=UDim2.fromOffset(math.min(480,size.X-32),116)
  card.Position=UDim2.new(0.5,0,0,52)
  title.Text=if Input.TouchEnabled then beat.Mobile or beat.Prompt else beat.Prompt
  body.Text=beat.Detail or ""
  nextButton.Visible=beat.Id=="GemIntro"
  marker.Adornee=nil;arrow.Visible=false;frame.Visible=false
  for _,m in masks do m.Visible=true end
  local target
  if beat.Id=="Mine" then
   body.Text=string.format("%d / 3 gems found. Walk to the glowing rock; click, tap or press E repeatedly to break it.",GemClient.Profile.Tutorial.Mined)
   local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   local best, dist=nil,math.huge
   for _,rock in CollectionService:GetTagged("OutpostNode") do
    local part=rock.PrimaryPart
    local owner=rock:GetAttribute("ClaimedBy")
    if root and part and (rock:GetAttribute("Hp") or 0)>0 and (not owner or owner==player.UserId) then
     local d=(part.Position-root.Position).Magnitude
     if d<dist then best,dist=rock,d end
    end
   end
   if best then
    marker.Adornee=best
    local point,onScreen=workspace.CurrentCamera:WorldToViewportPoint(best.PrimaryPart.Position)
    arrow.Visible=true
    arrow.Position=UDim2.fromOffset(math.clamp(point.X,120,size.X-120),math.clamp(point.Y-70,185,size.Y-70))
    arrow.Text=if onScreen then string.format("▼  MINE HERE · %d studs",dist) else "TURN TOWARD THE GLOWING ROCK"
    if onScreen then spot(point.X-95,point.Y-90,190,180) else spot(size.X*0.15,size.Y*0.25,size.X*0.7,size.Y*0.65) end
   else
    body.Text="Looking for an available rock nearby…"
    for _,m in masks do m.Visible=false end
   end
  elseif beat.Id=="OpenInventory" then
   target=LobbyUI.tile("INVENTORY")
   if LobbyUI.dashboardOpen() then advance(beat.Id) end
  elseif beat.Id=="CloseInventory" then
   for _,o in player.PlayerGui:GetDescendants() do if o:IsA("GuiObject") and o:GetAttribute("TutorialSocket")=="CloseInventory" then target=o;break end end
   if not LobbyUI.dashboardOpen() then advance(beat.Id) end
  elseif beat.Id~="GemIntro" then
   local slot=({SocketArmor="Armor",SocketWeapon="Weapon",SocketShield="Shield"})[beat.Id]
   for _,o in player.PlayerGui:GetDescendants() do if o:IsA("GuiObject") and o:GetAttribute("TutorialSocket")==slot then target=o;break end end
   if Tutorial.met(GemClient.Profile,beat.Id) then
    if lastSocket~=beat.Id then
     lastSocket=beat.Id
     local c=GemClient.Profile.Character
     local kind=ArmorSignatures.Slots[slot]
     local roll=kind and c.GearRolls and c.GearRolls[kind] and c.GearRolls[kind][c[slot]]
     local name,effect=ArmorSignatures.describe(roll,c[slot.."Gem"])
     if name~="" then UiKit.toast(name..": "..effect,Color3.fromRGB(90,245,150)) end
    end
    advance(beat.Id)
   end
  end
  if beat.Id~="Mine" then
   if not LobbyUI.dashboardOpen() and string.sub(beat.Id,1,6)=="Socket" then
    target=LobbyUI.tile("INVENTORY")
    title.Text="Reopen Inventory to continue."
    body.Text="Your gems are saved. Open Inventory, then follow the highlighted gem and socket."
   end
   if target and target.AbsoluteSize.X>0 and (LobbyUI.dashboardOpen() or beat.Id=="OpenInventory" or string.sub(beat.Id,1,6)=="Socket") then
    local p,s=target.AbsolutePosition,target.AbsoluteSize
    local x,y,w,h=p.X-8,p.Y-8,s.X+16,s.Y+16
    local element=({SocketArmor="Fire",SocketWeapon="Frost",SocketShield="Shock"})[beat.Id]
    if element then
     for _,o in player.PlayerGui:GetDescendants() do
      if o:IsA("GuiObject") and o:GetAttribute("TutorialGem")==element then
       local gp,gs=o.AbsolutePosition,o.AbsoluteSize
       local right,bottom=math.max(x+w,gp.X+gs.X+8),math.max(y+h,gp.Y+gs.Y+8)
       x,y=math.min(x,gp.X-8),math.min(y,gp.Y-8);w,h=right-x,bottom-y
       break
      end
     end
    end
    spot(x,y,w,h)
    rectangle(frame,p.X-8,p.Y-8,s.X+16,s.Y+16)
    -- Keep the explanation below the inventory's top controls.
    if p.Y<180 then card.Position=UDim2.new(0.5,0,1,-140) end
   else
    spot(size.X*0.2,size.Y*0.35,size.X*0.6,size.Y*0.4)
   end
  end
 end)
 while current() and GemClient.Profile.Tutorial.Run==runId do task.wait(0.2) end
 connection:Disconnect();marker:Destroy();gui:Destroy()
 if not current() then UiKit.toast("Ready! Mine gems and enchant your gear.",GOLD) end
end
while true do
 while not current() do task.wait(0.25) end
 while not OutpostScene.isActive() do task.wait(0.25) end
 run()
end
