local checks=0
local function check(value,message) checks+=1; assert(value,message) end
local a,ha,ra,loadout=makePlayer(801,arena,nil)
local b,hb,rb=makePlayer(802,arena+Vector3.new(0,0,-5),nil)
local function cast(id,rarity,key,ranked)
	now+=30
	CombatServer.reset(a); CombatServer.reset(b)
	ha.Health,hb.Health=1000,1000
	loadout.Surge1Gem,loadout.Surge2Gem,loadout.Surge3Gem=nil,nil,nil
	a:SetAttribute("MatchRarityCap",if ranked then 4 else nil)
	local gem={Surge=id,Element="Shock",Tier=rarity,Size=10,Clarity=10,Cut=10,SurgeRank=3,SurgeTier=4}
	loadout[Tech.SurgeSockets[key].."Gem"]=gem
	local st=CombatServer._state(a)
	st.Resources.Charge=100
	check(CombatServer._technology(a,nil,rb.Position,key),"Restored cast rejected "..key)
	local definition=Tech.surgeStats(gem,nil,ranked)
	local duration=Actions.castTime(definition)
	now+=duration; CombatServer._tick(duration)
	return 1000-hb.Health,st,gem
end
local common=cast("IonSpark","Common","R",false)
local legendary=cast("IonSpark","Legendary","R",false)
check(common>0 and math.abs(legendary/common-1.2)<.0001,"Live rarity damage scaling")
local normalized=cast("IonSpark","Legendary","E",true)
check(math.abs(normalized-common)<.0001,"Ranked normalization")
local _,st,gem=cast("CryoShield","Legendary","Q",false)
check(math.abs(st.Shield-36)<.0001,"Live barrier rarity scaling")
loadout.Surge2Gem=table.clone(gem)
now+=30
check(not CombatServer._technology(a,nil,rb.Position,"E"),"Duplicate ability cast")
a:SetAttribute("MatchRarityCap",nil)
-- Life-steal uses HP lost, never the requested hit, shield absorption or overkill.
local savedPositions={}
for _,other in playerList do
	if other~=a and other~=b and other.Character then
		local root=other.Character:FindFirstChild("HumanoidRootPart")
		if root then savedPositions[root]=root.Position; root.Position=Vector3.new(10000,0,10000) end
	end
end
local function leechCase(health, shield, antiHeal)
	now+=30
	CombatServer.reset(a); CombatServer.reset(b)
	ha.Health,hb.Health=500,health
	loadout.Surge1Gem={Surge="ResonantReaver",Tier="Common",Element="Poison",Size=10,Clarity=10,Cut=10}
	loadout.Surge2Gem,loadout.Surge3Gem=nil,nil
	local attacker,defender=CombatServer._state(a),CombatServer._state(b)
	attacker.Resources.Charge=100
	defender.Shield,defender.ShieldUntil=shield,now+10
	if antiHeal then CrowdControl.applyHealCut(attacker.CC,"MortalStrike",now) end
	check(CombatServer._technology(a,nil,rb.Position,"Q"),"Life-steal cast rejected")
	local seconds=Actions.castTime(Tech.surgeStats(loadout.Surge1Gem))
	now+=seconds; CombatServer._tick(seconds)
	local lost=health-hb.Health
	local expected=lost*.2*CrowdControl.healingMultiplier(attacker.CC,now)
	check(math.abs(ha.Health-500-expected)<.0001,"Life-steal ignored actual HP loss or anti-heal")
	return lost,ha.Health-500
end
local lost,healed=leechCase(1,0,false)
check(lost==1 and math.abs(healed-.2)<.0001,"Overkill inflated life-steal")
local absorbed,gained=leechCase(1000,10000,false)
check(absorbed==0 and gained==0,"Absorbed hit healed attacker")
leechCase(1000,0,true)
for root,position in savedPositions do root.Position=position end
print("PASS: "..checks.." live restored Surge casts, rarity, barriers, duplicate rejection and Ranked normalization")
