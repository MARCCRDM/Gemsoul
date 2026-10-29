from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source="local Training=(function()\n"+(root/"src/shared/TrainingRewards.luau").read_text(encoding="utf-8")+"\nend)()\n"
source+=r"""
local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local p={Coins=100,Intro={Done=true}}
check(#Training.record(p,"Fake",10000)==0 and p.Coins==100,"Unknown event paid")
check(#Training.record(p,"Mine")==1 and p.Coins==225,"First rock")
Training.record(p,"Mine");check(p.Coins==225,"Second rock paid early")
Training.record(p,"Mine");check(p.Coins==400,"Third rock reward")
for i=1,100 do Training.record(p,"Mine") end
check(p.Coins==400 and p.TrainingRewards.Counts.Mine==3,"Repeat farming")
Training.record(p,"Enchant")
Training.record(p,"Slot","Armor");Training.record(p,"Slot","Armor")
Training.record(p,"Slot","MadeUp")
check(p.TrainingRewards.Counts.Slot==1,"Duplicate/invalid socket counted")
Training.record(p,"Slot","Weapon");Training.record(p,"Slot","Shield")
check(p.Coins==775,"Distinct gear reward")
for _,event in {"EquipSurge","Heavy","Block","Surge","RivalWin"} do Training.record(p,event) end
check(p.Coins==1550,"Total reward budget must be 1450 (5x the beta's 290)")
local extraEvents={"MineGem","RareGem","LegendGem","TimedBlock","PvPPlayed","PvPWin","Boss","DungeonComplete","MarketBuy","MarketSale","KaijuCatch","Hyperbeam","KaijuBattle","Mech","RiftBoss"}
for _,event in extraEvents do Training.record(p,event) end
local total=100
local ids={}
for _,o in Training.Objectives do
 check(not ids[o.Id],"Duplicate task ID");ids[o.Id]=true
 check(o.Category~=nil,"Missing category")
 total+=o.Coins
 check(p.TrainingRewards.Paid[o.Id],"Missing paid flag: "..o.Id)
end
check(p.Coins==total,"Expanded payout budget")
for _,event in extraEvents do Training.record(p,event) end
check(p.Coins==total,"Expanded task replay paid twice")
-- Simulate persistence by rebuilding all tables and reset only onboarding.
local function copy(v) if type(v)~="table" then return v end;local t={};for k,x in v do t[k]=copy(x) end;return t end
local rejoined=copy(p);rejoined.Tutorial={Step=1,Done=false,Run=99}
for _,event in {"Mine","Enchant","EquipSurge","Hit","Heavy","Block","Surge","RivalWin"} do Training.record(rejoined,event) end
for _,slot in {"Armor","Weapon","Shield"} do Training.record(rejoined,"Slot",slot) end
for _,event in extraEvents do Training.record(rejoined,event) end
check(rejoined.Coins==total,"Reconnect or Dev replay repaid rewards")
local outOfOrder={Coins=0}
Training.record(outOfOrder,"RivalWin")
check(outOfOrder.Coins==250 and not outOfOrder.TrainingRewards.Paid.FirstRock,"Objectives forced into order")
local _,changed=Training.record(outOfOrder,"RivalWin")
check(not changed,"Completed action should not keep syncing")
local paid={}
check(Training.currentPage(paid)=="Basics","Basics must be first")
paid.PvPWin=true
check(Training.currentPage(paid)=="Basics","Later credit must not skip unfinished basics")
for _,o in Training.Objectives do if Training.pageOf(o)=="Basics" then paid[o.Id]=true end end
check(Training.currentPage(paid)=="Gear","Completed basics must advance automatically")
check(not paid.LegendFind and Training.pageOf({Id="LegendFind"})=="Discoveries","Legendary must not gate learning")
for _,page in Training.Pages do
 for _,o in Training.Objectives do if Training.pageOf(o)==page then paid[o.Id]=true end end
end
check(Training.currentPage(paid)==nil,"All-complete state")
-- A closed activity's page (dungeons off: PvE) is skipped and left out.
local partway={}
for _,o in Training.Objectives do
 local page=Training.pageOf(o)
 if page~="PvE" and page~="Market" and page~="Discoveries" then partway[o.Id]=true end
end
check(Training.currentPage(partway)=="PvE","Open PvE page should come next")
Training.Closed.PvE=true
check(Training.currentPage(partway)=="Market","A closed page held up the next one")
check(not Training.listed({Id="Boss",Category="PvE"}) and Training.listed({Id="FirstRock",Category="Basics"}),"Closed tasks listed (or open ones hidden)")
Training.Closed.PvE=nil
-- The lobby tracker's task: the first left on the current page.
check(Training.nextTask({}).Id=="FirstRock","The tracker must start on the first rock")
check(Training.nextTask({FirstRock=true,PvPWin=true}).Id=="GemFind","The tracker skipped ahead")
local miningDone={}
for _,o in Training.Objectives do if Training.pageOf(o)=="Basics" then miningDone[o.Id]=true end end
check(Training.nextTask(miningDone).Id=="Enchant","After mining the tracker must point at socketing")
Training.Closed.PvE=true
check(Training.nextTask(partway).Category=="Market","The tracker pointed at a closed task")
Training.Closed.PvE=nil
check(Training.nextTask(paid)==nil,"The tracker must go when every task is done")
-- The learning path: every step has its chapter, a GO and words; the
-- chapters are in order and each has its blurb.
local seenPages={}
for _,o in Training.Objectives do
 check(table.find(Training.Pages,o.Category)~=nil,"A step outside the chapters: "..o.Id)
 check(type(o.Go)=="string" and #o.Name>0 and #o.Hint>0,"A step without GO or words: "..o.Id)
 local i=table.find(Training.Pages,o.Category)
 for _,j in seenPages do check(j<=i,"Steps out of chapter order at "..o.Id) end
 table.insert(seenPages,i)
end
for _,page in Training.Pages do check(type(Training.Blurbs[page])=="string","No blurb for "..page) end
check(Training.Objectives[1].Id=="FirstRock" and Training.Pages[1]=="Basics","The path doesn't start at the first rock")
-- A step waiting on a switched-off feature (Mechs off) is left out, and the
-- chapter moves on without it.
Training.closeFor({Mechs=false})
check(not Training.listed({Id="Mech",Category="Explore",Needs="Mechs"}),"A step for a switched-off feature is listed")
local allButMech={}
for _,o in Training.Objectives do if o.Id~="Mech" and Training.pageOf(o)~="Explore" then allButMech[o.Id]=true end end
allButMech.Mech=nil
check(Training.nextTask(allButMech).Id=="RiftBoss","The tracker pointed at a switched-off step")
Training.closeFor({})
print("PASS: "..checks.." training reward checks: payouts, repeated actions, unique slots, persistence, replay and any-order progression")
"""
with tempfile.TemporaryDirectory(prefix="gemsoul-rewards-") as d:
    f=Path(d)/"training.luau";f.write_text(source,encoding="utf-8")
    subprocess.run([str(root/".tools/luau/luau.exe"),str(f)],check=True)
