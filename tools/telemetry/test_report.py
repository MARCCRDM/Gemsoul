"""Checks report.py's numbers on a made-up event log it knows the answers to,
and writes a DEMO dashboard from it (python3 tools/telemetry/test_report.py [out.html]).
"""
import json, random, sys, tempfile
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import report  # noqa: E402

DAY = 86400
START = int(datetime(2026, 11, 1, tzinfo=timezone.utc).timestamp())
STEPS = ['Joined', 'Kit', 'First fight', 'Round 1 won', 'Hunt bounty', 'Dungeon entered', 'Dungeon boss', 'Dungeon cleared', 'Lobby', 'First rock', 'First gem', 'Socketed', 'Second duel']


def write(dir_, server, hour_t, rows):
    key = 'ev/' + datetime.fromtimestamp(hour_t, timezone.utc).strftime('%Y-%m-%d/%H') + '/' + server
    (Path(dir_) / (key.replace('/', '_') + '.json')).write_text(json.dumps({'V': 1, 'Server': server, 'Place': 700, 'Rows': rows}))


def exact(dir_):
    """A tiny log with known answers."""
    rows = []
    # Day 0: two new players (1, 2); 1 comes back on day 1, 2 on day 7.
    for u in (1, 2):
        rows += [[START + 60, u, 'session_start', 0, 'new', 'US', None], [START + 660, u, 'session_end', 600, 3, 100, 80]]
        rows += [[START + 70, u, 'onboarding', 1, 'Joined', None, None]]
    rows += [[START + 80, 1, 'onboarding', 2, 'Kit', None, None]]
    rows += [[START + 81, 2, 'onboarding', 2, 'Style', None, None]]  # (the old list's step 2: not counted)
    rows += [[START + 90, 1, 'Purchase', 99, 'Coins10k', 'Robux', None], [START + 95, 2, 'Purchase', 1, 'Old', None, None]]
    rows += [[START + 100, 1, 'coins', 250, 'Duel', 'Gameplay', None], [START + 101, 1, 'coins', -50, 'Store', 'Shop', None]]
    rows += [[START + 102, 1, 'IntroRound', 1, 'Weapon', 'Rare', 'Won'], [START + 103, 2, 'IntroRound', 1, 'Weapon', 'Lost', 'Lost']]
    rows += [[START + 300, 0, 'server', 2, 700, None, None]]
    write(dir_, 'aaaa', START, rows)
    write(dir_, 'bbbb', START, [[START + 300, 0, 'server', 3, 700, None, None]])
    write(dir_, 'aaaa', START + DAY, [[START + DAY + 60, 1, 'session_start', 1, 'returning', 'US', None]])
    write(dir_, 'aaaa', START + 7 * DAY, [[START + 7 * DAY + 60, 2, 'session_start', 7, 'returning', 'US', None]])


def check():
    with tempfile.TemporaryDirectory() as d:
        exact(d)
        r = report.build(report.load(d))
    first = r['retention'][0]
    assert first['cohort'] == 2 and first['d1'] == 50.0 and first['d7'] == 50.0 and first['d3'] == 0.0, first
    assert [f['users'] for f in r['funnel']] == [2, 1] and r['funnel'][1]['drop'] == 50.0, r['funnel']
    day0 = r['days'][0]
    assert day0['revenue'] == 99 and day0['payers'] == 2 and day0['new'] == 2 and day0['avg_session_min'] == 10.0, day0
    assert day0['peak_ccu'] == 5, day0['peak_ccu']  # (two servers, one 5-minute bucket)
    assert r['economy']['sources'] == [['Duel', 250]] and r['economy']['sinks'] == [['Store', 50]], r['economy']
    assert r['intro_rounds'] == [{'round': 1, 'slot': 'Weapon', 'won': 1, 'lost': 1, 'rare': 1}], r['intro_rounds']
    assert r['products'][0] == ['Coins10k', 99, 1], r['products']
    assert r['range']['users'] == 2 and r['kpis']['d1'] == 50.0
    # Dev and test accounts: dropped, a marked one's earlier rows too; the latest mark wins.
    rows = [
        {'t': 1, 'u': 1, 'e': 'session_start', 'v': 0}, {'t': 1, 'u': 9, 'e': 'session_start', 'v': 0},
        {'t': 1, 'u': 5, 'e': 'session_start', 'v': 0}, {'t': 2, 'u': 5, 'e': 'analytics_excluded', 'v': 1},
        {'t': 1, 'u': 6, 'e': 'session_start', 'v': 0}, {'t': 2, 'u': 6, 'e': 'analytics_excluded', 'v': 1},
        {'t': 3, 'u': 6, 'e': 'analytics_excluded', 'v': 0},
    ]
    kept = report.drop_excluded(rows, {9})
    assert sorted(r['u'] for r in kept) == [1, 6], kept
    assert 11738957136 in report.listed_accounts(), 'Config.Playtest.Owners not read'
    print('PASS: telemetry report numbers (retention, funnel, revenue, sessions, concurrency, economy, intro rounds, dev accounts left out)')


