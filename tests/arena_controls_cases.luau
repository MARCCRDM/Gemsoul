local function signal()
 local callbacks={}
 return {Connect=function(_,f) table.insert(callbacks,f) end,Fire=function() for _,f in callbacks do f() end end}
end
local events,attrs,queued={},{Outpost=true},{}
local controls={Enabled=false,Enable=function(self) self.Enabled=true end,Disable=function(self) self.Enabled=false end}
local dashboard={Enabled=false}
local player={PlayerGui={FindFirstChild=function(_,name) return if name=="Dashboard" then dashboard else nil end}}
function player:GetAttribute(name) return attrs[name] end
function player:GetAttributeChangedSignal(name) events[name]=events[name] or signal(); return events[name] end
function player:SetAttribute(name,value) attrs[name]=value; if events[name] then events[name]:Fire() end end
function player:WaitForChild() return {WaitForChild=function() return "PlayerModule" end} end
local Players={LocalPlayer=player}
local Config={MenuOnly=true}
local GemClient,UiKit={},{}
local workspace={CurrentCamera={}}
local Enum={CameraType={Custom="Custom"}}
local task={spawn=function(f) table.insert(queued,f) end}
local require=function(name) assert(name=="PlayerModule");return {GetControls=function() return controls end} end
-- ARENA HERE
for _,f in queued do f() end
assert(controls.Enabled and not dashboard.Enabled,"Late controls load disabled the lobby or opened inventory")
player:SetAttribute("CombatSession","Rival")
assert(controls.Enabled and not dashboard.Enabled,"Combat did not own controls")
player:SetAttribute("CombatSession",nil)
assert(controls.Enabled and not dashboard.Enabled,"Arena return disabled driving or opened menu")
player:SetAttribute("Outpost",false)
assert(not controls.Enabled and dashboard.Enabled,"Menu-only mode lost its control lock")
player:SetAttribute("Outpost",true)
assert(controls.Enabled,"Returning to lobby failed to enable controls")
player:SetAttribute("Outpost",false)
player:SetAttribute("Expedition","Run")
assert(controls.Enabled,"Expedition movement disabled")
print("PASS: arena/lobby control handoff, delayed PlayerModule, and menu-only lock")
