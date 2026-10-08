local PlayerData=require(script.Parent.PlayerData)
local Events=require(script.Parent.CombatEvents)
local Training={}
function Training.start()
 local Shop=require(script.Parent.Shop)
 local Rules=require(game:GetService("ReplicatedStorage").Shared.TrainingRewards)
 Shop.register("TrackTask",function(player,id)
  local profile=PlayerData.get(player)
  if not profile or type(id)~="string" then return Shop.reply(false,"Task unavailable.") end
  for _,o in Rules.Objectives do
   if o.Id==id then
    local state=Rules.state(profile)
    state.Tracked=id
    PlayerData.sync(player)
    return Shop.reply(true,"Task tracked.")
   end
  end
  return Shop.reply(false,"Unknown task.")
 end)
 Events.listen(function(player,event)
  if event=="Hit" or event=="Heavy" or event=="Block" or event=="Surge" or event=="RivalWin" or event=="TimedBlock" then
   PlayerData.training(player,event)
  end
 end)
end
return Training
