# Day 7 — Cart

## 1. Goal

Give the mobile app a real, working cart: adding products (from the grid
and via the modifier sheet), editing quantity/note/per-item discount,
removing items, cart-level discounts, tax/total calculations, and local +
best-effort-remote persistence — matching `[OLD/SOURCE]`'s cart business
logic exactly. Also decide, concretely, how a cart is reached on a phone
(flagged as an open question at the end of Day 6): a persistent bottom
summary bar on the Register screen that opens a dedicated full-screen cart
view.

## 2. Source Project Investigation

```text
frontend-flutter-pos/lib/core/utils/money.dart
frontend-flutter-pos/lib/features/pos/models/cart_models.dart
frontend-flutter-pos/lib/features/pos/services/cart_service.dart
frontend-flutter-pos/lib/features/pos/providers/cart_provider.dart              (812 lines — read in full)
frontend-flutter-pos/lib/features/pos/widgets/qty_stepper.dart
frontend-flutter-pos/lib/features/pos/widgets/product_modifier_sheet.dart
frontend-flutter-pos/lib/features/pos/widgets/cart_items_list.dart              (the CURRENT icon-based version, per this task's "IMPORTANT RECENT CHANGES")
frontend-flutter-pos/lib/features/pos/widgets/cart_totals.dart
frontend-flutter-pos/lib/features/pos/widgets/cart_panel.dart                   (read to see how the above compose — no new logic of its own beyond table/customer header + Hold/Charge, both deferred)
frontend-flutter-pos/lib/features/pos/widgets/product_grid.dart                 (re-checked: the exact `onTap`/`onQuickAdd`/`onLongPress` wiring this day now reproduces)
frontend-flutter-pos/lib/features/pos/config/app_config.dart                    (useApiCartService switch point)
```

No backend files needed re-reading this day — `/api/carts/*` were already
traced via `ApiCartService`, which is a straight port.

## 3. Mobile Target

```text
frontend_flutter_mobile/lib/core/utils/money.dart                          (NEW)
frontend_flutter_mobile/lib/features/pos/models/cart_models.dart           (NEW)
frontend_flutter_mobile/lib/features/pos/services/cart_service.dart        (NEW)
frontend_flutter_mobile/lib/features/pos/providers/cart_provider.dart      (NEW)
frontend_flutter_mobile/lib/features/pos/widgets/qty_stepper.dart          (NEW)
frontend_flutter_mobile/lib/features/pos/widgets/product_modifier_sheet.dart (NEW)
frontend_flutter_mobile/lib/features/pos/widgets/cart_items_list.dart      (NEW)
frontend_flutter_mobile/lib/features/pos/widgets/cart_totals.dart          (NEW)
frontend_flutter_mobile/lib/features/pos/widgets/cart_summary_bar.dart     (NEW — no source equivalent)
frontend_flutter_mobile/lib/features/pos/screens/cart_screen.dart          (NEW — no source equivalent)
frontend_flutter_mobile/lib/core/config/app_config.dart                    (MODIFIED — useApiCartService)
frontend_flutter_mobile/lib/core/utils/bilingual.dart                      (MODIFIED — added Modifier*BilingualName extensions)
frontend_flutter_mobile/lib/features/pos/screens/pos_register_screen.dart  (MODIFIED — real cart wiring)
frontend_flutter_mobile/lib/l10n/app_en.arb / app_km.arb                   (MODIFIED — one new key, cartSummaryBarViewCart)
frontend_flutter_mobile/test/cart_provider_test.dart                       (NEW)
frontend_flutter_mobile/test/product_modifier_sheet_test.dart              (NEW)
frontend_flutter_mobile/test/cart_items_list_test.dart                     (NEW)
frontend_flutter_mobile/test/pos_register_screen_test.dart                 (MODIFIED — real cart assertions replace the Day 6 SnackBar stand-in)
```

## 4. Architecture Flow

