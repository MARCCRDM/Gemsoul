-- Shared.Lang: the lookup rules, against a small table; then the real
-- Spanish table (Shared.LangEs) for mistakes in its entries.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function same(got, want, message)
	check(got == want, message .. ": got " .. tostring(got) .. ", want " .. tostring(want))
end

local entries = {
	["PLAY"] = "JUGAR",
	["Rare"] = "Raro",
	["Common"] = "Común",
	["Chest"] = "Pecho",
	["Break {1} rocks"] = "Rompe {1} rocas",
	["{1} / {2} XP to level {3}"] = "{1} / {2} XP para el nivel {3}",
	["Day {1} of {2}. Don't break the chain!"] = "Día {1} de {2}. ¡No rompas la racha!",
	["{1} of {2} friends joined"] = "Se unieron {1} de {2} amigos",
	["{1}h left"] = "quedan {1}h",
	["1v1 PRACTICE"] = "PRÁCTICA 1v1",
	["DAILY CHALLENGE: {*}  +{=} coins"] = "DESAFÍO DIARIO: {*}  +{=} monedas",
	["{=} found a {*} gem"] = "{=} encontró una gema {*}",
	["{=} defeated {=}"] = "{=2} cayó ante {=1}",
	["Legendary"] = "Legendaria",
	["Rewards: {*}"] = "Premios: {*}",
	["Coins"] = "Monedas",
	["{=} found {*}"] = "{=} encontró {*}",
	["You found {*}"] = "Encontraste {*}",
	["{1} online · {2} searching"] = "{1} conectados · {2} buscando",
}

-- Off: nothing changes.
Lang.setLocale("en-us")
check(not Lang.active(), "English turned a translation on")
same(Lang.translate("PLAY"), "PLAY", "English translated")
same(Lang.language(), "en", "The language")

Lang.setLocale("es-mx", entries)
check(Lang.active(), "Spanish didn't turn on")
same(Lang.language(), "es", "The language")
same(Lang.translate("PLAY"), "JUGAR", "Exact text")
same(Lang.translate("Nothing like it"), "Nothing like it", "Unknown text")
same(Lang.translate(""), "", "Empty text")
same(Lang.translate("1,240"), "1,240", "A number")

