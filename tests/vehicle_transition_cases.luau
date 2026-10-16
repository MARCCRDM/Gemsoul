local function signal()
	local listeners = {}
	return { Connect=function(_,fn)
		local listener = {Fn=fn, Active=true}
		table.insert(listeners,listener)
		return {Disconnect=function() listener.Active=false end}
	end, Fire=function(_,...)
		for _,listener in listeners do if listener.Active then listener.Fn(...) end end
	end }
end
local attrs, signals = { Outpost=true }, {}
local player = { CameraMinZoomDistance=6, CameraMaxZoomDistance=40, CharacterAdded=signal() }
local playerGui = {ChildAdded=signal(), ChildRemoved=signal(), Children={}}
function playerGui:GetChildren() return self.Children end
function player:WaitForChild(name) assert(name=="PlayerGui"); return playerGui end
local GuiService = {MenuIsOpen=false, Changed=signal()}
function GuiService:GetPropertyChangedSignal(name) assert(name=="MenuIsOpen"); return self.Changed end
local function screen(name, enabled, parent)
	local item = {Name=name,Enabled=enabled,Parent=parent,Changed=signal(),ModalChanged=signal(),Attributes={}}
	function item:IsA(kind) return kind=="ScreenGui" end
	function item:GetPropertyChangedSignal(name) assert(name=="Enabled"); return self.Changed end
	function item:GetAttributeChangedSignal(name) assert(name=="BlocksMiningHud"); return self.ModalChanged end
	function item:GetAttribute(name) return self.Attributes[name] end
	function item:setEnabled(value) self.Enabled=value; self.Changed:Fire() end
	function item:setModal(value) self.Attributes.BlocksMiningHud=value; self.ModalChanged:Fire() end
	return item
end
local dashboard = screen("Dashboard", false, playerGui)
table.insert(playerGui.Children,dashboard)
function player:GetAttribute(k) return attrs[k] end
function player:GetAttributeChangedSignal(k) signals[k]=signals[k] or signal(); return signals[k] end
function player:SetAttribute(k,v) attrs[k]=v; if signals[k] then signals[k]:Fire() end end
local Enum = { CameraMode={LockFirstPerson="FirstPerson"} }
local Vector2 = { zero={}, new=function(x,y) return { X=x, Y=y, Magnitude=math.sqrt(x*x+y*y) } end }
local CFrame = { Angles=function() return { LookVector={X=0,Z=-1} } end }
local UDim2 = { fromScale=function() return {} end }
local RunService = { Heartbeat=signal() }
local task = { spawn=function(fn,...) fn(...) end }
local gui, title, blurb, controls, speedLabel, fill = {}, {}, {}, {}, {}, {}
local controlText = function() return "Drive" end
local lastDrive = {}
local Rules = { Machines={Mole={Name="Mole",Blurb="Drill mech",MaxSpeed=20}}, drive=function(_, _, _, throttle, steer)
	lastDrive = {throttle, steer}
	return 5,0
end }
local VehicleDrive, driving = {}, nil
local drive, steer = { PlaneVelocity=Vector2.zero }, {}
local chassis = { Size={Z=20}, AssemblyLinearVelocity={X=0,Z=0}, CFrame={ToOrientation=function() return 0,0,0 end} }
function chassis:FindFirstChild(name) return if name=="Drive" then drive else steer end
local machine = { GetAttribute=function() return 24 end, FindFirstChild=function() return chassis end }
local seat = { Parent=machine, ThrottleFloat=1, SteerFloat=0 }
function seat:IsA(name) return name=="VehicleSeat" end
function seat:GetAttribute(name) return if name=="OutpostMachine" then "Mole" else nil end
local hum = { Seated=signal() }
local character = { WaitForChild=function() return hum end, FindFirstChildOfClass=function() return hum end }
player.Character = character
local checks = 0
local function check(ok,message) checks+=1; assert(ok,message) end
local function board()
	hum.SeatPart, seat.Occupant = seat, hum
	hum.Seated:Fire(true,seat)
