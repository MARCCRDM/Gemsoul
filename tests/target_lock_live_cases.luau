local checks=0
local function check(ok,msg) checks+=1; assert(ok,msg) end
Lock.setActive(true)
bound(1/60)
check(Lock.target()==dummy,"Training visitor selected instead of enemy")
check(Lock.point()~=nil and lerps==1,"Camera did not track locked target")
input.Delta=Vector3.new(2,0,0)
now+=0.02; bound(1/60)
check(lerps==2 and Lock.target()==dummy,"Mouse look broke the lock or stopped tracking")
camera.CFrame=pose(camera.CFrame.Position,Vector3.new(0.8,0,-0.6))
now+=0.02; bound(1/60)
check(Lock.target()==dummy,"Turning away broke the lock")
input.Delta=Vector3.new(0,0,0)
camera.CFrame=pose(camera.CFrame.Position,Vector3.new(0,0,-1))
now+=0.1; bound(1/60)
check(Lock.target()==dummy,"Lock lost after looking back")
blocked=true; now+=0.02; bound(1/60)
check(Lock.target()==dummy and Lock.point()==nil,"Brief cover broke the lock, or aim assist went through the wall")
now+=4.1; bound(1/60)
check(Lock.target()==nil,"Lock held a target hidden too long")
blocked=false; dummy.Hum.Health=0; now+=0.2; bound(1/60)
check(Lock.target()==nil,"Dead target acquired")
dummy.Hum.Health=100; dummy.Vendor=true; now+=0.2; bound(1/60)
check(Lock.target()==nil,"Neutral vendor acquired")
dummy.Vendor=false; opponent.OptedIn=true; now+=0.2; bound(1/60)
check(Lock.target()==opponent.Character,"Nearest eligible PvP opponent not selected")
player.Team,opponent.Team,player.Neutral,opponent.Neutral="Blue","Blue",false,false
now+=0.2; bound(1/60)
check(Lock.target()==dummy,"Teammate lock retained")
-- A friendly spar in the lobby: your partner only, teammates or not; never
-- someone sparring with someone else, a knocked-down player, or a miner
-- with the pickaxe in hand.
dummy.Removed=true; player.Spar,opponent.Spar,player.SparWith,opponent.SparWith=true,true,opponent.UserId,99; now+=0.2; bound(1/60)
check(Lock.target()==nil,"Locked onto someone sparring with someone else")
opponent.SparWith=player.UserId; now+=0.2; bound(1/60)
check(Lock.target()==opponent.Character,"Sparring partner (a teammate) not locked")
opponent.SparDown=os.clock()+60; now+=0.2; bound(1/60)
check(Lock.target()==nil,"Knocked-down sparring player kept locked")
opponent.SparDown,opponent.Spar,opponent.SparWith=nil,nil,nil; now+=0.2; bound(1/60)
check(Lock.target()==nil,"A sparring player locked onto a miner")
player.Spar,player.SparWith=nil,nil; dummy.Removed=false; now+=0.2; bound(1/60)
check(Lock.target()==dummy,"Lock didn't go back to the enemy after the spar")
dummy.Removed=true; now+=0.2; bound(1/60)
check(Lock.target()==nil,"Unparented enemy retained")
dummy.Removed=false; dummy.Protected=true; now+=0.2; bound(1/60)
check(Lock.target()==nil,"ForceField target selected")
dummy.Protected=false; now+=0.2; bound(1/60)
Lock.setActive(false)
local previous=lerps; bound(1/60)
check(Lock.target()==nil and Lock.point()==nil and lerps==previous,"Inactive combat still moved camera")
Lock.setActive(true); now+=0.2; bound(1/60)
local beforeTouch=lerps
changed({UserInputType=Enum.UserInputType.Touch,KeyCode="Unknown"},false)
now+=0.02; bound(1/60)
check(lerps>beforeTouch and Lock.target()~=nil,"Touch look broke the lock")
now+=0.3
changed({UserInputType=Enum.UserInputType.Touch,KeyCode="Unknown"},true)
bound(1/60)
check(lerps>beforeTouch,"GUI touch incorrectly suspended camera tracking")
-- A menu pauses the pull but keeps the lock.
now+=0.2; bound(1/60)
local held=Lock.target()
Lock.setPaused(true); local pausedLerps=lerps
now+=0.1; bound(1/60)
check(held~=nil and Lock.target()==held and lerps==pausedLerps,"Pause dropped the lock or kept pulling the camera")
Lock.setPaused(false)
-- Hit from behind with no target: the attacker is locked at once.
Lock.reset()
camera.CFrame=pose(camera.CFrame.Position,Vector3.new(0,0,1))
now+=0.2; bound(1/60)
check(Lock.target()==nil,"Locked something behind you without being attacked")
Lock.engageNear(Vector3.new(600,0,-8))
now+=0.02; bound(1/60)
check(Lock.target()==dummy,"Attacker behind you not locked")
-- Switching uses the live candidates: the only nearby target stays locked.
check(Lock.switchCount()==1 and Lock.switch()==dummy and Lock.target()==dummy,"Switch with one nearby target lost it")
Lock.setActive(false)
check(Lock.switchCount()==0 and Lock.switch()==nil,"Switching worked outside combat")
-- On desktop (mouse and keyboard) the lock only picks targets by itself in a
-- 1v1: the Arena (a player or a rival) and a 1v1 match. Anywhere else you
-- aim with the mouse: nothing's locked for you, not even what hit you; X
-- locks what you're aiming at and, on the only target, lets go.
Lock.setActive(true)
input.KeyboardEnabled,player.Session=true,nil
camera.CFrame=pose(camera.CFrame.Position,Vector3.new(0,0,-1))
now+=0.2; local beforeDesk=lerps; bound(1/60)
check(not Lock.auto() and Lock.target()==nil and lerps==beforeDesk,"Desktop auto-locked (or pulled the camera) outside a 1v1")
Lock.engageNear(Vector3.new(600,0,-8)); now+=0.02; bound(1/60)
check(Lock.target()==nil,"Desktop auto-locked what hit it outside a 1v1")
check(Lock.switch()==dummy and Lock.target()==dummy,"X didn't lock what you're aiming at")
now+=0.02; bound(1/60)
check(Lock.target()==dummy and lerps>beforeDesk,"A target you locked wasn't held, or the camera didn't follow it")
check(Lock.switch()==nil and Lock.target()==nil,"X on the only target didn't let go")
now+=0.2; bound(1/60)
check(Lock.target()==nil,"Let go, the lock picked it straight back up")
for _,session in {"PvP","Training","Duel"} do
 player.Session=session
 check(Lock.auto(),"No automatic lock in a 1v1 on desktop ("..session..")")
end
player.Session="Training"; now+=0.2; bound(1/60)
check(Lock.target()==dummy,"The Arena on desktop didn't lock by itself")
player.Session="Raid"
check(not Lock.auto(),"Desktop auto-locks in a raid or dungeon")
player.Session=nil
lastInput({Name="Gamepad1"})
check(Lock.auto(),"A gamepad in hand lost the automatic lock")
lastInput({Name="MouseMovement"})
check(not Lock.auto(),"Back on the mouse, the lock stayed automatic")
input.KeyboardEnabled=false
check(Lock.auto(),"A touch screen (no keyboard) lost the automatic lock")
Lock.setActive(false)
print("PASS: "..checks.." real target-lock camera, input, LOS, PvP, pause, auto-engage, lifecycle, switching and desktop 1v1-only checks")
