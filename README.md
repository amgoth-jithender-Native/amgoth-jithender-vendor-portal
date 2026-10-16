# Membrane Watch

Vendor field-failure portal — pilot for **Vontron / RO Membrane** at Urban Company.

Lets a spare-part manufacturer log in and see field-failure data for their own
component: install cohort trends, defect rate by geography, defect rate by
water quality (TDS), and row-level spare records.

## Component Defect Analysis v3 (`component-analysis.html`, added 2026-10-16)

A third standalone page, implementing the "v3 Build Plan" — a general-purpose,
all-manufacturer, all-component defect-analysis system (vs. the original
single-vendor/single-component pilot in `index.html`). Built the concrete
Vontron/RO-Membrane pilot (Section 7 of the plan) first; the full "all
vendors, all components" system still waits on the real SKU→component→vendor
mapping and vendor list, but **extended 2026-10-16 to cover all 23
components**, with Vontron temporarily granted access to every one of them —
**user-confirmed interim decision**, not a final access policy, pending that
mapping. Peer session (`amgoth-jithender-vendor-portal-2b`) relayed this
request on the user's behalf; confirmed directly with the user before acting
on it, since it's a real (if temporary) data-exposure change that cuts
against this whole system's own confidentiality goal.

**Component grouping is provisional, keyword-based, not the real mapping**
(`/tmp` script `component_map.py`'s logic, one ordered list of
keyword→component rules — kept as the single editable place for when the
real list arrives). Classified all 369,059 defect line items into 26 buckets
by matching the raw invoiced item name; 23 are real physical components
(shown below), the other 3 (`non_spare_admin` — 244,567 "Free Native
Revisit/Repair", "Minor repair" etc., administrative not physical;
`truwater_other_line` — a different product line entirely, not Native RO;
`unmapped_other` — 81 blank item names) are excluded from the vendor-facing
component selector. Classification coverage: 99.98% of real item names
matched a component (two bugs caught and fixed before shipping — a trailing-
space typo silently excluded 18,214 `NATIVE M1 Tap` events from Tap
Assembly, and `TDSSENSOR` without a space wasn't matching the TDS Sensor
rule).

**The 23 components** (by event count): Non-spare/Admin and TruWater
excluded as above; **Sediment/Pre Filter** (24,565), **Tap/Faucet Assembly**
(18,814), **RO Membrane** (14,253), **Carbon/Health Booster Filter**
(14,224), **Solenoid Valve** (13,069), **PCB** (5,911), **PEK/PRV** (5,152),
**SMPS/Adapter** (5,131), **Booster/Dispensing Pump** (4,935), **Float
Switch/Assembly** (4,655), **Pressure Switch (HPS/LPS)** (4,381),
**Connectors/Valves/Fittings** (3,065), **Flow Restrictor/Sensor** (2,189),
**UV/LED** (812), **Wire Harness** (698), **TDS Sensor/Controller** (477),
**Battery** (394), **Bezel Assembly** (295), **Tank/Accessories** (256),
**UF Filter** (130), **UPS** (57), **Back Panel** (45), **RO Membrane
Housing** (14).

**Telemetry extended to all smart-capable defect events** (84,218 rows
matched, up from the RO-Membrane-only 5,265), same dual-path join as before
(direct for M1Pro/M2_UC/M3/M3Pro, customer-matched IoT platform for plain
M2) — no new join logic needed, just a wider population.

**Case detail is capped at 1,000 most-recent rows per component** to keep
total file size manageable (8.3 MB for all 23 components combined, vs. 6.8
MB for RO Membrane alone before the cap) — the headline event-count stat
per component is always the true, uncapped figure; only the row-level table
is capped, and this is disclosed on the page itself.

**New migration `007_all_components.sql`** (does not edit `006`, which the
user already ran) — seeds the 22 non-RO-Membrane components and grants
Vontron access to all 23 components × the same 4 funnels (no `F_PRESSURE`).
Kept every line short after the `006` paste-truncation incident.

**Master query (Phase 1), run directly on Jarvis, not a round-trip hand-off:**
all-time Native RO install base (**489,909 installs**, no date floor — scan-
verified barcode tracking goes back further than previously known, to Sep
2024) and a universal defect table (**369,059 line items**, any invoiced
spare, not just RO Membrane). Manufacturer derived from the validated barcode
substrings (`XRP`/`RPP`/`RPX` = Ronch, `AMX`/`AMB` = Amber — not the plan's
oversimplified "RP"/"AM" prefix). The old Ronch/Amber/UC `sold_to` channel
logic ([[project_vendor_defects_dashboard]]) is kept, generalized to any
component (first replacement = the machine's own manufacturer, 2nd+ = UC
repair-stock), per explicit instruction not to drop it.

