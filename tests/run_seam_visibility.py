"""Skin seams (SelectionBoxes) show only while their part does: never round the camera."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
setup = r'''
local Enum = { RenderPriority = { Camera = { Value = 200 } } }
local tagged, added, removed, bound, respawned = {}, nil, nil, nil, nil
local services = {
	CollectionService = {
		GetTagged = function(_, tag) return tagged[tag] or {} end,
		GetInstanceAddedSignal = function() return { Connect = function(_, fn) added = fn end } end,
		GetInstanceRemovedSignal = function() return { Connect = function(_, fn) removed = fn end } end,
	},
	RunService = {
		BindToRenderStep = function(_, name, priority, fn)
			assert(name == "SkinSeams" and priority == 204, "binds just after the first-person view (Camera + 3)")
			bound = fn
		end,
	},
	ReplicatedStorage = { Shared = { Tags = "Tags" } },
	Players = {
		LocalPlayer = {
			Character = nil,
			CharacterAdded = { Connect = function(_, fn) respawned = fn end },
		},
	},
}
local workspace = { CurrentCamera = nil }
local game = { GetService = function(_, name) return services[name] end }
-- Just enough Color3 for the animated seams.
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
	Lerp = function(a, b, k) return color(a.R + (b.R - a.R) * k, a.G + (b.G - a.G) * k, a.B + (b.B - a.B) * k) end,
	ToHSV = function(c)
		local hi, lo = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
		return 0, if hi == 0 then 0 else (hi - lo) / hi, hi
	end,
}
local typeof = function(value)
	return if getmetatable(value) == Color3 then "Color3" else type(value)
end
local os = { clock = function() return CLOCK end }
CLOCK = 0
local Tags = (function()
''' + (ROOT / "src/shared/Tags.luau").read_text(encoding="utf-8") + r'''
end)()
local require = function(name) if name == "Tags" then return Tags end return require(name) end
'''
source = (
    setup
    + "\nlocal SeamVisibility=(function()\n"
    + (ROOT / "src/client/Modules/SeamVisibility.luau").read_text(encoding="utf-8")
    + "\nend)()\n"
    + (ROOT / "tests/seam_visibility_cases.luau").read_text(encoding="utf-8")
)
with tempfile.TemporaryDirectory(prefix="gemsoul-seams-") as directory:
    script = Path(directory) / "seams.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
