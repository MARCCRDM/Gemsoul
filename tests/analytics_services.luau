-- Stand-ins for Systems/Analytics: signals, players, the services it uses,
-- the loop it starts and the warnings it gives.
local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end
local guids = 0
local HttpService = {
	GenerateGUID = function(_, _braces)
		guids += 1
		return "visit-" .. guids
	end,
}
local everyone = {}
local Players = {
	PlayerRemoving = signal(),
	GetPlayerByUserId = function(_, id)
		for _, p in everyone do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
}
local function makePlayer(id, name)
	local p = { UserId = id, Name = name }
	table.insert(everyone, p)
	return p
end
local MarketplaceService = { PromptProductPurchaseFinished = signal() }
local closers = {}
local game = {
	GetService = function(_, name)
		if name == "MarketplaceService" then
			return MarketplaceService
		end
		error("no service " .. name)
	end,
	BindToClose = function(_, fn)
		table.insert(closers, fn)
	end,
}
local loops = {}
local task = {
	-- (The flush loop is kept, not run: it never ends.)
	spawn = function(fn)
		table.insert(loops, fn)
	end,
	wait = function() end,
}
local warnings = {}
local function warn(message)
	table.insert(warnings, message)
end