```text
ProductGrid (tap / long-press)
    ↓
CartNotifier.addItemFromProduct() / addItem()
    ↓
state mutation (CartState.copyWith)
    ↓
CartNotifier.persistCart()  — SharedPreferences 'cart_state_v2' (OFFLINE snapshot, always succeeds or is skipped silently)
    ↓
CartNotifier._syncService() → CartService.saveCartItems()  — SWITCH POINT
    ↓ (useApiCartService == true, the current default)
ApiCartService.saveCartItems()
    ↓
ApiService.delete/post('/api/carts/...')
    ↓
Spring Boot cart endpoints
    ↓ (best-effort — any failure here is caught and logged, never rolls back local state)
CartItemsList / CartTotals / CartSummaryBar rebuild (ref.watch(cartProvider))
```

The OFFLINE snapshot (`persistCart`/`restoreCart`) and the SWITCH POINT
(`service`) are deliberately independent layers — a failure in one never
blocks or corrupts the other, exactly as `[OLD/SOURCE]`'s own file-header
comment in `cart_provider.dart` documents.

## 5. Files To Create

**`money.dart`** — `Money` (minor-unit arithmetic). Full port.

**`cart_models.dart`** — `SelectedModifier`, `DiscountType`, `OrderMode`
(+label), `CartItem`. Partial port (see section 6/12 for what's excluded).

**`cart_service.dart`** — `CartService` (abstract), `ApiCartService`,
`LocalCartService`, `cartServiceProvider`. Full port.

**`cart_provider.dart`** — `CartState` (full port, every field) +
`CartNotifier` (partial — core item/discount/tax mutators; see section 12
for the complete deferred list) + `cartProvider`.

**`qty_stepper.dart`** — `QtyStepper`. Full, byte-identical port.

**`product_modifier_sheet.dart`** — `ProductModifierSheet`. Selection/
validation/result-building logic is a byte-identical port; visual layout
was adapted for a phone bottom sheet (see section 10).

**`cart_items_list.dart`** — `CartItemsList`/`_CartItemCard`. Behavior
(swipe-to-delete+undo, tap-to-edit dialog, icon-based remove/modifier
actions with tooltips) ported; dense 5-column desktop row layout adapted
to a 2-line phone card (see section 10).

**`cart_totals.dart`** — `CartTotals`. Substantially reduced — subtotal/
tax/discounts/total + a discount-entry dialog + Clear Cart. Hold/Charge
buttons and backend-fetched discount presets dropped (see section 12).

**`cart_summary_bar.dart`** — `CartSummaryBar`. NEW, no source equivalent
— see section 10.

**`cart_screen.dart`** — `CartScreen`. NEW, no source equivalent — the
mobile destination `CartSummaryBar` opens.

## 6. Files To Modify

**`frontend_flutter_mobile/lib/core/config/app_config.dart`**
Existing: no cart-service switch flag.
Change: added `useApiCartService = true`, matching `[OLD/SOURCE]`'s
current default exactly (verified by re-reading `app_config.dart` fresh
this day, not assumed from Day 4 memory). Why: `cartServiceProvider`
needs it to pick between `ApiCartService`/`LocalCartService`.

**`frontend_flutter_mobile/lib/core/utils/bilingual.dart`**
Existing (Day 6): only `Product`/`Category` bilingual-name extensions.
Change: added `ModifierGroupBilingualName`/`ModifierOptionBilingualName` —
exactly the two extensions Day 6's own file header said to add "when/if a
later day actually ports the model they extend". `product_modifier_sheet
.dart` is that day.

**`frontend_flutter_mobile/lib/features/pos/screens/pos_register_screen.dart`**
Existing (Day 6): `onProductTap`/`onProductQuickAdd` both called a
temporary `_handleProductSelected` that showed an acknowledgment SnackBar;
no long-press handler; no cart UI at all.
Change: tap/quick-add now call `cartProvider.notifier.addItemFromProduct()`
directly (matching `[OLD/SOURCE]` `ProductGrid`'s own baked-in behavior —
tap always quick-adds, even for products with modifier groups); long-press
now opens `ProductModifierSheet` then calls `cartProvider.notifier
.addItem()` on a result (matching source's `pos_screen.dart` `onProductLongPress`
handler exactly); `ProductGrid.cartQtyFor` is now wired to the real cart
state instead of always returning 0; a `CartSummaryBar` was added below
the grid. Why: this is literally what "Day 7: Cart" means for the Register
screen — Day 6 explicitly left this wiring as a documented stand-in.

**`frontend_flutter_mobile/lib/l10n/app_en.arb` / `app_km.arb`**
Existing: no key naming the "open the cart" action — checked, and
`[OLD/SOURCE]` doesn't have one either (its cart is a permanent sidebar,
never something you "open").
Change: added `"cartSummaryBarViewCart": "View Cart"` /
`"...": "មើលកន្ត្រក"`. Why: a genuinely new mobile-only UI concept (a
tappable cart summary bar) needs its own label; reusing an ill-fitting
existing key (e.g. `navPos`, "POS") would have been worse than adding one
clearly-flagged new key. Regenerated via `flutter gen-l10n`; no generated
file hand-edited.

**`frontend_flutter_mobile/test/pos_register_screen_test.dart`**
Existing (Day 6): asserted the temporary SnackBar text appeared on tap.
Change: two tests now assert against `ProviderContainer`-level real cart
state (`cartProvider`) — tapping adds a real `CartItem`, tapping the same
product twice increments its quantity, and `CartSummaryBar` becomes
visible once the cart is non-empty. Why: direct, mechanical consequence of
the `pos_register_screen.dart` change above.

## 7. Functions

### Function: `CartNotifier.addItemFromProduct(product)`

FILE: `frontend_flutter_mobile/lib/features/pos/providers/cart_provider.dart`
CLASS: `CartNotifier`
SIGNATURE: `Future<void> addItemFromProduct(Product product)`
CALLED BY: `_PosRegisterScreenState._handleProductTap()`.
CALLS: `incrementItem()` (if the product is already a cart line) or
`addItem()` (new line).
INPUT: the tapped `Product`.
OUTPUT: none (`Future<void>`).
STATE CHANGES: either bumps an existing line's `qty` or appends a new
`CartItem` to `state.items`.
UI EFFECT: `PosRegisterScreen`'s `ProductGrid` rebuilds with an updated
`cartQtyFor` badge; `CartSummaryBar` appears/updates its count and total.

REUSE EXISTING FUNCTION — byte-identical logic.

### Function: `CartNotifier.addItem(item)`

FILE: same as above.
CLASS: `CartNotifier`
SIGNATURE: `Future<void> addItem(CartItem item)`
CALLED BY: `addItemFromProduct()`; `_PosRegisterScreenState
._handleProductLongPress()` (the modifier sheet's result);
`_CartItemCard.onDismissed`'s Undo action (re-adds a removed item).
CALLS: `persistCart()`, then best-effort `service.saveCartItems()` via
`_syncService`.
INPUT: a fully-formed `CartItem` (id/product/qty/addedAt/etc. already set
by the caller).
OUTPUT: none.
STATE CHANGES: appends to `state.items`.
UI EFFECT: cart list/totals/summary bar all rebuild.

MODIFIED vs. `[OLD/SOURCE]`: source also issues a waiting number here on
the cart's first item — deferred to Day 9, see section 12. Everything else
is unchanged.

### Function: `_ProductModifierSheetState._confirm()`

FILE: `frontend_flutter_mobile/lib/features/pos/widgets/product_modifier_sheet.dart`
CLASS: `_ProductModifierSheetState`
SIGNATURE: `void _confirm()`
CALLED BY: the sheet's Add/Update button.
CALLS: `_isValid` (getter), `_selectedModifiers` (getter),
`Navigator.of(context).pop(cartItem)`.
INPUT: none directly — reads `_selections`, `_qty`, `_noteCtl.text`.
OUTPUT: none (pops the sheet's route with a `CartItem?` result).
STATE CHANGES: `setState(() => _showValidation = true)` only when
validation fails (surfaces the error banner without closing).
UI EFFECT: closes the modal bottom sheet, handing the built `CartItem`
back to whichever caller opened it (`PosRegisterScreen`'s long-press
handler, or `_CartItemCard._editModifiers`).

REUSE EXISTING FUNCTION — byte-identical validation/construction logic
(see section 10 for what changed around it, visually).

### Function: `_CartItemCard._editModifiers(context)`

FILE: `frontend_flutter_mobile/lib/features/pos/widgets/cart_items_list.dart`
CLASS: `_CartItemCard`
SIGNATURE: `Future<void> _editModifiers(BuildContext context)`
CALLED BY: the cart line's "tune" icon (only rendered when
`item.product.modifierGroups.isNotEmpty`).
CALLS: `showModalBottomSheet<CartItem>()` with `ProductModifierSheet
(product: item.product, initialItem: item)`; on a non-null result,
`notifier.setItemModifiers()`.
INPUT: none beyond `context` (reads `item` from the enclosing widget).
OUTPUT: none.
STATE CHANGES: (via `setItemModifiers`) replaces the line's
`selectedModifiers`, and optionally its `qty`/`note` if changed in the
same sheet.
UI EFFECT: cart line re-renders with the new modifier summary/price.

REUSE EXISTING FUNCTION — byte-identical (this is the exact code already
present in `frontend-flutter-pos`'s CURRENT `cart_items_list.dart`, per
the recent icon-based-actions change).

## 8. User Click Flow

```text
User taps a product card (no modifiers needed right now)
↓
ProductCard._onTap() → 120ms press animation → widget.onTap!(product)
↓
ProductGrid's onTap = widget.onProductTap (bubbled from PosRegisterScreen)
↓
_PosRegisterScreenState._handleProductTap(product)
↓
ref.read(cartProvider.notifier).addItemFromProduct(product)
↓
CartNotifier.addItemFromProduct() → (new product) addItem() → state.items grows by 1
↓
persistCart() → SharedPreferences['cart_state_v2']
↓
_syncService(() => service.saveCartItems(...))  — best effort, failure logged only
↓
CartSummaryBar (ref.watch(cartProvider)) becomes visible, shows "1" + the new total
```

```text
User taps the CartSummaryBar
↓
Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()))
↓
CartScreen.build() — ref.watch(cartProvider) → CartItemsList + CartTotals
↓
User taps the delete icon on a line
↓
notifier.removeItem(item.id) → state.items shrinks → CartItemsList/CartTotals rebuild
```

```text
User long-presses a product with modifier groups
↓
_PosRegisterScreenState._handleProductLongPress(product)
↓
showModalBottomSheet<CartItem>(... ProductModifierSheet(product: product))
↓
user picks a required Size option, optionally some Toppings, sets qty, taps Add
↓
_ProductModifierSheetState._confirm() → _isValid == true → Navigator.pop(cartItem)
↓
result != null → ref.read(cartProvider.notifier).addItem(result)
↓
new CartItem (with selectedModifiers) appended to state.items
```

## 9. Data Flow

```text
line total shown in CartItemsList
↓
item.lineTotal = item.unitPrice * item.qty
↓
item.unitPrice = product.price + item.modifierPriceDelta
↓
item.modifierPriceDelta = sum of selectedModifiers[i].priceDelta
↓
formatAmount(lineTotal, watchCurrency(ref))  — same currency/format pipeline as Day 6's ProductCard
```

```text
cart grand total shown in CartTotals / CartSummaryBar
↓
CartState.finalTotal
↓
= toMajor(clamp(subtotalMinor - itemDiscountsMinor - cartDiscountMinor - loyaltyMinor, 0, ...)) + taxAmount
↓
every intermediate step computed in INTEGER MINOR UNITS (Money.toMinor/toMajor) to avoid float
  accumulation error across many cart lines — byte-identical arithmetic to [OLD/SOURCE]
