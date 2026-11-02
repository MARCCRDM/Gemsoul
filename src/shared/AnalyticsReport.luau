--[[
	The in-game analytics window's numbers (Server.AnalyticsPanel, Client
	AnalyticsUI), worked out from the game's own event log (Server.Telemetry):
	the same rows tools/telemetry/report.py reads, { t, u, e, v, a, b, c }.

	  AnalyticsReport.build(rows, options?) -> report   (pure)
	      options.Now    os.time() (for "today")
	      options.Live   { [userId] = { Name, Since, Step } } players here now
	      options.Exclude  { [userId] = true } accounts left out (dev and
	                     test accounts); and anyone marked so in the rows
	                     (an "analytics_excluded" row, its latest)
	  AnalyticsReport.excludedIn(rows, listed?) -> { [userId] = true }

	The report:
	  Players, New, Returning, Sessions, AvgSession (minutes), MedianSession,
	  PeakOnline, Revenue (Robux), Payers, Purchases, D1 = { Cohort, Back, Pct }
	  (players who came new on a day, of those whose next day is in the
	  range, how many came back on it; nil when no next day is in range)
	  Funnel   { { Step, Name, Users, Pct (of step 1), Drop (from the last) } }
	  Rounds   { { Round, Slot, Won, Lost, Rare } }
	  Devices, Countries, Sources, Sinks, Products, Events   { { Name, Value } },
	           biggest first (Countries and Events: the top 8)
	  Duels    { { Name, Wins, Losses } }
	  Lengths  { { Name, Value } }   sessions by length (<2m ... 40m+)
	  Taps     { { Name = "window/button", Value = taps, Players } }   the most
           pressed buttons (Server.UiTrack: micro-interactions), top 12
  Windows  { { Name, Value = opens, Players, AvgSeconds, AvgFirstTap,
           NoTap } }   windows opened: how long they stay up, how long
           before the first tap in them (hesitation), and the share shut
           with no tap at all; top 12 by opens
  Funnels  { [name] = steps, as Funnel's }   the game's other funnels
	           (Server.Analytics: "IntroRounds", "Store")
	  From, To   the first and last row's time; Rows   how many
]]
local AnalyticsReport = {}

AnalyticsReport.Top = 8
-- Session lengths' bands, in minutes: from, up to, name.
AnalyticsReport.Lengths = {
	{ 0, 2, "under 2m" },
	{ 2, 5, "2-5m" },
	{ 5, 10, "5-10m" },
	{ 10, 20, "10-20m" },
	{ 20, 40, "20-40m" },
	{ 40, math.huge, "40m+" },
}

local DAY = 86400

local function sorted(map: { [string]: number }, limit: number?)
	local list = {}
	for name, value in map do
		table.insert(list, { Name = name, Value = value })
	end
	table.sort(list, function(a, b)
		if a.Value ~= b.Value then
			return a.Value > b.Value
		end
		return a.Name < b.Name
	end)
	if limit then
		while #list > limit do
			table.remove(list)
		end
	end
	return list
end

local function count(set): number
	local n = 0
	for _ in set do
		n += 1
	end
	return n
end

local function pct(n: number, d: number): number?
	if d <= 0 then
		return nil
	end
	return math.floor(1000 * n / d + 0.5) / 10
end

