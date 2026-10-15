"""Copies of gear move as the gear does: LiveLooks, Prismatic shimmer and stone lights on copies and previews."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
setup = r'''
local tagged, addedTo, removedFrom, frames = {}, {}, {}, {}
local services = {
	CollectionService = {
		GetTagged = function(_, tag) return tagged[tag] or {} end,
		GetInstanceAddedSignal = function(_, tag)
			return { Connect = function(_, fn) addedTo[tag] = fn end }
		end,
		GetInstanceRemovedSignal = function(_, tag)
			return { Connect = function(_, fn) removedFrom[tag] = fn end }
		end,
	},
	RunService = {
		RenderStepped = { Connect = function(_, fn) table.insert(frames, fn) end },
	},
	ReplicatedStorage = { Shared = { Tags = "Tags" } },
}
local game = { GetService = function(_, name) return services[name] end }
local workspace = { CurrentCamera = nil }
-- Just enough Color3 and Vector3.
local Color3
local function color(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, Color3)
end
Color3 = {
	new = color,
	fromRGB = function(r, g, b) return color(r / 255, g / 255, b / 255) end,
	fromHSV = function(h, s, v)
		local i = math.floor(h * 6)
		local f = h * 6 - i
		local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
		local rgb = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i % 6 + 1]
		return color(rgb[1], rgb[2], rgb[3])
	end,
}
Color3.__index = {
	ToHSV = function(c)
		local hi, lo = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
		return 0, if hi == 0 then 0 else (hi - lo) / hi, hi
	end,
}
local Vector = {}
Vector.__sub = function(a, b)
	return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, Vector)
end
Vector.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	end
	return nil
end
local function at(x)
	return setmetatable({ X = x, Y = 0, Z = 0 }, Vector)
end
local typeof = function(value)
	return if getmetatable(value) == Color3 then "Color3" else type(value)
end
local os = { clock = function() return CLOCK end }
CLOCK = 0
local Tags = (function()
''' + (ROOT / "src/shared/Tags.luau").read_text(encoding="utf-8") + r'''
end)()
local script = { Parent = { LiveLooks = "LiveLooks" } }
local LiveLooks = (function()
''' + (ROOT / "src/client/Modules/LiveLooks.luau").read_text(encoding="utf-8") + r'''
end)()
local require = function(name)
	if name == "Tags" then return Tags end
	if name == "LiveLooks" then return LiveLooks end
	return require(name)
end
'''
source = (
    setup
    + "\nlocal PrismaticShimmer=(function()\n"
    + (ROOT / "src/client/Modules/PrismaticShimmer.luau").read_text(encoding="utf-8")
    + "\nend)()\n"
    + "\nlocal GemLights=(function()\n"
    + (ROOT / "src/client/Modules/GemLights.luau").read_text(encoding="utf-8")
    + "\nend)()\n"
    + (ROOT / "tests/live_looks_cases.luau").read_text(encoding="utf-8")
)
with tempfile.TemporaryDirectory(prefix="gemsoul-live-looks-") as directory:
    script = Path(directory) / "live_looks.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
