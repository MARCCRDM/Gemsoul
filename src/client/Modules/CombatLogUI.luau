--[[
	The combat log and fight details, like an RPG's.

	  Log      the last few lines, colour-coded:
	             Your Swing hits Kade Vorn for 24 (crit)
	             Kade Vorn's Heavy Blow hits you for 40 (31 blocked)
	             You are Burning (Thermal)
	  Details  this fight's breakdown: damage done (DPS, crit rate, biggest
	           hit, per ability) and damage taken (blocked, absorbed,
	           dodged, per ability), plus healing.

	Entries come from the server's "Log" events (see DamageLog); status lines
	come from the HUD's status bars. `format` and `tally` are pure, for tests.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local HudChrome = require(script.Parent.HudChrome)
local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)

local CombatLogUI = {}

local LINES = 6
local INK = Color3.fromRGB(12, 17, 28)
local TEXT = Color3.fromRGB(226, 232, 242)
local MUTED = Color3.fromRGB(150, 162, 182)
local GOLD = Color3.fromRGB(255, 196, 90)
local HURT = Color3.fromRGB(255, 110, 100)
local HEAL = Color3.fromRGB(110, 230, 140)

local function hex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function escape(value: string): string
	return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function paint(value: string, color: Color3, bold: boolean?): string
	local body = string.format('<font color="%s">%s</font>', hex(color), value)
	return if bold then "<b>" .. body .. "</b>" else body
end

local function abilityText(entry): string?
	if not entry.Ability then
		return nil
	end
	local color = GemConfig.ElementColors[entry.Element or ""] or GOLD
	return paint(escape(entry.Ability), color, true)
end

local function details(entry): string
	local notes = {}
	if entry.Crit then
		table.insert(notes, paint("critical", GOLD, true))
	end
	if entry.Blocked then
		table.insert(
			notes,
			string.format("%d %s", entry.Blocked, if entry.Kind == "Heal" then "prevented" else "blocked")
		)
	end
	if entry.Absorbed then
		table.insert(notes, string.format("%d absorbed", entry.Absorbed))
	end
	local text = if #notes > 0 then paint(" (" .. table.concat(notes, ", ") .. ")", MUTED) else ""
	if entry.Parried then
		text ..= paint(" PARRIED!", GOLD, true)
	end
	if entry.GuardBroken then
		text ..= paint(" GUARD BROKEN!", HURT, true)
	end
	return text
end

