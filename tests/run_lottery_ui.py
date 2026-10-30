"""Run the real intro controller with deterministic GUI, art and service doubles."""
from pathlib import Path
import re
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding="utf-8")
source=read("tests/roblox_primitives.luau")
source+="\nlocal GemTraits=(function()\n"+read("src/shared/GemTraits.luau")+"\nend)()\n"
source+="\nlocal GemRoller=(function()\n"+re.sub(r"^local \w+ = require\([^\n]+\)\n","",read("src/shared/GemRoller.luau"),flags=re.M)+"\nend)()\n"
source+="\nlocal ElementMatchup=(function()\n"+re.sub(r"^local \w+ = require\([^\n]+\)\n","",read("src/shared/ElementMatchup.luau"),flags=re.M)+"\nend)()\n"
source+="\nlocal Lottery=(function()\n"+re.sub(r"^local \w+ = require\([^\n]+\)\n","",read("src/shared/StarterLottery.luau"),flags=re.M)+"\nend)()\n"
source+="\nlocal Tech=(function()\n"+re.sub(r"^local \w+ = require\([^\n]+\)\n","",read("src/shared/CombatTechnology.luau"),flags=re.M)+"\nend)()\n"
source+=read("tests/lottery_ui_services.luau")
source+="\nlocal FastStart=(function()\n"+read("src/shared/FastStart.luau")+"\nend)()\n"
intro=re.sub(r"^local \w+ = require\([^\n]+\)\n","",read("src/client/Intro.client.luau"),flags=re.M)
# The old picker (FastStart.Pick on), then the fast start as it is (Pick
# off: rolled for them): Cryo, Thermal after a failed roll, a saved kit.
for pick, resume, element, fail in ((True, False, None, False), (True, True, None, False), (False, False, "Frost", False), (False, False, "Fire", True), (False, True, None, False)):
    setup = f'\nFastStart.Pick = {"true" if pick else "false"}\n'
    if element:
        setup += f'autoElement = "{element}"\n'
    if fail:
        setup += 'failPrepare = true\n'
    setup += '\nlocal resuming = false\n'
    if resume:
        setup += '''\nresuming = true
profile.Intro.Lottery = Lottery.prepareChoice(profile, "Juggernaut", "Frost", function(element)
 return {Id="saved-"..element, Element=element, Tier="Common"}
end)
'''
    # (The intro runs in its own function: its locals get their own 200 slots.)
    cases = "tests/element_picker_cases.luau" if pick else "tests/auto_intro_cases.luau"
    run=source+setup+"\n;(function()\n"+intro+"\nend)()\n"+read(cases)
    with tempfile.TemporaryDirectory(prefix="gemsoul-lottery-ui-") as directory:
        script=Path(directory)/"intro.luau"
        script.write_text(run,encoding="utf-8")
        subprocess.run([str(ROOT/".tools/luau/luau.exe"),str(script)],check=True)
