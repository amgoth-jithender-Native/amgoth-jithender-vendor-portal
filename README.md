# Membrane Watch

Vendor field-failure portal — pilot for **Vontron / RO Membrane** at Urban Company.

Lets a spare-part manufacturer log in and see field-failure data for their own
component: production cohort trends, defect rate by geography, defect rate by
water quality (TDS), and row-level spare records.

## Status

**Real data wired in — scope: Ronch-assembled machines only.** Login now uses
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

Not yet in scope (would extend the same pipeline):
- Amber-assembled and UC-direct machines (Part 1 currently covers Ronch only)
- Geography is by **city**, not state — UC's warehouse has no state-level
  dimension
- Even the improved barcode source is a partial reconstruction of a more
  complete 3-source method that used two now-blocked tables with no clean
  replacement — so the defect figures above remain a floor, not a ceiling
- May 2026's production cohort has unusually low spare-barcode traceability
  (12% vs 85-99% every other month) — likely a scanning gap in that batch's
  workbook, not investigated further yet
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
