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
local Rules = { Machines={Mole={Name="Mole",Blurb="Drill mech",MaxSpeed=20}}, drive=function() return 5,0 end }
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
print("PASS: " .. checks .. " vehicle transition checks")
