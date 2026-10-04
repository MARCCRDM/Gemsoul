"""Exercise the shared enemy aggro rules."""
from pathlib import Path
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")
source = "local Aggro=(function()\n" + read("src/shared/Aggro.luau") + "\nend)()\n" + read("tests/aggro_cases.luau")
with tempfile.TemporaryDirectory(prefix="gemsoul-aggro-") as directory:
    script = Path(directory) / "aggro.luau"
    script.write_text(source, encoding="utf-8")
    subprocess.run([str(ROOT / ".tools/luau/luau.exe"), str(script)], check=True)
