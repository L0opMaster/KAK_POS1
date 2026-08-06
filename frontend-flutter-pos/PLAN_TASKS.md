# Flutter POS — Plan Task Breakdown

Version: 2026-07-16
Source: `../FLUTTER_POS_PLAN.md`. Status legend: `[ ]` todo · `[~]` in progress · `[x]` done.

## Phase 0 — Consolidation (1–2 weeks)

Goal: one module tree, app builds and sells end-to-end as before.

- [ ]  P0-1 Inventory audit: list every screen/widget/provider duplicated between `lib/pos/` and `lib/features/pos/` (owner: FE)
- [ ]  P0-2 Merge `lib/pos/` into `lib/features/`; delete legacy tree; fix imports
- [ ]  P0-3 Single theme: delete ad-hoc colors, route everything through `pos_theme.dart` + `AppConfig` palette
- [ ]  P0-4 Remove back-office screens: suppliers, purchase orders, valuation, adjustments, transfers; keep read-only stock lookup
- [ ]  P0-5 Introduce `go_router` with route table for all remaining screens
- [ ]  P0-6 Define repository interfaces (`domain/`) over remote services; no behavior change
- [ ]  P0-7 CI check: `flutter analyze` clean + `flutter test` green; block PRs otherwise
- [ ]  P0-8 Update `DEVELOPER.md` layout section after merge

Exit test: cashier golden flow test passes on the consolidated tree.

## Phase 1 — Sale & Charge Parity (2–3 weeks)

Goal: 3-item sale with modifier, discount, split cash+KHQR in <30s.

- [ ]  P1-1 New Material 3 theme: green primary, white surfaces, dark mode toggle
- [ ]  P1-2 Product tiles with `cached_network_image`, price, stock badge; remove emoji placeholders
- [ ]  P1-3 Category pills with active state + horizontal scroll
- [ ]  P1-4 Modifier/quantity bottom sheet (opens when product has modifiers; qty stepper, line note)
- [ ]  P1-5 Line + receipt discounts with permission gate and preset amounts
- [ ]  P1-6 Charge screen: payment-method grid from `/api/payment-methods`
- [ ]  P1-7 Quick-cash buttons (exact, KHR 5,000/10,000/20,000, USD 1/5/10) + change-due screen
- [ ]  P1-8 Split payment rows (multi-method, running remainder)
- [ ]  P1-9 KHQR: show QR, manual confirm step
- [ ]  P1-10 PIN lock screen + fast cashier switch (backend PIN validation, hashed offline cache)
- [ ]  P1-11 Unit tests: discount math, split payment math, change calculation
- [ ]  P1-12 L10n: Khmer + English strings for all new UI

Exit test: timed checkout drill; UI checklist vs Loyverse reference.

## Phase 2 — Tickets, Shift, Receipts, Customers (3 weeks)

Goal: full cashier day executable entirely from the tablet.

- [ ]  P2-1 Open tickets list: name/table/age/amount; resume; void with permission
- [ ]  P2-2 Predefined ticket names from `/api/predefined-tickets`
- [ ]  P2-3 Merge and split tickets
- [ ]  P2-4 Dining options on ticket: dine-in / takeaway / delivery
- [ ]  P2-5 Shift open with float; live expected-cash panel
- [ ]  P2-6 Cash in/out with mandatory reason (`/api/shifts/{id}/cash-events`)
- [ ]  P2-7 Close-shift flow matching backend: precheck (in-progress blocks, held warns), counted cash, variance display
- [ ]  P2-8 Manager-credential force-close dialog + override reason
- [ ]  P2-9 Pending-approval state UI (variance > 10.00) + manager approve/reject
- [ ]  P2-10 Receipts history (terminal/shift filter) + detail view
- [ ]  P2-11 Item-level refund flow; reprint; share PDF
- [ ]  P2-12 Customer search/add; balance + credit limit display
- [ ]  P2-13 Charge-to-credit sale; collect repayment at POS
- [ ]  P2-14 E2E script: open shift → sell → hold/resume → refund → cash out → close with approval
- [ ]  P2-15 Update `USER_MANUAL.md` + training checklist

Exit test: recorded E2E run of the full cashier day.

## Phase 3 — Offline-First (2–3 weeks)

Goal: airplane-mode demo — 10 offline sales sync exactly once.

- [ ]  P3-1 **Backend**: accept `clientSaleId` idempotency key on sale + cash-event endpoints (blocks the rest of this phase)
- [ ]  P3-2 Local catalog cache (products, categories, modifiers, price lists, payment methods, customers) in sqflite/drift
- [ ]  P3-3 Delta sync on login + interval refresh; server-wins for catalog
- [ ]  P3-4 Write-local-first sales queue with UUID `clientSaleId`, FIFO push, retry with backoff
- [ ]  P3-5 Sync-status UI: queue viewer, per-item status, manual retry
- [ ]  P3-6 Offline PIN auth (hashed cache)
- [ ]  P3-7 Offline receipt numbering: terminal prefix + local sequence, reconciled on sync
- [ ]  P3-8 Conflict tests: duplicate push, out-of-order push, app kill mid-sync
- [ ]  P3-9 Shift totals reconciliation test vs backend after sync

Exit test: airplane-mode drill; backend shows exactly 10 sales, totals match.

## Phase 4 — Hardware & Restaurant (2–3 weeks)

Goal: real printer + scanner at the counter.

- [ ]  P4-1 **Week-1 spike**: Khmer text on 58/80mm ESC/POS printers (font vs image-mode fallback) — go/no-go on package choice
- [ ]  P4-2 Printer settings: add/discover (Bluetooth/LAN), test print, per-terminal profiles
- [ ]  P4-3 Receipt template: logo, store info, KHQR footer, dual currency totals
- [ ]  P4-4 Cash drawer kick via printer pulse
- [ ]  P4-5 Kitchen printing routed by product category
- [ ]  P4-6 HID barcode scanner support (keyboard-wedge listener on sale screen)
- [ ]  P4-7 Weight-embedded barcodes (configurable prefix/format)
- [ ]  P4-8 Table map screen (restaurant mode): status colors, tap to open/resume
- [ ]  P4-9 Hardware test matrix doc (printer models × Android versions)

Exit test: print Khmer receipt on real hardware; scan-to-sell with USB scanner.

## Phase 5 — Loyalty, CDS, Polish (3+ weeks)

Goal: loyalty pilot at one store.

- [ ]  P5-1 **Backend spec**: loyalty points module (earn rate, redeem rules, customer barcode) — separate design doc
- [ ]  P5-2 Backend implementation + API
- [ ]  P5-3 Flutter: points on customer select; redeem at charge; loyalty barcode scan
- [ ]  P5-4 Customer display companion mode (second device shows live ticket)
- [ ]  P5-5 Optional: time clock (backend + PIN-linked clock in/out)
- [ ]  P5-6 Optional: owner mini-dashboard (today's sales, shift status)
- [ ]  P5-7 Pilot rollout checklist + feedback loop

## Cross-Cutting (every phase)

- [ ]  CC-1 Unit tests for all money math; widget smoke tests for new screens
- [ ]  CC-2 Khmer + English strings shipped together
- [ ]  CC-3 `USER_MANUAL.md` / training docs updated when cashier flows change
- [ ]  CC-4 No back-office scope creep (PR checklist item)

## Suggested Order & Dependencies

```text
P0 (all) -> P1 -> P2 -> P3 (needs P3-1 backend) -> P4 -> P5 (needs P5-1/2 backend)
P4-1 spike can run in parallel with Phase 2/3.
P3-1 backend spec should be written during Phase 1.
```