def demo(dir_, days=21, seed=7):
    """A plausible-looking made-up log, for the DEMO dashboard only."""
    rng = random.Random(seed)
    uid = 1000
    returning = []
    for d in range(days):
        t0 = START + d * DAY
        rows = []
        new = rng.randint(18, 40) + d
        players = []
        for _ in range(new):
            uid += 1
            players.append((uid, True))
        players += [(u, False) for u in returning if rng.random() < 0.28]
        for u, fresh in players:
            t = t0 + rng.randint(0, DAY - 4000)
            length = int(rng.lognormvariate(6.3, 0.9))
            rows.append([t, u, 'session_start', 0, 'new' if fresh else 'returning', rng.choice(['US', 'US', 'BR', 'PH', 'GB', 'MX', 'DE']), None])
            rows.append([t + 5, u, 'device', 1, rng.choice(['phone', 'phone', 'phone', 'desktop', 'tablet']), '844x390', 'en-us'])
            if fresh:
                keep = 1.0
                for i, name in enumerate(STEPS, start=1):
                    keep *= {6: 0.85, 7: 0.8, 9: 0.55, 11: 0.6}.get(i, 0.99)
                    if rng.random() < keep:
                        rows.append([t + 20 * i, u, 'onboarding', i, name, None, None])
                won = 0
                for rd in range(1, 7):
                    if rng.random() < 0.82 - rd * 0.06:
                        won = rd
                        rows.append([t + 400 + rd * 90, u, 'IntroRound', rd, ['Weapon', 'Shield', 'Armor', 'Gloves', 'Boots', 'Helmet'][rd - 1], 'Rare' if rng.random() < .15 else 'Uncommon', 'Won'])
                    else:
                        rows.append([t + 400 + rd * 90, u, 'IntroRound', rd, '', 'Lost', 'Lost'])
                        break
                returning.append(u)
            for _ in range(rng.randint(0, 4)):
                rows.append([t + rng.randint(10, max(11, length)), u, 'DuelFinished', 1, rng.choice(['Ranked', 'Casual', 'Ranked']), rng.choice(['Win', 'Loss']), '1v1'])
            rows.append([t + 30, u, 'coins', rng.randint(100, 900), rng.choice(['Duel', 'Rival', 'Tasks', 'GemSale', 'MineWall']), 'Gameplay', None])
            if rng.random() < 0.4:
                rows.append([t + 60, u, 'coins', -rng.randint(100, 1200), rng.choice(['Store', 'Market', 'Daycare', 'MineEntry']), 'Shop', None])
            if rng.random() < 0.03:
                product = rng.choice([('StarterPack', 99), ('Coins10k', 199), ('ReaperBundle', 499)])
                rows.append([t + 90, u, 'Purchase', product[1], product[0], 'Robux', None])
            rows.append([t + length, u, 'session_end', length, rng.randint(1, 12), rng.randint(0, 5000), rng.randint(40, 180)])
        for b in range(0, DAY, 3600):
            rows.append([t0 + b + 300, 0, 'server', max(1, int(len(players) / 10 * (1 + 0.8 * rng.random()))), 700, None, None])
        rows.sort(key=lambda x: x[0])
        write(dir_, 'demo', t0, rows)


if __name__ == '__main__':
    check()
    if len(sys.argv) > 1:
        with tempfile.TemporaryDirectory() as d:
            demo(d)
            rep = report.build(report.load(d), demo=True)
            print('demo dashboard ->', report.render(rep, sys.argv[1]))
