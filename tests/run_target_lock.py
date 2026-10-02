"""Exercise production selection rules and camera controller with deterministic services."""
from pathlib import Path
import re
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")
rules = "local Rules=(function()\n" + read("src/shared/TargetLockRules.luau") + "\nend)()\n"
source = read("tests/roblox_primitives.luau") + rules + read("tests/target_lock_cases.luau")
source += "\ndo\n" + read("tests/target_lock_runtime.luau")
controller = re.sub(r"^local \w+ = require\([^\n]+\)\n", "", read("src/client/Modules/TargetLock.luau"), flags=re.M)
source += "\nlocal Lock=(function()\n" + controller + "\nend)()\n" + read("tests/target_lock_live_cases.luau") + "\nend\n"
with tempfile.TemporaryDirectory(prefix="gemsoul-target-lock-") as directory:
    script = Path(directory) / "target-lock.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
