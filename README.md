# Membrane Watch

Vendor field-failure portal — pilot for **Vontron / RO Membrane** at Urban Company.

Lets a spare-part manufacturer log in and see field-failure data for their own
component: install cohort trends, defect rate by geography, defect rate by
water quality (TDS), and row-level spare records.

## Status

**Cohort axis changed to install month (2026-10-15):** the "Install Cohort" tab
(formerly "Production Cohort") now groups by the month a machine was
**installed**, not the month its spare was produced — a full replacement of
the axis, not an added view (user's explicit call after weighing the
trade-off). Two real, disclosed consequences:
- **Coverage jumps from ~69% to ~100% of installs** — install month is known
  for virtually every machine (21 Amber rows with no recorded install date are
  the only exclusion), whereas production month was only knowable for the
  ~69% of installs traceable to a scanned spare barcode.
- **Defect counts per cell now include every qualifying repair**, including
  later UC-channel replacements, not just a machine's first (traceable)
  replacement — this is a real increase in what's counted, not just a
  relabeling. The trade-off: this view can no longer by itself point at "a bad
  production batch," since installs in a given month may contain machines
  assembled across several different production months. That diagnosis still
  lives in Row-Level Detail's unchanged **Spare Prod Month** column.
- The Sold-to filter on this tab now means "which manufacturer's *install*
  population" (Ronch vs Amber) rather than "which channel the failed spare
  came from" — selecting UC shows nothing here, since UC was never an
  assembler of machines (see Row-Level Detail for UC-attributed repairs).

**Correction surfaced while making this change:** Amber's install window was
previously (and wrongly) described as "Jul–Aug 2026 only." That was a
string-sort bug in a verbal date-range check (`"01/08/26" < "31/07/26"`
lexicographically, since day comes first in `DD/MM/YY`) — the underlying data
was never wrong, only that one descriptive claim. **Amber installs actually
run from Jun 2026 (39 installs) through the present (3,932 in Oct 2026 so far,
a partial month)** — corrected everywhere this was stated.

**Real data wired in — scope: Ronch-assembled and Amber-assembled machines.** Login now uses
real Supabase authentication with role-based access (admin/team/vendor) — the
hardcoded demo credential from the original prototype is gone. The numbers on
every tab are computed from an actual join of UC's install/defect data against
the manufacturing scan data, not mock figures.

**Cross-validated against true production records (2026-09-30):** every
number below has now been checked against Ronch's own production log (a
separate Google Sheet, not UC's warehouse) — genuinely independent evidence,
not another pull from the same pipeline. Full detail, including the month-by-
month breakdown, is in the "Production coverage" banner on the live page
itself (click it to expand) — this isn't just documentation, vendors can see
the same disclosure.
- Lifetime true Ronch production: 392,584 units. Machine-barcode tracking
  (the system this whole dashboard depends on) only exists from **Sep 2025
  onward** — everything produced Feb–Aug 2025 (127,770 real units) is a
  genuine historical blind spot, not a query gap.
- Within the tracked window, barcode-capture rate is **97.6%** (258,520 of
  264,814 true units) — the scanning process itself works well once it exists.
- This resolves the earlier "~21% no barcode match" concern in one important
  way: it's now clear most of that gap is concentrated in *when* a machine
  was produced (pre-tracking) rather than being a uniform, unexplained
  scanning failure throughout.

- **181,795 Ronch RO installs**, 15 Sep 2025 – 15 Sep 2026 — machine identity now
  resolved via scan-verified barcode records (`REQUESTXBARCODEXSCANSTATUS__DAILY__FACTS`)
  instead of the original single-source appliance table, for materially better
  per-install coverage (~94% vs ~79% on a sampled comparison). The population
  count itself moved only slightly (185,712 → 181,795) since it also draws
  from a different underlying install-identification query — treat this as
  cross-validation of the original number, not a correction of it
- **1,037 total RO Membrane replacement events** across 960 distinct machines
  (0.53% of installs had at least one) — counts **every** qualifying
  replacement per machine within the 1-year warranty, not just the first
- **Sold-to attribution**: a machine's first membrane replacement = **Ronch**
  (the originally factory-assembled spare failed); any second/third
  replacement on the same machine = **UC** (a repair-stock spare failed —
  Vontron sells directly to UC as a separate channel from what it ships to
  Ronch for assembly). 960 Ronch-attributed events, 77 UC-attributed
- Spare's own production month traced for 73.7% of installs (134,058), via
  the machine-barcode ↔ spare-barcode scan data — this only applies to a
  machine's *first* replacement, since UC-channel repair spares are never
  scanned into the assembly-line system
- Input TDS available for 40.0% of installs (72,774 rows; was 8.5% / 15,484
  from install audits alone). Source precedence: the installation-audit
  reading where captured (15,469 installs), otherwise the smart machine's own
  first daily average input TDS — `WATER_PURIFIERXMETRIC_DATE__DAILY__METRICS`
  for M1 Pro / M2_UC / M3 / M3 Pro (46,646, joined via
  `NATIVE_APPLIANCE__HOURLY__FACTS.APPLIANCE_ID`), and the older IoT platform
  `IOT_DEVICEXMETRIC_DATE__HOURLY__METRICS` for M2 (10,622, matched by
  customer, unambiguous matches only). M2 input logging began Mar 2026, so
  older M2 machines use their first logged day. Device readings under 20 ppm
  are treated as sensor faults. Non-smart M0/M1 machines have no sensor, so
  they only have the audit reading. 476 of the 1,037 defect events now carry
  a TDS band (was 190). Where both sources exist, band-level medians agree
  (audit 451 vs device 441; 302 vs 350); individual readings differ ~20-30%
  (hand pen vs built-in sensor). Build script: `~/uc-audit/portal_tds/build_portal_tds.py`
