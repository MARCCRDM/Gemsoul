"""Every combat sound file has its id slot in CombatSound (so upload_audio.py fills it in), every slot has its file, and the takes of a sound are numbered without gaps (CombatSound stops looking at the first missing number)."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / "assets" / "sounds" / "combat"
source = (ROOT / "src" / "client" / "Modules" / "CombatSound.luau").read_text(encoding="utf-8")
ids = source[source.index("CombatSound.Ids = {"): source.index("\n}\n", source.index("CombatSound.Ids = {"))]
slots = re.findall(r"^\t(\w+) = (\d+), -- ([\w.]+\.mp3)$", ids, flags=re.M)

files = sorted(p.name for p in folder.glob("*.mp3") if not p.name.startswith("_"))
named = [file for _, _, file in slots]
missing = [f for f in files if f not in named]
assert not missing, f"combat sounds with no id slot in CombatSound.Ids: {missing}"
orphans = [f for f in named if f not in files]
assert not orphans, f"id slots with no file in assets/sounds/combat: {orphans}"
twice = sorted({f for f in named if named.count(f) > 1})
assert not twice, f"files with two id slots: {twice}"

takes = {}
for name, _, _ in slots:
    m = re.fullmatch(r"(\w*?[A-Za-z])(\d)", name)
    if m:
        takes.setdefault(m.group(1), []).append(int(m.group(2)))
for sound, numbers in takes.items():
    assert sorted(numbers) == list(range(1, len(numbers) + 1)), f"{sound}'s takes skip a number: {sorted(numbers)}"

# The new combat sounds are played under these names.
for sound in ("Contact", "HeavyContact", "Deflect", "Stomp"):
    assert sound in takes, f"{sound} has no takes"
assert re.search(r"^\tCharge = \d+, -- charge\.mp3$", ids, flags=re.M), "the kaiju charge has no slot"

print(f"PASS: {len(slots)} combat sound id slots match {len(files)} files; takes numbered 1..n")
