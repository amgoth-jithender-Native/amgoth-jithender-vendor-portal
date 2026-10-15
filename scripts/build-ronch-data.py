#!/usr/bin/env python3
"""Build ronch-data.js (Ronch dashboard in index.html) from the debit note in debit-note-ronch.html.

The debit-note page is the source of truth for the revisit rows. This script tags each
row with a defect type (spare / non-spare) and a component, keys it by installation
month, and re-cuts the note's summary by installation quarter.

Run from the repo root:  python3 scripts/build-ronch-data.py
"""
import collections
import json
import re

SRC = 'debit-note-ronch.html'
OUT = 'ronch-data.js'

# Covered spares carry a price key that already names the component
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
    (('wire harness',), 'Wire Harness'),
    (('pressure enhancing', 'pressure reducing'), 'PEK / PRV'),
    (('battery', 'ups'), 'Battery'),
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


def main():
    html = open(SRC, encoding='utf-8').read()
    d = json.loads(re.search(r'var DEBIT_DATA = (\{.*?\});\n', html, re.S).group(1))
    idx = {h: i for i, h in enumerate(d['revisit_header'])}

    def g(r, col):
        return r[idx[col]]

    # Everything is keyed by installation month. The note itself splits by production quarter
    # and bills only Q3-25..Q3-26 production; here every chargeable line counts, whatever its build date.
    rows = []
    for r in d['revisit_rows']:
        group = g(r, 'Group')
        rows.append([
            g(r, 'Machine Barcode'), g(r, 'SKU'), ym(g(r, 'Installation Date')),
            g(r, 'Installation Date'), g(r, 'Revisit Date'), g(r, 'Tenure (days)'),
            g(r, 'Item / Issue'), group,
            'nonspare' if group == 'Non-spare' else 'spare',
            component(group, g(r, 'Price key'), g(r, 'Item / Issue'), g(r, 'Non-spare bucket')),
            g(r, 'Part cost (Rs)') or 0, g(r, 'Service cost (Rs)') or 0,
            1 if g(r, 'Within window') else 0,
            g(r, 'L1 reason'), g(r, 'L2 reason'), g(r, 'Price note'),
        ])
    cols = ['barcode', 'sku', 'install_month', 'install_date', 'revisit_date', 'tenure',
            'item', 'group', 'type', 'component', 'part', 'svc', 'within', 'l1', 'l2', 'price_note']
    c = {name: i for i, name in enumerate(cols)}

    # Debit note summary re-cut by installation quarter, chargeable lines only.
    # Install-time spare replacement has no revisit rows; it happened at installs during the
    # revisit month, so it sits in that month's quarter.
    install_time = next(r for r in d['with_service']['rows'] if r[0].startswith('Install-time'))
    revisit_q = quarter(ym(d['revisit_rows'][0][idx['Revisit Date']]))
    chargeable = [r for r in rows if r[c['within']]]
    quarters = sorted({quarter(r[c['install_month']]) for r in chargeable} | {revisit_q},
                      key=lambda q: (q[3:], q[:2]))

    def line(label, groups, field):
        vals = [0.0] * len(quarters)
        for r in chargeable:
            if r[c['group']] in groups:
                vals[quarters.index(quarter(r[c['install_month']]))] += r[c[field]]
        return [label] + [round(v, 2) for v in vals] + [round(sum(vals), 2)]

    it = [0.0] * len(quarters)
    it[quarters.index(revisit_q)] = install_time[-1]
    it_line = [install_time[0]] + it + [install_time[-1]]
    spares = ('Covered', 'Rest')

    def total(label, lines):
        return [label] + [round(sum(l[i] for l in lines), 2) for i in range(1, len(quarters) + 2)]

    with_lines = [line('Covered + Rest spares — Part cost', spares, 'part'),
                  line('Covered + Rest spares — Service cost', spares, 'svc'),
                  line('Filters — Part cost', ('Filter',), 'part'),
                  line('Filters — Service cost', ('Filter',), 'svc'),
                  line('Non-spare machine-fault — Service cost', ('Non-spare',), 'svc'),
                  it_line]
    without_lines = [with_lines[0], with_lines[2], it_line]
    header = ['Line item'] + quarters + ['Total (Rs)']
    with_service = {'header': header, 'rows': with_lines + [total('TOTAL DEBIT (with service cost)', with_lines)]}
    without_service = {'header': header, 'rows': without_lines + [total('TOTAL DEBIT (without service cost)', without_lines)]}

    out = {
        'meta': {
            'note_title': d['meta']['note_title'],
            'methodology': d['meta']['methodology'],
            'known_gaps': d['meta']['known_gaps'],
            'cohort_size': d['issue_breakdown']['cohort_size'],
            'quarters': quarters,
            'note_total': d['with_service']['rows'][-1][-1],
        },
        'with_service': with_service,
        'without_service': without_service,
        'cols': cols,
        'rows': rows,
    }
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('// Generated by scripts/build-ronch-data.py from debit-note-ronch.html. Do not edit by hand.\n')
        f.write('window.MW_RONCH = ' + json.dumps(out, ensure_ascii=False, separators=(',', ':')) + ';\n')

    counts = collections.Counter((r[c['type']], r[c['component']]) for r in rows)
    for (t, comp), n in sorted(counts.items(), key=lambda x: (x[0][0], -x[1])):
        print(f'{t:9} {comp:32} {n}')
    new_total = with_service['rows'][-1][-1]
    print(len(rows), 'rows ->', OUT)
    print('Debit by installation month: Rs %.2f (note, by production quarter: Rs %.2f, difference Rs %.2f)'
          % (new_total, out['meta']['note_total'], new_total - out['meta']['note_total']))


if __name__ == '__main__':
    main()
