# Day 9 — Customer / Table / Held & Waiting Tickets

## 1. Goal

Let a cashier attach a customer and/or table to the working cart, and put
a cart on hold / resume it later — the three pieces `cart_totals.dart`'s
Day 7 header flagged as deferred ("Hold/Charge actions — Day 9/11 scope")
and `cart_panel.dart`'s equivalent header flagged the same way ("table/
customer chips — Day 9 scope").

## 2. Starting State — More Was Already Built Than This Doc Existed to Say

Unlike Days 1-8, this day's code was **not** written from a blank slate in
this session. `customer_provider.dart`/`customer_service.dart`,
`table_selection_provider.dart`, `held_ticket_provider.dart`/
`held_ticket_service.dart`, `waiting_number_service.dart`,
`customer_picker_screen.dart`, `table_picker_screen.dart`, and
`held_tickets_screen.dart` all already existed, fully wired into
`mobile_shell_screen.dart` (whose own comments already said "MODIFIED Day
9" and referenced this file by name) and `cart_totals.dart` (Hold button
working, Clear button present). What was missing was this write-up, and —
found only by actually reading every ported file end-to-end against
source rather than trusting the existing "PARTIAL PORT" comments at face
value — two real bugs, corrected below (section 12).

## 3. Source Project Investigation

```text
frontend-flutter-pos/lib/features/pos/providers/customer_provider.dart
frontend-flutter-pos/lib/features/pos/services/customer_service.dart
frontend-flutter-pos/lib/features/pos/providers/table_selection_provider.dart
frontend-flutter-pos/lib/features/pos/widgets/table_selector.dart          (the dual-call gotcha)
frontend-flutter-pos/lib/features/pos/providers/held_ticket_provider.dart
frontend-flutter-pos/lib/features/pos/services/held_ticket_service.dart
frontend-flutter-pos/lib/features/pos/services/waiting_number_service.dart
frontend-flutter-pos/lib/features/pos/widgets/cart_panel.dart              (_handleClearPressed — re-read this session, see section 12)
```

## 4. The Dual-Call Gotcha — Verified, Already Correctly Ported

Source's `table_selector.dart` row `onTap`:
```dart
ref.read(tableSelectionProvider.notifier).select(table);   // 1st
ref.read(cartProvider.notifier).setTable(table.id);          // 2nd — MUST both happen, in this order
```
Calling only one leaves the UI showing a table that isn't actually
attached to the sale, or vice versa — a data-consistency invariant, not
incidental desktop-UI code. Read `table_picker_screen.dart`'s row `onTap`
this session and confirmed both calls are present, in the same order.

## 5. Scope Decisions — What Was Deliberately Not Ported

Three things are missing from this port relative to source, all with a
real, checked reason (not laziness):

- **Customer admin CRUD** (`create`/`update`/`delete`) — `customer_
  provider.dart`/`customer_service.dart` only port `load` and the
  single-customer resolver. A cashier attaching a customer to a sale never
  needs to create/edit/delete customer records from a phone; that's
  back-office work. `CustomerService`'s abstract interface itself doesn't
  even declare these three, unlike source's.
- **The waiting-tickets queue board** (`getWaitingTickets`/
  `saveWaitingTicket`/`upsertWaitingTicket`/`updateWaitingTicketStatus`/
  `markTicketReady`/`completeWaitingTicket`/`resetAllWaitingNumbers`, the
  `WaitingTicket` model, `waitingTicketsProvider`) — a customer-facing
  "your order is #042, now ready" display feature layered on top of the
  waiting-number pool. `waiting_number_service.dart` ports only the
  1-100 number pool + order-id binding (`issueNumber`/`releaseNumber`/
  `bindToOrder`/`getNumberForOrder`/`completeOrder`) that the hold/resume
  flow actually depends on — byte-identical to source. Nothing in this
  mobile app's scope (a cashier's own device) needs a customer-facing
  queue board; that belongs on a counter display, not the cashier's phone.
