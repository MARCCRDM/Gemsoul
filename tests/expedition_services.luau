local Config = {MaxGems = 200, MarketSellRate = 0.5, DataStoreName = "Regression"}
local registry, removals = {}, {}
local function removal(player) for _, callback in removals do callback(player) end end
local Players = {
 GetPlayerByUserId = function(_self, id) return registry[id] end,
 PlayerRemoving = {Connect = function(_self, callback) table.insert(removals, callback) end},
}
local guid = 0
local HttpService = {GenerateGUID = function() guid += 1; return "trade-" .. guid end}
local records, fault = {}, nil
local function clone(value)
 if type(value) ~= "table" then return value end
 local t = {}
 for k, v in value do t[k] = clone(v) end
 return t
end
local mockStore = {}
function mockStore:GetAsync(key)
 if fault == "read" then error("Injected read failure") end
 return clone(records[key])
end
function mockStore:SetAsync(key, value)
 if fault == "prepare" then error("Injected prepare failure") end
 records[key] = clone(value)
end
function mockStore:UpdateAsync(key, callback)
 local value = callback(clone(records[key]))
 if value ~= nil then records[key] = clone(value) end
 if fault == "commit" and value and value.Committed then error("Injected ambiguous final write") end
 return clone(value)
end
local DataStoreService = {GetDataStore = function() return mockStore end}
local task = {spawn = function(fn, ...) fn(...) end}
local game = {GetService = function(_self, name)
 if name == "Players" then return Players end
 if name == "HttpService" then return HttpService end
 if name == "DataStoreService" then return DataStoreService end
 return {}
end}
local Remotes = {Notify = {FireClient = function() end}, Request = {}}
local handlers = {}
local Shop = {
 register = function(id, callback) handlers[id] = callback end,
 reply = function(ok, message, extra)
  local result = extra or {}
  result.Ok = ok
  result.Message = message
  return result
 end,
}
local Nearby = {vendor = function() return true end}
local Progress = {addXP = function() end}
