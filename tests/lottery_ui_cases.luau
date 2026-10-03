local primary=find("TextButton","IGNITE THE LOTTERY")
local intro=find("ScreenGui")
check(#requests==0,"Welcome claimed or prepared rewards without input")
failPrepare=true
primary.Activated.Fire()
check(primary.Text=="RETRY THE LAUNCH" and not profile.Intro.Done,"Network failure cannot retry")
failPrepare=false
primary.Activated.Fire()
check(primary.Text=="REVEAL IN PROGRESS…" and #requests==2,"Equipment reels did not start")
primary.Activated.Fire()
check(#requests==2,"Double click made a duplicate request")
step(9)
check(primary.Text=="UNEARTH MY NINE GEMSTONES","Equipment stage did not complete")
local order={}
for _,entry in drawn do if entry.Card then table.insert(order,entry.Slot) end end
check(#order==6 and order[1]=="Boots" and order[6]=="Helmet","Equipment reveal order regressed")
check(not profile.Intro.Done and profile.Character.WeaponGem==nil,"Animation granted items before claim")
local selected
for _,obj in objects do if not obj.Destroyed and obj["@RewardName"]=="BootsGear" then selected=obj end end
selected.Activated.Fire()
check(find("TextLabel","BootsGear")~=nil and #requests==2,"Inspecting a reward did not work locally")
primary.Activated.Fire()
check(primary.Text=="REVEAL IN PROGRESS…" and #requests==2,"Gem stage requested a second lottery")
find("TextButton","Motion: full").Activated.Fire()
check(find("TextButton","Motion: calm")~=nil,"Calm motion toggle unavailable")
step(9)
check(primary.Text=="ATTUNE & BEGIN YOUR SAGA","Gem reveal failed to finish")
order={}
for _,entry in drawn do if entry.Card then table.insert(order,entry.Slot) end end
check(#order==15 and order[15]=="Surge3","Not all nine gems revealed")
failFinish=true
primary.Activated.Fire()
check(not intro.Destroyed and primary.Text=="ATTUNE & BEGIN YOUR SAGA","Claim failure destroyed intro or lost retry")
failFinish=false
find("TextButton","Skip reveal · keep all rewards").Activated.Fire()
check(intro.Destroyed and profile.Intro.Done,"Skip did not claim the saved rewards")
for _,slot in Lottery.GemOrder do check(profile.Character[slot.."Gem"]~=nil,"Claim omitted "..slot) end
local before=#requests
step(1)
input.InputBegan.Fire({KeyCode=Enum.KeyCode.Space},false)
check(#requests==before,"Closed intro retained input / animation callbacks")
check(table.find(sounds,"Lottery:SealBreak") and table.find(sounds,"Lottery:Lock") and table.find(sounds,"Lottery:Tick"),"Lottery missing its vault sounds")
check(not table.find(sounds,"Hover") and not table.find(sounds,"Reward"),"Lottery still plays menu clicks / the fanfare")
check(not humming,"Reactor hum kept running after the lottery closed")
print("PASS: "..checks.." real lottery UI flow, inspection, order, retries, nine rewards and cleanup checks")
