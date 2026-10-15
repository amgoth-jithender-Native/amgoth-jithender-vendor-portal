#!/usr/bin/env python3
"""Build the debit-note dashboards' data files for index.html from the standalone debit-note pages.

    debit-note-ronch.html -> ronch-data.js   (one period: September 2026 revisits)
    debit-note-amber.html -> amber-data.js   (two periods: through 31 Aug 2026, September 2026)

The debit-note pages are the source of truth for the revisit rows. This script tags each
row with a defect type (spare / non-spare) and a component, keys it by installation
month, and re-cuts each note's summary by installation quarter, checking the total
against the note.

Run from the repo root:  python3 scripts/build-debit-data.py
"""
import collections
import json
import re

# Ronch's price key / Amber's category already names the component for most spares
PRICE_KEY_COMPONENT = {
    'SV': 'Solenoid Valve', 'Dispensing SV': 'Solenoid Valve',
    'PCB': 'PCB', 'SMPS': 'SMPS', 'Float Assembly': 'Float Assembly',
    'HPS': 'Pressure Switch (HPS/LPS)', 'LPS': 'Pressure Switch (HPS/LPS)',
    'Dispensing Pump': 'Dispensing Pump', 'Booster Pump': 'Booster Pump',
    'Stem/Elbow Connector': 'Connectors & Fittings',
    'Dispensing LED': 'LED / UV', 'UV LED': 'LED / UV',
}
# Everything else is matched on the item name, first rule wins
ITEM_RULES = [
    (('membrane',), 'RO Membrane'),
    (('pre-carbon', 'pre-filter', 'pre filter', 'sediment'), 'Pre Filter'),
    (('health booster', 'lifebooster'), 'Post Carbon / Health Booster'),
    (('wire harness', 'wireharness'), 'Wire Harness'),
    (('pressure enhancing', 'pressure reducing'), 'PEK / PRV'),
    (('battery', 'ups'), 'Battery'),
    (('dispensing pump',), 'Dispensing Pump'),
    (('dispensing led', 'uv light'), 'LED / UV'),
    (('tap', 'nozzle'), 'Tap Assembly'),
    (('elbow', 'connector', 'diverter', 'tubing'), 'Connectors & Fittings'),
    (('tds sensor', 'tdssensor', 'flow sensor'), 'Sensors'),
    (('float',), 'Float Assembly'),
    (('pcb',), 'PCB'),
    (('smps', 'dc jack'), 'SMPS'),
]


def component(group, price_key, item, bucket):
    if group == 'Non-spare':
        return bucket or 'Other/unclassified'
    if price_key in PRICE_KEY_COMPONENT:
        return PRICE_KEY_COMPONENT[price_key]
    name = (item or '').lower()
    for needles, comp in ITEM_RULES:
        if any(n in name for n in needles):
            return comp
    return 'Other spares'


def ym(ddmmyy):
    """'24/09/26' -> '2026-09'"""
    return '20' + ddmmyy[6:8] + '-' + ddmmyy[3:5]


