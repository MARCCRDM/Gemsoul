local primary=find("TextButton","BEGIN MY SAGA")
local intro=find("ScreenGui")
check(#requests==0,"Welcome claimed or prepared rewards without input")
-- Pick an armor style and a starter element, then go: no lottery reveal.
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
-- A failed claim keeps the picker up and the button ready to try again.
failFinish=true
primary.Activated.Fire()
check(prepareArgs[1]=="Skirmisher" and prepareArgs[2]=="Frost","The chosen style and element weren't sent")
check(reward.Gear[1].Id=="ArmorSkirmisherBoots1","The kit doesn't match the chosen style")
check(#requests==3 and requests[3]=="FinishStarterLottery","The kit wasn't claimed straight after choosing")
check(not intro.Destroyed and primary.Text=="BEGIN MY SAGA","Claim failure destroyed intro or lost retry")
check(#drawn==0,"A lottery reveal still played")
failFinish=false
primary.Activated.Fire()
check(intro.Destroyed and profile.Intro.Done,"Choosing the kit did not claim it")
for _,slot in {"Surge1","Surge2","Surge3"} do check(profile.Character[slot.."Gem"]~=nil and profile.Character[slot.."Gem"].Element=="Frost","Claim omitted "..slot) end
local before=#requests
step(1)
input.InputBegan.Fire({KeyCode=Enum.KeyCode.Space},false)
check(#requests==before,"Closed intro retained input / animation callbacks")
check(not table.find(sounds,"Hover") and not table.find(sounds,"Reward"),"Intro plays menu clicks / the fanfare")
check(not humming,"Reactor hum kept running after the intro closed")
print("PASS: "..checks.." real starter-kit UI checks (style and element choice, retries, straight claim with no lottery, starter kit and cleanup)")
