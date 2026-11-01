"""Pull the game's own event log (Server.Telemetry) out of its DataStore with
Open Cloud, into tools/telemetry/data/ (one JSON file per saved key; a key
already pulled whole is skipped next time, the current hour's is re-pulled).

  ROBLOX_OPEN_CLOUD_KEY=...  ROBLOX_UNIVERSE_ID=...  python3 tools/telemetry/pull.py [days=14]

The API key needs the DataStore permissions "List entry keys" and "Read
entry" on the experience (docs/telemetry.md). It's read from the environment
only: never put it in a file in the repo.
"""
import json, os, sys, time, urllib.parse, urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

STORE = os.environ.get('TELEMETRY_STORE', 'SagaTelemetry_v1')
DATA = Path(__file__).resolve().parent / 'data'
API = 'https://apis.roblox.com/datastores/v1/universes/{u}/standard-datastores'


def get(url, key, tries=5):
    for attempt in range(tries):
        req = urllib.request.Request(url, headers={'x-api-key': key})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503) and attempt < tries - 1:
                time.sleep(2 ** attempt)
                continue
            raise SystemExit(f'Open Cloud said {e.code} for {url.split("?")[0]}: {e.read()[:300]!r}')
    raise SystemExit('Open Cloud kept failing')


def main():
    key = os.environ.get('ROBLOX_OPEN_CLOUD_KEY')
    universe = os.environ.get('ROBLOX_UNIVERSE_ID')
    if not key or not universe:
        raise SystemExit('Set ROBLOX_OPEN_CLOUD_KEY and ROBLOX_UNIVERSE_ID first (docs/telemetry.md).')
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 14
    base = API.format(u=universe)
    DATA.mkdir(parents=True, exist_ok=True)
    now = datetime.now(timezone.utc)
    current_hour = now.strftime('ev/%Y-%m-%d/%H/')
    pulled = skipped = 0
    for d in range(days, -1, -1):
        day = (now - timedelta(days=d)).strftime('ev/%Y-%m-%d/')
        cursor = ''
        while True:
            q = {'datastoreName': STORE, 'prefix': day, 'limit': 100}
            if cursor:
                q['cursor'] = cursor
            page = json.loads(get(f'{base}/datastore/entries?{urllib.parse.urlencode(q)}', key))
            for item in page.get('keys', []):
                k = item['key']
                out = DATA / (k.replace('/', '_') + '.json')
                if out.exists() and not k.startswith(current_hour):
                    skipped += 1
                    continue
                q2 = urllib.parse.urlencode({'datastoreName': STORE, 'entryKey': k})
                out.write_bytes(get(f'{base}/datastore/entries/entry?{q2}', key))
                pulled += 1
                time.sleep(0.25)  # (well inside Open Cloud's rate limits)
            cursor = page.get('nextPageCursor') or ''
            if not cursor:
                break
    print(f'pulled {pulled} keys, {skipped} already here, into {DATA}')


if __name__ == '__main__':
    main()
