-- Hand-shaped, corner-localized elemental filaments; no tiled border shapes.
local FX = {}
local colors = require(game:GetService("ReplicatedStorage").Shared.GemConfig).ElementColors
local function frame(parent)
 local f=Instance.new("Frame")
 f.BorderSizePixel=0
 f.AnchorPoint=Vector2.new(0.5,0.5)
 f.Active=false
 f.BackgroundTransparency=1
 f.Parent=parent
 return f
end
local function segment(f,a,b,width,color,opacity)
 local delta=b-a
 f.Position=UDim2.fromOffset((a.X+b.X)*0.5,(a.Y+b.Y)*0.5)
 f.Size=UDim2.fromOffset(delta.Magnitude+0.3,width)
 f.Rotation=math.deg(math.atan2(delta.Y,delta.X))
 f.BackgroundColor3=color
 f.BackgroundTransparency=1-opacity
 f.Visible=true
end
function FX.create(card: GuiObject,_gemWell: GuiObject)
 local layer=frame(card)
 layer.Name="ElementalCornerFX"
 layer.Position=UDim2.fromScale(0.5,0.5)
 layer.Size=UDim2.fromScale(1,1)
 layer.ClipsDescendants=true
 layer.ZIndex=2
 layer.Visible=false
 local lines={}
 for i=1,64 do
  local halo,core=frame(layer),frame(layer)
  for _,part in {halo,core} do
   local corner=Instance.new("UICorner")
   corner.CornerRadius=UDim.new(1,0)
   corner.Parent=part
   part.Visible=false
  end
  lines[i]={Halo=halo,Core=core}
 end
 return {Layer=layer,Lines=lines,Used=0}
end
function FX.update(effect,element,time)
 local tint=colors[element]
 effect.Layer.Visible=tint~=nil
 if not tint then return end
 local card=effect.Layer.Parent
 local w,h=card.Size.X.Offset,card.Size.Y.Offset
 if w<=0 or h<=0 then return end
 local count=0
 local function draw(a,b,width,color,alpha)
  count+=1
  local item=effect.Lines[count]
  if not item then return end
  segment(item.Halo,a,b,width+3,color,alpha*0.12)
  segment(item.Core,a,b,width,color,alpha)
 end
 local function mirror(p,side)
  return if side==1 then p else Vector2.new(w-p.X,h-p.Y)
 end
 if element=="Frost" then
  -- Sparse dendritic frost grows along opposite edges, with needle branches.
  local ice=Color3.fromRGB(164,229,246)
  for side=1,2 do
   local base=Vector2.new(3,9)
   for j=1,5 do
    local nextPoint=Vector2.new(3+(j%2)*1.5,9+j*6)
    draw(mirror(base,side),mirror(nextPoint,side),0.9,ice,0.52)
    local branch=Vector2.new(8, nextPoint.Y-4)
    draw(mirror(nextPoint,side),mirror(branch,side),0.6,ice,0.30+0.12*math.sin(time+ j))
    base=nextPoint
   end
   -- One fine crystal vein across the corner, not a sawtooth tile.
   draw(mirror(Vector2.new(5,3),side),mirror(Vector2.new(31,3),side),0.7,ice,0.45)
   draw(mirror(Vector2.new(18,3),side),mirror(Vector2.new(23,7),side),0.6,ice,0.3)
  end
 elseif element=="Shock" then
  -- Short asymmetric arcs, a persistent warm glow and restrained moving forks.
  local tick=math.floor(time*5)
  local electric=Color3.fromRGB(255,226,116)
  for side=1,2 do
   local prev=Vector2.new(4,8)
   for j=1,9 do
    local p=Vector2.new(3+((math.sin(j*19+tick)*0.5+0.5)*4),8+j*(h-21)/9)
    draw(mirror(prev,side),mirror(p,side),0.85,electric,0.40+0.12*math.sin(time*3+j))
    if j==3 or j==7 then
     draw(mirror(p,side),mirror(Vector2.new(10,p.Y-3),side),0.5,electric,0.35)
    end
    prev=p
   end
   draw(mirror(Vector2.new(8,3),side),mirror(Vector2.new(34,3),side),0.7,electric,0.32)
  end
 else
  -- Layered tapered curves suggest flame tongues / curling chemical vapor.
  local fire=element=="Fire"
  local outer=if fire then Color3.fromRGB(255,95,31) else Color3.fromRGB(59,191,116)
  local inner=if fire then Color3.fromRGB(255,210,110) else Color3.fromRGB(155,227,139)
  for side=1,2 do
   for strand=1,3 do
    local prev
    for j=0,9 do
     local t=j/9
     local curl=math.sin(t*5-time*(if fire then 1.8 else 0.65)+strand)
     local x=3+strand*0.6+curl*(if fire then 1.8 else 2.2)*math.sin(t*math.pi)
     local y=h-10-strand*3-t*(h*(if fire then 0.48 else 0.6))
     local p=mirror(Vector2.new(x,y),side)
     if prev then
      local alpha=(1-t)* (if fire then 0.42 else 0.19)
      local color=outer:Lerp(inner,(1-t)*0.65)
      draw(prev,p,math.max(0.4,(1-t)*(if fire then 2.8 else 4)),color,alpha)
     end
     prev=p
    end
   end
  end
 end
 for i=count+1,effect.Used do
  effect.Lines[i].Halo.Visible=false
  effect.Lines[i].Core.Visible=false
 end
 effect.Used=math.min(count,#effect.Lines)
end
return FX
