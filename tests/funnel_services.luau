-- Stand-ins for the onboarding funnel: signals, players with attributes,
-- profiles, the Funnel remote and the steps sent to Roblox.
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
local profiles = {}
local PlayerData = {
	Loaded = signal(),
	Trained = signal(),
	get = function(player)
		return profiles[player]
	end,
}
local Remotes = { Funnel = { OnServerEvent = signal() } }
local everyone = {}
local Players = {
	GetPlayers = function()
		return everyone
	end,
}
local function makePlayer(id, name)
	local attributes, watchers = {}, {}
	local p = { UserId = id, Name = name }
	function p:GetAttribute(key)
		return attributes[key]
	end
	function p:SetAttribute(key, value)
		attributes[key] = value
		if watchers[key] then
			watchers[key]:Fire()
		end
	end
	function p:GetAttributeChangedSignal(key)
		watchers[key] = watchers[key] or signal()
		return watchers[key]
	end
	return p
end
local sent = {}
local task = {
	spawn = function(fn, ...)
		fn(...)
	end,
}
local warnings = {}
local function warn(message)
	table.insert(warnings, message)
end