def quarter(month):
    """'2026-09' -> 'Q3-26'"""
    return 'Q%d-%s' % ((int(month[5:7]) - 1) // 3 + 1, month[2:4])


def short_sku(sku):
    """Amber SKUs look like 'UC/Native/M1Pro/12601'; keep just the model, e.g. 'M1 Pro'."""
    for part in (sku or '').split('/'):
        m = re.fullmatch(r'(M\d)(Pro)?', part, re.I)
        if m:
            return m.group(1).upper() + (' Pro' if m.group(2) else '')
    return sku


COLS = ['barcode', 'sku', 'install_month', 'install_date', 'revisit_date', 'tenure', 'item', 'group', 'type',
        'component', 'part', 'svc', 'within', 'l1', 'l2', 'price_note', 'period']
C = {name: i for i, name in enumerate(COLS)}

VENDORS = {
    'ronch': {
        'src': 'debit-note-ronch.html',
        'banner': 'Ronch warranty debit note: September-2026 revisits, any installation date, grouped by installation month.',
        'chargeable_rule': 'Chargeable = within the warranty window from install: spares 365 days, filters 30 days, non-spare service 180 days.',
        'tenure_buckets': [['≤1m', 30], ['1–2m', 60], ['2–6m', 180], ['6–12m', 365], ['12m+', None]],
        # (label, groups, cost field) for the summary table; install-time replacement is added from the note
        'lines': [('Covered + Rest spares — Part cost', ('Covered', 'Rest'), 'part'),
                  ('Covered + Rest spares — Service cost', ('Covered', 'Rest'), 'svc'),
                  ('Filters — Part cost', ('Filter',), 'part'),
                  ('Filters — Service cost', ('Filter',), 'svc'),
                  ('Non-spare machine-fault — Service cost', ('Non-spare',), 'svc')],
        'cols': {'install': 'Installation Date', 'revisit': 'Revisit Date', 'group': 'Group', 'key': 'Price key'},
    },
    'amber': {
        'src': 'debit-note-amber.html',
        'banner': 'Amber warranty debit note: Amber-assembled machines, revisits from June 2026, grouped by installation month.',
        'chargeable_rule': 'Chargeable = any revisit within 30 days of install (Amber single-window rule), so every line here is chargeable.',
        'tenure_buckets': [['≤3d', 3], ['4–7d', 7], ['8–15d', 15], ['16–30d', None]],
        'lines': [('Spares — Part cost', ('Spare',), 'part'),
                  ('Service cost (Rs 500/visit)', ('Spare', 'Non-spare'), 'svc')],
        'cols': {'install': 'Install Date', 'revisit': 'Visit Date', 'group': None, 'key': 'Category'},
    },
}
PERIOD_LABELS = {'view1': 'Revisits through 31 Aug 2026', 'view2': 'Revisits in September 2026'}


def build(name, cfg):
    html = open(cfg['src'], encoding='utf-8').read()
    d = json.loads(re.search(r'var DEBIT_DATA = (\{.*?\});\n', html, re.S).group(1))
    # Ronch's note is a single period; Amber's has views
    views = d.get('views') or [dict(d, key='sep26', title='Revisits in September 2026')]
    cc = cfg['cols']
    rows, periods = [], []
    for v in views:
        idx = {h: i for i, h in enumerate(v['revisit_header'])}

        def g(r, col):
            return r[idx[col]] if col else None

        start = len(rows)
        for r in v['revisit_rows']:
            item = g(r, 'Item / Issue')
            group = g(r, cc['group']) if cc['group'] else ('Spare' if item else 'Non-spare')
            rows.append([
                g(r, 'Machine Barcode'), short_sku(g(r, 'SKU')), ym(g(r, cc['install'])),
                g(r, cc['install']), g(r, cc['revisit']), g(r, 'Tenure (days)'),
                item, group, 'nonspare' if group == 'Non-spare' else 'spare',
                component(group, g(r, cc['key']), item, g(r, 'Non-spare bucket')),
                g(r, 'Part cost (Rs)') or 0, g(r, 'Service cost (Rs)') or 0,
                1 if g(r, 'Within window') else 0,
                g(r, 'L1 reason'), g(r, 'L2 reason'), g(r, 'Price note'), v['key'],
            ])
        periods.append({'key': v['key'], 'label': PERIOD_LABELS.get(v['key'], v['title']),
                        'cohort_size': v['issue_breakdown']['cohort_size'],
                        'note': v['with_service'], 'rows': rows[start:]})

    # One set of installation quarters for every period, so periods can be added together
    quarters = set()
    for p in periods:
        quarters |= {quarter(r[C['install_month']]) for r in p['rows'] if r[C['within']]}
        quarters |= set(p['note']['header'][1:-1])
    quarters = sorted(quarters, key=lambda q: (q[3:], q[:2]))

    out_periods = []
    for p in periods:
        chargeable = [r for r in p['rows'] if r[C['within']]]

        def line(label, groups, field):
            vals = [0.0] * len(quarters)
            for r in chargeable:
                if r[C['group']] in groups:
                    vals[quarters.index(quarter(r[C['install_month']]))] += r[C[field]]
            return [label] + [round(x, 2) for x in vals] + [round(sum(vals), 2)]

        # Install-time spare replacement has no revisit rows; take it from the note, whose
        # quarter columns are installation quarters for both notes
        note = p['note']
        it_src = next(r for r in note['rows'] if r[0].startswith('Install-time'))
        it = [0.0] * len(quarters)
        for q, val in zip(note['header'][1:-1], it_src[1:-1]):
            it[quarters.index(q)] += val
        it_line = [it_src[0]] + it + [it_src[-1]]

        def total(label, lines):
            return [label] + [round(sum(l[i] for l in lines), 2) for i in range(1, len(quarters) + 2)]

        with_lines = [line(*l) for l in cfg['lines']] + [it_line]
        without_lines = [l for l in with_lines if 'Part cost' in l[0]]
        header = ['Line item'] + quarters + ['Total (Rs)']
        ws = {'header': header, 'rows': with_lines + [total('TOTAL DEBIT (with service cost)', with_lines)]}
        wos = {'header': header, 'rows': without_lines + [total('TOTAL DEBIT (without service cost)', without_lines)]}
        new_total, note_total = ws['rows'][-1][-1], note['rows'][-1][-1]
        print('%-6s %-30s Rs %12.2f  (note Rs %12.2f, difference Rs %.2f)'
              % (name, p['label'], new_total, note_total, new_total - note_total))
        out_periods.append({'key': p['key'], 'label': p['label'], 'cohort_size': p['cohort_size'],
                            'note_total': note_total, 'with_service': ws, 'without_service': wos})

    out = {
        'meta': {
            'vendor': d['meta']['vendor'],
            'note_title': d['meta']['note_title'],
            'methodology': d['meta']['methodology'],
            'known_gaps': d['meta']['known_gaps'],
            'banner': cfg['banner'],
            'chargeable_rule': cfg['chargeable_rule'],
            'tenure_buckets': cfg['tenure_buckets'],
            # Distinct machines across all periods, the "% of machines" base when periods are combined
            'all_cohort_size': len({r[C['barcode']] for r in rows}),
        },
        'periods': out_periods,
        'cols': COLS,
        'rows': rows,
    }
    path = name + '-data.js'
    with open(path, 'w', encoding='utf-8') as f:
        f.write('// Generated by scripts/build-debit-data.py from %s. Do not edit by hand.\n' % cfg['src'])
        f.write('window.MW_DEBIT = window.MW_DEBIT || {};\n')
        f.write('window.MW_DEBIT.%s = %s;\n' % (name, json.dumps(out, ensure_ascii=False, separators=(',', ':'))))

    counts = collections.Counter((r[C['type']], r[C['component']]) for r in rows)
    for (t, comp), n in sorted(counts.items(), key=lambda x: (x[0][0], -x[1])):
        print('       %-9s %-32s %d' % (t, comp, n))
    print('      ', len(rows), 'rows ->', path)


def main():
    for name, cfg in VENDORS.items():
        build(name, cfg)


if __name__ == '__main__':
    main()
