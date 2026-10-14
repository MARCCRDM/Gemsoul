"""Skin seams (SelectionBoxes) show only while their part does: never round the camera."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
setup = r'''
local Enum = { RenderPriority = { Camera = { Value = 200 } } }
local tagged, added, bound = {}, nil, nil
local services = {
	CollectionService = {
		GetTagged = function(_, tag) return tagged[tag] or {} end,
		GetInstanceAddedSignal = function() return { Connect = function(_, fn) added = fn end } end,
		GetInstanceRemovedSignal = function() return { Connect = function() end } end,
	},
	RunService = {
		BindToRenderStep = function(_, name, priority, fn)
			assert(name == "SkinSeams" and priority == 204, "binds just after the first-person view (Camera + 3)")
			bound = fn
		end,
	},
	ReplicatedStorage = { Shared = { Tags = "Tags" } },
}
local game = { GetService = function(_, name) return services[name] end }
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
