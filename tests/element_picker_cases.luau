local function named(name)
 for _,obj in objects do if not obj.Destroyed and obj.Name==name then return obj end end
 error("Missing object "..name)
end
local primary=find("TextButton", if resuming then "EQUIP & FIGHT" else "CONTINUE   ›")
local back=find("TextButton","‹   Back to styles")
local area=named("ElementChoices")
-- A card is chosen when its tick shows.
local function ticked(obj)
 for _,child in obj.children do
  if child.ClassName=="TextLabel" and child.Text=="✓" and child.Visible~=false then return true end
  if ticked(child) then return true end
 end
 return false
end
local function selected(element) return ticked(named(element)) end
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
 check(#funnelSteps==0,"The style step was reported before a style was picked")
 for _,style in {"Prospector","Skirmisher","Juggernaut"} do
  named(style).Activated.Fire()
  primary.Activated.Fire()
  check(funnelSteps[#funnelSteps]=="Style","Picking a style wasn't reported to the onboarding funnel")
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
-- Resize the actual layout callback: all four fit without scrolling wherever
-- they can (side by side when wide and short, two by two when tall), never
-- overlap or overflow, never shrink below a readable card, and only very
-- small portrait screens scroll (to the last card).
for _,size in {{1200,365},{1800,600},{1200,620},{960,520},{800,215},{640,200},{296,560}} do
 local width,height=size[1],size[2]
 area.AbsoluteSize=Vector2.new(width,height)
 area:GetPropertyChangedSignal("AbsoluteSize").Fire()
 local scrolls=area.CanvasSize.Y.Offset>0
 local boxes={}
 for _,element in {"Fire","Frost","Shock","Poison"} do
  local card=named(element)
  local x,y,w,h=card.Position.X.Offset,card.Position.Y.Offset,card.Size.X.Offset,card.Size.Y.Offset
  check(w>=145 and h>=160,"Cards shrink below readable at "..width.."x"..height)
  check(x>=0 and x+w<=width,"Card overflows the viewport at "..width.."x"..height)
  if scrolls then
   check(y+h<=area.CanvasSize.Y.Offset,"Last card is not scrollable at "..width.."x"..height)
  else
   check(y>=0 and y+h<=height,"Card doesn't fit at "..width.."x"..height)
  end
  for _,b in boxes do
   check(x+w<=b[1] or b[1]+b[3]<=x or y+h<=b[2] or b[2]+b[4]<=y,"Cards overlap at "..width.."x"..height)
  end
  table.insert(boxes,{x,y,w,h})
 end
 check(scrolls==(width<400),"Scrolls when all four could fit, or overflows when they can't, at "..width.."x"..height)
 if width==1200 and height==365 then
  check(boxes[1][2]==boxes[4][2],"A wide, short screen doesn't put the four side by side")
 end
end
-- The element cards show the element and its strengths, never the moves:
-- those are a surprise, rolled as you equip.
local icons=0
for _,obj in objects do if obj.IconMove then icons+=1 end end
check(icons==0,"The element picker shows move icons")
for _,element in {"Fire","Frost","Shock","Poison"} do
 for _,pool in Lottery.starterPools(element) do
  for _,id in pool do
   local move=Tech.Catalog[id]
   for _,obj in objects do
    if move and obj.Text and not obj.Destroyed and obj.Visible~=false then
     check(not string.find(obj.Text,move.Name,1,true),"The element picker names the move "..move.Name)
    end
   end
  end
 end
 local texts={}
 local function gather(o) for _,c in o.children do if c.Text then table.insert(texts,c.Text) end gather(c) end end
 gather(named(element))
 local all=table.concat(texts,"\n")
 check(string.find(all,"STRENGTHS",1,true)~=nil,element.." card has no strengths")
 check(string.find(all,"BEATS",1,true)~=nil and string.find(all,"WEAK TO",1,true)~=nil,element.." card has no matchup in words")
end
failPrepare=true
primary.Activated.Fire()
check(primary.Text=="RETRY THE LAUNCH" and not profile.Intro.Done,"Network failure must leave the picker retryable")
check(prepareArgs[1]==(if resuming then "Juggernaut" else "Skirmisher"),"Wrong armor sent to server")
check(prepareArgs[2]==(if resuming then "Frost" else "Poison"),"Wrong explicit element sent to server")
print("PASS: "..checks.." starter picker checks ("..(if resuming then "saved kit" else "fresh choice")..", no automatic element, independent armor, disabled confirmation, responsive cards, strengths without moves and retry)")
