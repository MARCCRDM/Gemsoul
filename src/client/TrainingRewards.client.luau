-- Optional learning rewards: no modal tutorial, no client-completion request.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Rules=require(RS.Shared.TrainingRewards)
local GemClient=require(script.Parent.Modules.GemClient)
local UiKit=require(script.Parent.Modules.UiKit)
local player=Players.LocalPlayer
local function new(kind,props,parent)
 local o=Instance.new(kind);for k,v in props do o[k]=v end;o.Parent=parent;return o
end
local gui=new("ScreenGui",{Name="TrainingRewards",ResetOnSpawn=false,DisplayOrder=25,Enabled=false},player:WaitForChild("PlayerGui"))
local button=new("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,150),Size=UDim2.fromOffset(240,52),BackgroundColor3=Color3.fromRGB(17,29,40),TextColor3=Color3.fromRGB(255,207,103),TextSize=14,Font=Enum.Font.GothamBold,TextWrapped=true,Text="TRAINING REWARDS"},gui)
UiKit.round(button,10)
new("UIStroke",{Color=Color3.fromRGB(90,189,205),Thickness=1},button)
local panel=new("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(580,570),BackgroundColor3=Color3.fromRGB(12,19,30),Visible=false},gui)
UiKit.round(panel,14)
new("TextLabel",{Position=UDim2.fromOffset(20,14),Size=UDim2.new(1,-70,0,28),BackgroundTransparency=1,Text="LEARN • EARN • EXPLORE",TextSize=20,TextColor3=Color3.fromRGB(255,207,103),Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},panel)
new("TextLabel",{Position=UDim2.fromOffset(20,47),Size=UDim2.new(1,-40,0,42),BackgroundTransparency=1,Text="Complete in any order. Rewards arrive automatically, once per account.",TextWrapped=true,TextSize=13,TextColor3=Color3.fromRGB(188,207,220),Font=Enum.Font.Gotham},panel)
local close=new("TextButton",{Position=UDim2.new(1,-46,0,14),Size=UDim2.fromOffset(32,30),Text="X",BackgroundColor3=Color3.fromRGB(30,42,57),TextColor3=Color3.new(1,1,1),TextSize=16},panel)
local list=new("ScrollingFrame",{Position=UDim2.fromOffset(16,98),Size=UDim2.new(1,-32,1,-114),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=5},panel)
new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},list)
local rows={}
for i,o in Rules.Objectives do
 local row=new("Frame",{Size=UDim2.new(1,-8,0,110),BackgroundColor3=Color3.fromRGB(22,32,46),LayoutOrder=i},list)
 UiKit.round(row,8)
 local name=new("TextLabel",{Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,24),BackgroundTransparency=1,Text=o.Name,TextColor3=Color3.new(1,1,1),TextSize=16,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},row)
 new("TextLabel",{Position=UDim2.fromOffset(12,35),Size=UDim2.new(1,-24,0,42),BackgroundTransparency=1,Text=o.Hint,TextColor3=Color3.fromRGB(184,205,219),TextSize=13,Font=Enum.Font.Gotham,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left},row)
 local status=new("TextLabel",{Position=UDim2.fromOffset(12,80),Size=UDim2.new(1,-24,0,22),BackgroundTransparency=1,TextColor3=Color3.fromRGB(255,207,103),TextSize=13,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},row)
 rows[o.Id]={Name=name,Status=status}
end
local function refresh()
 local p=GemClient.Profile
 local state=p and p.TrainingRewards or {Counts={},Paid={}}
 local done,nextTask=0,nil
 for _,o in Rules.Objectives do
  local paid=state.Paid and state.Paid[o.Id]
  local count=math.min(o.Goal,state.Counts and state.Counts[o.Event] or 0)
  rows[o.Id].Status.Text=if paid then "COMPLETED  •  +"..o.Coins.." coins delivered" else count.." / "..o.Goal.."  •  +"..o.Coins.." coins"
  rows[o.Id].Status.TextColor3=if paid then Color3.fromRGB(95,236,153) else Color3.fromRGB(255,207,103)
  if paid then done+=1 elseif not nextTask then nextTask=o.Name end
 end
 button.Text="TRAINING  "..done.." / "..#Rules.Objectives.."\n"..(nextTask or "All learning rewards earned!")
end
button.Activated:Connect(function() panel.Visible=not panel.Visible;refresh() end)
close.Activated:Connect(function() panel.Visible=false end)
GemClient.Changed:Connect(refresh)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<0.25 then return end;elapsed=0
 local p=GemClient.Profile
 local dashboard=player.PlayerGui:FindFirstChild("Dashboard")
 gui.Enabled=p~=nil and p.Intro~=nil and p.Intro.Done and player:GetAttribute("Outpost")==true and not player:GetAttribute("CombatSession") and not player.PlayerGui:FindFirstChild("Tutorial") and not (dashboard and dashboard.Enabled)
 if not gui.Enabled then panel.Visible=false end
 local size=gui.AbsoluteSize
 panel.Size=UDim2.fromOffset(math.min(580,math.max(280,size.X-24)),math.min(570,math.max(180,size.Y-24)))
end)
refresh()
