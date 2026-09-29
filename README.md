# Membrane Watch

Vendor field-failure portal — pilot for **Vontron / RO Membrane** at Urban Company.

Lets a spare-part manufacturer log in and see field-failure data for their own
component: production cohort trends, defect rate by geography, defect rate by
water quality (TDS), and row-level spare records.

## Status

**Real data wired in — scope: Ronch-assembled machines only.** Login is still a
hardcoded demo credential with no real backend; the numbers on every tab are
computed from an actual join of UC's install/defect data against the
manufacturing scan data, not mock figures.

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
- Input TDS captured for 8.5% of installs (15,484) — reflects real field data
  collection, not a query gap
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
- TDS coverage (8.5%), input pressure (essentially uncaptured), and 39 spares
  with implausibly long production-to-assembly gaps remain open, unexplained
  data-quality findings — not resolved, just disclosed

## Running it

This is a single static `index.html` — no build step. Open it directly in a
browser, or serve the folder with any static file server.

Demo login: `dheerajbathla@urbancompany.com` / `dheeraj@123`

## Structure

- `index.html` — the entire app (markup, styles, mock data, and logic in one file)