-- One log line (RichText).
function CombatLogUI.format(entry): string
	local who = escape(entry.Who or "Something")
	local ability = abilityText(entry)
	local amount = entry.Amount or 0
	if entry.Kind == "Status" then
		local effect = StatusEffects.Catalog[entry.Status]
		local color = if effect then effect.Color else MUTED
		local label = paint(StatusEffects.label(entry.Status), color, true)
		local value = if entry.Value
				and entry.Value > 0
				and effect
				and string.find(effect.Text, "%d%%", 1, true)
			then string.format(" %d%%", entry.Value)
			else ""
		if entry.Dir == "In" then
			return string.format("You are %s%s", label, value)
		end
		return string.format("%s is %s%s", who, label, value)
	elseif entry.Kind == "Dodge" then
		if entry.Dir == "In" then
			return string.format("You %s %s's %s", paint("dodged", HEAL, true), who, ability or "attack")
		end
		return string.format("%s %s your %s", who, paint("dodged", HURT, true), ability or "attack")
	elseif entry.Kind == "Combo" then
		-- An element combo (Shatter, Combustion, Superconduct).
		local combo = paint(string.upper(entry.Combo or "Combo") .. "!", GOLD, true)
		if entry.Dir == "In" then
			return string.format("%s %s on you", combo, if entry.Who then "by " .. who else "")
		end
		return string.format("%s on %s", combo, who)
	elseif entry.Kind == "Miss" then
		-- A blinded fighter's blow goes wide (Solar Flare).
		if entry.Dir == "In" then
			return string.format("%s's %s %s (blinded)", who, ability or "attack", paint("misses you", HEAL, true))
		end
		return string.format("Your %s %s (blinded)", ability or "attack", paint("misses", HURT, true))
	elseif entry.Kind == "Heal" then
		local healed = paint(tostring(amount), HEAL, true)
		if entry.Dir == "Foe" then
			return string.format("%s's %s heals it for %s%s", who, ability or "heal", healed, details(entry))
		end
		return string.format("Your %s heals you for %s%s", ability or "heal", healed, details(entry))
	elseif entry.Kind == "GuardBreak" then
		return string.format("You %s %s's guard!", paint("broke", GOLD, true), who)
	elseif entry.Kind == "Parried" then
		return string.format("%s %s your %s!", who, paint("parried", HURT, true), ability or "attack")
	elseif entry.Kind == "Cast" then
		return string.format("%s casts %s", who, ability or "a surge")
	elseif entry.Kind == "Kill" then
		return string.format("You defeated %s!", paint(who, GOLD, true))
	end
	-- A hit.
	if entry.Dir == "Out" then
		return string.format(
			"Your %s hits %s for %s%s",
			ability or "attack",
			who,
			paint(tostring(amount), if entry.Crit then GOLD else TEXT, true),
			details(entry)
		)
	end
	local from = if entry.Who and ability
		then string.format("%s's %s", who, ability)
		elseif ability then ability
		else who
	return string.format("%s hits you for %s%s", from, paint(tostring(amount), HURT, true), details(entry))
end

local function newSide()
	return { Total = 0, Hits = 0, Crits = 0, Biggest = 0, Blocked = 0, Absorbed = 0, Dodged = 0, ByAbility = {} }
end

function CombatLogUI.newStats(now: number)
	return { Started = now, Last = now, Done = newSide(), Taken = newSide(), Healed = 0, FoeHealed = 0 }
end

-- Adds an entry to a fight's numbers.
function CombatLogUI.tally(stats, entry, now: number)
	stats.Last = now
	local amount = entry.Amount or 0
	if entry.Kind == "Heal" then
		if entry.Dir == "Foe" then
			stats.FoeHealed += amount
		else
			stats.Healed += amount
		end
		return
	end
	local side = if entry.Dir == "Out" then stats.Done elseif entry.Dir == "In" then stats.Taken else nil
	if not side then
		return
	end
	if entry.Kind == "Dodge" then
		side.Dodged += 1
		return
	end
	if entry.Kind ~= "Hit" then
		return
	end
	local key = entry.Ability or "Attack"
	if entry.Dir == "In" and entry.Who and entry.Ability then
		key = entry.Who .. " · " .. entry.Ability
	end
	local row = side.ByAbility[key]
	if not row then
		row = { Name = key, Element = entry.Element, Total = 0, Hits = 0, Crits = 0, Biggest = 0 }
		side.ByAbility[key] = row
	end
	for _, bucket in { side, row } do
		bucket.Total += amount
		bucket.Hits += 1
		bucket.Crits += if entry.Crit then 1 else 0
		bucket.Biggest = math.max(bucket.Biggest, amount)
	end
	side.Blocked += entry.Blocked or 0
	side.Absorbed += entry.Absorbed or 0
end

-- Rows sorted biggest first, each with its share of the total.
function CombatLogUI.rows(side)
	local rows = {}
	for _, row in side.ByAbility do
		table.insert(rows, row)
	end
	table.sort(rows, function(a, b)
		return a.Total > b.Total
	end)
	for _, row in rows do
		row.Share = if side.Total > 0 then row.Total / side.Total else 0
	end
	return rows
end

-- UI --------------------------------------------------------------------------------------

local function make(class: string, props, parent: Instance?)
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function label(parent, text, size, color, font)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

local function panel(parent, size)
	local frame = make("Frame", {
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.18,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = size,
	}, parent)
	HudChrome.dress(frame, { Transparency = 0.25, Studs = false })
	return frame