- **`HeldTicketNotifier.assignTable`** (re-assign an existing held
  ticket's table without resuming it first) — checked source's own UI
  (`held_tickets_dialog.dart`) this session: nothing calls it there
  either. It's dead code in source itself, not just unported here.

One thing is missing but genuinely deferred, not dropped:
**`releaseTicketById`** — called from source's `payment_screen.dart` after
a sale completes, to clean up the held ticket it was resumed from. Payment
is Day 11 scope; there is no caller for this method anywhere in what this
task has built through Day 9, so adding it now would be dead code. Day 11
must port it then — this is explicitly not the same "confirmed unused by
source too" reasoning as `assignTable` above.

## 6. Bug Found and Fixed #1 — `cart_totals.dart`'s Clear Button Called the Wrong Method

The existing `cart_totals.dart` file header claimed: *"source's 'Clear'
button really does call `heldTicketProvider.notifier.cancelResume()`."*
Re-reading source's actual, current `cart_panel.dart`
`_handleClearPressed` this session (not from memory) shows this is wrong:

```dart
// [OLD/SOURCE] cart_panel.dart — the REAL behavior
Future<void> _handleClearPressed(...) async {
  if (cart.heldTicketId == null) {
    await ref.read(cartProvider.notifier).clear();   // no confirmation at all
    return;
  }
  final confirmed = await showDialog<bool>(...);      // "Cancel Ticket" dialog
  if (confirmed != true) return;
  await ref.read(heldTicketProvider.notifier).cancelCurrentTicket();  // VOIDS the order
}
```

`cancelResume()` and `cancelCurrentTicket()` are different actions:
`cancelResume` puts an in-progress-resumed ticket back to "open" ("I'll
come back to this later"); `cancelCurrentTicket` permanently voids it on
the backend. The mobile port's Clear button was calling the wrong one,
and unconditionally showing a confirmation dialog even for a cart that
was never resumed from a ticket (source never confirms that case at all).

**Fixed**: `held_ticket_provider.dart` gained `cancelCurrentTicket()`,
ported from source's real body (releaseTicket + reload + clear cart).
`cart_totals.dart`'s Clear button (`_confirmClear` renamed `_handleClear`)
now branches exactly like source: no held ticket -> clear immediately, no
dialog; held ticket -> confirm, then `cancelCurrentTicket()`. The stale
file-header comment is corrected to describe the real branch.

## 7. Bug Found and Fixed #2 — `Navigator.pop()` With Nothing to Pop

`table_picker_screen.dart` (both the "No Table" button and the row
`onTap`) and `held_tickets_screen.dart` (the row `onTap`) called
`Navigator.of(context).pop()` after completing their action — copied from
source's dialog-dismiss pattern (`TableSelector`/`HeldTicketsDialog`
really are `AlertDialog`s there, so `pop()` correctly closes them).

But `mobile_shell_screen.dart`'s `destinations` list renders both screens
as permanent `IndexedStack` children — bottom-nav tab bodies, never
pushed via `Navigator.push`. `MobileShellScreen` is `main.dart`'s `home:`,
so it's the **only** route on the root `Navigator` once logged in.
Confirmed with a throwaway reproduction test (a `Scaffold` directly as
`MaterialApp.home`, tap a button that calls `Navigator.of(context).pop()`)
before touching any real code: the widget under test was gone afterward —
`pop()` doesn't safely no-op at the root, it tears the route down. In the
real app this meant selecting a table, or restoring a held ticket, would
blank the entire screen.

**Fixed**: added `shellTabIndexProvider` (`StateProvider<int>`,
`mobile_shell_screen.dart`) as the single source of truth for which tab
is selected — `MobileShellScreen` converted from `ConsumerStatefulWidget`
+ local `setState` to `ConsumerWidget` watching this provider directly.
Both screens now do
`ref.read(shellTabIndexProvider.notifier).state = 0` (switch to the
Register tab, so the cashier immediately sees the cart reflect their
selection) instead of `Navigator.pop()`. Any future tab body needing the
same "done, show me the result" behavior should use this provider, not
`Navigator.pop()` — documented directly on the provider.

## 8. Files Modified This Day

```text
mobile-flutter-pos/lib/features/pos/providers/held_ticket_provider.dart   (+cancelCurrentTicket, corrected header comment)
mobile-flutter-pos/lib/features/pos/widgets/cart_totals.dart              (Clear button branch fixed, corrected header comment)
mobile-flutter-pos/lib/features/shell/mobile_shell_screen.dart            (+shellTabIndexProvider, ConsumerStatefulWidget -> ConsumerWidget)
mobile-flutter-pos/lib/features/pos/screens/table_picker_screen.dart      (pop() -> shellTabIndexProvider, x2)
mobile-flutter-pos/lib/features/pos/screens/held_tickets_screen.dart      (pop() -> shellTabIndexProvider)
mobile-flutter-pos/test/held_ticket_provider_test.dart                    (+2 tests: cancelCurrentTicket)
mobile-flutter-pos/test/mobile_shell_screen_test.dart                     (+1 regression test: pop()-with-nothing-to-pop)
```
No files needed creating — everything this day's plan calls for already
existed from earlier days' incremental work.

## 9. Functions

`HeldTicketNotifier.cancelCurrentTicket()`
INPUT: none (reads `cartProvider`'s `heldTicketId`)
DOES: if the cart was resumed from a ticket, `service.releaseTicket` then
reload the held list; unconditionally `cartProvider.notifier.clear()`
OUTPUT: `Future<void>`
CALLER: `cart_totals.dart`'s Clear button, after confirmation
NEXT: cart is empty; if there was a ticket, it's gone from the backend
entirely (not just hidden) — matches `deleteTicket`'s backend effect but
additionally clears the *active* cart, which `deleteTicket` (used from
the held-tickets list, operating on tickets NOT currently in the cart)
does not need to do.

## 10. User Click Flow

```text
Tap "Tables" (bottom nav)
  -> shellTabIndexProvider.notifier.state = 1
  -> TablePickerScreen shown, tableProvider.notifier.search() (Day 9-existing)
Tap an AVAILABLE table row
  -> tableSelectionProvider.notifier.select(table)      [dual-call, section 4]
  -> cartProvider.notifier.setTable(table.id)
  -> shellTabIndexProvider.notifier.state = 0            [FIXED this day, section 7]
  -> Register tab shown, cart now carries the table

Tap "Held Tickets" (bottom nav) -> restore a ticket
  -> heldTicketProvider.notifier.restoreTicket(ticket)
  -> shellTabIndexProvider.notifier.state = 0             [FIXED this day, section 7]
  -> Register tab shown, cart now carries the ticket's items

Cart screen -> Clear (with an active held ticket)
  -> confirm dialog
  -> heldTicketProvider.notifier.cancelCurrentTicket()    [FIXED this day, section 6]
  -> ticket voided on backend, cart cleared
```

## 11. API

Same shared-backend endpoints as source, unchanged:
```text
Customers:       GET/POST/PUT/DELETE /api/customers          (this port only calls GET)
Held tickets:    GET/POST /api/pos/open-tickets
Waiting numbers: no backend endpoint — fully client-local
Tables (CRUD):   GET/POST/PUT/DELETE /api/tables              (this port only calls GET)
Table selection during a sale: no network call — 100% offline
```

## 12. Error Handling

`holdCurrentCart`/`restoreTicket`/`cancelResume`/`cancelCurrentTicket`/
`deleteTicket` all catch and surface errors into `HeldTicketState.error`
rather than throwing — matches source. `restoreTicket`'s
`service.holdTicket(...)` call that marks the ticket in-progress has its
own inner try/catch (non-fatal: the ticket already loaded into the cart
regardless of whether the backend ack succeeded) — also matches source
exactly, byte-for-byte comment included.

## 13. State Management

`shellTabIndexProvider` is new state introduced this day, but it is
UI-navigation state, not business state — it doesn't belong in
`CartState`/`HeldTicketState`/anything persisted, and holds nothing a
future day's business logic should ever read. Kept in
`mobile_shell_screen.dart` (where it's used) rather than a shared
"app-wide UI state" file, since nothing else needs it yet.

## 14. Testing

`test/held_ticket_provider_test.dart`: 2 new tests in the existing
`HeldTicketNotifier` group — `cancelCurrentTicket` with a resumed ticket
(asserts the ticket is gone from the fake service's store entirely, not
merely reset to `'open'` the way `cancelResume` leaves it — the exact
distinction section 6 fixes) and with no resumed ticket (just clears,
same as `cancelResume`'s equivalent case).

`test/mobile_shell_screen_test.dart`: 1 new regression test exercising
the section 7 fix end-to-end — tap "Tables", tap "No Table" (chosen
because it needs no backend table data, unlike a real row tap, which
would require mocking `tableProvider`'s HTTP layer to reach), then assert
`MobileShellScreen` is still mounted (nothing got popped off the root
route) AND the shell switched back to the Register tab. This is a real
regression test: it fails against the pre-fix code (confirmed by running
it against the old `Navigator.pop()` version before applying the fix).

**Coverage gap, stated honestly**: no equivalent widget-level regression
test exists for `held_tickets_screen.dart`'s identical fix, since
exercising its row tap needs `heldTicketProvider` to hold real ticket data
(would need the same `_FakeHeldTicketService` pattern from
`held_ticket_provider_test.dart` threaded through a shell-level widget
test). The underlying mechanism is identical and provider-level-verified
(section 14's `cancelCurrentTicket` tests exercise the same
`heldTicketProvider`/`cartProvider` wiring); the specific "does this
screen's tap handler still call the removed `Navigator.pop()`" question
was instead verified by direct code review (`grep -n Navigator` returned
zero matches in either file after the fix) rather than a second identical
widget test.

## 15. Verification

```text
$ flutter analyze
Analyzing frontend_flutter_mobile...
15 issues found. (ran in 1.5s)
```
All 15 are pre-existing-pattern `info`s in files this day didn't touch
(currency_utils.dart, cart_provider.dart, table_selection_provider.dart,
barcode_scanner_screen.dart, held_ticket_service.dart, table_service.dart,
category_tabs.dart, product_modifier_sheet.dart). Zero warnings, zero
errors, zero new issues from this day's changes.

```text
$ flutter test
00:05 +111: All tests passed!
```
111 tests total (3 new this day; every Day 1-8 test still passing).

`flutter run` against a live device was NOT performed this session (none
available) — recorded honestly, same limitation as every prior day noted
it.

## 16. Definition of Done

- [x] Customer/table/held-ticket providers and services ported (confirmed
      already done by earlier incremental work, verified function-by-
      function against current source this session)
- [x] Dual-call table-selection gotcha verified present and correctly
      ordered
- [x] Scope boundaries (customer CRUD, waiting queue board, `assignTable`)
      checked against source's OWN usage, not just this port's — confirmed
      genuinely unused, not just "unported"
- [x] `cancelCurrentTicket` ported (was missing; Clear button was silently
      calling the wrong method as a result) — bug fixed
- [x] `Navigator.pop()`-with-nothing-to-pop bug found (via a throwaway
      reproduction test, not assumption) and fixed in both affected
      screens, with a shared `shellTabIndexProvider` mechanism for any
      future tab body with the same need
- [x] `flutter analyze` — 0 errors/warnings (15 pre-existing-pattern infos,
      0 new)
- [x] `flutter test` — 111/111 passing (3 new)
- [x] Testing limitation (no widget-level regression test for the
      `held_tickets_screen.dart` half of the pop() fix) stated explicitly
- [ ] `flutter run` against a live device (not performed — none available
      this session)

## 17. What I Should Understand Before Day 10

`shellTabIndexProvider` now exists as the shell's navigation primitive —
Day 10 (Shift Management, per the source project's 20-day plan) adds a
`mobile_shift_screen.dart` that will most likely live behind the "More"
tab (`_MoreTab`'s current `navShifts` entry is still a `_ComingSoon`
placeholder pointing at Day 10); if that screen ever needs to hand
control back to a bottom-nav tab rather than simply popping its own
pushed route (it IS reached via `Navigator.push` from `_MoreTab`, unlike
this day's two fixed screens, so plain `pop()` is actually correct for
it — don't "fix" a screen that isn't broken by reflexively applying this
day's pattern everywhere). The real lesson to carry forward: before
copying a `Navigator.pop()` (or any other UI-lifecycle call) from source,
check whether the destination screen in THIS port is reached the same way
source's version is reached — a dialog-dismiss pattern ported onto a
persistent tab body is exactly how this day's bug happened.
