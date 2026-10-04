
-- Capture local geometry and weld ownership. R15 waist/hip joints move independently;
-- a rigid upper-torso apron below the joint is the regression this test prevents.
local transforms={}
transforms.__mul=function(a,b) return setmetatable({X=(a.X or 0)+(b.X or 0),Y=(a.Y or 0)+(b.Y or 0),Z=(a.Z or 0)+(b.Z or 0),Roll=(a.Roll or 0)+(b.Roll or 0)},transforms) end
CFrame.new=function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,Roll=0},transforms) end
CFrame.Angles=function(x,y,z) return setmetatable({X=0,Y=0,Z=0,Roll=z or 0},transforms) end
CFrame.identity=CFrame.new()
local originalNew=Instance.new
local welds={}
Instance.new=function(kind)
 local object=originalNew(kind)
 if kind=="WeldConstraint" then table.insert(welds,object) end
 return object
end
local checked=0
for _,look in {"UtilityMiner","FrontierRanger","HeavyVanguard"} do
 for rarity=1,5 do
  for _,scale in {.75,1,1.35} do
   local character=rig(true)
   local upper=character:FindFirstChild("UpperTorso")
   local lower=character:FindFirstChild("LowerTorso")
   upper.Size=Vector3.new(2,1.6,1)*scale
   lower.Size=Vector3.new(2,.4,1)*scale
   welds={}
   ArmorKits.build({},character,look,Color3.fromRGB(80,200,220),rarity,{Rarity=rarity,FinishColor=Color3.fromRGB(100,120,140)},"Armor")
   local pelvis=0
   for _,weld in welds do
    local part=weld.Part1
    if weld.Part0==upper then
     local cf=part.CFrame
     local half=(math.abs(math.cos(cf.Roll))*part.Size.Y+math.abs(math.sin(cf.Roll))*part.Size.X)/2
     assert(cf.Y-half>=-upper.Size.Y*.51,look.." chest geometry crosses waist joint at rarity "..rarity)
    elseif weld.Part0==lower then
     pelvis+=1
     assert(part.Massless and not part.CanCollide,"Pelvis armor affects walking physics")
    end
   end
   assert(pelvis>=8,"Missing articulated waist coverage")
   checked+=1
  end
 end
end
print("PASS: "..checked.." chest configurations: 3 families, 5 rarities, 3 body scales; upper plates clear waist, pelvis independently welded")
