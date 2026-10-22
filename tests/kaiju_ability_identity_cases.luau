-- lune run tests/kaiju_ability_identity_cases.luau <repo>
-- Actual models plus the production ability executor: anatomy, hit budgets,
-- elemental auras, escape from melee, and bounded defensive alternatives.
local fs, luau, process, R = require("@lune/fs"), require("@lune/luau"), require("@lune/process"), require("@lune/roblox")
local ROOT = process.args[1] or "."
local loaded, env = {}, nil
local now, checks = 0, 0
local function check(ok, why)
	checks += 1
	assert(ok, why)
end
local function named(name)
	return setmetatable({ __name = name }, { __index = function(_, key) return named(key) end })
end
local function load(name)
	if not loaded[name] then
		local path = ROOT .. "/src/shared/" .. name .. ".luau"
		if not fs.isFile(path) then path = ROOT .. "/src/server/Systems/" .. name .. ".luau" end
		loaded[name] = luau.load(fs.readFile(path), { debugName = name, environment = env })()
	end
	return loaded[name]
end
env = setmetatable({
	Instance=R.Instance, Vector3=R.Vector3, Vector2=R.Vector2, CFrame=R.CFrame, Color3=R.Color3, Enum=R.Enum,
	ColorSequence=R.ColorSequence, NumberSequence=R.NumberSequence,
	script={Parent=named("Parent")},
	game={GetService=function() return {Shared=named("Shared")} end},
	workspace={GetServerTimeNow=function() return now end},
	require=function(target) return load(target.__name) end,
}, {__index=_G})
local Models, Roles, Kaiju, Abilities, Fight = load("KaijuModels"), load("KaijuRoles"), load("Kaiju"), load("KaijuAbilities"), load("KaijuFight")
local V, CF = R.Vector3.new, R.CFrame.new
local queue, fx = {}, {}
Abilities.after=function(delay, fn) table.insert(queue,{At=now+delay,Fn=fn}) end
Abilities.clock=function() return now end
Abilities.fx=function(...) table.insert(fx,{...}) end
local function tick()
	table.sort(queue,function(a,b) return a.At<b.At end)
	local job=table.remove(queue,1)
	if job then now=job.At;job.Fn() end
end
local function flush() while #queue>0 do tick() end end
local function setup(species,element,size)
	now=0;queue={};fx={}
	local model=Models.build(species,element)
	-- Lune stores CFrame and Position separately; Roblox derives one from the other.
	for _,part in model:GetDescendants() do
		if part:IsA("BasePart") then part.Position=part.CFrame.Position end
	end
	local root=model.PrimaryPart
	local target=R.Instance.new("Part");target.Position=root.Position+V(0,0,-3);target.CFrame=CF(target.Position);target.Parent=R.Instance.new("Folder")
	local foe={Root=target};local hits={};local alive=true
	local caster={Model=model,Root=root,Size=size or 1,Element=element,Damage=100,Body={},Humanoid={Health=100,MaxHealth=200}}
	caster.Foes=function(at,radius) return if (target.Position-at).Magnitude<=radius then {foe} else {} end
	caster.Alive=function() return alive end
	caster.Hit=function(victim,amount,status) table.insert(hits,{Amount=amount,Status=status}) end
	return caster,foe,hits,function() alive=false end
end

