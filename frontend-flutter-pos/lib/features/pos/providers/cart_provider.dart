import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../models/cart_models.dart';
import '../models/product_models.dart';
import '../services/cart_service.dart';
import 'product_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_models.dart';
import '../services/waiting_number_service.dart';

final Provider<WaitingNumberService> waitingNumberServiceProvider =
    Provider<WaitingNumberService>(
  (Ref ref) => WaitingNumberService(),
);

final FutureProvider<List<WaitingTicket>> waitingTicketsProvider =
    FutureProvider<List<WaitingTicket>>(
  (Ref ref) async {
    final WaitingNumberService service =
        ref.watch(waitingNumberServiceProvider);

    return service.getWaitingTickets();
  },
);

/// State for the shopping cart.
class CartState {
  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'discount': discount,
        'discountType': discountType.index,
        'loyalty': loyalty,
        // 'loading': loading,
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
      // loading: json['loading'] as bool? ?? false,
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

  /// Customer queue number, from 1 to 100.
  final int? waitingNumber;

  /// Backend id of the held ticket this cart was resumed from, if any.
  /// Set by [CartNotifier.restoreItems] and used by the Hold button to
  /// update that same ticket in place instead of creating a new one.
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

  /// Cart subtotal in integer minor units (avoids float accumulation).
  int get _subtotalMinor => items.fold<int>(
        0,
        (int sum, CartItem item) =>
            sum + Money.lineTotalMinor(item.unitPrice, item.qty),
      );

  /// Per-item discount amount in minor units.
  int get _itemDiscountsMinor => items.fold<int>(
        0,
        (int sum, CartItem item) =>
            sum + Money.toMinor((item.discountAmount ?? 0) * item.qty),
      );

  /// Cart-level discount in integer minor units, never more than the subtotal.
  int get _discountMinor {
    final int raw = discountType == DiscountType.fixed
        ? Money.toMinor(discount)
        : Money.percentOfMinor(_subtotalMinor, discount);
    return raw.clamp(0, _subtotalMinor);
  }

  /// Subtotal after per-item discounts.
  double get total => Money.toMajor(_subtotalMinor - _itemDiscountsMinor);

  double get discountAmount => Money.toMajor(_discountMinor);

  /// Tax is per-product now (see `Product.taxRate`) — summed per item at
  /// each item's own rate, not one flat rate applied to the whole cart. The
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

/// Notifier responsible for loading/modifying the cart.
///
/// This class mixes two different persistence layers, so read each method's
/// comment carefully:
///   - `restoreCart` / `persistCart` (OFFLINE): a full snapshot of `state`
///     (items, discount, order mode, table, waiting number, ...) is
///     JSON-encoded into SharedPreferences under `_cartPrefsKey`
///     ('cart_state_v2'). This is a UI-level cache purely so the on-screen
///     cart survives an app restart/hot restart — it is independent of
///     whichever CartService is active.
///   - `service.getCartItems` / `saveCartItems` / `clearCart` (SWITCH
///     POINT): `service` is whatever cart_service.dart's
///     `cartServiceProvider` resolved to — ApiCartService (ONLINE) or
///     LocalCartService (OFFLINE), based on `AppConfig.useApiCartService`.
///     This is the source of truth for cart *items* specifically.
///
/// Tax is per-product (`Product.taxRate`), not synced/stored on the cart at
/// all — see `CartState.taxAmount`.
class CartNotifier extends StateNotifier<CartState> {
  static const _cartPrefsKey = 'cart_state_v2';

  // ── OFFLINE ───────────────────────────────────────────────────────────
  // Restores the cart when the application starts.
  /// Loading is true while SharedPreferences is being checked.
  /// Loading always becomes false when the operation finishes,
  /// whether cart data exists, does not exist, or restoration fails.
  /// Used by: the constructor below, so it runs once on app startup.
  Future<void> restoreCart() async {
    state = state.copyWith(loading: true);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final String? jsonString = prefs.getString(_cartPrefsKey);

      // No saved cart.
      if (jsonString == null || jsonString.isEmpty) {
        state = CartState.initial().copyWith(
          loading: true,
        );
        return;
      }

      final Map<String, dynamic> decoded =
          json.decode(jsonString) as Map<String, dynamic>;

      final CartState restored = CartState.fromJson(decoded);

      // Keep loading true until finally executes.
      // Remove an old waiting number when the restored cart is empty.
      state = restored.copyWith(
        loading: true,
        clearWaitingNumber: restored.items.isEmpty,
      );
    } catch (error, stackTrace) {
      debugPrint('Cart restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      state = CartState.initial().copyWith(
        loading: true,
      );
    } finally {
      // This always executes, including after return or error.
      state = state.copyWith(
        loading: false,
      );
    }
  }

