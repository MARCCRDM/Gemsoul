local checks=0
local function check(ok,msg) checks+=1; assert(ok,msg) end
for _, style in Lottery.Styles do
	for _, element in {"Fire", "Frost", "Shock", "Poison"} do
		local fresh = {Intro={}, Character={ItemGems={}}, Gems={}}
		local calls = 0
		local function factory(chosen)
			calls += 1
			return {Id="choice"..calls, Element=chosen, Tier="Legendary", Size=10, Clarity=10, Cut=10}
		end
		local kit = Lottery.prepareChoice(fresh, style, element, factory)
		check(kit.Version==2 and #kit.Gear==6 and #kit.Gems==2, "Chosen kit structure")
		for _, gear in kit.Gear do
			check(gear.Id==(if gear.Slot=="Weapon" then "SwordShield" else "Armor"..style..gear.Slot.."1"), "Wrong chosen family")
		end
		for index, entry in kit.Gems do
			check(entry.Gem.Element==element and entry.Gem.Tier=="Common", "Starter element/rarity")
			check(entry.Gem.Size==1 and entry.Gem.Clarity==1 and entry.Gem.Cut==1 and entry.Gem.SurgeRank==1, "Random starter advantage")
			check(Tech.canSocket(entry.Gem, if index==1 then "Q" else "E", {}), "Invalid starter role")
		end
		check(Lottery.prepareChoice(fresh,"Juggernaut","Poison",factory)==kit and calls==2,"Choice rerolled on retry")
		check(Lottery.finish(fresh,200),"Choice claim failed")
		check(fresh.Character.Surge3Gem==nil and Tech.surgeGem(fresh.Character,"R").Surge=="DefaultShift","Neutral Shift missing")
		check(fresh.Character.WeaponGem==nil and fresh.Character.ArmorGem==nil,"Starter equipment enchanted")
		check(Lottery.finish(fresh,200) and #fresh.Gems==0,"Choice duplicated on retry")
	end
end
check(Lottery.prepareChoice({Intro={}},"Invalid","Fire",function() error("Should not generate") end)==nil,"Invalid style accepted")
check(Lottery.prepareChoice({Intro={}},"Prospector","Invalid",function() error("Should not generate") end)==nil,"Invalid element accepted")
local profile={Intro={Done=false},Character={ItemGems={}},Gems={}}
for _,slot in Lottery.GearOrder do profile.Character[slot]=slot.."Item" end
local counter=0
local rng={NextInteger=function(_,a) return a end}
local function generate(element) counter+=1; return {Id="starter"..counter,Element=element,Tier="Common"} end
local plan=Lottery.prepare(profile,rng,generate)
check(#plan.Gear==6 and plan.Gear[1].Slot=="Boots" and plan.Gear[6].Slot=="Helmet","Equipment reveal order")
check(#plan.Gems==9 and counter==9,"Insufficient starter gems")
check(GemRoller.prototypeRole(plan.Gems[7].Gem.Surge)=="Attack","Starter Q needs Attack")
check(GemRoller.prototypeRole(plan.Gems[8].Gem.Surge)=="Defense","Starter E needs Defense")
check(GemRoller.prototypeRole(plan.Gems[9].Gem.Surge)=="Shift","Starter R needs Shift")
check(#profile.Gems==0 and profile.Character.WeaponGem==nil,"Prepared rewards granted early")
check(Lottery.prepare(profile,rng,generate)==plan and counter==9,"Reconnect or repeated request rerolled")
local elements,ids={},{}
for _,entry in plan.Gems do
 check(not ids[entry.Gem.Id],"Duplicate starter gem ID")
 ids[entry.Gem.Id]=true; elements[entry.Gem.Element]=true
 check(entry.Gem.Cut>=5 and entry.Gem.Cut<=8 and entry.Gem.CutMethod=="Starter","Not enchant-ready")
end
check(elements.Fire and elements.Frost and elements.Shock and elements.Poison,"Element coverage missing")
check(plan.Gems[9].Gem.Tier=="Uncommon","No guaranteed upgraded gem")
check(Lottery.finish(profile,200),"Initial claim failed")
for _,entry in plan.Gems do check(profile.Character[entry.Slot.."Gem"].Id==entry.Gem.Id,"Socket missing") end
check(profile.Intro.Done and profile.Intro.Spun and plan.Granted,"Completion flags missing")
check(#profile.Gems==0,"Starter reward duplicated in backpack")
check(Lottery.finish(profile,200) and #profile.Gems==0,"Repeated finish duplicated rewards")
check(profile.Character.ItemGems.Weapon.WeaponItem.Id==profile.Character.WeaponGem.Id,"Equipment swap persistence missing")
local existing={Id="existing",Cut=5}
local interrupted={Intro={},Character={Weapon="gun",WeaponGem=existing,ItemGems={}},Gems={{Id="full"}}}
Lottery.prepare(interrupted,rng,generate)
check(not Lottery.finish(interrupted,1),"Full pouch accepted displaced reward")
check(not interrupted.Intro.Done and not interrupted.Intro.Lottery.Granted and interrupted.Character.BootsGem==nil,"Failed claim partially mutated")
check(Lottery.finish(interrupted,2),"Claim did not recover with space")
check(interrupted.Character.WeaponGem==existing and #interrupted.Gems==2,"Existing equipped gem overwritten")
check(Lottery.finish(interrupted,2) and #interrupted.Gems==2,"Retry duplicated overflow reward")
print("PASS: "..checks.." starter lottery order, coverage, persisted rolls, nine sockets, retries and duplicate protection checks")
