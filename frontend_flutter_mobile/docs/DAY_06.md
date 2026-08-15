# Day 6 — Products

## 1. Goal

Give the mobile app's Register tab (stubbed as a placeholder on Day 5) a
real product-browsing experience: load the catalog, search, filter by
category, paginate on scroll, and select a product — matching
`[OLD/SOURCE]`'s product-loading business logic and API contract exactly,
in a phone-appropriate grid layout. Cart mutation (what actually happens
when a product is selected) is explicitly Day 7 scope — this day wires
selection UP TO a callback boundary and stops there.

## 2. Source Project Investigation

```text
frontend-flutter-pos/lib/features/pos/models/product_models.dart
frontend-flutter-pos/lib/features/pos/models/modifier_models.dart              (ModifierGroupResponse/ModifierOptionResponse only)
frontend-flutter-pos/lib/features/pos/providers/product_provider.dart
frontend-flutter-pos/lib/features/pos/providers/category_provider.dart
frontend-flutter-pos/lib/features/pos/services/product_service.dart
frontend-flutter-pos/lib/features/pos/services/demo_product_service.dart
frontend-flutter-pos/lib/features/pos/widgets/product_grid.dart
frontend-flutter-pos/lib/features/pos/widgets/product_card.dart
frontend-flutter-pos/lib/features/pos/widgets/category_tabs.dart
frontend-flutter-pos/lib/features/pos/screens/pos_screen.dart                  (_PosAppBarState's search debounce, _CategoryFilterBar, the productArea wiring)
frontend-flutter-pos/lib/core/utils/bilingual.dart                             (resolveBilingual + Product/Category extensions only)
frontend-flutter-pos/lib/core/config/currency_utils.dart
frontend-flutter-pos/lib/core/providers/currency_provider.dart                 (currencyCodeProvider only)
```

Backend, read to confirm the contract:

```text
backend-spring-boot/src/main/java/com/kaknnea/pos/controller/ProductController.java
backend-spring-boot/src/main/java/com/kaknnea/pos/controller/CategoryController.java
```

## 3. Mobile Target

```text
frontend_flutter_mobile/lib/features/pos/models/product_models.dart        (NEW)
frontend_flutter_mobile/lib/features/pos/models/modifier_models.dart       (NEW — partial port)
frontend_flutter_mobile/lib/features/pos/services/product_service.dart     (NEW)
frontend_flutter_mobile/lib/features/pos/providers/product_provider.dart   (NEW)
frontend_flutter_mobile/lib/features/pos/providers/category_provider.dart  (NEW)
frontend_flutter_mobile/lib/features/pos/widgets/category_tabs.dart        (NEW)
frontend_flutter_mobile/lib/features/pos/widgets/product_card.dart         (NEW)
frontend_flutter_mobile/lib/features/pos/widgets/product_grid.dart         (NEW)
frontend_flutter_mobile/lib/features/pos/screens/pos_register_screen.dart  (NEW)
frontend_flutter_mobile/lib/core/utils/bilingual.dart                      (NEW — partial port)
frontend_flutter_mobile/lib/core/config/currency_utils.dart                (NEW)
frontend_flutter_mobile/lib/core/providers/currency_provider.dart          (NEW — partial port)
frontend_flutter_mobile/lib/features/shell/mobile_shell_screen.dart        (MODIFIED — Register tab body)
frontend_flutter_mobile/test/product_provider_test.dart                   (NEW)
frontend_flutter_mobile/test/product_service_test.dart                    (NEW)
frontend_flutter_mobile/test/category_tabs_test.dart                      (NEW)
frontend_flutter_mobile/test/pos_register_screen_test.dart                (NEW)
frontend_flutter_mobile/test/mobile_shell_screen_test.dart                 (MODIFIED — Register tab assertion)
frontend_flutter_mobile/test/test_l10n_helper.dart                        (NEW — shared test scaffolding, ported from frontend-flutter-pos/test/test_l10n_helper.dart)
```

## 4. Architecture Flow

