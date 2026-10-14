local function named(name)
 for _,obj in objects do if not obj.Destroyed and obj.Name==name then return obj end end
 error("Missing object "..name)
end
local primary=find("TextButton", if resuming then "EQUIP & FIGHT" else "NEXT  ·  ELEMENT   ›")
local back=find("TextButton","‹   Back to styles")
local area=named("ElementChoices")
local function selected(element)
 for _,child in named(element).children do
  if child.ClassName=="TextLabel" and child.Text=="✓" then return true end
 end
 return false
end
check(#requests==0,"Opening the picker must not request a kit")
for _,obj in objects do
 if obj.Text then
  check(not string.find(string.lower(obj.Text),"own element",1,true),"Style ownership copy remains")
  check(not string.find(obj.Text,"SIGNATURE GEM",1,true),"Style card still assigns a signature gem")
 end
end
if resuming then
 check(selected("Frost") and not selected("Fire"),"Saved kit must restore its exact element")
 check(not back.Visible,"Committed kits cannot go back and change style")
 named("Fire").Activated.Fire()
 check(selected("Frost") and not selected("Fire"),"Committed kit choice changed")
else
 for _,style in {"Prospector","Skirmisher","Juggernaut"} do
  named(style).Activated.Fire()
  primary.Activated.Fire()
  check(area.Visible and not primary.Active,"Element step must start without a choice")
  for _,element in {"Fire","Frost","Shock","Poison"} do check(not selected(element),style.." auto-selected "..element) end
  primary.Activated.Fire()
  check(#requests==0,"Empty element choice reached the server")
  primary.MouseEnter.Fire(); primary.MouseLeave.Fire()
  check(primary.Text=="CHOOSE AN ELEMENT" and not primary.Active,"Hover activated the disabled button")
  back.Activated.Fire()
 end
 named("Prospector").Activated.Fire(); primary.Activated.Fire()
 named("Frost").Activated.Fire()
 check(primary.Active and primary.Text=="EQUIP & FIGHT" and selected("Frost"),"Explicit selection did not enable confirm")
 back.Activated.Fire(); named("Skirmisher").Activated.Fire(); primary.Activated.Fire()
 check(selected("Frost") and not selected("Shock"),"Changing armor overwrote the explicit element choice")
 named("Poison").Activated.Fire()
 check(selected("Poison") and not selected("Frost"),"Selection markers are not exclusive")
end
-- Resize the actual layout callback: no shrinking names into unreadable rows.
for _,width in {1200,820,819,500,296} do
 area.AbsoluteSize=Vector2.new(width,560)
 area:GetPropertyChangedSignal("AbsoluteSize").Fire()
 local columns=if width>=820 then 2 else 1
 for i,element in {"Fire","Frost","Shock","Poison"} do
  local card=named(element)
  check(card.Size.Y.Offset==292,"Cards shrink on small screens")
  check(card.Position.X.Offset+card.Size.X.Offset<=width,"Card overflows the viewport")
  check(card.Position.Y.Offset+card.Size.Y.Offset<=area.CanvasSize.Y.Offset,"Last card is not scrollable")
  check(card.Position.Y.Offset==4+math.floor((i-1)/columns)*304,"Cards overlap after resizing")
 end
end
local icons=0
for _,obj in objects do if obj.IconMove then icons+=1 end end
check(icons>=12,"Ability pools must show existing ability icons")
failPrepare=true
primary.Activated.Fire()
check(primary.Text=="RETRY THE LAUNCH" and not profile.Intro.Done,"Network failure must leave the picker retryable")
check(prepareArgs[1]==(if resuming then "Juggernaut" else "Skirmisher"),"Wrong armor sent to server")
check(prepareArgs[2]==(if resuming then "Frost" else "Poison"),"Wrong explicit element sent to server")
print("PASS: "..checks.." starter picker checks ("..(if resuming then "saved kit" else "fresh choice")..", no automatic element, independent armor, disabled confirmation, responsive cards, icons and retry)")
