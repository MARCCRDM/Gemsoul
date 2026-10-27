"""Creates the store's Developer Products on Roblox and writes their ids into
src/shared/Store.luau (Store.RobuxProducts).

  lune run tools/dev_products_manifest.luau . > manifest.json
  ROBLOX_API_KEY=... python3 tools/create_dev_products.py <universeId> manifest.json

Needs an Open Cloud key with developer-product read and write. Products that
already exist (same name) are reused, not created twice; ids already set in
Store.luau are left alone. Safe to run again.
"""
import json, re, sys, time, urllib.request, urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "src/shared/Store.luau"
API = "https://apis.roblox.com/developer-products/v2/universes/{u}/developer-products"


def call(method, url, key, body=None):
    data = None
    headers = {"x-api-key": key}
    if body is not None:  # (multipart form fields: what the create call takes)
        boundary = "----sagaminers"
        parts = [f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n' for k, v in body.items()]
        data = ("".join(parts) + f"--{boundary}--\r\n").encode()
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 4:
                time.sleep(2 + attempt * 2)
                continue
            raise SystemExit(f"{method} {url} -> {e.code}: {e.read().decode()[:400]}")


def existing(universe, key):
    found, token = {}, None
    while True:
        url = API.format(u=universe) + "/creator?pageSize=100" + (f"&pageToken={token}" if token else "")
        page = call("GET", url, key)
        for p in page.get("developerProducts", []):
            found[p.get("name")] = p.get("productId") or p.get("id")
        token = page.get("nextPageToken")
        if not token:
            return found


def main():
    import os
    key = os.environ.get("ROBLOX_API_KEY") or sys.exit("set ROBLOX_API_KEY")
    universe, manifest = sys.argv[1], json.loads(Path(sys.argv[2]).read_text())
    names = [m["Name"] for m in manifest]
    src = STORE.read_text()
    have = existing(universe, key)
    ids = {}
    for m in manifest:
        name = m["Name"] if names.count(m["Name"]) == 1 else f'{m["Name"]} ({m["Key"]})'
        products = re.search(r"Store\.RobuxProducts = \{.*?\n\}", src, re.S).group(0)
        current = re.search(rf"\n\t{m['Key']} = (\d+),", products)
        if current and current.group(1) != "0":
            ids[m["Key"]] = int(current.group(1))
            continue
        if name in have:
            ids[m["Key"]] = int(have[name])
        else:
            made = call("POST", API.format(u=universe), key, {
                "name": name,
                "description": f"Saga Miners: {m['Name']}",
                "price": m["Price"],
                "isForSale": "true",
            })
            ids[m["Key"]] = int(made.get("productId") or made.get("id"))
            time.sleep(0.4)  # (writes are rate limited)
        print(f'{m["Key"]:40} {ids[m["Key"]]:>14}  R$ {m["Price"]}')
    # (only inside Store.RobuxProducts: the price tables use the same keys)
    block = re.search(r"Store\.RobuxProducts = \{.*?\n\}", src, re.S)
    body = block.group(0)
    for k, v in ids.items():
        body = re.sub(rf"(\n\t{k} = )\d+,", rf"\g<1>{v},", body)
    STORE.write_text(src[: block.start()] + body + src[block.end():])
    print(f"{len(ids)} product ids in Store.RobuxProducts")


main()
