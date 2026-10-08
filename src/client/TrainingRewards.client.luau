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
local cyan=Color3.fromRGB(103,218,232)
local categoryColors={Mining=gold,Equipment=Color3.fromRGB(159,171,255),Combat=Color3.fromRGB(255,146,119),PvP=Color3.fromRGB(243,151,207),PvE=Color3.fromRGB(113,218,168),Market=cyan}
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
local function stroke(parent,color,transparency)
 return new("UIStroke",{Color=color,Thickness=1,Transparency=transparency or 0},parent)
end
local function gradient(parent,top,bottom)
 new("UIGradient",{Color=ColorSequence.new(top,bottom),Rotation=90},parent)
end
local function bar(parent,pos,size,color)
 local back=new("Frame",{Position=pos,Size=size,BackgroundColor3=Color3.fromRGB(40,53,69),BorderSizePixel=0},parent);UiKit.round(back,3)
 local fill=new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=color,BorderSizePixel=0},back);UiKit.round(fill,3)
 return fill
end
local gui=new("ScreenGui",{Name="TrainingRewards",ResetOnSpawn=false,DisplayOrder=25,Enabled=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild("PlayerGui"))
local launch=button(gui,"",UDim2.new(1,-16,0,150),UDim2.fromOffset(240,94));launch.AnchorPoint=Vector2.new(1,0)
stroke(launch,cyan,.65)
gradient(launch,Color3.fromRGB(27,47,61),Color3.fromRGB(14,24,38))
local launchTitle=label(launch,"OBJECTIVES",UDim2.fromOffset(12,6),UDim2.new(1,-24,0,20),12,gold)
local trackedLabel=label(launch,"",UDim2.fromOffset(12,28),UDim2.new(1,-24,0,24),14,Color3.new(1,1,1))
local trackedProgress=label(launch,"",UDim2.fromOffset(12,56),UDim2.new(1,-24,0,22),12)
local trackBar=new("Frame",{Position=UDim2.fromOffset(12,83),Size=UDim2.new(1,-24,0,3),BackgroundColor3=Color3.fromRGB(48,63,79),BorderSizePixel=0},launch)
local trackFill=new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=gold,BorderSizePixel=0},trackBar)
local shade=button(gui,"",UDim2.new(),UDim2.fromScale(1,1));shade.BackgroundColor3=Color3.new();shade.BackgroundTransparency=.25;shade.Visible=false;shade.AutoButtonColor=false
local panel=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(720,620),BackgroundColor3=Color3.fromRGB(12,19,30),BorderSizePixel=0},shade);UiKit.round(panel,14)
stroke(panel,Color3.fromRGB(94,132,162),.5)
gradient(panel,Color3.fromRGB(19,32,47),Color3.fromRGB(9,16,27))
local headerLine=new("Frame",{Position=UDim2.fromOffset(20,0),Size=UDim2.new(1,-40,0,2),BackgroundColor3=gold,BorderSizePixel=0},panel)
new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,0),NumberSequenceKeypoint.new(1,1)})},headerLine)
local heading=label(panel,"OBJECTIVES",UDim2.fromOffset(20,14),UDim2.new(1,-85,0,30),24,Color3.fromRGB(239,246,255));heading.Font=Enum.Font.GothamBold
local summary=label(panel,"",UDim2.fromOffset(20,47),UDim2.new(1,-40,0,20),12,gold)
local overallFill=bar(panel,UDim2.fromOffset(20,75),UDim2.new(1,-40,0,4),gold)
label(panel,"LEARN. EXPLORE. EARN.",UDim2.fromOffset(20,86),UDim2.new(1,-40,0,18),10,muted)
local close=button(panel,"X",UDim2.new(1,-58,0,14),UDim2.fromOffset(44,44));stroke(close,muted,.85)
local categories=new("ScrollingFrame",{Position=UDim2.fromOffset(16,110),Size=UDim2.new(1,-32,0,50),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.X,CanvasSize=UDim2.new(),ScrollBarThickness=2,ScrollingDirection=Enum.ScrollingDirection.X},panel)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},categories)
local filterBar=new("Frame",{Position=UDim2.fromOffset(16,164),Size=UDim2.new(1,-32,0,44),BackgroundTransparency=1},panel)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},filterBar)
local list=new("ScrollingFrame",{Position=UDim2.fromOffset(16,220),Size=UDim2.new(1,-32,1,-252),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3,ScrollBarImageColor3=cyan,ScrollingDirection=Enum.ScrollingDirection.Y},panel)
new("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},list)
label(panel,"Rewards delivered automatically · No expiry",UDim2.new(0,20,1,-25),UDim2.new(1,-40,0,18),11)
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
 local accent=categoryColors[o.Category] or gold
 local row=new("Frame",{Size=UDim2.new(1,-10,0,146),BackgroundColor3=Color3.fromRGB(21,32,46),BorderSizePixel=0,LayoutOrder=i},list);UiKit.round(row,10)
 gradient(row,Color3.fromRGB(29,43,59),Color3.fromRGB(18,29,43))
 local outline=stroke(row,accent,.85)
 local stripe=new("Frame",{Position=UDim2.fromOffset(0,15),Size=UDim2.new(0,3,1,-30),BackgroundColor3=accent,BorderSizePixel=0},row);UiKit.round(stripe,2)
 label(row,string.upper(o.Category),UDim2.fromOffset(16,10),UDim2.new(1,-130,0,16),10,accent)
 local title=label(row,o.Name,UDim2.fromOffset(16,30),UDim2.new(1,-132,0,27),17,Color3.fromRGB(240,246,255));title.Font=Enum.Font.GothamBold
 local reward=new("Frame",{Position=UDim2.new(1,-104,0,12),Size=UDim2.fromOffset(88,42),BackgroundColor3=Color3.fromRGB(50,43,28),BorderSizePixel=0},row);UiKit.round(reward,8);stroke(reward,gold,.78)
 local amount=label(reward,"+"..o.Coins,UDim2.fromOffset(0,3),UDim2.new(1,0,0,20),16,gold);amount.TextXAlignment=Enum.TextXAlignment.Center;amount.Font=Enum.Font.GothamBold
 local unit=label(reward,"COINS",UDim2.fromOffset(0,24),UDim2.new(1,0,0,12),9,gold);unit.TextXAlignment=Enum.TextXAlignment.Center
 local hint=label(row,o.Hint,UDim2.fromOffset(16,60),UDim2.new(1,-32,0,36),13)
 local status=label(row,"",UDim2.fromOffset(16,105),UDim2.new(1,-138,0,18),11,muted)
 local fill=bar(row,UDim2.fromOffset(16,131),UDim2.new(1,-140,0,4),accent)
 local pin=button(row,"Track",UDim2.new(1,-108,1,-52),UDim2.fromOffset(92,44))
 pin.Activated:Connect(function() if pin.Active then GemClient.request("TrackTask",o.Id) end end)
 rows[o.Id]={Frame=row,Status=status,Pin=pin,Outline=outline,Fill=fill,Title=title,Hint=hint,Accent=accent}
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
  row.Status.Text=if complete then "REWARD DELIVERED" else count.." / "..o.Goal.." COMPLETE"
  row.Fill.Size=UDim2.fromScale(if complete then 1 else count/o.Goal,1)
  row.Fill.BackgroundColor3=if complete then green else row.Accent
  row.Outline.Transparency=if nextTask==o and not complete then .15 else .85
  row.Outline.Color=if nextTask==o then gold else row.Accent
  row.Pin.BackgroundColor3=if nextTask==o and not complete then Color3.fromRGB(79,61,29) else Color3.fromRGB(31,47,64)
  row.Status.TextColor3=if complete then green else gold
  row.Pin.Text=if complete then "Done" elseif nextTask==o then "Tracking" else "Track"
  row.Pin.Active=not complete;row.Pin.AutoButtonColor=not complete
  row.Pin.TextColor3=if complete then green elseif nextTask==o then gold else Color3.new(1,1,1)
 end
 empty.Visible=visible==0
 summary.Text=done.." OF "..#Rules.Objectives.." COMPLETED  ·  YOUR JOURNEY"
 overallFill.Size=UDim2.fromScale(done/#Rules.Objectives,1)
 launchTitle.Text="OBJECTIVES  ·  "..done.." / "..#Rules.Objectives
 trackedLabel.Text=if nextTask then nextTask.Name else "All tasks complete!"
 trackedProgress.Text=if nextTask then math.min(nextTask.Goal,counts[nextTask.Event] or 0).." / "..nextTask.Goal.."  ·  +"..nextTask.Coins.." coins  ›" else "Open your achievements  ›"
 trackFill.Size=UDim2.fromScale(if nextTask then math.clamp((counts[nextTask.Event] or 0)/nextTask.Goal,0,1) else 1,1)
 for name,b in categoryButtons do
  b.TextColor3=if category==name then Color3.fromRGB(15,23,34) else muted
  b.BackgroundColor3=if category==name then gold else Color3.fromRGB(27,41,56)
 end
 for name,b in filterButtons do
  b.BackgroundColor3=if filter==name then Color3.fromRGB(35,65,78) else Color3.fromRGB(19,30,44)
  b.TextColor3=if filter==name then cyan else muted
 end
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
 panel.Size=UDim2.fromOffset(math.min(780,math.max(260,size.X-24)),math.min(650,math.max(300,size.Y-24)))
 local narrow=panel.AbsoluteSize.X<480
 for _,row in rows do
  row.Frame.Size=UDim2.new(1,-10,0,if narrow then 180 else 146)
  row.Title.Size=UDim2.new(1,-132,0,if narrow then 42 else 27)
  row.Title.TextSize=if narrow then 15 else 17
  row.Hint.Position=UDim2.fromOffset(16,if narrow then 78 else 60)
  row.Hint.Size=UDim2.new(1,-32,0,if narrow then 42 else 36)
  row.Status.Position=UDim2.new(0,16,1,-41)
  row.Fill.Parent.Position=UDim2.new(0,16,1,-15)
 end
 launch.Size=UDim2.fromOffset(math.min(240,math.max(190,size.X*.30)),94)
 launch.Position=UDim2.new(1,-12,0,if size.Y<500 then 64 else 150)
end)
refresh()
