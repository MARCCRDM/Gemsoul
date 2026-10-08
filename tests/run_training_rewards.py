from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source="local Training=(function()\n"+(root/"src/shared/TrainingRewards.luau").read_text(encoding="utf-8")+"\nend)()\n"
source+=r"""
local checks=0
local function check(value,message) checks+=1;assert(value,message) end
local p={Coins=100,Intro={Done=true}}
check(#Training.record(p,"Fake",10000)==0 and p.Coins==100,"Unknown event paid")
check(#Training.record(p,"Mine")==1 and p.Coins==125,"First rock")
Training.record(p,"Mine");check(p.Coins==125,"Second rock paid early")
Training.record(p,"Mine");check(p.Coins==160,"Third rock reward")
for i=1,100 do Training.record(p,"Mine") end
check(p.Coins==160 and p.TrainingRewards.Counts.Mine==3,"Repeat farming")
Training.record(p,"Enchant")
Training.record(p,"Slot","Armor");Training.record(p,"Slot","Armor")
Training.record(p,"Slot","MadeUp")
check(p.TrainingRewards.Counts.Slot==1,"Duplicate/invalid socket counted")
Training.record(p,"Slot","Weapon");Training.record(p,"Slot","Shield")
check(p.Coins==235,"Distinct gear reward")
for _,event in {"EquipSurge","Heavy","Block","Surge","RivalWin"} do Training.record(p,event) end
check(p.Coins==390,"Total reward budget must be 290")
local extraEvents={"MineGem","RareGem","LegendGem","TimedBlock","PvPPlayed","PvPWin","Boss","DungeonComplete","MarketBuy","MarketSale"}
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
check(outOfOrder.Coins==50 and not outOfOrder.TrainingRewards.Paid.FirstRock,"Objectives forced into order")
local _,changed=Training.record(outOfOrder,"RivalWin")
check(not changed,"Completed action should not keep syncing")
print("PASS: "..checks.." training reward checks: payouts, repeated actions, unique slots, persistence, replay and any-order progression")
"""
with tempfile.TemporaryDirectory(prefix="gemsoul-rewards-") as d:
    f=Path(d)/"training.luau";f.write_text(source,encoding="utf-8")
    subprocess.run([str(root/".tools/luau/luau.exe"),str(f)],check=True)
