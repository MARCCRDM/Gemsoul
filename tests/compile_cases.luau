-- Every script in the game compiles. Roblox's Luau refuses a script outright
-- (it never runs, not one line of it) for what only shows when it's compiled:
-- above all more than 200 locals alive at once in one function, the top of a
-- long client script reaching it a line at a time. Nothing else here would
-- notice: a test loads only the modules it's about.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local ROOT = process.args[1] or "."

local scripts, bad = 0, {}
local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.sub(name, -5) == ".luau" then
			scripts += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				table.insert(bad, string.sub(path, #ROOT + 2) .. ": " .. tostring(err))
			end
		end
	end
end
walk(ROOT .. "/src")
table.sort(bad)
assert(#bad == 0, "Scripts Roblox would refuse:\n" .. table.concat(bad, "\n"))
assert(scripts > 100, "Found only " .. scripts .. " scripts under src")
print(string.format("PASS: all %d scripts compile (none past 200 locals, nothing Roblox would refuse)", scripts))
