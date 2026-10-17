local function close(a, b) return math.abs(a - b) < 1e-6 end
local shapes = {"Wood", "Tree", "Shark", "Crocodile"}
for _, shape in shapes do
	local still = RivalPose.creatureStep(shape, 1.1, 1, 0)
	for _, angles in still do for _, a in angles do assert(a == 0, "Idle creature walks in place") end end
	local walk = RivalPose.creatureStep(shape, math.pi / 2, 1, 1)
	local reverse = RivalPose.creatureStep(shape, math.pi / 2, -1, 1)
	assert(close(walk.RightHip[1], -walk.LeftHip[1]), "Legs must alternate")
	assert(close(walk.RightHip[1], -reverse.RightHip[1]), "Backing up reverses gait")
	local attrs = {CreatureShape=shape, ActionKind="Heavy", ActionStart=100, ActionAt=101}
	for _, time in {100,100.5,101,101.1,101.5,102} do
		local pose = RivalPose.pose(attrs, time)
		for _, angles in pose do for _, a in angles do assert(a==a and math.abs(a)<10, "Invalid creature combat pose") end end
	end
end
assert(RivalPose.creatureStep("Shark",math.pi/2,1,1).RightHip[1] > RivalPose.creatureStep("Tree",math.pi/2,1,1).RightHip[1])
for _, kind in {"Propeller","Tail","Jaw","ThirdFoot","Moss"} do
	for i=0,100 do
		local x,y,z=Motion.angles(kind,100+i/60,i/9,i/100,1,100.4)
		assert(x==x and y==y and z==z and math.max(math.abs(x),math.abs(y),math.abs(z))<=2*math.pi)
	end
end
local stillFoot=Motion.angles("ThirdFoot",100,1,0,1)
assert(stillFoot==0,"Third foot slides at rest")
local jawIdle=Motion.angles("Jaw",100.225,0,0,1)
local jawStrike=Motion.angles("Jaw",100.225,0,0,1,100)
assert(jawStrike<jawIdle-0.2,"Missing jaw attack reaction")
local _,_,spin1=Motion.angles("Propeller",10,0,0,1)
local _,_,spin2=Motion.angles("Propeller",10.1,0,0,1)
assert(not close(spin1,spin2),"Propeller is static")
print("PASS: four creature gaits, reverse/idle, combat poses, bounded detail motion and attack reactions")
