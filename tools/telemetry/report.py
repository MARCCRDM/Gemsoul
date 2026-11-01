"""Build the dashboard from the game's own event log (Server.Telemetry).

  python3 tools/telemetry/report.py [data dir] [out.html]

Reads what pull.py saved (tools/telemetry/data/), works out the numbers and
writes one self-contained HTML file (tools/telemetry/dashboard.html by
default: open it in any browser, no internet needed) with them inside.

Every row is [time, userId, event, value, a, b, c] (Server.Telemetry). All days
are UTC.
"""
import json, statistics, sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent


def day_of(t):
    return datetime.fromtimestamp(t, timezone.utc).strftime('%Y-%m-%d')


def load(data_dir):
    rows = []
    for f in sorted(Path(data_dir).glob('*.json')):
        try:
            value = json.loads(f.read_text())
        except Exception:
            continue
        place = value.get('Place')
        server = value.get('Server') or f.stem
        for r in value.get('Rows', []):
            r = list(r) + [None] * (7 - len(r))
            rows.append({'t': r[0], 'u': r[1], 'e': r[2], 'v': r[3], 'a': r[4], 'b': r[5], 'c': r[6], 'place': place, 'server': server})
    rows.sort(key=lambda r: r['t'] or 0)
    return rows


def listed_accounts(config=HERE.parent.parent / 'src/shared/Config.luau'):
    """Owners, Testers and NoAnalytics from Config.Playtest: dev and test
    accounts, left out of every number (Server/Systems/DevAccounts)."""
    import re
    try:
        text = Path(config).read_text()
    except OSError:
        return set()
    ids = set()
    for name in ('Owners', 'Testers', 'NoAnalytics'):
        m = re.search(r'\b' + name + r'\s*=\s*\{([^}]*)\}', text)
        if m:
            ids.update(int(x) for x in re.findall(r'\d+', re.sub(r'--[^\n]*', '', m.group(1))))
    return ids


def drop_excluded(rows, listed=()):
    """Rows without the left-out accounts: `listed`, and anyone whose latest
    "analytics_excluded" row is 1 (marked NOT COUNTED in game), their rows
    from before the mark too."""
    skip = set(listed)
    latest = {}
    for r in rows:
        if r['e'] == 'analytics_excluded':
            if r['t'] >= latest.get(r['u'], (-1, None))[0]:
                latest[r['u']] = (r['t'], r['v'])
    for u, (_, v) in latest.items():
        if v == 1:
            skip.add(u)
        elif u not in set(listed):
            skip.discard(u)
    return [r for r in rows if r['u'] not in skip and r['e'] != 'analytics_excluded']


def pct(n, d):
    return None if not d else round(100.0 * n / d, 1)


