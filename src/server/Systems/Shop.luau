-- Server request router. Crafting, material purchases and cutting actions are retired.
local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)

local Shop = {}

local lastRequest: { [Player]: number } = {}

local function reply(ok: boolean, message: string, extra: { [string]: any }?): { [string]: any }
	local result = extra or {}
	result.Ok = ok
	result.Message = message
	return result
end

local handlers = {}

function handlers.GetProfile(player: Player)
	return reply(true, "", { Profile = PlayerData.snapshot(player) })
end

-- Lets other systems add request actions (e.g. the intro's).
function Shop.register(action: string, handler: (Player, ...any) -> { [string]: any })
	handlers[action] = handler
end

Shop.reply = reply

-- Entry point for every client request (also called directly by tests).
function Shop.handle(player: Player, action: any, ...): { [string]: any }
	if PlayerData.isTradeLocked(player) and action ~= "GetProfile" and action ~= "TradeState" then
		return reply(false, "Your equipment exchange is being saved. Please wait.")
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.2 then
		return reply(false, "Slow down!")
	end
	lastRequest[player] = now
	local handler = typeof(action) == "string" and handlers[action]
	if not handler or not PlayerData.get(player) then
		return reply(false, "Unknown request.")
	end
	return handler(player, ...)
end

function Shop.start()
	Remotes.Request.OnServerInvoke = Shop.handle
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return Shop