end
-- Input stand-ins: held keys, a focused chat box, the controls' move vector
-- and the MechInput remote (what reaches the server).
local keysDown, focusedBox, moveVec, clockNow = {}, nil, nil, 0
local os = { clock=function() return clockNow end }
local UserInputService = {}
function UserInputService:IsKeyDown(key) return keysDown[key] == true end
function UserInputService:GetFocusedTextBox() return focusedBox end
Enum.KeyCode = { W="W", A="A", S="S", D="D", Up="Up", Down="Down", Left="Left", Right="Right" }
local function vec(x, y, z) return { X=x, Y=y, Z=z, Magnitude=math.sqrt(x*x+y*y+z*z), IsVector3=true } end
local function typeof(value) return if type(value)=="table" and value.IsVector3 then "Vector3" else type(value) end
local controlStub = { GetMoveVector=function() return moveVec end }
local playerModule = { Module={ GetControls=function() return controlStub end } }
local playerScripts = { FindFirstChild=function(_, name) return if name=="PlayerModule" then playerModule else nil end }
function player:FindFirstChild(name) return if name=="PlayerScripts" then playerScripts else nil end
local function require(module) return module.Module end
local sent = {}
local mechInput = { FireServer=function(_, throttle, steer) table.insert(sent, {throttle, steer}) end }
local remotesFolder = { FindFirstChild=function(_, name) return if name=="MechInput" then mechInput else nil end }
local remotesHere = true
local ReplicatedStorage = { FindFirstChild=function(_, name) return if name=="Remotes" and remotesHere then remotesFolder else nil end }
-- DRIVE HERE
-- Boarding may finish before the controller attaches, without another Seated event.
hum.SeatPart, seat.Occupant = seat, hum
RunService.Heartbeat:Fire(.1)
check(VehicleDrive.isDriving() and drive.PlaneVelocity.Y==-5, "Missed boarding event left mech inert")
board()
check(player.CameraMinZoomDistance==24, "Repeated boarding reset mech zoom")
hum.SeatPart, seat.Occupant = nil, nil
hum.Seated:Fire(false,nil)
check(player.CameraMinZoomDistance==6, "Repeated boarding overwrote original zoom")
-- Occupancy and the driving constraints can replicate after the seat event.
hum.SeatPart = seat
hum.Seated:Fire(true,seat)
check(not VehicleDrive.isDriving(), "Started before occupant replicated")
local findConstraint = chassis.FindFirstChild
chassis.FindFirstChild = function() return nil end
seat.Occupant = hum
RunService.Heartbeat:Fire(.1)
check(not VehicleDrive.isDriving(), "Started with missing constraints")
chassis.FindFirstChild = findConstraint
RunService.Heartbeat:Fire(.1)
check(VehicleDrive.isDriving() and drive.PlaneVelocity.Y==-5, "Late constraints never resumed driving")
board()
check(VehicleDrive.isDriving() and gui.Enabled, "Lobby mech cannot be driven")
VehicleDrive.step(0.1)
check(drive.PlaneVelocity.Y==-5, "Valid driving stopped")
dashboard:setEnabled(true)
check(VehicleDrive.isDriving() and not gui.Enabled, "Inventory must hide HUD without ejecting rider")
check(drive.PlaneVelocity==Vector2.zero, "Opening menu did not immediately stop propulsion")
VehicleDrive.step(0.1)
check(drive.PlaneVelocity==Vector2.zero and not gui.Enabled, "Menu input continued driving")
local shop = screen("Shop", true, playerGui)
playerGui.ChildAdded:Fire(shop)
dashboard:setEnabled(false)
check(not gui.Enabled, "Closing inventory revealed HUD under another open menu")
shop:setEnabled(false)
check(gui.Enabled and VehicleDrive.isDriving(), "Closing last menu did not restore HUD")
VehicleDrive.step(0.1)
check(drive.PlaneVelocity.Y==-5, "Driving did not resume after closing menu")
local toast = screen("Toasts",true,playerGui)
playerGui.ChildAdded:Fire(toast)
check(gui.Enabled, "Nonmodal HUD hid driving card")
local rewards = screen("TrainingRewards",true,playerGui)
playerGui.ChildAdded:Fire(rewards)
check(gui.Enabled, "Nonmodal training notice hid HUD")
rewards:setModal(true)
check(not gui.Enabled, "Modal rewards did not hide HUD")
rewards:setModal(false)
check(gui.Enabled, "Closing reward modal did not restore HUD")
GuiService.MenuIsOpen=true; GuiService.Changed:Fire()
check(not gui.Enabled and drive.PlaneVelocity==Vector2.zero, "Roblox escape menu retained HUD or propulsion")
dashboard:setEnabled(true)
GuiService.MenuIsOpen=false; GuiService.Changed:Fire()
check(not gui.Enabled, "Closing escape menu ignored inventory")
dashboard:setEnabled(false)
check(gui.Enabled, "Escape and inventory close did not restore HUD")
shop:setEnabled(true)
shop.Parent=nil; playerGui.ChildRemoved:Fire(shop)
check(gui.Enabled, "Removed menu left stale blocker")
shop:setEnabled(true)
check(gui.Enabled, "Removed menu still had active watchers")
shop.Parent=playerGui; playerGui.ChildAdded:Fire(shop)
check(not gui.Enabled, "Reparented menu was not watched again")
shop:setEnabled(false)
hum.Seated:Fire(false,nil)
dashboard:setEnabled(true)
board()
check(VehicleDrive.isDriving() and not gui.Enabled, "Boarding with menu open revealed HUD")
dashboard:setEnabled(false)
check(gui.Enabled, "Boarding beneath menu failed to resume")
dashboard:setEnabled(true)
hum.SeatPart,seat.Occupant=nil,nil
dashboard:setEnabled(false)
check(not gui.Enabled, "Closing menu after seat exit flashed stale HUD")
VehicleDrive.step(0.1)
check(not VehicleDrive.isDriving(), "Lost seat was not cleaned up")
board()
player:SetAttribute("ArenaDropPreparing",100)
check(not VehicleDrive.isDriving() and not gui.Enabled and drive.PlaneVelocity==Vector2.zero, "Arena preparation retained drive/HUD")
check(player.CameraMinZoomDistance==6 and player.CameraMaxZoomDistance==40, "Mech zoom was not restored")
board() -- late seat event while match is preparing
check(not VehicleDrive.isDriving(), "Late seat event restarted mech in transition")
hum.SeatPart, seat.Occupant = nil, nil
player:SetAttribute("ArenaDropPreparing",nil)
check(not VehicleDrive.isDriving(), "Detached rider resumed driving on cleanup")
for _, attribute in {"ArenaDropUntil","CombatSession","Expedition"} do
	board()
	player:SetAttribute(attribute,100)
	check(not gui.Enabled and not VehicleDrive.isDriving(), attribute .. " did not end driving")
	board()
	check(not VehicleDrive.isDriving(), attribute .. " allowed reseating")
	hum.SeatPart, seat.Occupant = nil, nil
	player:SetAttribute(attribute,nil)