end

local function button(parent, text, x)
	local b = make("TextButton", {
		BackgroundColor3 = Color3.fromRGB(28, 36, 54),
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, x, 0, 5),
		Size = UDim2.fromOffset(74, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = GOLD,
		Text = text,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
	return b
end

-- The panel. Call :add(entry), :reset() and :layout(viewport) from the HUD.
function CombatLogUI.new(parent: Instance)
	local self = { Entries = {}, Stats = CombatLogUI.newStats(os.clock()), Showing = "Log", Dirty = true }

	-- The log --------------------------------------------------------------
	local logPanel = panel(parent, UDim2.fromOffset(340, 34 + LINES * 16))
	local title = label(logPanel, "COMBAT LOG", 11, HudChrome.Gold, HudChrome.Title)
	title.Position, title.Size = UDim2.fromOffset(10, 4), UDim2.new(1, -100, 0, 20)
	local detailsButton = button(logPanel, "DETAILS  L", -6)
	local lineHolder = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 26),
		Size = UDim2.new(1, -20, 1, -30),
	}, logPanel)
	local lines = {}
	for i = 1, LINES do
		local line = label(lineHolder, "", 11, TEXT)
		line.Position, line.Size = UDim2.fromOffset(0, (i - 1) * 16), UDim2.new(1, 0, 0, 16)
		line.TextStrokeTransparency = 0.7
		lines[i] = line
	end
	local empty = label(lineHolder, "Hits, blocks and effects show up here.", 11, MUTED)
	empty.Size = UDim2.new(1, 0, 0, 16)

	-- The details -----------------------------------------------------------
	local detailPanel = panel(parent, UDim2.fromOffset(460, 316))
	detailPanel.Visible = false
	local detailTitle = label(detailPanel, "FIGHT DETAILS", 11, HudChrome.Gold, HudChrome.Title)
	detailTitle.Position, detailTitle.Size = UDim2.fromOffset(12, 4), UDim2.new(1, -180, 0, 20)
	local backButton = button(detailPanel, "LOG  L", -6)
	local resetButton = button(detailPanel, "RESET", -86)
	local function column(x, heading, color)
		local holder = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(x, if x == 0 then 12 else 6, 0, 28),
			Size = UDim2.new(0.5, -18, 1, -36),
		}, detailPanel)
		local head = label(holder, heading, 11, color, Enum.Font.GothamBold)
		head.Size = UDim2.new(1, 0, 0, 16)
		local total = label(holder, "", 20, TEXT, Enum.Font.GothamBlack)
		total.Position, total.Size = UDim2.fromOffset(0, 16), UDim2.new(1, 0, 0, 24)
		local facts = label(holder, "", 10, MUTED)
		facts.Position, facts.Size = UDim2.fromOffset(0, 40), UDim2.new(1, 0, 0, 30)
		facts.TextWrapped, facts.TextYAlignment = true, Enum.TextYAlignment.Top
		local rows = {}
		for i = 1, 8 do
			local y = 74 + (i - 1) * 25
			local name = label(holder, "", 10, TEXT, Enum.Font.GothamBold)
			name.Position, name.Size = UDim2.fromOffset(0, y), UDim2.new(1, -44, 0, 14)
			local value = label(holder, "", 10, TEXT, Enum.Font.GothamBold)
			value.Position, value.Size = UDim2.new(1, -44, 0, y), UDim2.fromOffset(44, 14)
			value.TextXAlignment = Enum.TextXAlignment.Right
			local track = make("Frame", {
				BackgroundColor3 = Color3.fromRGB(28, 34, 50),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, y + 15),
				Size = UDim2.new(1, 0, 0, 5),
			}, holder)
			make("UICorner", { CornerRadius = UDim.new(0, 2) }, track)
			local fill =
				make("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
			make("UICorner", { CornerRadius = UDim.new(0, 2) }, fill)
			rows[i] = { Name = name, Value = value, Track = track, Fill = fill }
		end
		return { Total = total, Facts = facts, Rows = rows }
	end
	local done = column(0, "DAMAGE DONE", GOLD)
	local taken = column(0.5, "DAMAGE TAKEN", HURT)
	local healing = label(detailPanel, "", 10, HEAL)
	healing.AnchorPoint, healing.Position, healing.Size =
		Vector2.new(0, 1), UDim2.new(0, 12, 1, -6), UDim2.new(1, -24, 0, 14)

	local function fillColumn(view, side, isDone, seconds)
		view.Total.Text = tostring(math.floor(side.Total + 0.5))
		if isDone then
			view.Facts.Text = string.format(
				"%.0f DPS  ·  %d hits  ·  %d%% crit  ·  best %d%s",
				side.Total / math.max(1, seconds),
				side.Hits,
				if side.Hits > 0 then math.floor(side.Crits / side.Hits * 100 + 0.5) else 0,
				side.Biggest,
				if side.Dodged > 0 then string.format("  ·  %d dodged by foe", side.Dodged) else ""
			)
		else
			view.Facts.Text = string.format(
				"%d hits  ·  %d blocked  ·  %d absorbed  ·  %d dodged  ·  worst %d",
				side.Hits,
				side.Blocked,
				side.Absorbed,
				side.Dodged,
				side.Biggest
			)
		end
		local rows = CombatLogUI.rows(side)
		for i, row in view.Rows do
			local data = rows[i]
			local show = data ~= nil
			row.Name.Visible, row.Value.Visible, row.Track.Visible = show, show, show
			if data then
				row.Name.Text = escape(data.Name)
				row.Name.TextColor3 = GemConfig.ElementColors[data.Element or ""] or TEXT
				row.Value.Text = string.format("%d", data.Total)
				row.Fill.Size = UDim2.fromScale(data.Share, 1)
			end
		end
	end

	local function refresh()
		self.Dirty = false
		for i, line in lines do
			local entry = self.Entries[#self.Entries - LINES + i]
			line.Text = if entry then entry.Text else ""
			line.TextTransparency = if entry then math.clamp((LINES - i) * 0.07, 0, 0.45) else 0
		end
		empty.Visible = #self.Entries == 0
		if detailPanel.Visible then
			local stats = self.Stats
			local seconds = stats.Last - stats.Started
			detailTitle.Text = string.format("FIGHT DETAILS  ·  %ds", math.floor(seconds + 0.5))
			fillColumn(done, stats.Done, true, seconds)
			fillColumn(taken, stats.Taken, false, seconds)
			healing.Text = string.format(
				"You healed %d  ·  Foe healed %d",
				math.floor(stats.Healed + 0.5),
				math.floor(stats.FoeHealed + 0.5)
			)
		end
	end

	function self.add(_, entry)
		local now = os.clock()
		entry.Text = CombatLogUI.format(entry)
		table.insert(self.Entries, entry)
		if #self.Entries > 60 then
			table.remove(self.Entries, 1)
		end
		CombatLogUI.tally(self.Stats, entry, now)
		self.Dirty = true
	end

	function self.reset()
		self.Stats = CombatLogUI.newStats(os.clock())
		self.Dirty = true
	end

	function self.toggle()
		local showDetails = not detailPanel.Visible
		detailPanel.Visible, logPanel.Visible = showDetails, not showDetails
		self.Dirty = true
	end

	function self.step(_, visible: boolean)
		if not visible then
			logPanel.Visible, detailPanel.Visible = false, false
			return
		end
		if not detailPanel.Visible then
			logPanel.Visible = true
		end
		if self.Dirty then
			refresh()
		end
	end

	detailsButton.Activated:Connect(self.toggle)
	backButton.Activated:Connect(self.toggle)
	resetButton.Activated:Connect(self.reset)
	self.LogPanel, self.DetailPanel = logPanel, detailPanel
	return self
end

return CombatLogUI