local function median(list: { number }): number?
	if #list == 0 then
		return nil
	end
	local copy = table.clone(list)
	table.sort(copy)
	local mid = (#copy + 1) / 2
	if mid % 1 == 0 then
		return copy[mid]
	end
	return (copy[math.floor(mid)] + copy[math.ceil(mid)]) / 2
end

local function round1(x: number?): number?
	return if x then math.floor(x * 10 + 0.5) / 10 else nil
end

-- The accounts to leave out: `listed` (UserId -> true) and anyone whose
-- latest "analytics_excluded" row says so (marked NOT COUNTED).
function AnalyticsReport.excludedIn(rows: { any }, listed: { [number]: boolean }?): { [number]: boolean }
	local out = table.clone(listed or {})
	local latest: { [number]: number } = {}
	for _, r in rows do
		if r[3] == "analytics_excluded" then
			local u, t = tonumber(r[2]) or 0, tonumber(r[1]) or 0
			if t >= (latest[u] or -math.huge) then
				latest[u] = t
				out[u] = if tonumber(r[4]) == 1 then true else (listed and listed[u]) or nil
			end
		end
	end
	return out
end

function AnalyticsReport.build(rows: { any }, options: any?)
	options = options or {}
	-- (dev and test accounts: none of their rows count)
	local skip = AnalyticsReport.excludedIn(rows, options.Exclude)
	if next(skip) then
		local kept = {}
		for _, r in rows do
			if not skip[tonumber(r[2]) or 0] and r[3] ~= "analytics_excluded" then
				table.insert(kept, r)
			end
		end
		rows = kept
	end
	local players, newPlayers, payers = {}, {}, {}
	local activeDays: { [number]: { [number]: boolean } } = {} -- day -> users
	local newDay: { [number]: number } = {} -- user -> the day they came new
	local sessions, lengths = 0, {}
	local revenue, purchases = 0, 0
	local funnelUsers: { [number]: { [number]: boolean } } = {}
	local funnelNames: { [number]: string } = {}
	local rounds = {}
	local devices: { [number]: string } = {}
	local countries: { [number]: string } = {}
	local sources, sinks, products, events = {}, {}, {}, {}
	local duels = {}
	local funnels = {} -- name -> { Users = { [step] = set }, Names = { [step] = name } }
	local taps = {} -- "window/button" -> { Value, Players = set }
	local windows = {} -- window -> { Opens, Seconds, Tapped, FirstTap, Players = set }
	local online: { [number]: { [string]: number } } = {} -- 5-minute bucket -> server -> players
	local from, to = math.huge, 0
	for _, r in rows do
		local t, u, e, v, a, b, c = tonumber(r[1]) or 0, tonumber(r[2]) or 0, r[3], r[4], r[5], r[6], r[7]
		if type(e) ~= "string" then
			continue
		end
		from, to = math.min(from, t), math.max(to, t)
		events[e] = (events[e] or 0) + 1
		local day = t - t % DAY
		if u ~= 0 then
			players[u] = true
			activeDays[day] = activeDays[day] or {}
			activeDays[day][u] = true
		end
		local n = tonumber(v)
		if e == "session_start" then
			sessions += 1
			if a == "new" then
				newPlayers[u] = true
				if not newDay[u] or day < newDay[u] then
					newDay[u] = day
				end
			end
			if type(b) == "string" and b ~= "" then
				countries[u] = b
			end
		elseif e == "session_end" and n and n >= 0 then
			table.insert(lengths, n / 60)
		elseif e == "device" then
			devices[u] = if type(a) == "string" then a else "unknown"
		elseif e == "onboarding" and n then
			local step = math.floor(n)
			funnelUsers[step] = funnelUsers[step] or {}
			funnelUsers[step][u] = true
			if type(a) == "string" then
				funnelNames[step] = a
			end
		elseif e == "IntroRound" and n then
			local k = math.floor(n)
			local rd = rounds[k] or { Round = k, Slot = nil, Won = {}, Lost = 0, Rare = 0 }
			rounds[k] = rd
			if type(a) == "string" and a ~= "" then
				rd.Slot = a
			end
			if c == "Won" or c == "Done" then
				rd.Won[u] = true
				if b == "Rare" then
					rd.Rare += 1
				end
			elseif c == "Lost" then
				rd.Lost += 1
			end
		elseif e == "DuelFinished" then
			local mode = if type(a) == "string" then a else "?"
			local d = duels[mode] or { Name = mode, Wins = 0, Losses = 0 }
			duels[mode] = d
			if b == "Win" then
				d.Wins += 1
			elseif b == "Loss" then
				d.Losses += 1
			end
		elseif e == "coins" and n then
			local reason = if type(a) == "string" and a ~= "" then a else "Other"
			if n >= 0 then
				sources[reason] = (sources[reason] or 0) + n
			else
				sinks[reason] = (sinks[reason] or 0) - n
			end
		elseif e == "Purchase" then
			purchases += 1
			payers[u] = true
			local robux = if b == "Robux" and n then n else 0
			revenue += robux
			local product = if type(a) == "string" then a else "?"
			products[product] = (products[product] or 0) + robux
		elseif e == "store_funnel" and n then
			-- (the game's other funnels: Analytics' Store and IntroRounds)
			local name = if type(b) == "string" then b else "?"
			local f = funnels[name] or { Users = {}, Names = {} }
			funnels[name] = f
			local step = math.floor(n)
			f.Users[step] = f.Users[step] or {}
			f.Users[step][u] = true
			if type(a) == "string" then
				f.Names[step] = a
			end
		elseif e == "ui_tap" and n and type(a) == "string" and type(b) == "string" then
			local key = a .. "/" .. b
			local t = taps[key] or { Value = 0, Players = {} }
			taps[key] = t
			t.Value += n
			t.Players[u] = true
		elseif e == "ui_window" and n and type(a) == "string" then
			local w = windows[a] or { Opens = 0, Seconds = 0, Tapped = 0, FirstTap = 0, Players = {} }
			windows[a] = w
			w.Opens += 1
			w.Seconds += n
			w.Players[u] = true
			local first = tonumber(b)
			if first and first >= 0 then
				w.Tapped += 1
				w.FirstTap += first
			end
		elseif e == "server" and n then
			local bucket = t - t % 300
			online[bucket] = online[bucket] or {}
			online[bucket][tostring(r.server or "here")] = n
		end
	end
	if from == math.huge then
		from = 0
	end

	-- Day-1 return: of those who came new on a day whose next day is in the
	-- range (and over: today's newcomers can't have come back yet).
	local lastDay = to - to % DAY
	local cohort, back = 0, 0
	for u, day in newDay do
		if day + DAY <= lastDay then
			cohort += 1
			if activeDays[day + DAY] and activeDays[day + DAY][u] then
				back += 1
			end
		end
	end

	-- A funnel's steps in order: players at each, their share of the first
	-- step's, and the drop from the step before.
	local function stepsOf(users, names)
		local order = {}
		for step in users do
			table.insert(order, step)
		end
		table.sort(order)
		local out = {}
		local first = if order[1] then count(users[order[1]]) else 0
		local before = nil
		for _, step in order do
			local n = count(users[step])
			table.insert(out, {
				Step = step,
				Name = names[step] or tostring(step),
				Users = n,
				Pct = pct(n, first),
				Drop = if before then pct(before - n, before) else 0,
			})
			before = n
		end
		return out
	end
	local funnelList = {}
	for name, f in funnels do
		funnelList[name] = stepsOf(f.Users, f.Names)
	end

	local steps = {}
	for step in funnelUsers do
		table.insert(steps, step)
	end
	table.sort(steps)
	local funnel = {}
	local top = if steps[1] then count(funnelUsers[steps[1]]) else 0
	local previous = nil
	for _, step in steps do
		local users = count(funnelUsers[step])
		table.insert(funnel, {
			Step = step,
			Name = funnelNames[step] or tostring(step),
			Users = users,
			Pct = pct(users, top),
			Drop = if previous then pct(previous - users, previous) else 0,
		})
		previous = users
	end

	local roundList = {}
	for _, rd in rounds do
		table.insert(roundList, { Round = rd.Round, Slot = rd.Slot, Won = count(rd.Won), Lost = rd.Lost, Rare = rd.Rare })
	end
	table.sort(roundList, function(a, b)
		return a.Round < b.Round
	end)

	local peak = 0
	for _, servers in online do
		local sum = 0
		for _, n in servers do
			sum += n
		end
		peak = math.max(peak, sum)
	end
	local live = options.Live
	if type(live) == "table" then
		peak = math.max(peak, count(live))
	end

	local function tally(map: { [number]: string })
		local out = {}
		for _, name in map do
			out[name] = (out[name] or 0) + 1
		end
		return out
	end
	local duelList = {}
	for _, d in duels do
		table.insert(duelList, d)
	end
	table.sort(duelList, function(a, b)
		return a.Wins + a.Losses > b.Wins + b.Losses
	end)
	local total = 0
	for _, x in lengths do
		total += x
	end
	local lengthList = {}
	for _, band in AnalyticsReport.Lengths do
		local n = 0
		for _, x in lengths do
			if x >= band[1] and x < band[2] then
				n += 1
			end
		end
		table.insert(lengthList, { Name = band[3], Value = n })
	end
	local tapList = {}
	for key, t in taps do
		table.insert(tapList, { Name = key, Value = t.Value, Players = count(t.Players) })
	end
	table.sort(tapList, function(x, y)
		return if x.Value ~= y.Value then x.Value > y.Value else x.Name < y.Name
	end)
	while #tapList > 12 do
		table.remove(tapList)
	end
	local windowList = {}
	for name, w in windows do
		table.insert(windowList, {
			Name = name,
			Value = w.Opens,
			Players = count(w.Players),
			AvgSeconds = round1(w.Seconds / w.Opens),
			AvgFirstTap = if w.Tapped > 0 then round1(w.FirstTap / w.Tapped) else nil,
			NoTap = pct(w.Opens - w.Tapped, w.Opens),
		})
	end
	table.sort(windowList, function(x, y)
		return if x.Value ~= y.Value then x.Value > y.Value else x.Name < y.Name
	end)
	while #windowList > 12 do
		table.remove(windowList)
	end
	local playerCount, newCount = count(players), count(newPlayers)
	return {
		Rows = #rows,
		From = from,
		To = to,
		Players = playerCount,
		New = newCount,
		Returning = playerCount - newCount,
		Sessions = sessions,
		AvgSession = if #lengths > 0 then round1(total / #lengths) else nil,
		MedianSession = round1(median(lengths)),
		PeakOnline = peak,
		Revenue = revenue,
		Purchases = purchases,
		Payers = count(payers),
		D1 = if cohort > 0 then { Cohort = cohort, Back = back, Pct = pct(back, cohort) } else nil,
		Funnel = funnel,
		Rounds = roundList,
		Devices = sorted(tally(devices)),
		Countries = sorted(tally(countries), AnalyticsReport.Top),
		Sources = sorted(sources, AnalyticsReport.Top),
		Sinks = sorted(sinks, AnalyticsReport.Top),
		Products = sorted(products, AnalyticsReport.Top),
		Events = sorted(events, AnalyticsReport.Top),
		Duels = duelList,
		Lengths = lengthList,
		Funnels = funnelList,
		Taps = tapList,
		Windows = windowList,
	}
end

return AnalyticsReport
