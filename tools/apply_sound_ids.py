"""
Writes uploaded sound ids into the scripts from a list of "file=id" lines,
and remembers them in tools/audio_ids.json as upload_audio.py does, for
sounds uploaded without an Open Cloud key (Studio's Asset Manager, or the
Creator Hub) instead of by tools/upload_audio.py.

    python tools/apply_sound_ids.py ids.txt
    python tools/apply_sound_ids.py --paste        (paste the lines, then Ctrl+Z Enter / Ctrl+D)
    python tools/apply_sound_ids.py ids.txt --dry-run

Where the lines come from:
  1. Studio > View > Asset Manager > Import: pick the sound files (the
     folder tools/upload_audio.py reads them from, or the zip of the ones
     still to upload). Wait for them to be reviewed (minutes, usually).
  2. Asset Manager > Audio: select them all, right-click > Insert. Each
     becomes a Sound in the Workspace, named after its file.
  3. View > Command Bar: paste tools/studio_print_sound_ids.lua, Enter. The
     Output window prints one "name=id" line per sound: copy them into a
     text file and run this on it.
Any of these line shapes is read:  swing_1.mp3=1234567890
  swing_1=1234567890   swing_1.mp3: rbxassetid://1234567890   [swing_1] 1234567890
  swing_1_nCWuLo=1234567890   (the random tag Studio's import adds is taken off)
The name is matched against the sound folders upload_audio.py knows
(assets/music, assets/sounds, assets/sounds/combat, assets/sounds/lottery,
assets/sounds/narration) and its "Name = 0, -- file.mp3" line in the matching
script gets the id. Names that match no file are listed at the end.
"""
import argparse
import json
import os
import re
import sys

sys.dont_write_bytecode = True  # (no __pycache__ in tools/)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from upload_audio import EXTENSIONS, GROUPS, IDS_FILE, ROOT, write_ids  # noqa: E402

AUDIO = tuple(e for e in EXTENSIONS if e != ".png")
LINE = re.compile(
    r"^\s*\[?\s*([A-Za-z0-9_\-]+?)(\.(?:mp3|ogg|wav))?\s*[\]=:,\s]+\s*(?:rbxassetid://|https?://www\.roblox\.com/asset/\?id=)?(\d{6,})\b"
)


def sound_files():
    """Every sound file the scripts expect: { "swing_1.mp3": (folder, lua) }."""
    found = {}
    for folder, lua in GROUPS:
        directory = os.path.join(ROOT, folder)
        if not os.path.isdir(directory):
            continue
        for name in sorted(os.listdir(directory)):
            if name.endswith(AUDIO) and not name.startswith("_"):
                found[name] = (folder, lua)
    return found


def parse(lines):
    """{ name as written: id } from lines in any of the shapes above."""
    ids = {}
    for line in lines:
        match = LINE.match(line)
        if match:
            ids[match.group(1) + (match.group(2) or "")] = int(match.group(3))
    return ids


def resolve(ids, files):
    """Pairs each written name with its file; unknown names apart."""
    by_stem = {}
    for name in files:
        by_stem.setdefault(os.path.splitext(name)[0], []).append(name)
    matched, unknown = {}, []
    suffix = re.compile(r"_(?=[A-Za-z0-9]{4,8}$)(?=.*[A-Za-z])[A-Za-z0-9]+$")

    def lookup(name):
        if name in files:
            return name
        if name in by_stem and len(by_stem[name]) == 1:
            return by_stem[name][0]
        return None

    for written, asset_id in ids.items():
        name = written
        found = lookup(name)
        # Studio's bulk import tags each name with a random suffix
        # (swing_3_nCWuLo): taken off, one piece at a time, till it's a file.
        while not found and suffix.search(name):
            name = suffix.sub("", name)
            found = lookup(name)
        if found:
            matched[found] = asset_id
        else:
            unknown.append(written)
    return matched, unknown


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file", nargs="?", help="text file of name=id lines")
    parser.add_argument("--paste", action="store_true", help="read the lines from the terminal instead")
    parser.add_argument("--dry-run", action="store_true", help="show what would change, change nothing")
    args = parser.parse_args()
    if args.paste or not args.file:
        print("Paste the name=id lines, then Ctrl+Z Enter (Windows) or Ctrl+D:")
        lines = sys.stdin.read().splitlines()
    else:
        with open(args.file, encoding="utf-8") as f:
            lines = f.read().splitlines()
    ids = parse(lines)
    if not ids:
        print("No name=id lines found.")
        return 1
    files = sound_files()
    matched, unknown = resolve(ids, files)
    known = {}
    if os.path.exists(IDS_FILE):
        with open(IDS_FILE) as f:
            known = json.load(f)
    per_script = {}
    for name, asset_id in matched.items():
        folder, lua = files[name]
        per_script.setdefault(lua, {})[name] = asset_id
        known[f"{folder}/{name}"] = asset_id
    for lua, group in sorted(per_script.items()):
        if args.dry_run:
            for name, asset_id in sorted(group.items()):
                print(f"  would set {name} -> {asset_id} in {lua}")
        else:
            print(f"{lua}: {write_ids(lua, group)} ids written")
    if not args.dry_run and matched:
        with open(IDS_FILE, "w") as f:
            json.dump(known, f, indent=2, sort_keys=True)
    print(f"{len(matched)} of {len(ids)} names matched a sound file.")
    for name in unknown:
        print(f"  no such sound file: {name}")
    if matched and not args.dry_run:
        print("Done. Sync with Rojo (or commit and pull) and press Play to hear them.")
    return 0 if matched else 1


if __name__ == "__main__":
    sys.exit(main())