**Cross-validated against the already-proven Ronch/Amber pilot numbers**,
not just spot-checked: filtering this broader table back down to the exact
old pilot's scope gives 1,150 Ronch / 45 Amber RO-Membrane events vs. the
validated 960 / 39 — ~20% higher, fully traced (not left as an unexplained
gap) to the old pilot's SKU-code filter using a suffix match (`ILIKE
'%/12501'`) that silently misses `UC/NATIVE/12501/M0` (code isn't at the
string's end) and never included `M3`/`M3 Pro` codes at all. v3's broader,
SKU-code-agnostic population is a genuine completeness fix, not a
discrepancy.

**Phase 2 (telemetry)** reuses the validated TDS-at-install logic plus two
metrics not used before: `AVG_TDS` (output TDS) and `WATER_CONSUMED`, both
already present in the same `WATER_PURIFIERXMETRIC_DATE__DAILY__METRICS` /
`IOT_DEVICEXMETRIC_DATE__HOURLY__METRICS` tables as input TDS — no new
tables needed. M2's IoT-platform join (`SMARTAPPLIANCE_DP__VIEW`, matched by
customer, "unique" match quality only) reused verbatim from
`~/uc-audit/portal_tds/q2_device_tds_iot_m2.sql` rather than re-derived.
36.1% of RO Membrane defect events (4,994 of 13,816) have usable windowed
telemetry (install date → revisit date).

**Known gaps, disclosed in the page itself, not just here:**
- **"No barcode match" machines (174,253 installs, 35.6% of the fleet) show
  a 5.9% lifetime RO-Membrane defect rate vs. Ronch's 1.1% and Amber's
  0.2%** — confirmed this is an age/exposure-time effect, not a quality
  signal: these machines have a median install date over a year earlier
  than barcode-matched ones. Don't compare these rates head-to-head.
- **`water_consumed` figures are provisional** — computed assuming the
  source fields are in millilitres, not litres, based on real single-day
  values (3,000–21,000) that only make sense as a household daily total in
  mL. This unit assumption has not been confirmed with whoever owns the
  telemetry pipeline.
- `F_PRESSURE` is specified in the plan but not meaningfully buildable —
  input pressure capture is ~0.04% system-wide (established in prior work),
  unchanged by this rebuild.
- `smart_device_flag` is a SKU-string heuristic (M1Pro/M2/M2Pro/M3/M3Pro =
  smart), not confirmed live telemetry presence.
- `component`/`spare_vendor` mapping for anything beyond RO Membrane is
  pending the user's SKU→component→vendor list (Section 9 of the plan) —
  `spare_changed` on the raw defect table carries the item name, ready to
  join once that list exists.

**Permission model (Phase 4/6), fully separate tables** —
`supabase/migrations/006_component_access.sql`: `components`, `v3_vendors`,
`vendor_component_access`, `vendor_funnel_access`, `component_audit_log`.
Deliberately **not** `vendor_access` (which gates the original Vontron tabs
and the Ronch/Amber debit-note dashboards in `index.html`) and **not**
anything Part 1 (debit notes) touches — a change here cannot affect Siddharth
or Keshav's debit notes, by construction (different tables, different page).
Seeded with Vontron → RO Membrane → `F_TDS_IN`/`F_TDS_OUT`/`F_TDS_IO`/
`F_WATER` (no `F_PRESSURE`, per the gap above). Admin users get a "Manage
access" button in the page itself to grant/revoke per vendor, writing to
`component_audit_log` on every change — real enforcement happens through
these tables via Supabase RLS policies (same `profiles.role`/`vendor_name`
pattern as every other page), not UI-only hiding.

**Architecture note, stated plainly:** like every other page in this portal,
this one ships as a static GitHub Pages file with the Supabase anon key
embedded (safe — protected by RLS, not secrecy). The actual defect/cohort/
geo/case-detail *data* is embedded as a static JSON blob in the page itself,
not served from Supabase tables with live per-row RLS — so while *access to
the page's login* and the *permission grants* are real and enforced in
Supabase, a sufficiently determined user could still extract the raw
embedded JSON from this file's source. For a single-vendor pilot (Vontron
only) this is an acceptable, disclosed limitation, same as the earlier
debit-note pages. If/when a second vendor's *different* component data needs
to ship from the *same* file without being visible to the first vendor,
this needs to move to live Supabase-table queries with row-level security,
not static embedding — flagged now so it isn't a surprise at Phase 8 (scale
to all vendors).

## Ronch warranty debit note (`debit-note-ronch.html`, added 2026-10-15)

A second, separate page — not a tab in the main portal — for **Ronch** (the
machine assembler) to see their own warranty debit note: what they owe UC for
defects on machines they built, split into spare and non-spare line items.
This is a different kind of data from the rest of this portal (internal
warranty cost figures, not RO Membrane field-failure rates) and a different
vendor (Ronch, not Vontron), so it's a standalone file sharing only the login
system, not a tab added to `index.html`.

- Same Supabase auth as the main portal, same `profiles` table — gated on
  `role IN ('admin','team_management')` or `role='vendor' AND vendor_name='Ronch'`
  (case-insensitive), via the same `accessProblem()` pattern as `PORTAL_VENDOR`.
  See `supabase/assign_roles.sql` for the template to grant a user access —
  **the actual Supabase Auth account still has to be created by an admin in
  the Dashboard first** (Authentication → Users → Add user, or send an
  invite); this file only assigns the role/vendor_name once that account
  exists. Nothing here creates a login on its own.
- Data: `Ronch_Debit_Note_Sept2026.xlsx` (Sept 2026 revisits, any machine
  production/install date), embedded directly — summary (with/without
  service, **by install quarter**, corrected 2026-10-15, see below), issue-level
  breakdown (spare vs non-spare categories, % of the 6,772-machine cohort), the
  spare price reference table that drives every part-cost line, and all 8,498
  revisit-level rows (filterable by barcode, SKU, group, chargeable window,
  reason).
- Known gaps, same as the source workbook: 13 item types have no priced BOM
  source (priced Rs 0, flagged, not hidden); 49 of 60 Rest/Filter/Other spare
  items had their Sept-26 price carried forward from Aug-26, not individually
  re-verified that month.
- Deploy: `.github/workflows/deploy.yml` copies and key-injects this file the
  same way it does `index.html` — no separate deploy step needed.
- This is a point-in-time snapshot (data pulled/built 2026-10-05/06) — not
  live-queried, unlike the main portal. Re-run the debit-note build and
  re-extract into this page to refresh it.
- **A second Ronch surface also exists**: `index.html` itself now has an
  integrated Ronch dashboard (Debit Note, Components, Install Cohort, By
  Model, Revisit Detail tabs) that a Ronch/Siddharth login lands on directly,
  built by a parallel session the same day. `ronch-data.js` is generated
  *from* this page's `DEBIT_DATA` via `scripts/build-debit-data.py` — re-run
  it (or tell that session) if `DEBIT_DATA`'s structure or `revisit_header`
  columns ever change here. Which of the two surfaces Siddharth should
  actually use is still an open question for the user to decide.
- **Fixed 2026-10-15**: the summary table was originally grouped by each
  line's *production* quarter (inherited from the source workbook), which
  silently excluded 26 real chargeable line items (Rs 16,880.66) from
  machines produced before Q3-25 or with an unreadable production date, even
  though they were installed within the warranty window and genuinely
  chargeable — the exact same class of mistake as the main portal's own
  install-month cohort-axis fix earlier the same day. Regrouped by install
  quarter instead: total with service rose from Rs 21,07,235.34 to
  Rs 21,24,116.01, reconciling with the parallel `index.html` dashboard's own
  fix to within 1 paisa.

## Amber warranty debit note (`debit-note-amber.html`, added 2026-10-15)

Same pattern as the Ronch page above, for **Amber** — two views matching the
two debit notes already built for them:
- **View 1**: cumulative revisits through 31 Aug 2026 (`Rs 7,21,828.36` with
  service / `Rs 83,328.36` without) — a view switcher at the top of the page
  toggles between the two.
- **View 2**: revisits in September 2026 only (`Rs 4,41,819.12` with service /
  `Rs 64,319.12` without).
- Amber's methodology is simpler than Ronch's: a single rule (any revisit
  within 30 days of install is chargeable; flat Rs 500/visit service cost),
  no Covered/Rest/Filter split.
- **Verified before building, not assumed**: checked whether the same
  production-quarter-vs-install-quarter bug that hit the Ronch note also
  applies here. It doesn't — Amber's entire production history is Q2-26/Q3-26
  only (production itself only began ~Jun 2026), so production quarter and
  install quarter can never diverge enough to drop a chargeable row. Zero
  rows are excluded by the quarter axis in either view, confirmed directly
  against the raw revisit data, not inferred from the Ronch fix.
- Auth: `role IN ('admin','team_management')` or `role='vendor' AND
  vendor_name` is `'amber'` or `'keshav'` (case-insensitive) — the admin
  created Keshav's account with `vendor_name='Keshav'` directly (a person's
  name, not the company name), same situation as Siddharth/Ronch, so the page
  accepts either value rather than requiring a specific one.
- Known gaps, same as the source workbooks: 14 item types have no
  Amber-specific BOM price source (approx-matched from M1/M2 family tabs
  where possible, flagged "approx"); no Amber M0 BOM tab exists at all.

## Status

**Row-level cleanup + maturity-gating (2026-10-15):**
- **Production month now decoded from the machine's own barcode** when the
  specific spare isn't traceable (397 of 400 previously-"Not traceable" rows
  fixed) — e.g. `NVM1XRP250713104` → `25`+`07` → Jul-25. Validated against real
  ground truth at **99.98% (Ronch) / 98.61% (Amber)** accuracy before trusting
  it at scale. Labeled via a `prod_source` field (`spare_barcode` vs
  `machine_barcode`) so the two meanings never blend silently — a
  machine-barcode-decoded month is the machine's own assembly date, not
  necessarily the specific (untraceable) repair spare's own production date.
  3 rows stay "Not traceable" (malformed barcodes); 1 implausible decode
  (5-year gap to install) was reverted rather than trusted.
- **Re-investigated the 177 "Not recorded" Reason/Sub-reason rows** using the
  most precise possible join (exact install ID + row-numbered revisit match,
  same method as Amber's). Result: zero additional reasons recovered — these
  are genuinely unrecorded in the source ticketing system, not a join bug.
  Confirmed, not fixed, because there was nothing to fix.
- **Every tenure bucket now shows a dash instead of a possibly-misleading 0**
  when that window isn't fully matured yet for the group's own most-recently-
  installed machine — e.g. an install month's 6-12m column stays blank until
  even its last day's install has had the full 365 days, not just its first.
  Applies to Install Cohort, Geography, and TDS alike. A non-zero count still
  shows even if not fully matured (it's a real observation, just possibly
  incomplete) — only a 0 that might just mean "too soon to tell" gets dashed.
  TDS band maturity is computed from a point-in-time device-TDS snapshot
  (pulled 2026-10-06), so it's a little more conservative than Cohort/
  Geography, which use live install dates.

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

**Vendor access (admin).** Admins get a *Vendor access* button in the top bar.
It lists every vendor (the distinct `profiles.vendor_name` of vendor accounts),
lets the admin tick which tables each vendor sees (Install Cohort, Geography,
Water Quality, Row-Level Detail), and offers *Preview as …* to view the portal
exactly as that vendor will (rates only, states only, only the ticked tables).
Vendor logins with no vendor name appear at the bottom and can be linked there.
Choices are stored in `public.vendor_access` (`supabase/migrations/003_vendor_access.sql`);
a vendor with no tables assigned can't sign in. The page still carries only
Vontron's data, so other vendors stay blocked ("dashboard is being set up")
until their data is added. Hiding tables is a display rule only: every table's
data still ships inside the page.

**Ronch dashboard (warranty debit note).** The portal carries a second dataset:
Ronch's September-2026 warranty debit note. The Ronch login (vendor_name `Ronch`, or
`Siddharth` for now) lands on it; admins and team management switch with the
*Vendor* dropdown. Defect type (Spare / Non-spare) and Component (every component in
the note) both filter five tables: Debit Note, Components, Install Cohort, By
Model and Revisit Detail. The data lives in `ronch-data.js`, loaded only when the
Ronch dashboard opens, and is rebuilt from `debit-note-ronch.html` with
`python3 scripts/build-debit-data.py`. Everything is grouped by the machine's
**installation month/quarter**, not production month. That counts every chargeable
line: Rs 21,24,116.00, versus the issued note's Rs 21,07,235.34, which grouped by
production quarter and so dropped 26 chargeable lines (Rs 16,880.66) built before
Q3-25 or with an unreadable build date. Install-time spare replacement
(Rs 49,079.46) has no revisit rows and sits in the revisit month's quarter (Q3-26). Run
`supabase/migrations/004_ronch_tabs.sql` so these tables can be assigned in
Vendor access.

**Amber dashboard (warranty debit note).** The same five tables for Amber-assembled
machines, for the Amber login (vendor_name `Keshav`, or `Amber`). A *Period*
dropdown picks revisits through 31 Aug 2026, September 2026, or both. Amber's
single 30-day window makes every line chargeable, so tenure is split by days
(≤3d / 4–7d / 8–15d / 16–30d). The data is `amber-data.js`, built from
`debit-note-amber.html` by the same script; each period reconciles exactly to the
note (Rs 7,21,828.36 through Aug, Rs 4,41,819.12 in Sep). Run
`supabase/migrations/005_amber_tabs.sql` to give the Keshav login its tables.

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
- Maturity-gating (2026-10-15, see above) now applies uniformly to **every**
  bucket, not just 12–18m/18–24m: a cell only shows a real 0 once the group's
  latest-installed machine has had that bucket's full window to mature,
  otherwise it's a dash. As of 2026-10-15 only Sep-25 install cohort's 12-18m
  is matured (0 qualifying events so far); 18-24m is a dash everywhere (first
  machines reach 18 months in Mar 2027). State view in Geography sums the
  cities that have a value. All 10 replacements at 366–376 days are counted
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
