local primary=find("TextButton","REVEAL MY STARTER KIT")
local intro=find("ScreenGui")
check(#requests==0,"Welcome claimed or prepared rewards without input")
-- Pick an armor style and a starter element before the reveal.
local function pick(name)
 for _,obj in objects do if not obj.Destroyed and obj.ClassName=="TextButton" and obj.Name==name then return obj end end
 error("Missing choice "..name)
end
pick("Skirmisher").Activated.Fire()
pick("Frost").Activated.Fire()
check(find("TextLabel","SELECTED")~=nil,"The chosen style isn't marked")
failPrepare=true
primary.Activated.Fire()
check(primary.Text=="RETRY THE LAUNCH" and not profile.Intro.Done,"Network failure cannot retry")
failPrepare=false
primary.Activated.Fire()
check(primary.Text=="REVEAL IN PROGRESS…" and #requests==2,"Equipment reels did not start")
check(prepareArgs[1]=="Skirmisher" and prepareArgs[2]=="Frost","The chosen style and element weren't sent")
check(reward.Gear[1].Id=="ArmorSkirmisherBoots1","The kit doesn't match the chosen style")
primary.Activated.Fire()
check(#requests==2,"Double click made a duplicate request")
step(9)
check(primary.Text=="REVEAL MY STARTER GEMS","Equipment stage did not complete")
local order={}
for _,entry in drawn do if entry.Card then table.insert(order,entry.Slot) end end
check(#order==6 and order[1]=="Boots" and order[6]=="Helmet","Equipment reveal order regressed")
check(not profile.Intro.Done and profile.Character.WeaponGem==nil,"Animation granted items before claim")
local selected
for _,obj in objects do if not obj.Destroyed and obj["@RewardName"]=="ArmorSkirmisherBoots1" then selected=obj end end
selected.Activated.Fire()
check(find("TextLabel","ArmorSkirmisherBoots1")~=nil and #requests==2,"Inspecting a reward did not work locally")
primary.Activated.Fire()
check(primary.Text=="REVEAL IN PROGRESS…" and #requests==2,"Gem stage requested a second lottery")
find("TextButton","Motion: full").Activated.Fire()
check(find("TextButton","Motion: calm")~=nil,"Calm motion toggle unavailable")
step(9)
check(primary.Text=="EQUIP & BEGIN YOUR SAGA","Gem reveal failed to finish")
order={}
for _,entry in drawn do if entry.Card then table.insert(order,entry.Slot) end end
check(#order==9 and order[7]=="Surge1" and order[9]=="Surge3","Not all three starter gems revealed")
failFinish=true
primary.Activated.Fire()
check(not intro.Destroyed and primary.Text=="EQUIP & BEGIN YOUR SAGA","Claim failure destroyed intro or lost retry")
failFinish=false
find("TextButton","Skip reveal · keep all rewards").Activated.Fire()
check(intro.Destroyed and profile.Intro.Done,"Skip did not claim the saved rewards")
for _,slot in {"Surge1","Surge2","Surge3"} do check(profile.Character[slot.."Gem"]~=nil and profile.Character[slot.."Gem"].Element=="Frost","Claim omitted "..slot) end
local before=#requests
step(1)
input.InputBegan.Fire({KeyCode=Enum.KeyCode.Space},false)
check(#requests==before,"Closed intro retained input / animation callbacks")
check(table.find(sounds,"Lottery:SealBreak") and table.find(sounds,"Lottery:Lock") and table.find(sounds,"Lottery:Tick"),"Lottery missing its vault sounds")
check(not table.find(sounds,"Hover") and not table.find(sounds,"Reward"),"Lottery still plays menu clicks / the fanfare")
check(not humming,"Reactor hum kept running after the lottery closed")
print("PASS: "..checks.." real lottery UI flow, inspection, order, retries, style and element choice, starter kit and cleanup checks")
