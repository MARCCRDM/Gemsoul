"""Execute onboarding server/rules checks using the bundled Luau runtime."""
from pathlib import Path
import re, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[1]
modules = ["src/shared/Tutorial.luau", "src/shared/StarterLottery.luau", "src/shared/EquipmentSlots.luau", "src/server/Systems/Intro.luau"]
source = "local modules = {}\n"
for path in modules:
    source += 'modules["' + path + '"] = function()\n' + (ROOT/path).read_text(encoding="utf-8") + '\nend\n'
case = (ROOT/"tests/tutorial_cases.luau").read_text(encoding="utf-8")
case = re.sub(r'local (fs|luau|process) = require\([^\n]+\)\n', '', case)
case = re.sub(r'local ROOT = [^\n]+', 'local ROOT = "."', case)
start = case.index('local function load(')
end = case.index('-- Roblox stand-ins.', start)
case = case[:start] + "local function load(path, env)\n local base = setmetatable(env or {}, {__index=getfenv()})\n return setfenv(modules[path], base)()\nend\n" + case[end:]
with tempfile.TemporaryDirectory(prefix="gemsoul-tutorial-") as d:
    path = Path(d)/"tutorial.luau"
    path.write_text(source+case, encoding="utf-8")
    subprocess.run([str(ROOT/".tools/luau/luau.exe"), str(path)], check=True)