-- Numbers.
same(Lang.translate("Break 10 rocks"), "Rompe 10 rocas", "A number in the text")
same(Lang.translate("40 / 150 XP to level 6"), "40 / 150 XP para el nivel 6", "Three numbers")
same(Lang.translate("Day 4 of 7. Don't break the chain!"), "Día 4 de 7. ¡No rompas la racha!", "A full stop after a number")
same(Lang.translate("2 of 3 friends joined"), "Se unieron 2 de 3 amigos", "Numbers moved")
same(Lang.translate("39h left"), "quedan 39h", "A number with a unit")
same(Lang.translate("1v1 PRACTICE"), "PRÁCTICA 1v1", "1v1 isn't a number")
same(Lang.translate("Break 1,250 rocks"), "Rompe 1,250 rocas", "Thousands")
local key, numbers = Lang.normalize('<font color="#59A3F8">Break 3 rocks</font>')
same(key, '<font color="#59A3F8">Break {1} rocks</font>', "Digits in a tag")
same(#numbers, 1, "Numbers in a tag")

-- Capitals.
same(Lang.translate("RARE"), "RARO", "Capitals use the entry")
same(Lang.translate("COMMON"), "COMÚN", "Accented capitals")
same(Lang.translate("BREAK 5 ROCKS"), "ROMPE 5 ROCAS", "Capitals with a number")
same(Lang.upper('<font color="#abc">á</font>'), '<font color="#abc">Á</font>', "Tags keep their case")

-- Rich text and lists, piece by piece.
same(Lang.translate('<font color="#59A3F8">RARE</font>  ·  CHEST'), '<font color="#59A3F8">RARO</font>  ·  PECHO', "Tags and a list")
same(Lang.translate("Rare\nCommon"), "Raro\nComún", "Lines")
same(Lang.translate("Rare · Mystery"), "Raro · Mystery", "A piece with no entry")
same(
	Lang.translate('<font color="#4ED692">●</font> 5 online · 1 searching'),
	'<font color="#4ED692">●</font> 5 conectados · 1 buscando',
	"A run between tags tried whole first"
)

-- {*} and {=}.
same(Lang.translate("DAILY CHALLENGE: Break 10 rocks  +40 coins"), "DESAFÍO DIARIO: Rompe 10 rocas  +40 monedas", "{*} translates, {=} keeps")
same(Lang.translate("Kade found a Legendary gem"), "Kade encontró una gema Legendaria", "A name kept")
same(Lang.translate("Mira defeated Orrin"), "Orrin cayó ante Mira", "Matches in another order")
same(Lang.translate("Rewards: Coins"), "Premios: Monedas", "A wildcard at the end")
same(Lang.translate("You found Coins"), "Encontraste Monedas", "The entry with more fixed text first")
same(Lang.translate("Mira found Coins"), "Mira encontró Monedas", "The general entry")

-- The same text twice (the cache), and a full cache.
same(Lang.translate("Break 10 rocks"), "Rompe 10 rocas", "From the cache")
for i = 1, 4100 do
	Lang.translate("Break " .. i .. " rocks")
end
same(Lang.translate("Break 7 rocks"), "Rompe 7 rocas", "After the cache filled")

-- Text built in code.
same(Lang.format("Break {1} rocks", 12), "Rompe 12 rocas", "format")
same(Lang.format("Not an entry {1}", 3), "Not an entry 3", "format with no entry")
Lang.setLocale("en")
same(Lang.format("Break {1} rocks", 12), "Break 12 rocks", "format in English")
same(Lang.translate("Break 10 rocks"), "Break 10 rocks", "Off again")

print("PASS: " .. checks .. " translation checks (exact, numbers, capitals, rich text, lists, wildcards, cache, format)")

-- The Spanish table ------------------------------------------------------------------------------------
local tableChecks = checks
local count = 0
for english, spanish in LangEs do
	count += 1
	check(type(english) == "string" and type(spanish) == "string", "Not a string: " .. tostring(english))
	check(spanish ~= "", "No Spanish for " .. english)
	local wild = string.find(english, "{[%*=]}") ~= nil
	-- Numbers: the key is exactly what the game would make of a text with
	-- numbers in those places, and the Spanish uses no number the key lacks.
	local slots = 0
	for n in english:gmatch("{(%d+)}") do
		slots = math.max(slots, tonumber(n))
	end
	check(not (wild and slots > 0), "A {*} entry with numbers: " .. english)
	if slots > 0 then
		local sample = english:gsub("{(%d+)}", function(n)
			return tostring(10 + tonumber(n))
		end)
		local key = Lang.normalize(sample)
		check(key == english, "The game reads " .. sample .. " as " .. key .. ", not " .. english)
	else
		-- (A number left in a key would never match: the game reads it as {1}.)
		local key, found = Lang.normalize(english)
		check(#found == 0, "A number in an entry with no {1}: " .. english .. " (use " .. key .. ")")
	end
	for n in spanish:gmatch("{(%d+)}") do
		check(tonumber(n) <= slots, "The Spanish uses {" .. n .. "} that " .. english .. " doesn't have")
	end
	if wild then
		local _, matches = english:gsub("{[%*=]}", "")
		local used = 0
		for _ in spanish:gmatch("{[%*=]%d*}") do
			used += 1
		end
		check(used <= matches, "The Spanish has more {*} than " .. english)
	end
	-- Rich text: the same tags.
	local function tags(s)
		local t = {}
		for tag in s:gmatch("<[^>]*>") do
			table.insert(t, (tag:gsub("{([%*=])%d*}", "{%1}")))
		end
		table.sort(t)
		return table.concat(t)
	end
	check(tags(english) == tags(spanish), "Tags differ: " .. english)
end
check(count > 400, "The Spanish table is short: " .. count)
print("PASS: " .. (checks - tableChecks) .. " checks on " .. count .. " Spanish entries (numbers, wildcards, tags)")