```text
PosRegisterScreen (search field / category tabs / grid scroll)
    ↓
ProductNotifier.loadProducts() / searchProducts() / filterByCategory() / loadMore()
    ↓
ProductService (productServiceProvider -> _FallbackProductService)
    ↓
ApiProductService.getProducts()
    ↓
ApiService.get('/api/products/pos-catalog')  (no query/category)  OR  ApiService.get('/api/products', {q, categoryId, page, size})  (filtered)
    ↓
Spring Boot ProductController.search() / posCatalog()
    ↓
backend ProductService (Java)
    ↓
database
    ↓
Page<ProductDtos.ProductResponse>  OR  List<ProductDtos.ProductResponse>
    ↓
JSON
    ↓
Product.fromJson() (Flutter model)
    ↓
ProductState.products (Riverpod)
    ↓
ProductGrid rebuild -> ProductCard per product
```

On any failure in the API leg (including — critically — the test sandbox's
always-blocked HTTP), `_FallbackProductService` catches it and calls
`DemoProductService` instead, so the same UI code path renders either way.

## 5. Files To Create

**`product_models.dart`** — `Category`, `Product`. Full fidelity port
(nothing trimmed).

**`modifier_models.dart`** — `ModifierOptionResponse`, `ModifierGroupResponse`
+ their three JSON-coercion helpers. PARTIAL PORT (see section 6/7 for what
was dropped and why) — needed only so `Product.fromJson()` can parse the
`modifierGroups` field.

**`product_service.dart`** — `ProductService` (abstract), `ApiProductService`,
`DemoProductService`, `_FallbackProductService`, `productServiceProvider`.

**`product_provider.dart`** — `ProductState`, `ProductNotifier`,
`productsProvider`.

**`category_provider.dart`** — `CategoryNotifier`, `categoriesProvider`.

**`category_tabs.dart`** — `CategoryTabs` (horizontal pill row + "All").

**`product_card.dart`** — `ProductCard` + its private sub-widgets
(`_CategoryPlaceholder`, `_LowStockBadge`, `_QuickAddButton`,
`_OutOfStockLabel`).

**`product_grid.dart`** — `ProductGrid` (infinite-scroll grid) + private
`_LoadMoreIndicator`.

**`pos_register_screen.dart`** — `PosRegisterScreen`: assembles search bar
+ `CategoryTabs` + `ProductGrid`/loading/error/empty states. This is the
one file with no direct `[OLD/SOURCE]` counterpart file (it's the mobile
equivalent of the product-browsing HALF of `pos_screen.dart`, adapted —
see section 10).

**`bilingual.dart`** — `resolveBilingual`, `ProductBilingualName`,
`CategoryBilingualName`. PARTIAL PORT.

**`currency_utils.dart`** — `currencySymbol`, `formatAmount`,
`watchCurrency`, `readCurrency`. Full port.

**`currency_provider.dart`** — `currencyCodeProvider`. PARTIAL PORT.

## 6. Files To Modify

**`frontend_flutter_mobile/lib/features/shell/mobile_shell_screen.dart`**
Existing: Register tab's body was `_ComingSoon(day: 'Day 6/7', feature: 'Products & Cart')`.
Change: now `const PosRegisterScreen()`. Why: this is the actual Day 6
deliverable — without it, every file above would exist but never be
reachable from the app.

**`frontend_flutter_mobile/test/mobile_shell_screen_test.dart`**
Existing: the first test asserted the `_ComingSoon` placeholder text was
visible on the Register tab; the tab-switching test asserted that same
text became absent after switching away.
Change: first test now asserts `find.byType(PosRegisterScreen)` instead;
the tab-switching test now asserts the `NavigationBar.selectedIndex` and
AppBar title instead of a since-removed placeholder string. Why: both are
direct, mechanical consequences of the shell change above — see the
"Problems Found" note in section 12 about why the old "findsNothing"
assertion would otherwise have gone silently vacuous rather than failing
loudly.

## 7. Functions — deliberate scope reductions (full detail)

Every function below is either **REUSE EXISTING FUNCTION** (byte-identical
logic, only file location/imports adapted) or explicitly marked as a
reduction with its rationale. Nothing was silently trimmed.

### `ProductService` (abstract class) — REDUCED

