-- Optional permanent objectives. Completion and rewards are server-owned.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Rules=require(RS.Shared.TrainingRewards)
local GemClient=require(script.Parent.Modules.GemClient)
local UiKit=require(script.Parent.Modules.UiKit)
local player=Players.LocalPlayer
local gold=Color3.fromRGB(255,207,103)
local muted=Color3.fromRGB(169,188,207)
local green=Color3.fromRGB(108,229,177)
local function new(kind,props,parent)
 local o=Instance.new(kind);for k,v in props do o[k]=v end;o.Parent=parent;return o
end
local function label(parent,text,pos,size,fontSize,color)
 return new("TextLabel",{Position=pos,Size=size,BackgroundTransparency=1,Text=text,TextSize=fontSize,TextColor3=color or muted,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true},parent)
end
local function button(parent,text,pos,size)
 local b=new("TextButton",{Position=pos,Size=size,BackgroundColor3=Color3.fromRGB(29,43,60),TextColor3=Color3.new(1,1,1),TextSize=13,Font=Enum.Font.GothamBold,Text=text,BorderSizePixel=0},parent)
 UiKit.round(b,8);return b
end
local gui=new("ScreenGui",{Name="TrainingRewards",ResetOnSpawn=false,DisplayOrder=25,Enabled=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild("PlayerGui"))
local launch=button(gui,"",UDim2.new(1,-16,0,150),UDim2.fromOffset(240,94));launch.AnchorPoint=Vector2.new(1,0)
local launchTitle=label(launch,"OBJECTIVES",UDim2.fromOffset(12,6),UDim2.new(1,-24,0,20),12,gold)
local trackedLabel=label(launch,"",UDim2.fromOffset(12,28),UDim2.new(1,-24,0,24),14,Color3.new(1,1,1))
local trackedProgress=label(launch,"",UDim2.fromOffset(12,56),UDim2.new(1,-24,0,22),12)
local trackBar=new("Frame",{Position=UDim2.fromOffset(12,83),Size=UDim2.new(1,-24,0,3),BackgroundColor3=Color3.fromRGB(48,63,79),BorderSizePixel=0},launch)
local trackFill=new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=gold,BorderSizePixel=0},trackBar)
local shade=button(gui,"",UDim2.new(),UDim2.fromScale(1,1));shade.BackgroundColor3=Color3.new();shade.BackgroundTransparency=.25;shade.Visible=false;shade.AutoButtonColor=false
local panel=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(720,620),BackgroundColor3=Color3.fromRGB(12,19,30),BorderSizePixel=0},shade);UiKit.round(panel,14)
local heading=label(panel,"OBJECTIVES",UDim2.fromOffset(20,12),UDim2.new(1,-85,0,28),22,gold);heading.Font=Enum.Font.GothamBold
local summary=label(panel,"",UDim2.fromOffset(20,44),UDim2.new(1,-40,0,20),13)
label(panel,"Tasks · Learn at your pace. Rewards arrive automatically.",UDim2.fromOffset(20,67),UDim2.new(1,-40,0,36),13)
local close=button(panel,"X",UDim2.new(1,-58,0,12),UDim2.fromOffset(44,44))
local categories=new("ScrollingFrame",{Position=UDim2.fromOffset(16,110),Size=UDim2.new(1,-32,0,50),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.X,CanvasSize=UDim2.new(),ScrollBarThickness=2,ScrollingDirection=Enum.ScrollingDirection.X},panel)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},categories)
local filterBar=new("Frame",{Position=UDim2.fromOffset(16,170),Size=UDim2.new(1,-32,0,44),BackgroundTransparency=1},panel)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},filterBar)
local list=new("ScrollingFrame",{Position=UDim2.fromOffset(16,225),Size=UDim2.new(1,-32,1,-241),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=5},panel)
new("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},list)
local empty=label(list,"Nothing here yet. Try All tasks or another category.",UDim2.new(),UDim2.new(1,-12,0,70),15)
local category,filter="All","Active"
local rows,categoryButtons,filterButtons={},{},{}
local refresh
for i,name in {"All","Mining","Equipment","Combat","PvP","PvE","Market"} do
 local b=button(categories,name,UDim2.new(),UDim2.fromOffset(if name=="Equipment" then 108 else 80,44));b.LayoutOrder=i;categoryButtons[name]=b
 b.Activated:Connect(function() category=name;list.CanvasPosition=Vector2.zero;refresh() end)
end
for i,name in {"Active","Completed","All tasks"} do
 local b=button(filterBar,name,UDim2.new(),UDim2.new(1/3,-6,1,0));b.LayoutOrder=i;filterButtons[name]=b
 b.Activated:Connect(function() filter=name;list.CanvasPosition=Vector2.zero;refresh() end)
end
for i,o in Rules.Objectives do
 local row=new("Frame",{Size=UDim2.new(1,-10,0,158),BackgroundColor3=Color3.fromRGB(21,32,46),BorderSizePixel=0,LayoutOrder=i},list);UiKit.round(row,10)
 label(row,string.upper(o.Category),UDim2.fromOffset(12,7),UDim2.new(1,-24,0,16),10,gold)
 local title=label(row,o.Name,UDim2.fromOffset(12,28),UDim2.new(1,-24,0,25),16,Color3.new(1,1,1));title.Font=Enum.Font.GothamBold
 label(row,o.Hint,UDim2.fromOffset(12,57),UDim2.new(1,-24,0,48),13)
 local status=label(row,"",UDim2.fromOffset(12,114),UDim2.new(1,-126,0,32),12,gold)
 local pin=button(row,"Track",UDim2.new(1,-106,0,108),UDim2.fromOffset(94,44))
 pin.Activated:Connect(function() if pin.Active then GemClient.request("TrackTask",o.Id) end end)
 rows[o.Id]={Frame=row,Status=status,Pin=pin}
end
refresh=function()
 local p=GemClient.Profile
 local state=p and p.TrainingRewards or {}
 local paid,counts=state.Paid or {},state.Counts or {}
 local done,visible,nextTask=0,0,nil
 for _,o in Rules.Objectives do
  if paid[o.Id] then done+=1 elseif not nextTask then nextTask=o end
 end
 for _,o in Rules.Objectives do if o.Id==state.Tracked and not paid[o.Id] then nextTask=o end end
 for _,o in Rules.Objectives do
  local row=rows[o.Id];local complete=paid[o.Id]==true
  local show=(category=="All" or category==o.Category) and (filter=="All tasks" or (filter=="Completed")==complete)
  row.Frame.Visible=show;if show then visible+=1 end
  local count=math.min(o.Goal,counts[o.Event] or 0)
  row.Status.Text=if complete then "+"..o.Coins.." coins delivered" else count.." / "..o.Goal.."  ·  +"..o.Coins.." coins"
  row.Status.TextColor3=if complete then green else gold
  row.Pin.Text=if complete then "Done" elseif nextTask==o then "Tracking" else "Track"
  row.Pin.Active=not complete;row.Pin.AutoButtonColor=not complete
  row.Pin.TextColor3=if complete then green elseif nextTask==o then gold else Color3.new(1,1,1)
 end
 empty.Visible=visible==0
 summary.Text=done.." / "..#Rules.Objectives.." completed · Permanent rewards"
 launchTitle.Text="OBJECTIVES  ·  "..done.." / "..#Rules.Objectives
 trackedLabel.Text=if nextTask then nextTask.Name else "All tasks complete!"
 trackedProgress.Text=if nextTask then math.min(nextTask.Goal,counts[nextTask.Event] or 0).." / "..nextTask.Goal.."  ·  +"..nextTask.Coins.." coins  ›" else "Open your achievements  ›"
 trackFill.Size=UDim2.fromScale(if nextTask then math.clamp((counts[nextTask.Event] or 0)/nextTask.Goal,0,1) else 1,1)
 for name,b in categoryButtons do b.TextColor3=if category==name then gold else muted end
 for name,b in filterButtons do b.BackgroundColor3=if filter==name then Color3.fromRGB(54,65,78) else Color3.fromRGB(24,35,49) end
end
launch.Activated:Connect(function() shade.Visible=not shade.Visible;refresh() end)
close.Activated:Connect(function() shade.Visible=false end)
GemClient.Changed:Connect(refresh)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.25 then return end;elapsed=0
 local p=GemClient.Profile
 local dashboard=player.PlayerGui:FindFirstChild("Dashboard")
 gui.Enabled=p~=nil and p.Intro~=nil and p.Intro.Done and player:GetAttribute("Outpost")==true and not player:GetAttribute("CombatSession") and not player.PlayerGui:FindFirstChild("Tutorial") and not (dashboard and dashboard.Enabled)
 if not gui.Enabled then shade.Visible=false end
 local size=gui.AbsoluteSize
 panel.Size=UDim2.fromOffset(math.min(720,math.max(260,size.X-24)),math.min(650,math.max(300,size.Y-24)))
 launch.Size=UDim2.fromOffset(math.min(240,math.max(190,size.X*.30)),94)
 launch.Position=UDim2.new(1,-12,0,if size.Y<500 then 64 else 150)
end)
refresh()
