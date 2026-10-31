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
 -- No CONTINUE: tapping a card picks it and, a beat later, moves on.
 check(not primary.Visible,"The picks still show a CONTINUE button")
 for _,style in {"Prospector","Skirmisher","Juggernaut"} do
  named(style).Activated.Fire()
  runDelayed(now+1)
  check(funnelSteps[#funnelSteps]=="Style","Tapping a style didn't move on (or wasn't reported to the funnel)")
  check(area.Visible and not primary.Visible,"The element step didn't open on its own, or shows a button")
  for _,element in {"Fire","Frost","Shock","Poison"} do check(not selected(element),style.." auto-selected "..element) end
  check(#requests==0,"An element request went out before one was tapped")
  back.Activated.Fire()
 end
 -- Tapping an element picks it at once; the kit goes out a beat later,
 -- unless they've gone back meanwhile.
 named("Prospector").Activated.Fire(); runDelayed(now+1)
 named("Frost").Activated.Fire()
 check(selected("Frost") and #requests==0,"Tapping an element didn't pick it, or sent it at once")
 back.Activated.Fire(); runDelayed(now+1)
 check(#requests==0,"Going back didn't stop the element going out")
 named("Skirmisher").Activated.Fire(); runDelayed(now+1)
 check(selected("Frost") and not selected("Shock"),"Changing armor overwrote the explicit element choice")
 named("Poison").Activated.Fire()
 check(selected("Poison") and not selected("Frost"),"Selection markers are not exclusive")
 back.Activated.Fire(); runDelayed(now+1)
 check(#requests==0,"A pick went out after going back")
end
-- The style cards: only the picked one has the bright edge, and at every size
-- the art fills its window (no gaps) with the bonus strip along the bottom.
if not resuming then
 local function child(obj,name,class)
  for _,c in obj.children do if (not name or c.Name==name) and (not class or c.ClassName==class) and not c.Destroyed then return c end end
 end
 back.Activated.Fire(); named("Juggernaut").Activated.Fire()
 for _,style in {"Prospector","Skirmisher","Juggernaut"} do
  local edge=child(named(style),nil,"UIStroke")
  check((edge.Thickness>1)==(style=="Juggernaut"),"Only the picked style should have the bright edge: "..style)
 end
 local styleArea=named("Prospector").Parent
 local before=styleArea.AbsoluteSize
 for _,size in {{1200,450},{900,560},{800,300},{620,250}} do
  styleArea.AbsoluteSize=Vector2.new(size[1],size[2])
  styleArea:GetPropertyChangedSignal("AbsoluteSize").Fire()
  for _,style in {"Prospector","Skirmisher","Juggernaut"} do
   local card=named(style)
   local w,h=card.Size.X.Offset,card.Size.Y.Offset
   local window=child(card,"ArtWindow"); local art=child(window,"StyleArt")
   local artH=window.Size.Y.Offset
   check(art.Size.X.Offset>=w and art.Position.X.Offset<=0 and art.Position.X.Offset+art.Size.X.Offset>=w,style.." art leaves a gap at the sides")
   check(art.Position.Y.Offset<=0 and art.Position.Y.Offset+art.Size.Y.Offset>=artH,style.." art leaves a gap at the top or bottom")
   local strip=child(card,"BonusStrip")
   check(strip.Position.Y.Scale==1 and strip.Position.Y.Offset==-strip.Size.Y.Offset and strip.Size.Y.Offset>=28,style.." bonus strip not along the bottom")
   check(artH<h-strip.Size.Y.Offset-60,style.." art leaves no room for the stats")
  end
 end
 styleArea.AbsoluteSize=before
 styleArea:GetPropertyChangedSignal("AbsoluteSize").Fire()
 back.Activated.Fire(); runDelayed(now+1); named("Skirmisher").Activated.Fire(); runDelayed(now+1)
 check(area.Visible,"Tapping an armor card did not move on to the elements")
 named("Poison").Activated.Fire()
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
 local texts,bullets={},0
 local function gather(o)
  for _,c in o.children do
   if c.Text then table.insert(texts,c.Text) end
   if c.Text=="◆" then bullets+=1 end -- (one per strength line)
   gather(c)
  end
 end
 gather(named(element))
 local all=table.concat(texts,"\n")
 check(bullets>=2,element.." card has no strengths")
 check(string.find(all,"BEATS",1,true)~=nil and string.find(all,"WEAK TO",1,true)~=nil,element.." card has no matchup in words")
end
failPrepare=true
-- A fresh pick launches by itself a beat after the tap; a saved kit still has
-- its button.
if resuming then primary.Activated.Fire() else runDelayed(now+1) end
check(primary.Visible and primary.Text=="RETRY THE LAUNCH" and not profile.Intro.Done,"Network failure must leave the picker retryable")
check(prepareArgs[1]==(if resuming then "Juggernaut" else "Skirmisher"),"Wrong armor sent to server")
check(prepareArgs[2]==(if resuming then "Frost" else "Poison"),"Wrong explicit element sent to server")
-- The starter roll: three reels of real 3D gems (no flat stand-ins), every
-- rarity at its real odds on a glow of its colour, in clipped windows (3D
-- views don't draw inside a CanvasGroup). Only the gems in a window are 3D,
-- and a reel reuses its models as cells pass.
failPrepare=false
primary.Activated.Fire()
local windows,glows,cellCount,tiersSeen={},0,0,{}
for _,obj in objects do
 if not obj.Destroyed and obj.Name=="ReelWindow" then table.insert(windows,obj) end
 if not obj.Destroyed and obj.Name=="ReelCell" then
  cellCount+=1
  local mine=0
  for _,c in obj.children do if c.Name=="RarityGlow" then mine+=1; tiersSeen[c.BackgroundColor3]=true end end
  check(mine==2,"A reel cell has no rarity glow")
  glows+=mine
 end
 check(not (obj.ClassName=="CanvasGroup" and not obj.Destroyed),"A reel window is a CanvasGroup: its 3D gems wouldn't draw")
end
check(#windows==3,"Expected three reel windows")
for _,w in windows do check(w.ClassName=="Frame" and w.ClipsDescendants==true,"A reel window doesn't clip its gems") end
check(cellCount>=60,"The reels are too short")
local seen=0
for _ in tiersSeen do seen+=1 end
check(seen>=3,"The reels don't roll through the rarities")
-- Spin each reel through every cell: never more than three 3D gems in a
-- window, and the models are reused.
local strips={}
for _,obj in objects do
 if not obj.Destroyed and obj.Name=="ReelCell" and obj.Parent and not table.find(strips,obj.Parent) then table.insert(strips,obj.Parent) end
end
check(#strips==3,"Expected three reel strips")
for n=60,2,-1 do
 for _,strip in strips do strip.Position=UDim2.fromOffset(0,24-(n-1)*108) end
 step(0.1)
 for _,strip in strips do
  local shown=0
  for _,cell in strip.children do
   for _,c in cell.children do if c.ClassName=="ViewportFrame" and c.Name=="ReelGem" and c.Parent==cell then shown+=1 end end
  end
  check(shown<=3,"More than three 3D gems in a reel window")
 end
end
check(reelModels>=3 and reelModels<=45,"Reel gem models not reused: "..reelModels)
-- The gem roll has no button of its own, and a click can't hurry it: every
-- reel plays out. Once the gems are out it says what's next (the first
-- fight: no kaiju roll in the intro, that's Wren's) and goes on by itself,
-- or at once on a click (not one still coming as they land), closing the
-- intro behind the loading screen.
local nextUp
for _,obj in objects do if not obj.Destroyed and obj.Name=="NextUp" then nextUp=obj end end
check(nextUp and nextUp.ClassName=="TextLabel" and not nextUp.Visible,"The gem roll has no next line waiting")
check(string.find(nextUp.Text,"FIRST FIGHT",1,true)~=nil,"The gem roll's next line isn't the first fight: "..tostring(nextUp.Text))
local shade=nextUp.Parent
while shade and shade.ClassName~="TextButton" do shade=shade.Parent end
local function buttons(o,list)
 for _,c in o.children do
  if not c.Destroyed and c.ClassName=="TextButton" then table.insert(list,c.Text or "") end
  buttons(c,list)
 end
 return list
end
check(shade and #buttons(shade,{})==0,"The gem roll has a button: "..table.concat(shade and buttons(shade,{}) or {},", "))
local function finished() return table.find(requests,"FinishStarterLottery")~=nil end
for _=1,5 do shade.Activated.Fire() end
check(not nextUp.Visible and not finished(),"A click mid-spin landed the gems")
for _=1,300 do
 if nextUp.Visible then break end
 step(0.05)
 runDelayed(now)
end
check(nextUp.Visible and not finished(),"The gems out by themselves: no next line, or it went on at once")
local landed=now
shade.Activated.Fire()
check(not finished(),"A click as the gems landed went straight past them")
if resuming then
 runDelayed(landed+1.9)
 check(not finished(),"It went on to the fight too soon")
 runDelayed(landed+2.1)
 check(finished() and shade.Destroyed,"It didn't go on to the fight by itself")
else
 step(0.7)
 shade.Activated.Fire()
 check(finished() and shade.Destroyed,"A click didn't go on to the fight")
end
check(held[1]=="Intro","The intro didn't close behind the loading screen")
check(type(heldOptions[1].Until)=="function" and players.LocalPlayer:GetAttribute("IntroCover")==true,"The loading screen isn't held till the first fight")
check(heldOptions[1].Until()==false,"The cover lets go before the fight")
players.LocalPlayer:SetAttribute("IntroCover",nil)
check(heldOptions[1].Until()==true,"The cover doesn't let go once the fight's on")
for _,obj in objects do
 check(not (obj.ClassName=="TextButton" and string.find(obj.Text or "","TO THE FIGHT",1,true)),"The roll had a button to the fight: "..tostring(obj.Text))
end
print("PASS: "..checks.." starter picker checks ("..(if resuming then "saved kit" else "fresh choice")..", no automatic element, independent armor, disabled confirmation, responsive cards, strengths without moves and retry, no button on the gem roll: on to the first fight by itself or on a click, the loading screen held till it starts)")
