--[[
	Translations. The game is written in English; a player whose Roblox
	language is Spanish sees it in Spanish. Screens don't call anything: the
	client translates every label as its text is set (client/Translate), from
	the table in Shared.LangEs.

	  Lang.setLocale(id)      a Roblox locale ("es-mx", "es-es", "en-us"...);
	                          Spanish turns the table on, anything else off
	  Lang.active()           true while a translation is on
	  Lang.translate(text)    the text in the player's language (the same
	                          text when there's nothing to translate)
	  Lang.format(key, ...)   an entry with its {1}, {2}... filled in, for
	                          text built in code

	Table entries (key = the English, value = the Spanish):
	  ["PLAY"] = "JUGAR"
	      exact text
	  ["Break {1} rocks"] = "Rompe {1} rocas"
	      {1}, {2}... are the numbers in the text, in order ("40", "1,250",
	      "39h"); the Spanish may use them in any order
	  ["DAILY CHALLENGE: {*}"] = "DESAFÍO DIARIO: {*}"
	      {*} matches any text and translates it too; {=} matches text kept
	      as it is (a player's name). In the Spanish, {*} and {=} take the
	      matches in order, or {*2} names the second one.

	Text that matches no entry is split and its pieces translated: rich-text
	tags are kept and the words between them translated, and so is each
	part of a "  ·  " or "\n" list. ALL-CAPS text uses the entry for the same
	words in any case ("RARE" uses "Rare"), in capitals.
]]
local Lang = {}

local tables = {
	es = function()
		return require(script.Parent.LangEs)
	end,
}

local current: string? = nil
local exact: { [string]: string } = {}
local upper: { [string]: string } = {} -- an entry's key in capitals -> its value
local wild: { { Pattern: string, Kinds: { string }, Value: string, Fixed: number } } = {}
local cache: { [string]: string } = {}
local cached = 0

-- Capitals for Spanish: string.upper leaves accented letters alone.
-- (Rich-text tags are left as they are.)
local ACCENTS = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
local function capsRun(run: string): string
	return (string.upper(run):gsub("\195[\128-\191]", function(c)
		return ACCENTS[c] or c
	end))
end
local function caps(text: string): string
	if not string.find(text, "<", 1, true) then
		return capsRun(text)
	end
	return (text:gsub("([^<]*)(<?[^>]*>?)", function(run, tag)
		return capsRun(run) .. tag
	end))
end
Lang.upper = caps

-- Numbers become {1}, {2}... (not inside <tags>, not glued to a word
-- before them, and not the 1s of "1v1").
local function numberize(segment: string, numbers: { string }): string
	return (segment:gsub("()(%d[%d,%.]*)", function(at: number, run: string)
		local trail = run:match("[,%.]+$") or ""
		run = string.sub(run, 1, #run - #trail)
		local before = if at > 1 then string.sub(segment, at - 1, at - 1) else ""
		local after = string.sub(segment, at + #run, at + #run + 1)
		if before:match("[%w{]") or after:match("^[vVxX]%d") then
			return nil
		end
		table.insert(numbers, run)
		return "{" .. #numbers .. "}" .. trail
	end))
end

function Lang.normalize(text: string): (string, { string })
	local numbers = {}
	if not string.find(text, "%d") then
		return text, numbers
	end
	local out, at = {}, 1
	while at <= #text do
		local open = string.find(text, "<", at, true)
		local close = open and string.find(text, ">", open, true)
		if not open or not close then
			table.insert(out, numberize(string.sub(text, at), numbers))
			break
		end
		table.insert(out, numberize(string.sub(text, at, open - 1), numbers))
		table.insert(out, string.sub(text, open, close))
		at = close + 1
	end
	return table.concat(out), numbers
end

local function fill(value: string, numbers: { string }): string
	return (value:gsub("{(%d+)}", function(i)
		return numbers[tonumber(i)] or ""
	end))
end

local function escape(text: string): string
	return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function compile(key: string, value: string)
	local kinds = {}
	local pattern = escape(key):gsub("{%%?([%*=])}", function(kind)
		table.insert(kinds, kind)
		return "(.-)"
	end)
	local fixed = #(key:gsub("{[%*=]}", ""))
	table.insert(wild, { Pattern = "^" .. pattern .. "$", Kinds = kinds, Value = value, Fixed = fixed })
end

-- (`entries` stands in for the language's table: tests.)
function Lang.setLocale(id: string?, entries: { [string]: string }?)
	local language = string.lower(string.sub(id or "", 1, 2))
	local load = if entries then function()
		return entries
	end else tables[language]
	if entries then
		current = nil
	end
	if (if load then language else nil) == current then
		return
	end
	current = if load then language else nil
	table.clear(exact)
	table.clear(upper)
	table.clear(wild)
	table.clear(cache)
	cached = 0
	if not load then
		return
	end
	for key, value in load() do
		if string.find(key, "{[%*=]}") then
			compile(key, value)
		else
			exact[key] = value
			local capitals = caps(key)
			if capitals ~= key and upper[capitals] == nil then
				upper[capitals] = caps(value)
			end
		end
	end
	-- The most fixed text first: the more specific entry wins ("<b>You</b>
	-- found..." before "<b>{=}</b> found...").
	table.sort(wild, function(a, b)
		if a.Fixed ~= b.Fixed then
			return a.Fixed > b.Fixed
		end
		return a.Pattern < b.Pattern
	end)
end

function Lang.active(): boolean
	return current ~= nil
end

function Lang.language(): string
	return current or "en"
end

local translate

-- One whole text against the table: exact, with its numbers, then the {*}
-- entries. nil when nothing matches.
local function lookup(text: string, depth: number): string?
	local hit = exact[text] or upper[text]
	if hit then
		return hit
	end
	local key, numbers = Lang.normalize(text)
	if #numbers > 0 then
		hit = exact[key] or upper[key]
		if hit then
			return fill(hit, numbers)
		end
	end
	if depth > 2 then
		return nil
	end
	for _, entry in wild do
		local found = { string.match(key, entry.Pattern) }
		if #found > 0 then
			local parts = {}
			for i, part in found do
				part = fill(part, numbers)
				parts[i] = if entry.Kinds[i] == "*" then translate(part, depth + 1) else part
			end
			local nextPart = 0
			local out = entry.Value:gsub("{[%*=](%d*)}", function(index)
				if index ~= "" then
					return parts[tonumber(index)] or ""
				end
				nextPart += 1
				return parts[nextPart] or ""
			end)
			return out
		end
	end
	return nil
end

-- A piece of a list: its spaces kept, the words translated.
local function piece(part: string, depth: number): string
	local lead, body, trail = part:match("^(%s*)(.-)(%s*)$")
	if body == "" then
		return part
	end
	return lead .. (lookup(body, depth) or body) .. trail
end

local SEPARATORS = { "\n", "  ·  ", " · " }

-- Text with no entry of its own: its rich-text runs and list pieces.
local function split(text: string, depth: number): string
	local out, at = {}, 1
	while at <= #text do
		local open = string.find(text, "<", at, true)
		local close = open and string.find(text, ">", open, true)
		local run = string.sub(text, at, if open and close then open - 1 else #text)
		local lead, body, trail = run:match("^(%s*)(.-)(%s*)$")
		local whole = if body ~= "" and run ~= text then lookup(body, depth) else nil
		if whole then
			-- (The run has an entry of its own: "5 online · 1 searching".)
			table.insert(out, lead .. whole .. trail)
		elseif run ~= "" then
			local pieces = { run }
			for _, separator in SEPARATORS do
				local nextPieces = {}
				for _, p in pieces do
					if type(p) == "table" then
						table.insert(nextPieces, p) -- (a separator found already)
						continue
					end
					local start = 1
					while true do
						local s, e = string.find(p, separator, start, true)
						if not s then
							table.insert(nextPieces, string.sub(p, start))
							break
						end
						table.insert(nextPieces, string.sub(p, start, s - 1))
						table.insert(nextPieces, { separator })
						start = e + 1
					end
				end
				pieces = nextPieces
			end
			for _, p in pieces do
				table.insert(out, if type(p) == "table" then p[1] else piece(p, depth))
			end
		end
		if not (open and close) then
			break
		end
		table.insert(out, string.sub(text, open, close))
		at = close + 1
	end
	return table.concat(out)
end

function translate(text: string, depth: number?): string
	if current == nil or text == "" or not string.find(text, "%a") then
		return text
	end
	local d = depth or 0
	if d == 0 then
		local hit = cache[text]
		if hit then
			return hit
		end
	end
	local out = lookup(text, d)
	if out == nil then
		out = if string.find(text, "<", 1, true) or string.find(text, "·", 1, true) or string.find(text, "\n", 1, true)
			then split(text, d)
			else piece(text, d) -- (the same words with spaces around them)
	end
	if d == 0 then
		-- (A cap, so a clock that counts every second can't grow it forever.)
		if cached >= 4000 then
			table.clear(cache)
			cached = 0
		end
		cache[text] = out
		cached += 1
	end
	return out
end
Lang.translate = function(text: string): string
	return translate(text)
end

function Lang.format(key: string, ...: any): string
	local numbers = { ... }
	for i, v in numbers do
		numbers[i] = tostring(v)
	end
	return fill(if current and exact[key] then exact[key] else key, numbers)
end

return Lang
