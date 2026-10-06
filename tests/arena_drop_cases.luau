local checks = 0
local function check(v, m) checks += 1; assert(v,m) end
local p,h,root = makePlayer(978,arena,nil)
p:SetAttribute("ArenaDropUntil",workspace:GetServerTimeNow()+7)
local hp = h.Health
local amount = CombatServer.hurt(p,100,"Fire",nil,false,false)
check(amount == 0 and h.Health == hp,"Insertion fighter took damage")
CombatServer._input(p,"BeginAttack","Right")
check(CombatServer._state(p).ChargeStarted == nil,"Insertion accepted an attack charge")
CombatServer._input(p,"Block",true,root.Position+Vector3.new(0,0,-4))
check(p:GetAttribute("Blocking") ~= true,"Insertion accepted a guard action")
check(ArenaDrop.duration(2) > 5.2,"Second pod exits after protection ends")
check(ArenaDrop.duration(4) > ArenaDrop.duration(2),"Team insertion does not scale")
p:SetAttribute("ArenaDropUntil",nil)
ArenaDrop.cancel(p.Character)
print("PASS: "..checks.." orbital insertion protection and timing checks")