end
board()
player.CameraMode = Enum.CameraMode.LockFirstPerson
player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 0.5,0.5
player:SetAttribute("CombatSession","Rival")
hum.Seated:Fire(false,nil)
check(player.CameraMinZoomDistance==0.5 and player.CameraMaxZoomDistance==0.5, "Late unseat corrupted first-person camera")
player.CameraMode=nil
hum.SeatPart, seat.Occupant = nil,nil
player:SetAttribute("CombatSession",nil)
board()
player:SetAttribute("Outpost",false)
check(not VehicleDrive.isDriving() and not gui.Enabled, "Leaving lobby retained driving")
-- Input: the seat's floats first, then the controls' move vector, then the keys.
player:SetAttribute("Outpost", true)
hum.SeatPart, seat.Occupant = nil, nil
hum.Seated:Fire(false, nil)
board()
check(VehicleDrive.isDriving(), "Could not board for the input checks")
local function frame() clockNow += 0.125; VehicleDrive.step(0.125) end
local function lastSent() return sent[#sent] or {} end
seat.ThrottleFloat, seat.SteerFloat = 1, 0
frame()
check(lastDrive[1]==1 and lastDrive[2]==0, "Seat throttle was not used")
check(lastSent()[1]==1 and lastSent()[2]==0, "Seat throttle never reached the server")
local count = #sent
frame()
check(#sent==count, "Unchanged input was resent every frame")
clockNow += 0.5
frame()
check(#sent==count+1, "Held input was not refreshed for the server")
seat.ThrottleFloat, seat.SteerFloat = 0, 0
moveVec = vec(0.5, 0, -1)
frame()
check(lastDrive[1]==1 and lastDrive[2]==0.5, "Move vector did not stand in for silent seat floats")
check(lastSent()[1]==1 and lastSent()[2]==0.5, "Move vector input never reached the server")
moveVec = vec(0, 0, 0)
keysDown = {W=true, A=true}
frame()
check(lastDrive[1]==1 and lastDrive[2]==-1, "W and A did not drive with the seat and controls silent")
keysDown = {Down=true, Right=true}
frame()
check(lastDrive[1]==-1 and lastDrive[2]==1, "Arrow keys did not drive")
keysDown = {W=true, S=true}
frame()
check(lastDrive[1]==0 and lastDrive[2]==0, "W and S together did not cancel out")
keysDown = {Down=true, Right=true}
frame()
focusedBox = {}
frame()
check(lastDrive[1]==0 and lastDrive[2]==0, "Typing in chat drove the mech")
check(lastSent()[1]==0 and lastSent()[2]==0, "The server kept the old input while typing")
focusedBox = nil
keysDown = {W=true}
frame()
check(lastSent()[1]==1, "Input did not resume after typing")
seat.ThrottleFloat = -0.5
frame()
check(lastDrive[1]==-0.5 and lastSent()[1]==-0.5, "The seat's own throttle did not take priority over the keys")
seat.ThrottleFloat = 0
frame()
dashboard:setEnabled(true)
check(lastSent()[1]==0 and lastSent()[2]==0, "Opening a menu left the server driving")
count = #sent
VehicleDrive.step(0.1)
check(#sent==count, "A menu kept sending input")
dashboard:setEnabled(false)
frame()
check(lastSent()[1]==1, "Closing the menu did not resume input")
-- A sweeping stick: at most 10 sends a second, but letting go goes out at once.
count = #sent
for i = 1, 60 do
	clockNow += 1/60
	seat.ThrottleFloat = 0.2 + (i % 2) * 0.5
	VehicleDrive.step(1/60)
end
check(#sent - count <= 11, "A sweeping stick flooded the server: " .. (#sent - count) .. " sends in a second")
check(#sent - count >= 7, "A sweeping stick was not kept up to date")
clockNow += 0.01
seat.ThrottleFloat = 0
keysDown = {}
VehicleDrive.step(0.01)
check(lastSent()[1]==0 and lastSent()[2]==0, "Letting go waited for the rate limit")
keysDown = {W=true}
clockNow += 0.2
frame()
remotesHere = false
count = #sent
clockNow += 1
frame()
check(#sent==count and lastDrive[1]==1, "A missing remote stopped the client driving")
remotesHere = true
frame()
hum.SeatPart, seat.Occupant = nil, nil
hum.Seated:Fire(false, nil)
check(lastSent()[1]==0 and lastSent()[2]==0, "Getting out left the server driving")
keysDown = {}
print("PASS: " .. checks .. " vehicle transition checks")