- 679 of the 1,037 events trace to an identifiable spare barcode and appear
  in the row-level tab with that barcode; UC-attributed events show the
  machine barcode instead (labeled, not fabricated as a spare barcode)
- No video/photo evidence field exists in the source data — the row-level
  tab's video column is honestly empty for all real rows, not fabricated

**Amber added (2026-10-13):** same pipeline and sold-to logic as Ronch, mirrored
onto Amber-assembled machines — first replacement per machine = **Amber**, any
later replacement = **UC** (same repair-stock channel Ronch's UC-attributed
events come from). Real, important differences from Ronch, disclosed rather
than smoothed over:
- **16,567 Amber installs** (vs 181,795 Ronch) — Amber only appears in UC's
  install pipeline from **Jun 2026 onward** (its production itself only
  started ~Jun 2026 per the true-production log), so this is the full
  population to date, not an artificially narrowed window. Install volume is
  still ramping: 39 in Jun, 3,054 in Jul, 5,555 in Aug, 3,966 in Sep, 3,932 in
  Oct so far (partial month).
- **39 defect events, all first replacements, 0 second+** — Amber's cohort is
  too new to have reached the later tenure buckets (6–12m, 12–18m, 18–24m)
  that a meaningful share of Ronch's defects fall into. **Amber's defect rate
  (0.24%) is not yet a fair comparison to Ronch's (0.53%)** — give it more
  warranty-year runway before reading anything into the gap.
- Machine/spare-barcode traceability for Amber comes from a **different
  source**: a vendor-provided "Amber Scanning Data" sheet (Customer Serial No
  = machine barcode, Finish Date = shared machine+spare test date, RO Membrane
  SNo = spare barcode) — not the Snowflake scan-verified table Ronch uses,
  since Amber isn't yet in that table under this barcode scheme in volume.
- **Spare traceability is much lower for Amber: 15.4% vs Ronch's 73.7%** — a
  real data-quality gap in the vendor's own sheet (RO Membrane SNo is recorded
  for only ~26% of all Amber rows), not a join bug, and it varies sharply by
  SKU (M2PRO ~41%, M1PRO ~12%, M0V1 ~0.5%).
- **Zero TDS coverage for Amber** (no device-sensor enrichment pass has been
  run for it yet, unlike Ronch's 40%) — this dilutes the combined TDS coverage
  figure shown in the banner from 40.0% to 36.7%; disclosed, not hidden.
- Jul 2026 shows 0 Amber membrane-traced installs and Aug 2026 only 6 (vs
  1,398 in Jun and 1,143 in Sep) — a dip similar in shape to Ronch's May-2026
  anomaly, confirmed real in the source sheet, not yet root-caused.
- The Cohort tab's "Sold to" filter genuinely splits Ronch vs Amber install
  trends (`DATA.cohortRonch` / `DATA.cohortAmber`), not just a label —
  Geography and TDS tabs remain combined-only (no per-manufacturer split
  requested there).

Not yet in scope (would extend the same pipeline):
- UC-direct machines (sold straight to the end customer, no assembler)
- Geography is by **city**, not state — UC's warehouse has no state-level
  dimension
- Even the improved barcode source is a partial reconstruction of a more
  complete 3-source method that used two now-blocked tables with no clean
  replacement — so the defect figures above remain a floor, not a ceiling
- May 2026's production cohort has unusually low spare-barcode traceability
  (12% vs 85-99% every other month) — likely a scanning gap in that batch's
  workbook, not investigated further yet. This is now only visible via
  Row-Level Detail's Spare Prod Month column, since Install Cohort no longer
  groups by production month (see above)
- Install cohort funnel 12–18m / 18–24m: an install month gets a value
  (defects ÷ total installs for that month) only if some of its machines have
  already been in use past 12 / 18 months; otherwise the cell shows a dash.
  As of 2026-10-15 only Sep–Oct 2025 install cohorts show 12–18m (0 qualifying
  events in that window so far), and 18–24m is a dash everywhere (first
  machines reach 18 months in Mar 2027, since installs start 15 Sep 2025)
- Geography + TDS funnels 12–18m / 18–24m (2026-10-06): same rule as the
  cohort funnel; a city / TDS band gets a value only if some of its machines
  have been in use past 12 / 18 months, otherwise a dash. State view sums the
  cities that have data. All 10 replacements at 366–376 days are counted
  (geography, TDS, and install cohort all count every qualifying event now).
- Row-level detail now has **Reason** and **Sub-reason** (the revisit ticket's
  REASON / SUBREASON from `REQUEST__NATIVE_INSTALLATION_REVISIT__DAILY__FACTS`,
  matched on install + revisit date; 177 of 1,037 have none recorded and show
  "Not recorded"), plus a Reason filter. The 10 replacements beyond 365 days
  are added as rows (tenure filter options 366–548 / 549–730 days), so the
  table has 1,047 records while the warranty-year headline stays 1,037.
  Script: `~/uc-audit/portal_tds/extend_geo_tds_rows.py` (+ `q3_membrane_events_reasons.sql`)
- TDS coverage (40%, non-smart models audit-only), input pressure (essentially uncaptured), and 39 spares
  with implausibly long production-to-assembly gaps remain open, unexplained
  data-quality findings — not resolved, just disclosed

## Running it

This is a single static `index.html` — no build step. Open it directly in a
browser, or serve the folder with any static file server. Real login now
requires Supabase credentials (see `config.local.js`, git-ignored) — the
original hardcoded demo login is gone.

## Structure

- `index.html` — the entire app (markup, styles, mock data, and logic in one file)