  // ── OFFLINE ───────────────────────────────────────────────────────────
  /// Saves cart to shared preferences (key `_cartPrefsKey`). Called after
  /// almost every cart mutation below (addItem, removeItem, increment/
  /// decrement, discounts, order mode, table, tax rate, ...) so the on-screen
  /// cart snapshot in SharedPreferences always matches `state`.
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
  /// the on-disk `persistCart()` snapshot, which is the actual source of
  /// truth `restoreCart()` reads on refresh. Without this separation, any
  /// hiccup talking to `service` (e.g. the ApiCartService network round
  /// trip) would silently stop new items from ever being restored, or
  /// leave stale items frozen in the snapshot forever.
  Future<void> _syncService(Future<void> Function() action, String label) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Cart $label (remote) failed: $e');
    }
  }

  /// Default constructor for CartNotifier.
  CartNotifier(
    this.service,
    this.waitingNumberService,
    this._ref,
  ) : super(CartState.initial().copyWith(loading: true)) {
    restoreCart();
  }

  /// The cart service.
  final CartService service;
  final WaitingNumberService waitingNumberService;
  final Ref _ref;

  // ── SWITCH POINT (via `service`) ──────────────────────────────────────
  /// Loads the cart from the service. `service` was injected by
  /// `cartProvider` below from `cartServiceProvider`
  /// (features/pos/services/cart_service.dart), which is itself the actual
  /// online/offline switch (`AppConfig.useApiCartService`). This method
  /// doesn't know or care which side it's talking to.
  Future<void> loadCart() async {
    try {
      final List<CartItem> list = await service.getCartItems();
      state = state.copyWith(items: list);
    } catch (e) {
      debugPrint('Cart load failed: $e');
      state = state.copyWith(loading: false);
    }
  }

  Future<int> ensureWaitingNumber() async {
    // if (state.items.isEmpty) {
    //   throw StateError(
    //     'Cannot create waiting number for an empty cart.',
    //   );
    // }

    if (state.waitingNumber != null) {
      return state.waitingNumber!;
    }

    final int number = await waitingNumberService.issueNumber();

    state = state.copyWith(waitingNumber: number);

    await persistCart();

    return number;
  }

  /// Loads a full set of items into the cart in one shot, e.g. when
  /// resuming a held ticket. Unlike calling [addItem] in a loop, this does
  /// NOT auto-issue a new waiting number per item — pass the ticket's
  /// original [waitingNumber] (looked up via
  /// `WaitingNumberService.getNumberForOrder`) so the resumed order keeps
  /// showing the same number instead of climbing to a new one. Pass null
  /// only for tickets held before waiting-number binding existed, in which
  /// case the next [ensureWaitingNumber] call will issue a fresh one.
  ///
  /// [heldTicketId], when set, records which backend ticket this cart came
  /// from so the Hold button can update that same ticket in place instead
  /// of creating a new one.
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

  /// Adds a new item to cart from a product. If the product is already in the
  /// cart, it increments the quantity (Loyverse-style direct tap). Never
  /// prompts for modifiers itself — if the product has any, the cashier
  /// picks them afterward via the "Modifier" button on the cart line.
  Future<void> addItemFromProduct(Product product) async {
    // Find existing item by product id (not string id which is ephemeral)
    final existingIdx =
        state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIdx >= 0) {
      // Already in cart — increment quantity
      final existing = state.items[existingIdx];
      await incrementItem(existing.id);
    } else {
      // New item — generate unique id and add
      final newItem = CartItem(
        id: '${DateTime.now().microsecondsSinceEpoch}_${product.id}',
        product: product,
        qty: 1,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await addItem(newItem);
    }
  }

  /// Finds a product by barcode and adds it through the same local-cart path
  /// used when a cashier taps a product tile.
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

      // Use an already-loaded product first for faster scanning. The visible
      // catalog may be filtered, so use normal product search as a fallback.
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

      // This is the same path used by a normal product click. It adds a new
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

  // ── SWITCH POINT (via `service`) + OFFLINE (via `persistCart`) ────────
  /// Adds an item and assigns a waiting number to the cart.
  ///
  /// The waiting number is created only once for the whole cart,
  /// not once for every product. Note the persistence order at the end:
  /// `persistCart()` (the OFFLINE UI-state snapshot `restoreCart()` reads on
  /// refresh) always runs first, and `service.saveCartItems` (the SWITCH
  /// POINT — ONLINE or OFFLINE CartService) is synced afterwards via
  /// `_syncService`, which swallows its own failures. This ordering matters:
  /// if the remote sync ran first and failed, the on-refresh snapshot would
  /// never see the change. The remaining mutators below (removeItem,
  /// incrementItem, decrementItem, setItemQuantity, setItemNote,
  /// setItemDiscount, clear, applyDiscount/clearDiscount, setOrderMode,
  /// setTaxRate, setCustomer, setTable) follow this same pattern: mutate
  /// `state`, persist locally, then best-effort sync `service.*`.
  Future<void> addItem(final CartItem item) async {
    state = state.copyWith(loading: true);

    try {
      int? waitingNumber = state.waitingNumber;

      // Assign a waiting number when the first product is added.
      if (waitingNumber == null) {
        waitingNumber = await waitingNumberService.issueNumber();
      }

      state = state.copyWith(
        items: <CartItem>[
          ...state.items,
          item,
        ],
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

  /// Removes an item from the cart.
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

  /// increment quantity of an existing item (or add if not present)
  Future<void> incrementItem(final String id) async {
    state = state.copyWith(loading: true);
    try {
      final int idx = state.items.indexWhere((final CartItem i) => i.id == id);
      if (idx >= 0) {
        final CartItem item = state.items[idx];
        final CartItem updated = item.copyWith(qty: item.qty + 1);
        final List<CartItem> list = <CartItem>[...state.items];
        list[idx] = updated;
        state = state.copyWith(items: list);
        await persistCart();
        await _syncService(
            () => service.saveCartItems(state.items), 'increment');
      }
    } catch (e) {
      debugPrint('Cart increment failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// decrement quantity, removing item if it reaches zero
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
  Future<void> setItemQuantity(final String id, final int qty) async {
    state = state.copyWith(loading: true);
    try {
      final int idx = state.items.indexWhere((final CartItem i) => i.id == id);
      if (idx < 0) {
        return;
      }
      if (qty <= 0) {
        await removeItem(id);
        return;
      }
      final CartItem item = state.items[idx];
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
  }

  /// Update the modifier selections attached to a cart item (e.g. choosing
  /// a Sugar Level for an Ice Latte already in the cart). Also updates the
  /// quantity/note if they were changed in the same edit sheet.
  Future<void> setItemModifiers(
    final String id, {
    required List<SelectedModifier> selectedModifiers,
    int? qty,
    String? note,
  }) async {
    state = state.copyWith(loading: true);
    try {
      final int idx = state.items.indexWhere((final CartItem i) => i.id == id);
      if (idx < 0) {
        return;
      }
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

  /// Update the note attached to a cart item.
  Future<void> setItemNote(final String id, final String? note) async {
    state = state.copyWith(loading: true);
    try {
      final int idx = state.items.indexWhere((final CartItem i) => i.id == id);
      if (idx < 0) {
        return;
      }
      final CartItem item = state.items[idx];
      final CartItem updated = item.copyWith(note: note);
      final List<CartItem> list = <CartItem>[...state.items];
      list[idx] = updated;
      state = state.copyWith(items: list);
      await persistCart();
      await _syncService(() => service.saveCartItems(state.items), 'note update');
    } catch (e) {
      debugPrint('Cart note update failed: $e');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// Clears the cart.
  Future<void> clear({
    bool releaseWaitingNumber = true,
  }) async {
    final int? waitingNumber = state.waitingNumber;

    state = state.copyWith(loading: true);

    if (releaseWaitingNumber && waitingNumber != null) {
      try {
        await waitingNumberService.releaseNumber(waitingNumber);
      } catch (e) {
        debugPrint('Cart clear (release waiting number) failed: $e');
      }
    }

    // Reset local state and the on-disk snapshot unconditionally, so a
    // failure below (e.g. a network blip clearing the remote cart) can
    // never leave the SharedPreferences snapshot stuck with stale items
    // that `restoreCart()` would bring back on the next refresh.
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

  /// Remove any discount.
  void clearDiscount() {
    state = state.copyWith(discount: 0, discountType: DiscountType.fixed);
    persistCart();
  }

  /// Set the order mode (Dine-in / Takeaway / Delivery).
  void setOrderMode(OrderMode mode) {
    state = state.copyWith(orderMode: mode);
    persistCart();
  }

  /// Apply loyalty deduction.
  void applyLoyalty(final double amount) {
    state = state.copyWith(loyalty: amount);
  }

  /// Remove any loyalty deduction.
  void clearLoyalty() => state = state.copyWith(loyalty: 0);

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

  /// Detaches the table from this cart (e.g. counter-service order, or the
  /// cashier picked "No Table" in the table picker).
  void clearTable() {
    state = state.copyWith(clearTable: true);
    persistCart();
  }

}

// ══ SWITCH POINT (assembly) ═══════════════════════════════════════════
/// Provider for the cart notifier. Reads `cartServiceProvider` (the actual
/// ONLINE/OFFLINE switch, defined in cart_service.dart) and injects the
/// resolved CartService into CartNotifier — this is where the switch
/// point's output gets wired into the rest of the cart UI.
final StateNotifierProvider<CartNotifier, CartState> cartProvider =
    StateNotifierProvider<CartNotifier, CartState>(
        (final StateNotifierProviderRef<CartNotifier, CartState> ref) {
  final CartService service = ref.read(cartServiceProvider);
  final WaitingNumberService waitingNumberService =
      ref.read(waitingNumberServiceProvider);

  return CartNotifier(
    service,
    waitingNumberService,
    ref,
  );
});