def build(rows, demo=False):
    users = [r for r in rows if r['u']]
    days = sorted({day_of(r['t']) for r in rows}) if rows else []
    active = defaultdict(set)          # day -> users
    first_new = {}                     # user -> day they came new
    first_seen = {}
    for r in users:
        d = day_of(r['t'])
        active[d].add(r['u'])
        first_seen.setdefault(r['u'], d)
        if r['e'] == 'session_start' and r['a'] == 'new':
            first_new.setdefault(r['u'], d)
    cohort_of = {u: first_new.get(u, first_seen[u]) for u in first_seen}
    user_days = defaultdict(set)
    for d, us in active.items():
        for u in us:
            user_days[u].add(d)

    per_day = {d: {'day': d, 'dau': len(active[d]), 'new': 0, 'sessions': 0, 'lengths': [], 'revenue': 0,
                   'payers': set(), 'coins_in': 0, 'coins_out': 0, 'ccu': defaultdict(dict)} for d in days}
    funnel_users = defaultdict(set)
    funnel_names = {}
    rounds = defaultdict(lambda: {'won': set(), 'lost': 0, 'rare': 0, 'slot': None})
    duels = defaultdict(Counter)
    sources, sinks = Counter(), Counter()
    products = defaultdict(lambda: [0, 0])
    devices, countries, events, versions = defaultdict(set), defaultdict(set), Counter(), Counter()
    lengths_all = []
    for r in rows:
        d = day_of(r['t'])
        p = per_day[d]
        e = r['e']
        events[e] += 1
        if r['place'] is not None:
            versions[str(r['place'])] += 1
        if e == 'session_start':
            p['sessions'] += 1
            if r['a'] == 'new':
                p['new'] += 1
            if r['b']:
                countries[r['b']].add(r['u'])
        elif e == 'session_end' and isinstance(r['v'], (int, float)) and r['v'] >= 0:
            p['lengths'].append(r['v'] / 60)
            lengths_all.append(r['v'] / 60)
        elif e == 'device':
            devices[r['a'] or 'unknown'].add(r['u'])
        elif e == 'onboarding' and isinstance(r['v'], (int, float)):
            funnel_users[int(r['v'])].add(r['u'])
            funnel_names[int(r['v'])] = r['a']
        elif e == 'IntroRound' and isinstance(r['v'], (int, float)):
            rd = rounds[int(r['v'])]
            rd['slot'] = r['a'] or rd['slot']
            if r['c'] in ('Won', 'Done'):
                rd['won'].add(r['u'])
                if r['b'] == 'Rare':
                    rd['rare'] += 1
            elif r['c'] == 'Lost':
                rd['lost'] += 1
        elif e == 'DuelFinished':
            duels[r['a'] or '?'][r['b'] or '?'] += 1
        elif e == 'coins' and isinstance(r['v'], (int, float)):
            if r['v'] >= 0:
                sources[r['a'] or 'Other'] += r['v']
                p['coins_in'] += r['v']
            else:
                sinks[r['a'] or 'Other'] += -r['v']
                p['coins_out'] += -r['v']
        elif e == 'Purchase':
            robux = r['v'] if r['b'] == 'Robux' and isinstance(r['v'], (int, float)) else 0
            p['revenue'] += robux
            p['payers'].add(r['u'])
            products[r['a'] or '?'][0] += robux
            products[r['a'] or '?'][1] += 1
        elif e == 'server' and isinstance(r['v'], (int, float)):
            bucket = r['t'] - r['t'] % 300
            p['ccu'][bucket][r.get('server') or '?'] = r['v']

    out_days = []
    for d in days:
        p = per_day[d]
        ls = p['lengths']
        ccu = max((sum(v.values()) for v in p['ccu'].values()), default=0)
        out_days.append({
            'day': d, 'dau': p['dau'], 'new': p['new'], 'sessions': p['sessions'],
            'avg_session_min': round(statistics.mean(ls), 1) if ls else None,
            'median_session_min': round(statistics.median(ls), 1) if ls else None,
            'revenue': p['revenue'], 'payers': len(p['payers']),
            'coins_in': p['coins_in'], 'coins_out': p['coins_out'], 'peak_ccu': ccu,
        })

    # Retention: of the players who first came on a day, how many came back N days on.
    last = days[-1] if days else None
    def plus(d, n):
        return datetime.fromtimestamp(datetime.strptime(d, '%Y-%m-%d').replace(tzinfo=timezone.utc).timestamp() + n * 86400, timezone.utc).strftime('%Y-%m-%d')
    cohorts = defaultdict(list)
    for u, d in cohort_of.items():
        cohorts[d].append(u)
    retention = []
    for d in days:
        members = cohorts.get(d, [])
        row = {'day': d, 'cohort': len(members)}
        for n in (1, 3, 7):
            target = plus(d, n)
            row[f'd{n}'] = pct(sum(1 for u in members if target in user_days[u]), len(members)) if last and target <= last and members else None
        retention.append(row)

    def weighted(n):
        num = den = 0
        for r in retention:
            if r[f'd{n}'] is not None:
                num += r[f'd{n}'] * r['cohort']
                den += r['cohort']
        return round(num / den, 1) if den else None

    steps = sorted(funnel_users)
    top = len(funnel_users[steps[0]]) if steps else 0
    funnel = []
    prev = None
    for s in steps:
        n = len(funnel_users[s])
        funnel.append({'step': s, 'name': funnel_names.get(s) or str(s), 'users': n, 'pct': pct(n, top),
                       'drop': pct(prev - n, prev) if prev else 0})
        prev = n

    week = out_days[-7:]
    dau7 = [x['dau'] for x in week]
    revenue7 = sum(x['revenue'] for x in week)
    payers7 = len(set().union(*[per_day[x['day']]['payers'] for x in week])) if week else 0
    hist_edges = [(0, 2, '<2m'), (2, 5, '2-5m'), (5, 10, '5-10m'), (10, 20, '10-20m'), (20, 40, '20-40m'), (40, 1e9, '40m+')]
    return {
        'generated': datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC'),
        'demo': demo,
        'range': {'from': days[0] if days else None, 'to': last, 'rows': len(rows), 'users': len(first_seen)},
        'kpis': {
            'dau_today': out_days[-1]['dau'] if out_days else 0,
            'dau_avg7': round(statistics.mean(dau7), 1) if dau7 else 0,
            'new_7d': sum(x['new'] for x in week),
            'avg_session_min': round(statistics.mean(lengths_all), 1) if lengths_all else None,
            'd1': weighted(1), 'd7': weighted(7),
            'revenue_7d': revenue7, 'payers_7d': payers7,
            'arpdau_7d': round(revenue7 / sum(dau7), 2) if sum(dau7) else 0,
            'peak_ccu': max((x['peak_ccu'] for x in out_days), default=0),
        },
        'days': out_days,
        'retention': retention,
        'funnel': funnel,
        'intro_rounds': [{'round': k, 'slot': v['slot'], 'won': len(v['won']), 'lost': v['lost'], 'rare': v['rare']} for k, v in sorted(rounds.items())],
        'duels': {m: dict(c) for m, c in duels.items()},
        'economy': {'sources': [list(x) for x in sources.most_common()], 'sinks': [list(x) for x in sinks.most_common()]},
        'products': sorted(([k, v[0], v[1]] for k, v in products.items()), key=lambda x: -x[1]),
        'devices': sorted(([k, len(v)] for k, v in devices.items()), key=lambda x: -x[1]),
        'countries': sorted(([k, len(v)] for k, v in countries.items()), key=lambda x: -x[1])[:12],
        'sessions_hist': [[label, sum(1 for x in lengths_all if lo <= x < hi)] for lo, hi, label in hist_edges],
        'events': [list(x) for x in events.most_common(25)],
        'versions': [list(x) for x in sorted(versions.items(), key=lambda x: x[0])],
    }


def render(report, out):
    template = (HERE / 'dashboard_template.html').read_text()
    html = template.replace('/*DATA*/null', json.dumps(report))
    Path(out).write_text(html)
    return out


def main():
    data_dir = sys.argv[1] if len(sys.argv) > 1 else HERE / 'data'
    out = sys.argv[2] if len(sys.argv) > 2 else HERE / 'dashboard.html'
    rows = drop_excluded(load(data_dir), listed_accounts())
    report = build(rows)
    (Path(out).with_suffix('.json')).write_text(json.dumps(report, indent=1))
    print(f'{len(rows)} rows, {report["range"]["users"]} players -> {render(report, out)}')


if __name__ == '__main__':
    main()
