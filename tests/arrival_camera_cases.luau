local vmt={}
local Vector3={new=function(x,y,z) return setmetatable({X=x,Y=y,Z=z},vmt) end}
vmt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vmt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vmt.__mul=function(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
vmt.__index=function(a,key)
 if key=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z) end
 if key=="Unit" then return a*(1/a.Magnitude) end
end
Vector3.zero=Vector3.new(0,0,0)
local CFrame={new=function(v) return {Position=v,LookVector=Vector3.new(0,0,-1)} end}
CFrame.lookAt=function(eye,focus) return {Position=eye,LookVector=(focus-eye).Unit} end
local Enum={CameraMode={Classic="Classic"},CameraType={Custom="Custom"},RenderPriority={Camera={Value=200}}}
local callbacks,attributes={},{}
local added
local humanoid={Health=100,CameraOffset=Vector3.new(0,-10,0)}
local root={Position=Vector3.new(0,4,0),CFrame=CFrame.new(Vector3.zero)}
local character={FindFirstChild=function(_,name) return if name=="HumanoidRootPart" then root else nil end,FindFirstChildOfClass=function() return humanoid end}
local player={Character=character,CameraMode="Classic",CameraMinZoomDistance=1,CameraMaxZoomDistance=80,
 GetAttribute=function(_,key) return attributes[key] end,
 CharacterAdded={Connect=function(_,fn) added=fn end}}
local camera={CFrame=CFrame.new(Vector3.new(0,-20,0)),CameraType="Scriptable",CameraSubject="OldHumanoid"}
local workspace={CurrentCamera=camera}
local run={BindToRenderStep=function(_,name,priority,fn) assert(priority>203);callbacks[name]=fn end,
 UnbindFromRenderStep=function(_,name) callbacks[name]=nil end}
local game={GetService=function(_,name) return if name=="Players" then {LocalPlayer=player} else run end}
local function step(count)
 for _=1,count or 1 do for _,fn in table.clone(callbacks) do fn(1/60) end end
end
local checks=0
local function check(ok,message) checks+=1;assert(ok,message) end
-- MODULE HERE
local spawn=CFrame.new(Vector3.new(0,4,7000))
ThirdPerson.enter(spawn)
local old=camera.CFrame
step(8)
check(camera.CFrame==old,"Reset at stale arena coordinates before teleport")
root.Position=spawn.Position
step(2)
check(camera.CFrame==old,"Reset before the teleport settled")
-- A late first-person cleanup must not put the camera back inside the body.
player.CameraMode="FirstPerson";player.CameraMinZoomDistance=.5;player.CameraMaxZoomDistance=.5
step(1)
check(camera.CFrame.Position.Y==root.Position.Y+10,"Arrival camera is not safely above the player")
check(camera.CFrame.Position.Z==root.Position.Z+18,"Arrival camera is not behind the spawn heading")
check(camera.CFrame.LookVector.Y<0,"Camera is still looking up from below the ground")
check(camera.Focus.Position.Y==root.Position.Y+2,"Camera focus is not at the character")
check(camera.CameraSubject==humanoid and camera.CameraType=="Custom","Did not restore the live humanoid camera")
check(humanoid.CameraOffset==Vector3.zero,"Combat offset survived the arrival reset")
check(player.CameraMode=="Classic" and player.CameraMaxZoomDistance==40,"Combat zoom settings survived")
step(1)
check(player.CameraMinZoomDistance==6 and next(callbacks)==nil,"Reset retained control of the camera")
local userView=CFrame.new(Vector3.new(10,20,7000));camera.CFrame=userView;step(10)
check(camera.CFrame==userView,"Arrival reset fights normal camera orbit")
-- Fast reentry uses only the newest destination and exit cancels pending work.
ThirdPerson.enter(CFrame.new(Vector3.new(1000,4,7000)))
ThirdPerson.enter(spawn);step(3)
check(camera.CFrame~=userView,"Latest arrival did not replace a pending reset")
ThirdPerson.exit();step(5)
check(next(callbacks)==nil and player.CameraMinZoomDistance==1 and player.CameraMaxZoomDistance==80,"Exit failed to restore settings")
-- Combat and insertion retain ownership; a stalled teleport cannot bind forever.
ThirdPerson.enter(spawn);attributes.CombatSession="PvP";old=camera.CFrame;step(4)
check(camera.CFrame==old and next(callbacks)==nil,"Lobby reset overrode an active fight")
attributes.CombatSession=nil;ThirdPerson.enter(spawn);attributes.Spar=true;old=camera.CFrame;step(4)
check(camera.CFrame==old and next(callbacks)==nil,"Lobby reset pulled the camera out of a spar")
attributes.Spar=nil
attributes.CombatSession=nil;ThirdPerson.enter(spawn);attributes.ArenaDropUntil=123;step(4)
check(camera.CFrame==old,"Lobby reset overrode insertion")
attributes.ArenaDropUntil=nil;step(3);step(1)
ThirdPerson.enter(CFrame.new(Vector3.new(5000,0,0)));step(310)
check(next(callbacks)==nil and player.CameraMinZoomDistance==6,"Stalled arrival never released zoom")
-- Respawning waits for the new character parts and binds the new humanoid.
player.Character=nil;added();step(4);check(next(callbacks)~=nil,"Missing character cancelled recovery")
humanoid={Health=100};player.Character=character;root.Position=Vector3.new(5000,0,0);step(3)
check(camera.CameraSubject==humanoid,"Respawn retained the old humanoid")
ThirdPerson.exit();added()
check(next(callbacks)==nil,"Respawn outside a mining world claimed the camera")
ThirdPerson.enter();step(3)
check(camera.CFrame.Position.Z==root.Position.Z+14 and camera.CFrame.Position.Y==root.Position.Y+8,"Mine camera inherited lobby framing")
ThirdPerson.exit()
print("PASS: "..checks.." arrival camera checks: delayed teleport, safe pitch, combat cleanup, orbit, cancellation, insertion, timeout and respawn")
