do
local checked=0
for _,spec in {{Element="Fire",Shape="Wood"},{Element="Frost",Shape="Shark"},{Element="Poison",Shape="Tree"},{Element="Shock",Shape="Crocodile"}} do
 for rarity=1,5 do
  local c={Class="Warrior"}
  DungeonLoadout.apply(c,spec,rarity,Random.new(123+rarity))
  for _,slot in Slots.Order do
   local roll=GearRolls.get(c,slot)
   assert(roll and roll.Rarity==rarity,"Wrong armor rarity")
   assert(c.ItemGems[slot][c[slot]]==c[slot.."Gem"],"Socket not bound to equipped item")
  end
  for _,slot in {"Helmet","Armor","Gloves","Boots","Shield","Weapon","Surge1","Surge2","Surge3"} do
   local g=c[slot.."Gem"]
   assert(g.Element==spec.Element and g.Tier==GemRoller.Rarities[rarity].Name,"Mixed element or rarity")
   assert(g.Surge==GemRoller.Surges[spec.Element][g.SurgeTier],"Wrong elemental ability")
   for _,m in {"Size","Clarity","Cut"} do assert(g[m]>=rarity*2 and g[m]<=math.min(10,rarity*2+1),"Metric progression failed") end
   checked+=1
  end
  assert(Classes.ratings(c).Defense~=nil,"Equipment cannot calculate combat stats")
 end
end
print("PASS: "..checked.." elemental dungeon sockets across all four creatures and five gear tiers")
end
