local checks=0
local function check(ok,msg) checks+=1; assert(ok,msg) end
table.insert(profile.Gems, {Id="extra", Element="Fire", Surge="ThermalBurst", Cut=5})
profile.Character.Surge2Gem={Id="equipped", Element="Fire", Surge="ThermalBurst", Cut=5}
check(PlayerData.socketGem(player,"extra","Surge3")==nil,"Duplicate ability accepted")
check(PlayerData.findGem(player,"extra")~=nil,"Rejected socket consumed gem")
profile.Character.Surge2Gem=nil
PlayerData.removeGem(player,"extra")
check(PlayerData.socketGem(player,"a","Surge1").Id=="a","Surge socket failed without gear item")
check(#profile.Gems==1 and profile.Character.Surge1Gem.Id=="a","Surge gem duplicated")
check(PlayerData.socketGem(player,"a","Surge2")==nil,"Equipped surge gem socketed twice")
check(PlayerData.socketGem(player,"b","Surge1").Id=="b" and profile.Gems[1].Id=="a","Replace did not return previous gem")
check(PlayerData.unsocketGem(player,"Surge1").Id=="b" and profile.Character.Surge1Gem==nil and #profile.Gems==2,"Unsocket lost gem")
check(PlayerData.socketGem(player,"a","FakeSlot")==nil,"Unknown socket accepted")
check(PlayerData.socketGem(player,"a","Weapon").Id=="a" and profile.Character.ItemGems.Weapon.gun.Id=="a","Equipment persistence regressed")
check(PlayerData.unsocketGem(player,"Weapon").Id=="a" and profile.Character.ItemGems.Weapon.gun==nil,"Equipment unsocket regressed")
PlayerData.socketGem(player,"a","Surge3")
Config.MaxGems=1
check(PlayerData.unsocketGem(player,"Surge3")==nil and profile.Character.Surge3Gem.Id=="a","Full backpack lost surge gem")
print("PASS: "..checks.." real PlayerData equipment / Surge socket moves, replacement and capacity checks")
