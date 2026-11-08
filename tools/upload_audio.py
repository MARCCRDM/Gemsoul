"""
Uploads the game's audio to Roblox and writes each id into the scripts, so
the real sounds and music play instead of the built-in stand-ins.

    python tools/upload_audio.py --key YOUR_API_KEY --user YOUR_USER_ID

What you need (once):
  1. An Open Cloud API key: create.roblox.com > Creator Hub > Open Cloud >
     API Keys > Create API Key. Add the "Assets" API with Read and Write,
     allow your IP (or 0.0.0.0/0), save, and copy the key.
  2. Your user id: the number in your profile's URL
     (roblox.com/users/123456789/profile).

It uploads, in this order (most important first):
  assets/music/*.mp3          -> src/client/Modules/Music.luau
  assets/sounds/combat/*.mp3  -> src/client/Modules/CombatSound.luau
  assets/sounds/lottery/*     -> src/client/Modules/LotterySound.luau
  assets/sounds/narration/*   -> src/client/Modules/Narration.luau
  assets/sounds/*.mp3         -> src/client/Modules/UiSound.luau
  assets/images/menu/*.png    -> src/shared/MainMenuContent.luau (the main menu's banners)
then replaces the matching "Name = 0, -- file.mp3" (or .ogg, .png) lines with the new ids.
Pictures go up as Decals; if a banner shows blank in game, upload that .png in
Studio's Asset Manager instead and paste its image id into the line by hand.

Roblox limits how many audio files an account can upload a month (fewer
for accounts that aren't ID-verified). Ids already uploaded are remembered
in tools/audio_ids.json and skipped next time, so if you hit the limit just
run it again later; --limit N uploads at most N files this run, --dry-run
shows what it would do, --force re-uploads everything, --only PREFIX uploads
just the files whose path starts with PREFIX (e.g. the new narration:
--only assets/sounds/narration/basics_).

No API key? Import the files in Studio (View > Asset Manager > Import) and
run tools/apply_sound_ids.py on the ids instead: it writes the same lines.
"""
import argparse
import json
import mimetypes
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
IDS_FILE = os.path.join(ROOT, "tools", "audio_ids.json")
GROUPS = [
    ("assets/music", "src/client/Modules/Music.luau"),
    ("assets/sounds/combat", "src/client/Modules/CombatSound.luau"),
    ("assets/sounds/lottery", "src/client/Modules/LotterySound.luau"),
    ("assets/sounds/narration", "src/client/Modules/Narration.luau"),
    ("assets/sounds", "src/client/Modules/UiSound.luau"),
    ("assets/images/menu", "src/shared/MainMenuContent.luau"),
]
EXTENSIONS = (".mp3", ".ogg", ".png")
API = "https://apis.roblox.com/assets/v1"


def multipart(fields, file_field, file_name, file_bytes, content_type):
    boundary = uuid.uuid4().hex
    lines = []
    for name, value in fields.items():
        lines += [f"--{boundary}", f'Content-Disposition: form-data; name="{name}"', "", value]
    head = "\r\n".join(lines + [
        f"--{boundary}",
        f'Content-Disposition: form-data; name="{file_field}"; filename="{file_name}"',
        f"Content-Type: {content_type}",
        "",
        "",
    ]).encode()
    tail = f"\r\n--{boundary}--\r\n".encode()
    return head + file_bytes + tail, f"multipart/form-data; boundary={boundary}"


def call(url, key, data=None, content_type=None):
    request = urllib.request.Request(url, data=data, method="POST" if data else "GET")
    request.add_header("x-api-key", key)
    if content_type:
        request.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode() or "{}")
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"{error.code} {error.reason}: {error.read().decode(errors='replace')[:400]}")


def upload(path, key, user):
    name = os.path.splitext(os.path.basename(path))[0].replace("_", " ").title()
    picture = path.endswith(".png")
    payload = {
        "assetType": "Decal" if picture else "Audio",
        "displayName": (f"Saga Miners {name}" if picture else f"Brainrot Crusaders {name}")[:50],
        "description": "Main menu picture for Saga Miners." if picture else "Game audio for Brainrot Crusaders.",
        "creationContext": {"creator": {"userId": str(user)}},
    }
    with open(path, "rb") as f:
        body, ctype = multipart(
            {"request": json.dumps(payload)},
            "fileContent",
            os.path.basename(path),
            f.read(),
            mimetypes.guess_type(path)[0] or ("image/png" if picture else "audio/mpeg"),
        )
    operation = call(f"{API}/assets", key, body, ctype)
    path_ = operation.get("path") or ("operations/" + operation.get("operationId", ""))
    for _ in range(60):
        if operation.get("done"):
            break
        time.sleep(2)
        operation = call(f"{API}/{path_}", key)
    if not operation.get("done"):
        raise RuntimeError("Roblox is still processing it; run again in a minute.")
    if "error" in operation:
        raise RuntimeError(json.dumps(operation["error"]))
    asset_id = (operation.get("response") or {}).get("assetId")
    if not asset_id:
        raise RuntimeError("No asset id in the reply: " + json.dumps(operation)[:300])
    return int(asset_id)


def write_ids(lua_path, ids_by_file):
    path = os.path.join(ROOT, lua_path)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    changed = 0
    for file_name, asset_id in ids_by_file.items():
        pattern = re.compile(r"(\b\w+ = )\d+(, -- " + re.escape(file_name) + r")")
        text, count = pattern.subn(lambda m: f"{m.group(1)}{asset_id}{m.group(2)}", text)
        changed += count
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--key", required=True, help="Open Cloud API key with Assets read + write")
    parser.add_argument("--user", required=True, help="your Roblox user id")
    parser.add_argument("--limit", type=int, default=999, help="upload at most this many files this run")
    parser.add_argument("--force", action="store_true", help="upload again even if already uploaded")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--only", action="append", default=[], help="upload only files whose path starts with this (repeatable), e.g. assets/sounds/narration/basics_")
    args = parser.parse_args()

    known = {}
    if os.path.exists(IDS_FILE):
        with open(IDS_FILE) as f:
            known = json.load(f)
    uploaded = 0
    for folder, lua in GROUPS:
        directory = os.path.join(ROOT, folder)
        if not os.path.isdir(directory):
            continue
        ids = {}
        for name in sorted(os.listdir(directory)):
            if not name.endswith(EXTENSIONS) or name.startswith("_"):
                continue
            rel = f"{folder}/{name}"
            if args.only and not any(rel.startswith(prefix) for prefix in args.only):
                if rel in known:
                    ids[name] = known[rel]
                continue
            if rel in known and not args.force:
                ids[name] = known[rel]
                continue
            if uploaded >= args.limit:
                print(f"  skipped {rel} (--limit reached)")
                continue
            if args.dry_run:
                print(f"  would upload {rel}")
                continue
            try:
                asset_id = upload(os.path.join(directory, name), args.key, args.user)
            except RuntimeError as problem:
                print(f"  FAILED {rel}: {problem}")
                if "429" in str(problem) or "limit" in str(problem).lower():
                    print("  Looks like the upload limit: run again later; finished files are remembered.")
                    break
                continue
            known[rel] = asset_id
            ids[name] = asset_id
            uploaded += 1
            print(f"  uploaded {rel} -> {asset_id}")
            with open(IDS_FILE, "w") as f:
                json.dump(known, f, indent=2, sort_keys=True)
        if ids and not args.dry_run:
            print(f"{lua}: {write_ids(lua, ids)} ids written")
    print("Done. Sync with Rojo (or commit and pull) and press Play to hear them.")


if __name__ == "__main__":
    sys.exit(main())