for _,element in {"Fire","Frost","Shock","Poison"} do
	for _,species in {"Triskull","Brightsteel"} do
		local caster,foe,hits=setup(species,element)
		local id=Roles.kit(species).E;local plan=Kaiju.AbilityPlans[id]
		check(Abilities.cast(caster,foe,id),"No anatomical volley")
		flush()
		local damage,statusCount,shots,positions=0,0,0,{}
		for _,hit in hits do
			damage+=hit.Amount
			if hit.Status then statusCount+=1 end
		end
		for _,event in fx do
			check(event[1]~="TriadShow","Body volley rendered as a sky storm")
			if event[1]=="Shot" then
				shots+=1;local start=event[3];local matched=false
				for _,part in caster.Model:GetDescendants() do
					if part:IsA("BasePart") and part.Name==plan.Origin then
						local mouth=part.Position+part.CFrame.LookVector*part.Size.Z/2
						matched=matched or (mouth-start).Magnitude<0.001
					end
				end
				check(matched,"A volley shot did not start at its anatomical emitter")
				positions[tostring(start)]=true
			end
		end
		local unique=0;for _ in positions do unique+=1 end
		check(unique==(if species=="Triskull" then 3 else 4),"Volley did not cycle all heads/vents")
		check(shots==plan.Hits and #hits==plan.Hits,"Wrong number of volley hits")
		check(math.abs(damage-100)<1e-5,"Volley multiplied its whole-cast damage by hit count")
		check(statusCount==1,"Volley status was not confined to its final hit")
		check(hits[#hits].Status==(if species=="Triskull" then Roles.ElementStatus[element] else "Vulnerable"),"Wrong final volley effect")
	end
	local caster,foe,hits=setup("Mossback",element)
	check(Abilities.cast(caster,foe,Roles.kit("Mossback").R),"No Overgrowth")
	flush()
	check(#hits==4,"Overgrowth did not tick for its four seconds")
	for _,hit in hits do check(hit.Status==Roles.ElementStatus[element],"Aura leaked unresolved Element status") end
	check(caster.Body.Defense==nil,"Overgrowth ward did not expire")
end

-- A physical multi-hit attack can be escaped between its hits, at both scales.
for _,size in {0.45,1} do
	for _,species in {"Sickleclaw","Drillhorn","Hulkshell","Triskull","Brightsteel","Dreadcrown","Bladebrow"} do
		local caster,foe,hits=setup(species,"Fire",size)
		local id=Roles.kit(species).Q;local plan=Kaiju.AbilityPlans[id]
		check(plan.Reach and plan.Shape=="Flurry","A physical strike lacks a reach limit")
		check(Abilities.cast(caster,foe,id),"Physical move failed")
		tick()
		foe.Root.Position=caster.Root.Position+V(0,0,-100)
		foe.Root.CFrame=CF(foe.Root.Position)
		flush()
		check(#hits==1,"A fleeing target was hit out of melee reach")
		check(math.abs(hits[1].Amount-100/plan.Hits)<1e-5,"Melee hit budget changed")
		if plan.Hits>1 then check(hits[1].Status==nil,"Skipped final blow still applied a status") end
	end
end

for _,species in {"Sickleclaw","Dreadcrown"} do
	local caster,foe=setup(species,"Shock")
	caster.Leap=function() error("A defensive ward teleported") end
	check(Abilities.cast(caster,foe,Roles.kit(species).R),"No defense")
	check(math.abs(Abilities.soak(caster.Body,100)-65)<1e-5,"Defense should reduce damage, not grant invulnerability")
	flush()
	check(Abilities.soak(caster.Body,100)==100,"Defense outlasted its duration")
end

do
	local caster,foe,hits,kill=setup("Triskull","Frost")
	Abilities.cast(caster,foe,Roles.kit("Triskull").E)
	kill();flush()
	check(#hits==0,"Dead caster completed its volley")
end
check(Fight.surgeKind(Kaiju.AbilityPlans.K_TailSweep)=="Heavy","Tail sweep lacks its spin pose")
check(Fight.surgeKind(Kaiju.AbilityPlans.K_Haymaker)=="Heavy","Hulkshell lacks its fist slam pose")
check(Fight.surgeKind(Kaiju.AbilityPlans.K_FourArmFlurry)=="Light","Four-arm flurry lacks its arm pose")
print(string.format("PASS: %d kaiju ability identity checks (actual rigs, all elements, volley budgets, auras, melee escape, defenses, death cancellation)",checks))
