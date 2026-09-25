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

- 185,954 Ronch RO installs, 15 Sep 2025 – 15 Sep 2026
- 940 confirmed RO Membrane defects within the 365-day warranty (0.51%)
- Spare's own production month traced for 73.4% of installs (136,456), via
  the machine-barcode ↔ spare-barcode scan data
- Input TDS captured for 8.3% of installs (15,459) — reflects real field data
  collection, not a query gap
- 659 of the 940 defects trace to an identifiable spare barcode and appear in
  the row-level tab; the other 281 are counted in the cohort/city/TDS totals
  but have no traceable spare barcode, so aren't shown as individual records
- No video/photo evidence field exists in the source data — the row-level
  tab's video column is honestly empty for all real rows, not fabricated

Not yet in scope (would extend the same pipeline):
- Amber-assembled and UC-direct machines (Part 1 currently covers Ronch only)
- Geography is by **city**, not state — UC's warehouse has no state-level
  dimension
- ~21% of RO Membrane invoice events warehouse-wide lack barcode
  traceability, so the 940-defect figure is a floor, not a ceiling

## Running it

This is a single static `index.html` — no build step. Open it directly in a
browser, or serve the folder with any static file server.

Demo login: `dheerajbathla@urbancompany.com` / `dheeraj@123`

## Structure

- `index.html` — the entire app (markup, styles, mock data, and logic in one file)
