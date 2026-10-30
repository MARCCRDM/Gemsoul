-- The fast start without a picker (FastStart.Pick off; Client Intro): over
-- the picker at once (it never shows), a reel of the two starter elements
-- runs while the server rolls one, Thermal or Cryo, lands on it, and goes on
-- by itself to the surge roll and then the first fight (no kaiju roll: that's
-- Wren's), closing behind a loading screen held till the fight starts. A
-- failed roll: RETRY. Run by tests/run_lottery_ui.py (with autoElement and
-- resuming set).
local function named(name)
 for _,obj in objects do if not obj.Destroyed and obj.Name==name then return obj end end
 return nil
end
local veil=named("ElementRoll")
check(veil and veil.ClassName=="TextButton" and veil.ZIndex>=30,"No element roll over the picker")
check(veil.Parent and veil.Size.X.Scale==1 and veil.Size.Y.Scale==1,"The element roll doesn't fill the screen")
-- Only the two starter elements on the reel, never a picker card to tap.
local cards={}
for _,element in FastStart.StarterElements do
 local function under(o) for _,c in o.children do if not c.Destroyed and c.Name==element then return c end local f=under(c) if f then return f end end return nil end
 local card=under(veil)
 check(card~=nil,"No "..element.." on the reel")
 cards[element]=card
end
check(#FastStart.StarterElements==2 and FastStart.StarterElements[1]=="Fire" and FastStart.StarterElements[2]=="Frost","The starter elements aren't Thermal and Cryo")
for _,other in {"Shock","Poison"} do
 local function under(o) for _,c in o.children do if not c.Destroyed and c.Name==other then return c end local f=under(c) if f then return f end end return nil end
 check(under(veil)==nil,"Ion or Corrosive on the starter reel")
end
local result=named("ElementResult")
local retry=named("Retry")
local kicker=named("Kicker")
-- The roll went out by itself, with no choice sent (the server rolls it).
check(requests[1]=="PrepareStarterLottery" and #requests==1,"The element wasn't rolled by itself")
if failPrepare then
 runDelayed(now+20)
 check(retry.Visible and kicker.Text=="COULDN'T ROLL YOUR ELEMENT" and result.Text=="","A failed roll didn't offer RETRY")
 check(not profile.Intro.Done and named("NextUp")==nil,"A failed roll went on")
 failPrepare=false
 retry.Activated.Fire()
 check(not retry.Visible and #requests==2,"RETRY didn't roll again")
end
-- The reel runs a while, then lands on the server's roll.
runDelayed(now+0.5)
check(result.Text=="","It landed at once, with no reel")
local rolledFor=now
for _=1,400 do
 if result.Text~="" then break end
 now+=0.02
 runDelayed(now)
end
check(now-rolledFor<6,"The reel ran too long")
local expected=profile.Intro.Lottery.Element
check(expected==(if resuming then "Frost" else autoElement),"The server's roll isn't the one shown")
check(result.Text==string.upper(GemConfig.ElementLabels[expected]),"It landed on "..tostring(result.Text).." not "..expected)
check(kicker.Text=="YOUR ELEMENT","No YOUR ELEMENT over the result")
-- A beat to see it, then the surge roll, by itself.
check(named("NextUp")==nil,"The surge roll came too soon")
runDelayed(now+1.5)
local nextUp=named("NextUp")
check(nextUp~=nil,"The surge roll didn't come by itself")
runDelayed(now+0.5)
check(veil.Destroyed,"The element roll stayed under the surge roll")
check(string.find(nextUp.Text,"FIRST FIGHT",1,true)~=nil,"The surge roll's next line isn't the first fight")
-- The surge roll lands and goes on to the fight by itself.
local shade=nextUp.Parent
while shade and shade.ClassName~="TextButton" do shade=shade.Parent end
local function finished() return table.find(requests,"FinishStarterLottery")~=nil end
runDelayed(now+10)
check(finished() and shade.Destroyed and profile.Intro.Done,"It didn't go on to the first fight by itself")
check(held[#held]=="Intro" and type(heldOptions[#heldOptions].Until)=="function","The loading screen isn't held till the fight")
check(players.LocalPlayer:GetAttribute("IntroCover")==true and heldOptions[#heldOptions].Until()==false,"The cover lets go before the fight")
for _,obj in objects do
 check(not (obj.ClassName=="TextButton" and not obj.Destroyed and string.find(obj.Text or "","START",1,true)),"A START button (the kaiju roll) in the intro")
end
print("PASS: "..checks.." intro checks ("..(if resuming then "a saved kit" else autoElement)..": no picker, Thermal or Cryo rolled by the server on a reel of the two, RETRY, on to the surge roll and the first fight by itself, no kaiju, the loading screen held till the fight)")
