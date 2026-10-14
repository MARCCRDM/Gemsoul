local function signal()
	local listeners = {}
	return { Connect=function(_,fn) table.insert(listeners,fn) end, Fire=function(_,...)
		for _,fn in listeners do fn(...) end
	end }
end
local attrs, signals = { Outpost=true }, {}
local player = { CameraMinZoomDistance=6, CameraMaxZoomDistance=40, CharacterAdded=signal() }
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
board()
check(VehicleDrive.isDriving() and gui.Enabled, "Lobby mech cannot be driven")
VehicleDrive.step(0.1)
check(drive.PlaneVelocity.Y==-5, "Valid driving stopped")
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
