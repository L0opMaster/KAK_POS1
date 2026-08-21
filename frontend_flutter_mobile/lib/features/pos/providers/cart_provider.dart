import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../models/cart_models.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';
import '../services/cart_service.dart';
import '../services/waiting_number_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// cart_provider.dart` — PARTIAL PORT. `CartState` is a FULL port. As of
/// Day 9, `CartNotifier` now also has `ensureWaitingNumber`,
/// `restoreItems` (resuming a held ticket), `setCustomer`/`clearCustomer`,
/// `setTable`/`clearTable`, and `addItem`/`clear` now genuinely
/// issue/release waiting numbers (Day 7's deferral note on those two is
/// now resolved). Still NOT ported: `loadCart` (the SWITCH POINT
/// `service.getCartItems()` read) — not called by anything in
/// `[OLD/SOURCE]`'s own `cart_provider.dart` either (grep confirmed zero
/// call sites); kept out entirely rather than porting genuinely-dead code.
/// `applyLoyalty`/`clearLoyalty` are ported despite `loyalty` being
/// otherwise unused — two-line field setters with zero dependencies,
/// needed for `finalTotal`'s formula to be exercisable at all.
///
/// FIXED (this session): `CartState` used to carry a single flat `taxRate`
/// field (default 0.08) applied to the whole cart, and `PaymentScreen` sent
/// that flat rate to the backend as `'taxRate'` in the sale-create payload.
/// Source has since moved tax to be per-product (`Product.taxRate`, added
/// alongside the admin Item Management screen) — the backend now derives
/// tax entirely from each line's own product (`SaleService.computeLineTaxes`)
/// and no longer reads a cart-wide rate at all. Mobile's cart never followed
/// that migration, so it kept charging every product the same flat 8%
/// regardless of its actual configured rate, and kept sending a `taxRate`
/// the backend either ignored or (worse) treated as an override. `taxRate`/
/// `withTaxRate`/`setTaxRate` are removed; `taxAmount` now sums each item's
/// own `product.taxRate` against its cart-discount-prorated taxable amount,
/// and a new `blendedTaxRate` getter (display-only, e.g. the "Tax (X%)"
/// label) mirrors the backend's own blended-rate derivation — both exact
/// ports of source's post-fix `CartState`.
class CartState {
  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'discount': discount,
        'discountType': discountType.index,
        'loyalty': loyalty,
        'orderMode': orderMode.index,
        'customerId': customerId,
        'tableId': tableId,
        'waitingNumber': waitingNumber,
        'heldTicketId': heldTicketId,
      };

  static CartState fromJson(Map<String, dynamic> json) {
    final itemsRaw = (json['items'] as List<dynamic>?)
            ?.map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return CartState(
      items: itemsRaw,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      discountType: DiscountType.values[json['discountType'] ?? 0],
      loyalty: (json['loyalty'] as num?)?.toDouble() ?? 0,
      loading: false,
      orderMode: OrderMode.values[json['orderMode'] ?? 0],
      customerId: json['customerId'] as int?,
      tableId: json['tableId'] as int?,
      waitingNumber: (json['waitingNumber'] as num?)?.toInt(),
      heldTicketId: (json['heldTicketId'] as num?)?.toInt(),
    );
  }

  CartState({
    required this.items,
    this.discount = 0,
    this.discountType = DiscountType.fixed,
    this.loyalty = 0,
    this.loading = false,
    this.orderMode = OrderMode.dineIn,
    this.customerId,
    this.tableId,
    this.waitingNumber,
    this.heldTicketId,
  });

  factory CartState.initial() =>
      CartState(items: <CartItem>[], orderMode: OrderMode.dineIn);

  final List<CartItem> items;
  final double discount;
  final DiscountType discountType;
  final double loyalty;
  final bool loading;
  final OrderMode orderMode;
  final int? customerId;
  final int? tableId;
  final int? waitingNumber;
  final int? heldTicketId;

  CartState copyWith({
    List<CartItem>? items,
    double? discount,
    DiscountType? discountType,
    double? loyalty,
    bool? loading,
    OrderMode? orderMode,
    int? customerId,
    int? tableId,
    int? waitingNumber,
    bool clearWaitingNumber = false,
    bool clearCustomer = false,
    bool clearTable = false,
    int? heldTicketId,
    bool clearHeldTicketId = false,
  }) {
    return CartState(
      items: items ?? this.items,
      discount: discount ?? this.discount,
      discountType: discountType ?? this.discountType,
      loyalty: loyalty ?? this.loyalty,
      loading: loading ?? this.loading,
      orderMode: orderMode ?? this.orderMode,
      customerId: clearCustomer ? null : customerId ?? this.customerId,
      tableId: clearTable ? null : tableId ?? this.tableId,
      waitingNumber:
          clearWaitingNumber ? null : waitingNumber ?? this.waitingNumber,
      heldTicketId:
          clearHeldTicketId ? null : heldTicketId ?? this.heldTicketId,
    );
  }

  int get _subtotalMinor => items.fold<int>(
        0,
        (int sum, CartItem item) =>
            sum + Money.lineTotalMinor(item.unitPrice, item.qty),
      );

  int get _itemDiscountsMinor => items.fold<int>(
        0,
        (int sum, CartItem item) =>
            sum + Money.toMinor((item.discountAmount ?? 0) * item.qty),
      );

  int get _discountMinor {
    final int raw = discountType == DiscountType.fixed
        ? Money.toMinor(discount)
        : Money.percentOfMinor(_subtotalMinor, discount);
    return raw.clamp(0, _subtotalMinor);
  }

  /// Subtotal after per-item discounts.
  double get total => Money.toMajor(_subtotalMinor - _itemDiscountsMinor);

  double get discountAmount => Money.toMajor(_discountMinor);

  /// Tax is per-product (see `Product.taxRate`) — summed per item at each
  /// item's own rate, not one flat rate applied to the whole cart. The
  /// cart-level discount is prorated across items by each item's share of
  /// [total] before taxing, mirroring the backend's `computeLineTaxes`
  /// exactly (see `SaleService.java`) so the on-screen total during
  /// checkout matches what actually gets charged, not a flat blended guess.
  double get taxAmount {
    if (total <= 0) return 0;
    double sum = 0;
    for (final item in items) {
      final netItemTotal =
          item.lineTotal - (item.discountAmount ?? 0) * item.qty;
      final share = netItemTotal / total;
      final itemCartDiscount = discountAmount * share;
      final taxable = netItemTotal - itemCartDiscount;
      sum += taxable * item.product.taxRate;
    }
    return sum;
  }

  /// Blended effective rate across all items, for display only (e.g. the
  /// "Tax (X%)" label) — mirrors the backend's `blendedTaxRate` derivation.
  double get blendedTaxRate {
    final taxable = total - discountAmount;
    if (taxable <= 0) return 0;
    return taxAmount / taxable;
  }

  /// Grand total: subtotal - cart discount + tax - loyalty
  double get finalTotal {
    final int subtotalAfterItemDiscounts = _subtotalMinor - _itemDiscountsMinor;
    final int net =
        (subtotalAfterItemDiscounts - _discountMinor - Money.toMinor(loyalty))
            .clamp(0, subtotalAfterItemDiscounts);
    final double netMajor = Money.toMajor(net);
    return netMajor + taxAmount;
  }
}

