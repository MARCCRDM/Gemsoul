from pathlib import Path
r=Path(__file__).resolve().parents[1]
p=r/'src/client/Combat.client.luau'
old=p.read_text()
effects=old[old.index('local fxFolder = Instance.new("Folder")'):old.index('-- Just for the caster')]
prefix=r'''-- Four universal actions: click/tap Attack, hold for Heavy, Space Dodge, hold RMB Block.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Actions = require(ReplicatedStorage.Shared.CombatActions)
local ArenaScene = require(script.Parent.Modules.ArenaScene)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)
if Config.MenuOnly and not Config.CombatEnabled then return end
local player = Players.LocalPlayer
local input = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatInput")
local fxEvent = ReplicatedStorage.Remotes:WaitForChild("CombatFx")
local P = IronUi.Colors
local new, text = IronUi.new, IronUi.text
local cooldowns = {}
local holding, blockHeld, chargeStarted, nextAttack, nextBlockUpdate = false, false, 0, 0, 0
local gui = UiKit.gui("CombatHud", 5)
local hud = new("Frame", {BackgroundColor3=P.Inset, BackgroundTransparency=0.1, AnchorPoint=Vector2.new(0.5,1), Position=UDim2.new(0.5,0,1,-16), Size=UDim2.fromOffset(380,154)}, gui)
UiKit.round(hud,12)
local hp = text(hud,"",14,P.Text,IronUi.Bold)
hp.Position=UDim2.fromOffset(12,8); hp.Size=UDim2.new(1,-24,0,22)
local hint = text(hud,"Click Attack · Hold Heavy · Space Dodge · Hold RMB Block",11,P.Dim)
hint.Position=UDim2.fromOffset(12,32); hint.Size=UDim2.new(1,-24,0,28); hint.TextWrapped=true
local row=new("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(12,66),Size=UDim2.new(1,-24,0,70)},hud)
UiKit.list(row,8,true).HorizontalAlignment=Enum.HorizontalAlignment.Center
local slots={}
local function rootPart()
 return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function canFight()
 local root=rootPart()
 return root and not player.PlayerGui:FindFirstChild("Intro") and Combat.canFight(root.Position)
  and (not Config.MenuOnly or ArenaScene.isActive())
end
local aimParams=RaycastParams.new()
aimParams.FilterType=Enum.RaycastFilterType.Exclude
local function aimPoint()
 local root=rootPart()
 local fallback=if root then root.Position+root.CFrame.LookVector*40 else Vector3.zero
 if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then return fallback end
 local camera=workspace.CurrentCamera
 local mouse=UserInputService:GetMouseLocation()
 local ray=camera:ViewportPointToRay(mouse.X,mouse.Y)
 aimParams.FilterDescendantsInstances={player.Character,workspace:FindFirstChild("CombatFx")}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,aimParams)
 return if hit then hit.Position else ray.Origin+ray.Direction*120
end
local function face(aim)
 local root=rootPart()
 if root then
  local flat=Vector3.new(aim.X,root.Position.Y,aim.Z)
  if (flat-root.Position).Magnitude>0.5 then root.CFrame=CFrame.lookAt(root.Position,flat) end
 end
end
local function rules()
 local loadout=GemClient.Profile and GemClient.Profile.Character
 if not loadout then return Actions.resolve({},"Sword",0) end
 local weapon=Classes.weapon(loadout.Class,loadout.Weapon)
 local effects=Classes.effects(loadout)
 return Actions.resolve(Classes.setState(loadout).Counts,if weapon and weapon.Attack.Kind=="Melee" then "Sword" else "Pistol",1-(effects.CooldownMult or 1))
end
local function beginAttack()
 if not canFight() or blockHeld or holding or os.clock()<nextAttack then return end
 holding,chargeStarted=true,os.clock()
 input:FireServer("BeginAttack")
end
local function releaseAttack()
 if not holding then return end
 holding=false
 if not canFight() then input:FireServer("CancelAttack"); return end
 local aim=aimPoint(); face(aim)
 local heavy=os.clock()-chargeStarted>=Actions.Base.Heavy.Charge
 nextAttack=os.clock()+(if heavy then rules().HeavyCooldown else rules().BasicCooldown)
 input:FireServer("ReleaseAttack",aim)
end
local function setBlock(held)
 if held and not canFight() then return end
 blockHeld=held
 if held then holding=false; input:FireServer("CancelAttack") end
 local aim=aimPoint()
 if held then face(aim) end
 input:FireServer("Block",held,aim)
 nextBlockUpdate=os.clock()+0.15
end
local function dodge()
 if not canFight() then return end
 local cd=cooldowns.Dodge
 if cd and os.clock()<cd.Ready then return end
 holding=false; blockHeld=false
 input:FireServer("CancelAttack"); input:FireServer("Block",false)
 local root=rootPart()
 local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 input:FireServer("Dodge",if humanoid and humanoid.MoveDirection.Magnitude>0.1 then humanoid.MoveDirection else root.CFrame.LookVector)
end
local function makeSlot(id,label,key)
 local button,faceBox=IronUi.chunk(row,{Color=Color3.fromRGB(52,46,70),Size=UDim2.fromOffset(80,70),Radius=10,Lip=4,Stripes="None"})
 local name=text(faceBox,label,12,P.Text,IronUi.Bold); name.Position=UDim2.fromOffset(4,28); name.Size=UDim2.new(1,-8,0,26); name.TextXAlignment=Enum.TextXAlignment.Center
 local keyLabel=text(faceBox,key,10,P.Gold); keyLabel.Position=UDim2.fromOffset(6,4)
 local timer=text(faceBox,"",18,P.Gold,IronUi.Bold); timer.Position=UDim2.fromOffset(4,18); timer.Size=UDim2.new(1,-8,0,25); timer.TextXAlignment=Enum.TextXAlignment.Center
 slots[id]={Button=button,Name=name,Timer=timer}
 return button
end
local attackButton=makeSlot("Basic","Attack","CLICK / TAP")
local heavyButton=makeSlot("Heavy","Heavy","HOLD")
local dodgeButton=makeSlot("Dodge","Dodge","SPACE")
local blockButton=makeSlot("Block","Block","HOLD RMB")
local function pressInput(obj) return obj.UserInputType==Enum.UserInputType.MouseButton1 or obj.UserInputType==Enum.UserInputType.Touch end
attackButton.InputBegan:Connect(function(obj) if pressInput(obj) then beginAttack() end end)
attackButton.InputEnded:Connect(function(obj) if pressInput(obj) then releaseAttack() end end)
heavyButton.Activated:Connect(function()
 beginAttack()
 if holding then task.delay(Actions.Base.Heavy.Charge+0.1,releaseAttack) end
end)
dodgeButton.Activated:Connect(dodge)
blockButton.InputBegan:Connect(function(obj) if pressInput(obj) then setBlock(true) end end)
blockButton.InputEnded:Connect(function(obj) if pressInput(obj) then setBlock(false) end end)
local leave=IronUi.gemButton(gui,"LEAVE ARENA",P.Gold,ArenaScene.leave)
leave.AnchorPoint=Vector2.new(1,0); leave.Position=UDim2.new(1,-20,0,20); leave.Size=UDim2.fromOffset(160,38)
local function cancel()
 holding=false; blockHeld=false; input:FireServer("CancelAttack"); input:FireServer("Block",false)
end
UserInputService.InputBegan:Connect(function(obj,processed)
 if processed or UserInputService:GetFocusedTextBox() then return end
 if obj.UserInputType==Enum.UserInputType.MouseButton1 then beginAttack()
 elseif obj.UserInputType==Enum.UserInputType.MouseButton2 then setBlock(true) end
end)
UserInputService.InputEnded:Connect(function(obj)
 if obj.UserInputType==Enum.UserInputType.MouseButton1 then releaseAttack()
 elseif obj.UserInputType==Enum.UserInputType.MouseButton2 then setBlock(false) end
end)
UserInputService.WindowFocusReleased:Connect(cancel)
ContextActionService:BindActionAtPriority("UniversalDodge",function(_,state)
 if not canFight() or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin then dodge() end
 return Enum.ContextActionResult.Sink
end,false,Enum.ContextActionPriority.High.Value+10,Enum.KeyCode.Space)
player.CharacterAdded:Connect(function() cancel(); cooldowns={}; nextAttack=0 end)
player:GetAttributeChangedSignal("CombatSession"):Connect(function() cancel(); cooldowns={}; nextAttack=0 end)
local lastActive=false
RunService.RenderStepped:Connect(function()
 local fight=canFight() == true
 gui.Enabled=fight
 leave.Visible=ArenaScene.isActive()
 if not fight then if lastActive then cancel() end; lastActive=false; return end
 lastActive=true
 local camera=workspace.CurrentCamera
 local viewport=camera.ViewportSize
 local scale=math.min(1,math.max(0.65,(viewport.X-20)/380))
 local sizing=hud:FindFirstChildOfClass("UIScale")
 if not sizing then sizing=new("UIScale",{},hud) end
 sizing.Scale=scale
 local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if humanoid then hp.Text=string.format("%s  ·  %d / %d HP  ·  %d Shield",player:GetAttribute("CombatSession") or "Combat",math.ceil(humanoid.Health),math.ceil(humanoid.MaxHealth),player:GetAttribute("Shield") or 0) end
 local now=os.clock()
 if holding then
  slots.Basic.Timer.Text=string.format("%d%%",math.min(100,math.floor((now-chargeStarted)/Actions.Base.Heavy.Charge*100)))
  if now-chargeStarted>=Actions.Base.Heavy.Charge+0.1 then releaseAttack() end
 end
 if blockHeld and now>=nextBlockUpdate then local aim=aimPoint(); face(aim); input:FireServer("Block",true,aim); nextBlockUpdate=now+0.15 end
 for id,slot in slots do
  local cd=cooldowns[id]; local remaining=if cd then math.max(0,cd.Ready-now) else 0
  if not (id=="Basic" and holding) then slot.Timer.Text=if remaining>0 then string.format("%.1f",remaining) else "" end
 end
 slots.Block.Name.Text=if player:GetAttribute("Blocking") then "Blocking" else "Block"
end)
'''
extra=r'''
function handlers.Cooldown(id,seconds)
 cooldowns[id]={Ready=os.clock()+seconds,Total=seconds}
 if id=="Basic" or id=="Heavy" then nextAttack=os.clock()+seconds end
end
function handlers.BlockBroken(seconds)
 blockHeld=false
 cooldowns.Block={Ready=os.clock()+seconds,Total=seconds}
 UiKit.toast("Guard broken!",P.Gold)
end
function handlers.BlockSpark(position,broken)
 local spark=ring(position,if broken then 2 else 1,if broken then Color3.fromRGB(255,160,50) else P.Teal,0.2)
 fade(spark,0.2,Vector3.new(0.1,6,6))
end
function handlers.BlockRaise(who)
 local root=who.Character and who.Character:FindFirstChild("HumanoidRootPart")
 if root then local plate=effectPart(Vector3.new(2.4,2.5,0.1),root.CFrame*CFrame.new(0,0,-2),P.Teal); plate.Transparency=0.6; fade(plate,0.2) end
end
function handlers.BlockGem(who,element)
 local colors={Fire=Color3.fromRGB(255,100,55),Frost=Color3.fromRGB(90,195,255),Poison=Color3.fromRGB(100,230,130),Shock=Color3.fromRGB(255,230,80)}
 handlers.Buff(who,colors[element] or P.Teal)
end
function handlers.DodgeRoll(who,origin,direction,distance,afterimage)
 local color=if afterimage then Color3.fromRGB(80,225,255) else P.Gold
 for i=0,4 do
  task.delay(i*0.05,function()
   local cf=CFrame.lookAt(origin+direction*distance*i/4,origin+direction*(distance*i/4+1))
   local ghost=effectPart(if afterimage then Vector3.new(1.4,2.6,0.4) else Vector3.new(1.8,0.15,1),cf,color)
   ghost.Transparency=0.55; fade(ghost,0.25)
  end)
 end
 if who==player then holding=false end
end
fxEvent.OnClientEvent:Connect(function(kind,...) local handler=handlers[kind]; if handler then handler(...) end end)
'''
p.write_text(prefix+effects+extra,encoding='utf-8')
