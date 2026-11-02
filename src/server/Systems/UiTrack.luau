--[[
	Micro-interactions: what players tap and which windows they open, and how
	long a window sits open before they tap anything in it (hesitation),
	from Client UiTrack, into the game's own log (Server.Telemetry; dev and
	test accounts are left out there) and from there the ANALYTICS window's
	TAPS and WINDOWS (Shared.AnalyticsReport).

	The client sends a batch every so often (Remotes.UiTrack):
	  { Taps = { [key] = count }, Windows = { { Name, Seconds, FirstTap? } } }
	  key: "<window>/<button>" (a button's ScreenGui and its own name or words)

	Log rows:
	  ui_tap     v = taps   a = the window, b = the button
	  ui_window  v = seconds open   a = the window   b = seconds to its first tap (-1: none)

	Each player's batches are capped (MaxRows a minute): a broken client
	can't flood the log.

	  UiTrack.clean(batch) -> taps, windows   (pure: what's kept of a batch)
	  UiTrack.start()
]]
local Players = game:GetService("Players")

local Remotes = require(script.Parent.Remotes)
local Telemetry = require(script.Parent.Telemetry)

local UiTrack = {}

UiTrack.MaxRows = 60 -- a player's rows a minute, at most
UiTrack.MaxName = 48 -- characters kept of a window's or button's name

local function name(value: any): string?
	if type(value) ~= "string" or value == "" then
		return nil
	end
	return string.sub(value, 1, UiTrack.MaxName)
end

-- What's kept of a batch: { { window, button, count } }, { { window, seconds, firstTap } }.
function UiTrack.clean(batch: any): ({ any }, { any })
	local taps, windows = {}, {}
	if type(batch) ~= "table" then
		return taps, windows
	end
	if type(batch.Taps) == "table" then
		for key, count in batch.Taps do
			local window, button = nil, nil
			if type(key) == "string" then
				window, button = string.match(key, "^([^/]*)/(.+)$")
			end
			local n = tonumber(count)
			window, button = name(window), name(button)
			if window and button and n and n >= 1 then
				table.insert(taps, { window, button, math.min(math.floor(n), 500) })
			end
		end
	end
	if type(batch.Windows) == "table" then
		for _, w in batch.Windows do
			if type(w) == "table" then
				local window, seconds = name(w.Name), tonumber(w.Seconds)
				local first = tonumber(w.FirstTap)
				if window and seconds and seconds >= 0 and seconds < 86400 then
					table.insert(windows, { window, math.floor(seconds * 10 + 0.5) / 10, if first and first >= 0 then math.floor(first * 10 + 0.5) / 10 else -1 })
				end
			end
		end
	end
	return taps, windows
end

local budget: { [Player]: { At: number, Rows: number } } = {}

local function take(player: Player): boolean
	local now = os.clock()
	local b = budget[player]
	if not b or now - b.At >= 60 then
		b = { At = now, Rows = 0 }
		budget[player] = b
	end
	if b.Rows >= UiTrack.MaxRows then
		return false
	end
	b.Rows += 1
	return true
end

local started = false
function UiTrack.start()
	if started then
		return
	end
	started = true
	Remotes.UiTrack.OnServerEvent:Connect(function(player: Player, batch: any)
		local taps, windows = UiTrack.clean(batch)
		for _, t in taps do
			if not take(player) then
				return
			end
			Telemetry.record(player, "ui_tap", t[3], t[1], t[2])
		end
		for _, w in windows do
			if not take(player) then
				return
			end
			Telemetry.record(player, "ui_window", w[2], w[1], w[3])
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		budget[player] = nil
	end)
end

return UiTrack