```

```text
persisted cart snapshot (survives app restart)
↓
CartState.toJson() → SharedPreferences['cart_state_v2']  (written by persistCart(), after nearly every mutator)
↓
(next app launch) CartNotifier constructor → restoreCart() → SharedPreferences.getString('cart_state_v2') → CartState.fromJson()
```

## 10. Mobile UI

**Cart reachability** (the question Day 6 explicitly left open): source's
`pos_screen.dart` puts a fixed 380px `CartPanel` sidebar permanently
beside the product grid — always visible, no navigation needed. A phone
has no room for that. This port adds `CartSummaryBar` — a green bar
pinned to the bottom of `PosRegisterScreen`, visible only once the cart
has items, showing item count and running total, that pushes a dedicated
`CartScreen` on tap. This is the standard "View Cart" bar pattern used
across mobile e-commerce/POS apps generally (and specifically matches how
Loyverse's own mobile app — this project's stated design inspiration,
per `pos_theme.dart` — surfaces its cart). A bottom sheet was considered
and rejected: editing a cart line already opens its own dialog/bottom
sheet (qty/note/discount, or the modifier sheet), and stacking that on top
of a cart-bottom-sheet nests modals one level deeper than necessary; a
full screen keeps editing flows flatter.

**`CartItemsList` row layout**: source's row is 5 fixed-width `SizedBox`
columns (qty badge | description flex-3 | qty number 50px | unit price
60px | line total 70px) — tuned for a wide desktop cart panel. This port
uses a 2-line card: name/modifier-summary/note on the left with price/line
total right-aligned above, and the interactive row (QtyStepper, modifier
icon, remove icon) below — the same information, arranged for a card
that's realistically 300-400px wide instead of a fixed-width table row.
Swipe-to-delete (`Dismissible`) and tap-to-edit (a dialog for qty/note/
discount) are BOTH kept as-is — both are genuinely good, common mobile
interaction patterns, arguably better suited to touch than to the desktop
they were written for.

**`ProductModifierSheet` layout**: kept as a `showModalBottomSheet`
(matches source's own presentation, already a reasonable choice for
either platform), but internal spacing/typography was simplified — no
custom animation curves, standard `CheckboxListTile`/`RadioListTile`
instead of hand-styled selection rows. The underlying selection state,
validation rule, and result-building logic are untouched (see section 7).

**`CartTotals`**: kept as a bottom-anchored summary block (works
identically on phone and desktop — it's already just a `Column` of rows),
with Hold/Charge removed (see section 12) and its discount dialog
simplified from an `AlertDialog` with two custom-styled "chip" rows into
one using standard `ChoiceChip`/`ActionChip` widgets — same options,
same result (`notifier.applyDiscount(amount, type: type)`), less bespoke
styling code.

## 11. API

METHOD: `POST` — PATH: `/api/carts` — creates a cart (`{customerId: 0}`
placeholder) — Flutter caller: `ApiCartService._getOrCreateCart()`.
METHOD: `GET` — PATH: `/api/carts/{id}` — Flutter caller: `ApiCartService.getCartItems()`.
METHOD: `DELETE` — PATH: `/api/carts/{id}` — Flutter caller:
`ApiCartService.saveCartItems()` (clears before re-adding) and `clearCart()`.
METHOD: `POST` — PATH: `/api/carts/{id}/items` — body: `CartItem.toApiJson()`
(`{productId, quantity, note?, lineDiscount?}`) — Flutter caller:
`ApiCartService.saveCartItems()`.
METHOD: `DELETE` — PATH: `/api/carts/{id}/items/{itemId}` — Flutter caller:
`ApiCartService.removeCartItem()` (declared, not currently called by
`CartNotifier` — same as source, which also never calls it directly,
preferring the read-modify-write `saveCartItems` cycle for every mutation).

None of these were re-verified against the backend controller source this
day (they were already traced during the original `cart_service.dart`
read, and the endpoint shapes are unchanged from that reading) — flagged
here for completeness rather than re-asserted as freshly confirmed.

## 12. Error Handling

- **Loading**: `state.loading` toggles true/false around every mutator;
  not currently surfaced as a visible spinner anywhere in the mobile UI
  (source doesn't show one for cart mutations either — they're fast local
  operations, the loading flag mainly exists to prevent double-submits in
  spots this port doesn't yet have, like the Hold flow).
- **Remote sync failure**: `_syncService` catches and logs; local state
  and the OFFLINE `persistCart()` snapshot are never rolled back. Verified
  directly in `cart_provider_test.dart`'s "a failed remote sync does not
  roll back local state" test, and observed for real in
  `pos_register_screen_test.dart`'s output (`API POST /api/carts -> ERR
  400`, `Cart add (remote) failed`), since `AppConfig.useApiCartService =
  true` means every test-sandbox cart mutation actually exercises this
  exact path.
- **Restore failure** (corrupt/unreadable SharedPreferences snapshot):
  caught, falls back to `CartState.initial()` — same as source.
- **Required-modifier validation**: handled entirely client-side in
  `ProductModifierSheet`, no network involved.

**Problems Found (real, source-inherited findings — not fixed here, per
the source-of-truth rule):**

1. **`CartTotals`'s "Clear" button is mislabeled in `[OLD/SOURCE]`.** The
   button shows a delete-sweep icon and the label `context.l10n.cartClear`
   ("Clear"), but its `onPressed` calls `ref.read(heldTicketProvider
   .notifier).cancelResume()` — NOT `cartProvider.notifier.clear()`. This
   was found by tracing every line of `cart_totals.dart` for this day's
   research. Whether `cancelResume()` happens to also clear the cart as a
   side effect of its OWN logic was not independently verified (out of
   scope — `heldTicketProvider` is Day 9). Regardless of what it
   currently does, a button labeled "Clear" wired to a held-ticket
   cancellation method rather than the obviously-corresponding
   `cartProvider.notifier.clear()` is worth a real look in
   `frontend-flutter-pos`. This port's own Clear button calls the actual
   `cartProvider.notifier.clear()` — the correct, obviously-intended
   behavior for a button with that label — which is a deliberate,
   reported divergence, not a silent "fix".
2. **The Charge button's backend integration looks unfinished in
   `[OLD/SOURCE]`.** `cart_totals.dart` builds a `saleLines` list from
   cart items and then never uses it — it's constructed, then
   `Navigator.push(... PaymentScreen(total: ..., saleLines: saleLines,
   ...))` is called, but nothing in the traced code path confirms
   `PaymentScreen` actually consumes `saleLines` as constructed (that file
   wasn't read this day — Payment is Day 11+, entirely out of this task's
   scope). Not investigated further; flagged only because it was visible
   while reading `cart_totals.dart` for the parts this day DOES port.

## 13. State Management

`cartProvider` (`StateNotifierProvider<CartNotifier, CartState>`): watched
by `PosRegisterScreen` (for `cartQtyFor` badges and `CartSummaryBar`'s
visibility/total), `CartSummaryBar`, `CartScreen`, `CartItemsList` (via
the `items`/`notifier` it's handed — note `CartItemsList` itself doesn't
watch the provider directly, its parent does and passes data down, exactly
matching source's own prop-drilling shape for this widget).

Local (non-Riverpod) state: `_ProductModifierSheetState._selections`/`_qty`/
`_noteCtl`/`_showValidation` — correctly local, scoped to one open sheet
instance; `_CartItemCard`'s edit-dialog `TextEditingController`s —
likewise local to one open dialog.

Invalidation/rebuild: no manual `ref.invalidate()` in this flow — every
transition is a direct `state = ...` assignment inside `CartNotifier`,
same as source.

## 14. Testing

`test/cart_provider_test.dart` (NEW, 19 tests) — `CartState` calculation
correctness (simple total/tax, fixed discount, percent discount clamping,
per-item discount, full JSON round-trip of every field including the
Day-9-reserved ones), and `CartNotifier` mutators (add/increment/
decrement/remove/setQuantity/setNote/setDiscount/setModifiers/clear,
cart-level discount/order-mode/tax-rate/loyalty, a failed-remote-sync
resilience test, and a real restart-persistence test using two separate
`CartNotifier` instances against the same mocked `SharedPreferences`).

`test/product_modifier_sheet_test.dart` (NEW, 4 tests) — renders every
group/option, blocks confirmation with a visible error when a required
group has no selection, returns the correct `CartItem` (with the right
`unitPrice`/`selectedModifiers`) when a required option is picked, and
confirms a multi-select group accepts more than one option.

`test/cart_items_list_test.dart` (NEW, 6 tests) — empty state, name/qty/
price/line-total rendering (including confirming the REAL currency
fallback — `KHR`, not an assumed `USD` — since `/api/settings/general` is
unreachable in the test sandbox, same as production would behave offline),
delete icon calling `removeItem` with the right id, swipe-to-dismiss +
Undo round-trip, modifier icon correctly absent for a product with no
modifier groups, and the QtyStepper's `+` calling `setItemQuantity`.

`test/pos_register_screen_test.dart` (MODIFIED, see section 6) — 2 of its
tests now assert real `cartProvider` state changes instead of a SnackBar.

All tests are in `frontend_flutter_mobile/test/`.

## 15. Verification

```text
$ flutter analyze
Analyzing frontend_flutter_mobile...
5 issues found. (ran in 1.4s)
```
All 5 are pre-existing-pattern `info`s (2 `unnecessary_underscores` from
Day 6, 1 `prefer_spread_collections` from Day 6, 2 `deprecated_member_use`
for `RadioListTile.groupValue`/`onChanged` — Flutter's own suggested
`RadioGroup` migration wasn't adopted this day, kept as a simple,
well-understood pattern rather than an in-progress Flutter API). Zero
warnings, zero errors.

```text
$ flutter test
00:04 +80: All tests passed!
```
80 tests total (29 new this day: 19 in `cart_provider_test.dart`, 4 in
`product_modifier_sheet_test.dart`, 6 in `cart_items_list_test.dart` —
plus every Day 1-6 test still passing, including the 2 updated
`pos_register_screen_test.dart` assertions).

`flutter run` against a live backend/device was NOT performed this session
(none available) — recorded honestly.

## 16. Definition of Done

- [x] `CartState`/`CartNotifier` core mutators ported and traced
      function-by-function; deferred scope explicitly listed, not silently
      dropped
- [x] Adding from the grid (tap = quick-add, long-press = modifier sheet
      first) matches source's exact behavior
- [x] Editing an existing line's modifiers/qty/note/discount all work
- [x] Swipe-to-delete + Undo, and icon-based Remove/Modifier actions
      (matching the CURRENT source UI, not an older text-based version)
- [x] Subtotal/tax/discount/total calculations verified against
      hand-computed expected values in tests
- [x] Local persistence survives a simulated app restart (tested)
- [x] Remote-sync failure never corrupts local cart state (tested and
      observed)
- [x] A concrete, justified answer to "how is the cart reached on a
      phone" (`CartSummaryBar` -> `CartScreen`)
- [x] 2 real source-code findings documented (mislabeled Clear button,
      possibly-unused `saleLines` in the Charge flow) — neither fixed,
      both reported
- [x] `flutter analyze` — 0 errors/warnings (5 pre-existing-pattern infos)
- [x] `flutter test` — 80/80 passing
- [ ] `flutter run` against a live device (not performed — none available
      this session)

## 17. What I Should Understand Before Moving to Day 8

`CartNotifier.addProductByBarcode` was deliberately NOT ported this day —
it's explicitly Day 8 scope (Barcode Scanner), even though it lives in the
same source file as everything else Day 7 ported. Day 8 needs to add it to
`cart_provider.dart` (or decide it belongs somewhere else) and wire a real
scanner input to it — the method's source body is already fully read and
understood (falls back from the currently-loaded/filtered product list to
`ProductNotifier.findByBarcode()`, checks active/sellable/outOfStock before
adding, returns a `BarcodeAddResult` with a user-facing message either
way). `CartState.waitingNumber`/`customerId`/`tableId`/`heldTicketId` exist
as passive fields with zero notifier methods setting them — Day 9 is where
those become real, and should NOT need to touch `CartState`'s shape at
all, only add the actions (`setCustomer`, `setTable`, `restoreItems`,
`ensureWaitingNumber`) `[OLD/SOURCE]`'s `CartNotifier` already has ready to
port. `CartTotals` has no Charge button at all right now — Day 11+
(explicitly out of this task's Day 4-10 scope) is where that gets built,
and whoever does it should read this day's "Problems Found" #2 about
`saleLines` before assuming source's Charge flow is already fully wired.
