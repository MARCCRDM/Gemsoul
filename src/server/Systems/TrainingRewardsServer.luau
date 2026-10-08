local PlayerData=require(script.Parent.PlayerData)
local Events=require(script.Parent.CombatEvents)
local Training={}
function Training.start()
 Events.listen(function(player,event)
  if event=="Hit" or event=="Heavy" or event=="Block" or event=="Surge" or event=="RivalWin" then
   PlayerData.training(player,event)
  end
 end)
end
return Training