`[OLD/SOURCE]` declares `getPopularProducts`, `getLowStockProducts`,
`createProduct`, `updateProduct`, `deleteProduct` in addition to
`getProducts`/`getCategories`/`findByBarcode`. NONE of the five dropped
methods are called by `ProductNotifier`, `CategoryNotifier`, `ProductGrid`,
or `ProductCard` — they exist for admin/back-office CRUD screens and a
"popular/low-stock" dashboard feature, none of which are in this task's
Day 4-10 scope. Add them back (copying source's existing bodies verbatim)
the day a feature that actually calls them gets built — not speculatively.

### `DemoProductService` — TRIMMED DATA, IDENTICAL LOGIC

8 demo products / 3 categories here vs. source's 15 / 4. The filter/search/
pagination/simulated-latency LOGIC is byte-identical; only the literal
product list is shorter. This is fallback placeholder data (shown only
when the real backend is unreachable), not a business contract, so a
smaller set was judged sufficient to exercise every code path (search
across name/sku/barcode, category filter, pagination) without hand-copying
15 near-identical literals.

### `ProductNotifier.addProduct/updateProduct/deleteProduct` — DROPPED

Admin CRUD, not called by anything a cashier-facing product grid needs.
Same rationale as the `ProductService` reduction above.

### Function: `ProductNotifier.loadProducts({query, categoryId})`

FILE: `frontend_flutter_mobile/lib/features/pos/providers/product_provider.dart`
CLASS: `ProductNotifier`
SIGNATURE: `Future<void> loadProducts({String? query, int? categoryId})`
CALLED BY: `PosRegisterScreen.initState()` (initial load, no filters),
`ProductNotifier.searchProducts()`, `ProductNotifier.filterByCategory()`,
`ProductNotifier.refresh()`.
CALLS: `ProductService.getProducts()`.
INPUT: optional search text, optional category id — `null`/`null` means
"load everything" (routes to the `pos-catalog` endpoint, see section 11).
OUTPUT: none (`Future<void>`) — result lives in `state`.
STATE CHANGES: `state.isLoading = true` immediately, then on completion
either `products`/`hasMore`/`totalCount` (success) or `error` (failure) —
byte-identical to `[OLD/SOURCE]`.
UI EFFECT: `PosRegisterScreen` rebuilds — shows a spinner, then either the
grid, an error state, or an empty state (see section 12).

REUSE EXISTING FUNCTION — byte-identical logic.

### Function: `ProductGrid._onScroll()`

FILE: `frontend_flutter_mobile/lib/features/pos/widgets/product_grid.dart`
CLASS: `_ProductGridState`
SIGNATURE: `void _onScroll()` (private, `ScrollController` listener)
CALLED BY: the grid's `ScrollController` on every scroll frame.
CALLS: `widget.onLoadMore` (→ `ProductNotifier.loadMore()`) when within
200px of the bottom and not already loading.
INPUT: none (reads `_scrollController.position`).
OUTPUT: none.
STATE CHANGES: none directly.
UI EFFECT: triggers the next page load — same 200px threshold as
`[OLD/SOURCE]`.

REUSE EXISTING FUNCTION — byte-identical logic.

### Function: `_PosRegisterScreenState._onSearchChanged()`

FILE: `frontend_flutter_mobile/lib/features/pos/screens/pos_register_screen.dart`
CLASS: `_PosRegisterScreenState`
SIGNATURE: `void _onSearchChanged()` (private, `TextEditingController`
listener)
CALLED BY: `_searchCtl`'s listener, on every keystroke.
CALLS: (after a 300ms debounce) `ProductNotifier.searchProducts()`.
INPUT: the search field's current trimmed text.
OUTPUT: none.
STATE CHANGES: none directly — delegates to `ProductNotifier`.
UI EFFECT: grid re-renders with filtered results once the debounced search
resolves.

REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` `_PosAppBarState`'s
identical 300ms-debounce pattern — same timing, same call target.

### Function: `_PosRegisterScreenState._handleProductSelected(product)`

FILE: `frontend_flutter_mobile/lib/features/pos/screens/pos_register_screen.dart`
CLASS: `_PosRegisterScreenState`
SIGNATURE: `void _handleProductSelected(Product product)`
CALLED BY: `ProductGrid.onProductTap`/`onProductQuickAdd` (both wired to
this same handler for now).
CALLS: `ScaffoldMessenger.of(context).showSnackBar()`.
INPUT: the tapped `Product`.
OUTPUT: none.
STATE CHANGES: none.
UI EFFECT: shows an acknowledgment SnackBar naming the product and stating
cart wiring is Day 7 scope.

NEW FUNCTION. TEMPORARY — see "Problems Found" (section 12) and section 10
for exactly what this replaces and why it can't do more yet.

## 8. User Click Flow

```text
User types "latte" in the search field
↓
TextField.onChanged (via _searchCtl listener) -> _onSearchChanged()
↓
Timer(300ms) debounce
↓
ref.read(productsProvider.notifier).searchProducts('latte')
↓
ProductNotifier.searchProducts() -> loadProducts(query: 'latte')
↓
state = state.copyWith(isLoading: true, currentPage: 0, hasMore: true)
↓
ProductService.getProducts(query: 'latte', categoryId: null, page: 0, size: 48)
↓
_FallbackProductService._tryApi(apiCall, demoCall)
↓
ApiProductService.getProducts() -> ApiService.get('/api/products', {q: 'latte', page: 0, size: 48})
↓ (on failure, e.g. no backend reachable)
DemoProductService.getProducts(query: 'latte', ...) -> filters the demo list client-side
↓
state = state.copyWith(products: [...], isLoading: false, hasMore: ..., totalCount: ...)
↓
PosRegisterScreen rebuilds (ref.watch(productsProvider)) -> ProductGrid shows only matching cards
```

```text
User taps a product card
↓
ProductCard._onTap() -> 120ms press-scale animation -> widget.onTap!(product)
↓
ProductGrid's onTap = widget.onProductTap (bubbled from PosRegisterScreen)
↓
_PosRegisterScreenState._handleProductSelected(product)
↓
ScaffoldMessenger shows "Selected: <name> — cart wiring lands in Day 7"
```
(Compare to `[OLD/SOURCE]`'s equivalent flow, which at this exact point
calls `ref.read(cartProvider.notifier).addItemFromProduct(product)` instead
— see section 12 for exactly what's deferred and why.)

## 9. Data Flow

```text
product image
↓
Product.imageUrl (from backend, or a picsum.photos seed URL in demo data — same URLs [OLD/SOURCE] uses)
↓
Image.network(p.imageUrl!) inside ProductCard
↓
loadingBuilder / errorBuilder fall back to _CategoryPlaceholder (a colored icon tile) if the image is missing/fails to load
```

```text
displayed product name
↓
Product.nameEn / Product.nameKm (from backend JSON)
↓
p.localizedName(lang) — ProductBilingualName extension, resolveBilingual()
↓
ref.watch(appLanguageProvider) supplies `lang`
↓
Text widget in ProductCard
```

```text
displayed price
↓
Product.price (double, from backend JSON)
↓
formatAmount(p.price, watchCurrency(ref))
↓
watchCurrency reads currencyCodeProvider (FutureProvider hitting /api/settings/general, cached in SharedPreferences, defaulting to 'KHR' while loading/on error)
↓
currencySymbol(code) maps the code to a display glyph (e.g. 'USD' -> '$')
↓
Text widget in ProductCard, e.g. "$4.50"
```

## 10. Mobile UI

**Grid columns**: `[OLD/SOURCE]` hardcodes `_fixedColumns = 5` via
`SliverGridDelegateWithFixedCrossAxisCount` for a desktop-width viewport.
This port uses `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160)`
instead — a responsive column count (2 on a typical phone width, more on a
tablet/landscape) rather than a fixed number tuned for one screen size.
Card internals (image, badges, name/price/stock row) are visually
unchanged; only the name/price font sizes were retuned slightly smaller to
fit a narrower card.

**No cart sidebar**: `[OLD/SOURCE]` `pos_screen.dart`'s `body: Row(...)`
puts a fixed 380px `CartPanel` sidebar next to the product area — there is
no room for a permanent 380px side panel on a phone. `PosRegisterScreen`
is product-browsing only; Day 7 needs to decide how the cart is reached on
mobile (most likely a bottom sheet, a separate tab, or a floating summary
bar — NOT a sidebar). This is flagged for Day 7 to decide deliberately,
not pre-empted here.

**`CategoryTabs` over `_CategoryFilterBar`**: `pos_screen.dart` doesn't
actually use the reusable `CategoryTabs` widget — it has its own
`_CategoryFilterBar` with nearly-identical pill rendering PLUS
desktop-only mouse-wheel horizontal-scroll handling
(`Listener(onPointerSignal: _handleMouseWheel, ...)`, `ScrollConfiguration`
allowing mouse/trackpad/stylus drag devices). None of that is meaningful on
a touchscreen. This port uses the standalone `CategoryTabs` widget
directly (already generic and touch-appropriate) rather than reproducing
`_CategoryFilterBar`'s desktop-specific duplicate — same visual result,
less code, no dead mouse-wheel branch. See section 12 for why this
duplication existing in source at all is itself worth flagging.

**Search bar**: kept as a single always-visible `TextField` at the top,
same debounce/hint text as source; source's separate barcode-input
`TextField` next to it is Day 8 (Barcode Scanner) scope, not duplicated
here.

Portrait is the primary target; the grid's `MaxCrossAxisExtent` delegate
already degrades correctly to more columns in landscape/tablet widths
without a separate code path.

## 11. API

METHOD: `GET`
PATH: `/api/products/pos-catalog`
REQUEST: none (optional `storeId` query param, unused by this port)
RESPONSE: `List<ProductResponse>` (flat array, no pagination wrapper)
Flutter caller: `ApiProductService.getProducts()` when `query == null && categoryId == null`
Backend controller: `ProductController.posCatalog()`
Backend service: `productService.posCatalog(storeId)` (Java)

METHOD: `GET`
PATH: `/api/products`
REQUEST: query params `q`, `categoryId`, `page`, `size` (all optional except page/size default to 0/20 server-side; this client always sends page/size explicitly)
RESPONSE: `Page<ProductResponse>` (`{content: [...], ...pagination metadata}`)
Flutter caller: `ApiProductService.getProducts()` when a query or category filter is active
Backend controller: `ProductController.search()`
Backend service: `productService.search(...)` (Java)

METHOD: `GET`
PATH: `/api/categories`
RESPONSE: `List<CategoryResponse>`
Flutter caller: `ApiProductService.getCategories()`
Backend controller: `CategoryController` (root `@GetMapping`)

METHOD: `GET`
PATH: `/api/settings/general`
RESPONSE: (partial) `{currency: "USD", ...}`
Flutter caller: `currencyCodeProvider`
Used for: display-only price formatting, not a Settings feature (see
section 6 of DAY_05.md's Settings scoping note, and section 5 above).

No endpoint, param, or field above was invented — confirmed directly from
`ProductController.java`/`CategoryController.java`.

## 12. Error Handling

- **Loading**: `state.isLoading && state.products.isEmpty` shows a
  centered `CircularProgressIndicator` (initial load); `state.isLoadingMore`
  shows the grid's trailing `_LoadMoreIndicator` (pagination).
- **API error**: `_FallbackProductService` catches ANY exception from the
  API leg and falls back to `DemoProductService` — this means a real user
  on a phone with no signal, or hitting the wrong `AppConfig.baseUrl`, sees
  the demo catalog instead of an error screen. This is `[OLD/SOURCE]`'s own
  deliberate design (byte-identical fallback wiring), not something this
  port invented.
- **Empty state** (search/filter matches nothing): a centered "not found"
  message.
- **Genuine load failure** (only reachable if BOTH the API and the demo
  fallback throw, which the demo service never does in current code): the
  same "not found" message plus a Refresh button — matches `[OLD/SOURCE]`
  `pos_screen.dart`'s equivalent error branch.
- **Network/unauthorized**: identical to Day 4's `ApiService` error mapping
  — a 401 here would trigger `ApiService.onUnauthorized` (wired Day 4) and
  log the user out, same as any other authenticated call.

**Problems Found (real, source-inherited findings — not fixed here, per
the source-of-truth rule):**

1. **`onProductTap` is dead code in `[OLD/SOURCE]` `pos_screen.dart`.**
   `pos_screen.dart` passes both `onProductTap` (opens a
   `ProductModifierSheet`) AND `onProductLongPress` (also opens the sheet)
   to `ProductGrid`. But `ProductGrid` itself never calls
   `widget.onProductTap` for the card's primary tap — it always calls
   `cartProvider.notifier.addItemFromProduct(p)` directly (see source
   `product_grid.dart`'s own `onTap:` closure), and `onLongPress:
   widget.onProductLongPress ?? widget.onProductTap` means the passed-in
   `onProductTap` closure is only ever reached as a fallback for
   long-press, and only if `onProductLongPress` is null — which
   `pos_screen.dart` never lets happen, since it always supplies both. Net
   effect: `pos_screen.dart`'s `onProductTap` closure (~14 lines opening a
   modifier sheet) is unreachable dead code in the current wiring. Not
   reproduced in this port's `ProductGrid` (whose `onProductTap` param IS
   the primary tap handler, by design — see item 2) — flagging this as
   something worth a real cleanup in `frontend-flutter-pos` itself,
   without touching that project here.

2. **Cart wiring is intentionally deferred, not a defect** — distinct from
   finding #1. `[OLD/SOURCE]` `ProductGrid` bakes `cartProvider.notifier
   .addItemFromProduct` directly into its own `onTap`/`onQuickAdd`
   closures. `cartProvider` doesn't exist in `frontend_flutter_mobile` yet
   (Day 7). This port's `ProductGrid` instead REQUIRES the caller to
   supply `onProductTap`/`onProductQuickAdd` callbacks, bubbled up to
   `PosRegisterScreen`, which currently just shows an acknowledgment
   SnackBar. Day 7 must explicitly decide whether to (a) bake the real
   `cartProvider` calls directly into `ProductGrid` to restore exact parity
   with source, or (b) keep the callback shape and wire it from
   `PosRegisterScreen`/wherever the cart lives on mobile. Either is
   reasonable; leaving the SnackBar stand-in in place past Day 7 would not
   be.

3. **`ProductCard`/`ProductGrid`'s `onDelete` parameter is dead in
   `[OLD/SOURCE]` too** — declared on both classes, threaded through, but
   never read inside `ProductCard.build()` (no delete affordance is wired
   to it) and never passed a value by `pos_screen.dart`. Not ported here
   (there was nothing to port — the parameter has no behavior attached to
   it in source).

## 13. State Management

`productsProvider` (`StateNotifierProvider<ProductNotifier, ProductState>`):
watched by `PosRegisterScreen` (drives the loading/error/empty/grid
branch), read (not watched) by its own action methods.
`categoriesProvider` (`StateNotifierProvider<CategoryNotifier, AsyncValue<List<Category>>>`):
watched by `PosRegisterScreen` to build `CategoryTabs`' pill list;
`CategoryNotifier` loads once at creation (constructor calls
`loadCategories()`), same as `[OLD/SOURCE]`.
`currencyCodeProvider` (`FutureProvider<String>`): watched (via
`watchCurrency`) by every `ProductCard` to format its price — each card
independently rebuilds if the currency code changes, though in practice it
resolves once near app startup and rarely changes mid-session.

Local (non-Riverpod) state: `_PosRegisterScreenState._selectedCategoryId`
(int?) and the search `TextEditingController` — correctly local, since no
other widget needs to know which category pill is currently highlighted or
what's currently typed in the search box; only the RESULTING filtered
product list (which lives in `productsProvider`) is shared state.

Invalidation/rebuild: no manual `ref.invalidate()` anywhere in this flow —
every transition is a direct `state = ...` assignment inside
`ProductNotifier`/`CategoryNotifier`, exactly like `[OLD/SOURCE]`.

## 14. Testing

`test/product_provider_test.dart` (NEW) — `ProductNotifier` against a
fully deterministic fake `ProductService` (no network at all): load
success/failure, search, category filter, loadMore no-op behavior (only 3
fixture products vs. a 48-item page size), `findByBarcode`'s exact-match
requirement. Plus one `CategoryNotifier` test.

`test/product_service_test.dart` (NEW) — `DemoProductService` directly:
active-only filtering, category filter, cross-field (name/sku/barcode)
search, pagination, `getCategories`, `findByBarcode`.

`test/category_tabs_test.dart` (NEW) — renders "All" + every category,
reports the right id (or `null` for "All") on tap.

`test/pos_register_screen_test.dart` (NEW) — full-screen integration
against the real `productServiceProvider` (i.e. the actual
API-then-demo-fallback path, not a fake): initial load shows the demo
grid, search filters it, category tab filters it, tapping a product shows
the Day 7 acknowledgment SnackBar.

`test/mobile_shell_screen_test.dart` (MODIFIED, see section 6).

All tests are in `frontend_flutter_mobile/test/`.

## 15. Verification

```text
$ flutter analyze
Analyzing frontend_flutter_mobile...
3 issues found. (ran in 1.3s)
```
All 3 are pre-existing-pattern `info`-level lints (`unnecessary_underscores`
×2 in `currency_utils.dart`, `prefer_spread_collections` ×1 in
`category_tabs.dart`) — zero warnings, zero errors.

```text
$ flutter test
00:03 +50: All tests passed!
```
50 tests total (16 new this day: 7 in `product_provider_test.dart`, 6 in
`product_service_test.dart`, 1 in `category_tabs_test.dart`, 4 in
`pos_register_screen_test.dart` — plus the Day 1-5 tests still passing,
minus the 2 `mobile_shell_screen_test.dart` assertions that were updated
rather than net-new).

`flutter run` against a live backend/device was NOT performed this session
(none available) — recorded honestly.

One real test-authoring pitfall worth recording precisely because it cost
real debugging time: a `flutter_test` widget test that never calls
`SharedPreferences.setMockInitialValues({})` doesn't fail loudly — it
manifests as an unrelated-looking async provider (`productsProvider`,
completely unconnected to `SharedPreferences`) getting permanently stuck
`isLoading: true`, because `appLanguageProvider`'s unmocked platform
channel call stalls the shared widget-tree async chain `CategoryTabs`
happens to sit on. Fixed by adding the mock `setUp()` — every test file in
this suite now has it.

## 16. Definition of Done

- [x] Product/Category models, services, providers ported and traced
      function-by-function
- [x] Real product grid replaces the Day 5 placeholder on the Register tab
- [x] Search (debounced, 300ms) and category filtering both call the real
      `ProductNotifier` methods
- [x] Infinite-scroll pagination (`loadMore`, 200px threshold) ported
- [x] API-first-with-demo-fallback resilience pattern preserved exactly
- [x] Mobile-appropriate grid (responsive columns, no fixed desktop count)
- [x] Product tap wired to a clearly-temporary, clearly-labelled
      acknowledgment — not silently faked as cart integration
- [x] 3 real source-code findings documented (2 dead-code paths in
      `[OLD/SOURCE]`, 1 intentional Day 6->7 boundary) — none silently
      papered over
- [x] `flutter analyze` — 0 errors/warnings (3 pre-existing-pattern infos)
- [x] `flutter test` — 50/50 passing
- [ ] `flutter run` against a live device (not performed — none available
      this session)

## 17. What I Should Understand Before Moving to Day 7

`ProductGrid.onProductTap`/`onProductQuickAdd` are REQUIRED callback
parameters right now, both wired to the same temporary
`_handleProductSelected` SnackBar in `PosRegisterScreen`. Day 7 builds
`cartProvider` and must replace that stand-in with real
`addItemFromProduct`/`addItem` calls — and needs to explicitly decide
whether that logic lives inside `ProductGrid` itself (matching
`[OLD/SOURCE]`'s exact structure, where the grid owns the cart call) or
stays in `PosRegisterScreen` via the callback (the shape this port
currently has). Either is defensible; picking one silently and moving on
without noting the choice would not be. Also carry forward: there is still
no cart UI destination on mobile at all — Day 7's own docs need to state
where a cashier actually SEES the cart on a phone (bottom sheet vs. a
dedicated tab vs. something else), since source's fixed 380px sidebar
isn't an option and this day deliberately left that decision alone.
