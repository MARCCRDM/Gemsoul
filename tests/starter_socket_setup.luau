type Gem = any
local player={}
local profile={Character={Class="Warrior",Weapon="gun",ItemGems={Weapon={}}},Gems={{Id="a",Cut=5},{Id="b",Cut=7}}}
local profiles={[player]=profile}
local SOCKET_KEYS={Weapon="WeaponGem",Surge1="Surge1Gem",Surge2="Surge2Gem",Surge3="Surge3Gem"}
local Slots={SurgeDefinitions={Surge1={},Surge2={},Surge3={}}}
local Config={MaxGems=200}
local updates=0
local function sync() updates+=1 end
local characterChanged={Fire=function() end}
local PlayerData={}
function PlayerData.findGem(_,id) for _,gem in profile.Gems do if gem.Id==id then return gem end end end
function PlayerData.removeGem(_,id) for index,gem in profile.Gems do if gem.Id==id then return table.remove(profile.Gems,index) end end end
