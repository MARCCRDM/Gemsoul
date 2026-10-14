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
for resume in (False, True):
    setup = '\nlocal resuming = false\n'
    if resume:
        setup = '''\nlocal resuming = true
profile.Intro.Lottery = Lottery.prepareChoice(profile, "Juggernaut", "Frost", function(element)
 return {Id="saved-"..element, Element=element, Tier="Common"}
end)
'''
    run=source+setup+"\ndo\n"+intro+"\nend\n"+read("tests/element_picker_cases.luau")
    with tempfile.TemporaryDirectory(prefix="gemsoul-lottery-ui-") as directory:
        script=Path(directory)/"intro.luau"
        script.write_text(run,encoding="utf-8")
        subprocess.run([str(ROOT/".tools/luau/luau.exe"),str(script)],check=True)