/// User-facing result of attempting to add a barcode to the active cart.
/// Added Day 8. COPY/ADAPT NEARLY EXACTLY from `[OLD/SOURCE]`.
class BarcodeAddResult {
  const BarcodeAddResult({
    required this.added,
    required this.message,
    this.product,
  });

  final bool added;
  final String message;
  final Product? product;
}

/// Result of a cart mutation that can be blocked by a stock cap or a
/// defense-in-depth active/sellable check (mirrors [BarcodeAddResult]'s
/// success-flag-plus-detail shape). [message] is only set for the
/// active/sellable cases, reusing the same hardcoded-English convention
/// [CartNotifier.addProductByBarcode] already uses for those — the
/// stock-cap case instead carries the raw [stockCapAvailableQty] so callers
/// can build the localized "Only N available" text via
/// `context.l10n.cartOnlyStockAvailable(...)` (this class has no
/// BuildContext to localize it itself).
class CartMutationResult {
  const CartMutationResult.ok()
      : ok = true,
        message = null,
        stockCapAvailableQty = null;

  const CartMutationResult.blocked(this.message, {this.stockCapAvailableQty})
      : ok = false;

  final bool ok;
  final String? message;
  final int? stockCapAvailableQty;
}

/// Notifier responsible for loading/modifying the cart. See the file
/// header for exactly what's ported vs. deferred to a later day.
class CartNotifier extends StateNotifier<CartState> {
  static const _cartPrefsKey = 'cart_state_v2';

