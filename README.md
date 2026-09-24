# Membrane Watch

Vendor field-failure portal — pilot for **Vontron / RO Membrane** at Urban Company.

Lets a spare-part manufacturer log in and see field-failure data for their own
component: production cohort trends, defect rate by geography, defect rate by
water quality (TDS), and row-level spare records.

## Status

**Prototype stage — all data on this page is illustrative sample data, not real
figures.** Login is a hardcoded demo credential with no real backend; this exists
to validate the UI/flow before wiring up the actual warehouse data.

Still needed before this can run on real data:
- UC's spare-barcode ↔ machine-barcode scanning data format (links a spare to
  the machine it was assembled into)
- The data source for a spare's own production month (distinct from the
  machine's production month)

## Running it

This is a single static `index.html` — no build step. Open it directly in a
browser, or serve the folder with any static file server.

Demo login: `dheerajbathla@urbancompany.com` / `dheeraj@123`

## Structure

- `index.html` — the entire app (markup, styles, mock data, and logic in one file)