  /// OFFLINE — restores the cart when the application starts.
  Future<void> restoreCart() async {
    state = state.copyWith(loading: true);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_cartPrefsKey);

      if (jsonString == null || jsonString.isEmpty) {
        state = CartState.initial().copyWith(loading: true);
        return;
      }

      final Map<String, dynamic> decoded =
          json.decode(jsonString) as Map<String, dynamic>;
      final CartState restored = CartState.fromJson(decoded);

      state = restored.copyWith(
        loading: true,
        clearWaitingNumber: restored.items.isEmpty,
      );
    } catch (error, stackTrace) {
      debugPrint('Cart restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = CartState.initial().copyWith(loading: true);
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// OFFLINE — saves cart to shared preferences. Called after almost every
  /// cart mutation below so the on-screen cart snapshot always matches
  /// `state`.
  Future<void> persistCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cartPrefsKey, json.encode(state.toJson()));
    } catch (e) {
      debugPrint('Cart persist skipped: $e');
    }
  }

  /// Best-effort sync to the remote/local `service` (the SWITCH POINT).
  /// Failures here are logged only — they must never prevent or roll back
  /// the on-disk `persistCart()` snapshot.
  Future<void> _syncService(
      Future<void> Function() action, String label) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Cart $label (remote) failed: $e');
    }
  }

  CartNotifier(this.service, this.waitingNumberService, this._ref)
      : super(CartState.initial().copyWith(loading: true)) {
    restoreCart();
  }

  final CartService service;

  /// Added Day 9 — issues/releases the 1-100 local waiting-number pool
  /// (`ensureWaitingNumber`/`addItem`/`clear`) and binds it to a held
  /// ticket id (`restoreTicket`, via `held_ticket_provider.dart`).
  final WaitingNumberService waitingNumberService;

  /// Added Day 8 — needed by `addProductByBarcode()` to read the
  /// currently-loaded product list and fall back to a fresh search.
  final Ref _ref;

  /// Returns the cart's current waiting number, issuing a new one if it
  /// doesn't have one yet.
  Future<int> ensureWaitingNumber() async {
    if (state.waitingNumber != null) {
      return state.waitingNumber!;
    }
    final int number = await waitingNumberService.issueNumber();
    state = state.copyWith(waitingNumber: number);
    await persistCart();
    return number;
  }

  /// Loads a full set of items into the cart in one shot, e.g. when
  /// resuming a held ticket. Unlike calling `addItem` in a loop, this does
  /// NOT auto-issue a new waiting number per item — pass the ticket's
  /// original [waitingNumber] so the resumed order keeps showing the same
  /// number instead of climbing to a new one.
  Future<void> restoreItems({
    required List<CartItem> items,
    int? waitingNumber,
    int? heldTicketId,
    int? tableId,
  }) async {
    state = state.copyWith(loading: true);
    try {
      state = CartState.initial().copyWith(
        items: items,
        waitingNumber: waitingNumber,
        heldTicketId: heldTicketId,
        tableId: tableId,
      );
      await persistCart();
      await _syncService(() => service.saveCartItems(items), 'restore');
    } catch (e) {
      debugPrint('Cart restore failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// Set the customer for this cart.
  void setCustomer(int customerId) {
    state = state.copyWith(customerId: customerId);
    persistCart();
  }

  /// Reverts the cart to a walk-in (no customer) sale.
  void clearCustomer() {
    state = state.copyWith(clearCustomer: true);
    persistCart();
  }

  /// Set the table for dine-in orders. Optional — counter-service shops
  /// never call this and the cart just stays table-less.
  void setTable(int tableId) {
    state = state.copyWith(tableId: tableId);
    persistCart();
  }

  /// Detaches the table from this cart.
  void clearTable() {
    state = state.copyWith(clearTable: true);
    persistCart();
  }

  /// Finds a product by barcode and adds it through the same local-cart
  /// path used when a cashier taps a product tile.
  Future<BarcodeAddResult> addProductByBarcode(String barcode) async {
    final String normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      return const BarcodeAddResult(
        added: false,
        message: 'Enter or scan a barcode',
      );
    }

    try {
      Product? product;
      final String comparableBarcode = normalizedBarcode.toLowerCase();

      // Use an already-loaded product first for faster scanning. The
      // visible catalog may be filtered, so use normal product search as a
      // fallback.
      for (final Product candidate in _ref.read(productsProvider).products) {
        if (candidate.barcode.trim().toLowerCase() == comparableBarcode) {
          product = candidate;
          break;
        }
      }

      product ??= await _ref
          .read(productsProvider.notifier)
          .findByBarcode(normalizedBarcode);

      if (product == null) {
        return BarcodeAddResult(
          added: false,
          message: 'No product found for barcode $normalizedBarcode',
        );
      }

      if (!product.active) {
        return BarcodeAddResult(
          added: false,
          message: '${product.nameEn} is inactive',
          product: product,
        );
      }

      if (!product.sellable) {
        return BarcodeAddResult(
          added: false,
          message: '${product.nameEn} is not sellable',
          product: product,
        );
      }

      if (product.outOfStock) {
        return BarcodeAddResult(
          added: false,
          message: '${product.nameEn} is out of stock',
          product: product,
        );
      }

      // This is the same path used by a normal product tap. It adds a new
      // local-cart line or increases the quantity of an existing line.
      await addItemFromProduct(product);

      return BarcodeAddResult(
        added: true,
        message: '${product.nameEn} added to cart',
        product: product,
      );
    } catch (error, stackTrace) {
      debugPrint('Barcode lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return BarcodeAddResult(
        added: false,
        message: 'Could not look up barcode $normalizedBarcode',
      );
    }
  }

  /// Sums cart qty across every line for [productId] — a product can appear
  /// as several lines with different modifier selections — optionally
  /// excluding one line (used by [setItemQuantity] so a line's own current
  /// qty isn't double-counted against itself when computing its new total).
  int _cartQtyForProduct(int productId, {String? excludingLineId}) =>
      state.items
          .where((item) =>
              item.product.id == productId && item.id != excludingLineId)
          .fold(0, (int sum, item) => sum + item.qty);

  /// Returns null if [product] can supply [desiredTotalQty] units across the
  /// whole cart — always true when it doesn't track inventory, matching the
  /// backend's own `outOfStock = trackInventory && availableSaleQty <= 0`
  /// formula — otherwise the number of units that ARE available (floored,
  /// clamped to >= 0 in case the backend snapshot is already oversold), for
  /// the "Only N available" message.
  int? _stockCapIfExceeded(Product product, int desiredTotalQty) {
    if (!product.trackInventory) return null;
    final double available = product.availableSaleQty ?? product.stock;
    if (desiredTotalQty <= available) return null;
    final int floored = available.floor();
    return floored < 0 ? 0 : floored;
  }

  /// Adds a new item to cart from a product. If the product is already in
  /// the cart, increments the quantity (Loyverse-style direct tap). Never
  /// prompts for modifiers itself — if the product has any, the cashier
  /// picks them afterward via the "Modifier" button on the cart line.
  Future<CartMutationResult> addItemFromProduct(Product product) async {
    final existingIdx =
        state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIdx >= 0) {
      final existing = state.items[existingIdx];
      return incrementItem(existing.id);
    }

    // New line — defense-in-depth: the product grid doesn't itself filter
    // inactive/unsellable/out-of-stock products, so mirror the same checks
    // addProductByBarcode already applies before this path existed.
    if (!product.active) {
      return CartMutationResult.blocked('${product.nameEn} is inactive');
    }
    if (!product.sellable) {
      return CartMutationResult.blocked('${product.nameEn} is not sellable');
    }
    final int? cap = _stockCapIfExceeded(product, 1);
    if (cap != null) {
      return CartMutationResult.blocked(
        '${product.nameEn} is out of stock',
        stockCapAvailableQty: cap,
      );
    }

    final newItem = CartItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_${product.id}',
      product: product,
      qty: 1,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await addItem(newItem);
    return const CartMutationResult.ok();
  }

  /// Adds an item and assigns a waiting number to the cart (only once for
  /// the whole cart, not once per product). Day 9: now issues a waiting
  /// number on the first item added, matching `[OLD/SOURCE]` exactly
  /// (Day 7 deferred this).
  Future<void> addItem(final CartItem item) async {
    state = state.copyWith(loading: true);
    try {
      int? waitingNumber = state.waitingNumber;
      if (waitingNumber == null) {
        waitingNumber = await waitingNumberService.issueNumber();
      }
      state = state.copyWith(
        items: <CartItem>[...state.items, item],
        waitingNumber: waitingNumber,
      );
      await persistCart();
      await _syncService(() => service.saveCartItems(state.items), 'add');
    } catch (e) {
      debugPrint('Cart add failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> removeItem(final String id) async {
    state = state.copyWith(loading: true);
    try {
      state = state.copyWith(
          items: state.items.where((element) => element.id != id).toList());
      await persistCart();
      await _syncService(() => service.saveCartItems(state.items), 'remove');
    } catch (e) {
      debugPrint('Cart remove failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<CartMutationResult> incrementItem(final String id) async {
    final int idx = state.items.indexWhere((final CartItem i) => i.id == id);
    if (idx < 0) {
      return const CartMutationResult.ok();
    }

    final CartItem item = state.items[idx];
    final int? cap = _stockCapIfExceeded(
      item.product,
      _cartQtyForProduct(item.product.id) + 1,
    );
    if (cap != null) {
      return CartMutationResult.blocked(
        '${item.product.nameEn} is out of stock',
        stockCapAvailableQty: cap,
      );
    }

    state = state.copyWith(loading: true);
    try {
      final CartItem updated = item.copyWith(qty: item.qty + 1);
      final List<CartItem> list = <CartItem>[...state.items];
      list[idx] = updated;
      state = state.copyWith(items: list);
      await persistCart();
      await _syncService(
          () => service.saveCartItems(state.items), 'increment');
    } catch (e) {
      debugPrint('Cart increment failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
    return const CartMutationResult.ok();
  }

  /// Decrement quantity, removing item if it reaches zero.
  Future<void> decrementItem(final String id) async {
    state = state.copyWith(loading: true);
    try {
      final int idx = state.items.indexWhere((final CartItem i) => i.id == id);
      if (idx >= 0) {
        final CartItem item = state.items[idx];
        if (item.qty <= 1) {
          await removeItem(id);
        } else {
          final CartItem updated = item.copyWith(qty: item.qty - 1);
          final List<CartItem> list = <CartItem>[...state.items];
          list[idx] = updated;
          state = state.copyWith(items: list);
          await persistCart();
          await _syncService(
              () => service.saveCartItems(state.items), 'decrement');
        }
      }
    } catch (e) {
      debugPrint('Cart decrement failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// Set a specific quantity for an existing item (removes item if qty <= 0).
  Future<CartMutationResult> setItemQuantity(
    final String id,
    final int qty,
  ) async {
    state = state.copyWith(loading: true);
    try {
      final int idx = state.items.indexWhere((final CartItem i) => i.id == id);
      if (idx < 0) return const CartMutationResult.ok();
      if (qty <= 0) {
        await removeItem(id);
        return const CartMutationResult.ok();
      }
      final CartItem item = state.items[idx];
      final int? cap = _stockCapIfExceeded(
        item.product,
        _cartQtyForProduct(item.product.id, excludingLineId: id) + qty,
      );
      if (cap != null) {
        return CartMutationResult.blocked(
          '${item.product.nameEn} is out of stock',
          stockCapAvailableQty: cap,
        );
      }
      final CartItem updated = item.copyWith(qty: qty);
      final List<CartItem> list = <CartItem>[...state.items];
      list[idx] = updated;
      state = state.copyWith(items: list);
      await persistCart();
      await _syncService(
          () => service.saveCartItems(state.items), 'quantity update');
    } catch (e) {
      debugPrint('Cart quantity update failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
    return const CartMutationResult.ok();
  }

  /// Update the modifier selections attached to a cart item. Also updates
  /// the quantity/note if they were changed in the same edit sheet.
  Future<void> setItemModifiers(
    final String id, {
    required List<SelectedModifier> selectedModifiers,
    int? qty,
    String? note,
  }) async {
    state = state.copyWith(loading: true);
    try {
      final int idx = state.items.indexWhere((final CartItem i) => i.id == id);
      if (idx < 0) return;
      final CartItem item = state.items[idx];
      final CartItem updated = item.copyWith(
        qty: qty,
        note: note,
        selectedModifiers: selectedModifiers,
      );
      final List<CartItem> list = <CartItem>[...state.items];
      list[idx] = updated;
      state = state.copyWith(items: list);
      await persistCart();
      await _syncService(
          () => service.saveCartItems(state.items), 'modifier update');
    } catch (e) {
      debugPrint('Cart modifier update failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> setItemNote(final String id, final String? note) async {
    state = state.copyWith(loading: true);
    try {
      final int idx = state.items.indexWhere((final CartItem i) => i.id == id);
      if (idx < 0) return;
      final CartItem item = state.items[idx];
      final CartItem updated = item.copyWith(note: note);
      final List<CartItem> list = <CartItem>[...state.items];
      list[idx] = updated;
      state = state.copyWith(items: list);
      await persistCart();
      await _syncService(
          () => service.saveCartItems(state.items), 'note update');
    } catch (e) {
      debugPrint('Cart note update failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// Set per-item discount amount (applied per unit).
  Future<void> setItemDiscount(String id, double amount) async {
    state = state.copyWith(loading: true);
    try {
      final idx = state.items.indexWhere((i) => i.id == id);
      if (idx < 0) return;
      final item = state.items[idx];
      final adjusted = amount.clamp(0.0, item.product.price);
      final updated = item.copyWith(discountAmount: adjusted);
      final list = [...state.items];
      list[idx] = updated;
      state = state.copyWith(items: list);
      await persistCart();
      await _syncService(
          () => service.saveCartItems(state.items), 'item discount');
    } catch (e) {
      debugPrint('Cart item discount failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// Clears the cart. Day 9: [releaseWaitingNumber] now genuinely releases
  /// the waiting number (matching `[OLD/SOURCE]`) — Day 7 deferred this.
  /// `held_ticket_provider.dart`'s `holdCurrentCart`/`cancelResume` both
  /// call this with the default (release) — a ticket being held or
  /// abandoned should free its slot in the 1-100 pool either way.
  Future<void> clear({bool releaseWaitingNumber = true}) async {
    final int? waitingNumber = state.waitingNumber;
    state = state.copyWith(loading: true);

    if (releaseWaitingNumber && waitingNumber != null) {
      try {
        await waitingNumberService.releaseNumber(waitingNumber);
      } catch (e) {
        debugPrint('Cart clear (release waiting number) failed: $e');
      }
    }

    state = CartState.initial();
    await persistCart();
    await _syncService(() => service.clearCart(), 'clear');
    state = state.copyWith(loading: false);
  }

  /// Apply a discount (amount or percent).
  void applyDiscount(final double amount,
      {DiscountType type = DiscountType.fixed}) {
    state = state.copyWith(discount: amount, discountType: type);
    persistCart();
  }

  void clearDiscount() {
    state = state.copyWith(discount: 0, discountType: DiscountType.fixed);
    persistCart();
  }

  void setOrderMode(OrderMode mode) {
    state = state.copyWith(orderMode: mode);
    persistCart();
  }

  void applyLoyalty(final double amount) {
    state = state.copyWith(loyalty: amount);
  }

  void clearLoyalty() => state = state.copyWith(loyalty: 0);
}

/// Added Day 9 — `[OLD/SOURCE]` declares this at the top of its own
/// `cart_provider.dart` alongside `waitingTicketsProvider` (the
/// queue-board feature this port doesn't build — see
/// waiting_number_service.dart's file header).
final Provider<WaitingNumberService> waitingNumberServiceProvider =
    Provider<WaitingNumberService>((Ref ref) => WaitingNumberService());

final StateNotifierProvider<CartNotifier, CartState> cartProvider =
    StateNotifierProvider<CartNotifier, CartState>(
        (final Ref ref) {
  final CartService service = ref.read(cartServiceProvider);
  final WaitingNumberService waitingNumberService =
      ref.read(waitingNumberServiceProvider);
  return CartNotifier(service, waitingNumberService, ref);
});
