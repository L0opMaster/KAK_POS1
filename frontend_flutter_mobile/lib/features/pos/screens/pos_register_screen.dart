import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../models/product_models.dart';
import '../providers/cart_provider.dart';
import '../providers/category_provider.dart';
import '../providers/product_provider.dart';
import 'barcode_scanner_screen.dart';
import '../widgets/category_tabs.dart';
import '../widgets/product_grid.dart';
import '../widgets/product_modifier_sheet.dart';

/// Mobile equivalent of the product-browsing part of `[OLD/SOURCE]`
/// `frontend-flutter-pos/lib/features/pos/screens/pos_screen.dart` — search
/// bar + category filter + product grid. Does NOT include source's cart
/// sidebar (`CartPanel`, fixed 380px) — there's no room for a permanent
/// side panel on a phone; see DAY_06.md section 10 for the layout
/// adaptation. `CartFab` (hosted on `MobileShellScreen`'s Scaffold, since
/// this screen has none of its own) is the mobile answer instead — a
/// floating action button showing live item count/total, replacing the
/// original `CartSummaryBar` bottom bar.
///
/// MODIFIED Day 7: `onProductTap`/`onProductQuickAdd` now call the real
/// `cartProvider.notifier.addItemFromProduct()` — matching `[OLD/SOURCE]`
/// `ProductGrid`'s own baked-in tap behavior ("Loyverse behaviour: tap
/// always quick-adds, even for products with modifier groups — pick
/// modifiers afterward via the cart line's Modifier button"). Long-press
/// opens `ProductModifierSheet` first, matching source's
/// `pos_screen.dart` `onProductLongPress` handler exactly.
class PosRegisterScreen extends ConsumerStatefulWidget {
  const PosRegisterScreen({super.key});

  @override
  ConsumerState<PosRegisterScreen> createState() => _PosRegisterScreenState();
}

class _PosRegisterScreenState extends ConsumerState<PosRegisterScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _searchDebounce;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(_onSearchChanged);
    Future.microtask(
        () => ref.read(productsProvider.notifier).loadProducts());
  }

  @override
  void dispose() {
    _searchCtl.removeListener(_onSearchChanged);
    _searchDebounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  /// REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` `_PosAppBarState`'s
  /// search debounce (300ms) — identical timing and call target
  /// (`productsProvider.notifier.searchProducts`).
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchCtl.text.trim();
      ref.read(productsProvider.notifier).searchProducts(query);
    });
  }

  void _selectCategory(int? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    ref.read(productsProvider.notifier).filterByCategory(categoryId);
  }

  /// REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` `ProductGrid`'s own
  /// `onTap`/`onQuickAdd` closures — tap always quick-adds, even for
  /// products with modifier groups (pick modifiers afterward via the cart
  /// line's Modifier button, wired in `cart_items_list.dart`).
  void _handleProductTap(Product product) {
    ref.read(cartProvider.notifier).addItemFromProduct(product);
  }

  /// REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` `pos_screen.dart`'s
  /// `onProductLongPress` handler — opens the modifier sheet first, then
  /// adds the configured item.
  Future<void> _handleProductLongPress(Product product) async {
    final result = await showModalBottomSheet<CartItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(PosTheme.radiusLarge)),
      ),
      builder: (_) => ProductModifierSheet(product: product),
    );
    if (result != null) {
      ref.read(cartProvider.notifier).addItem(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final productState = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.asData?.value ?? const <Category>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              PosTheme.spacingMd, PosTheme.spacingSm, PosTheme.spacingMd, 0),
          child: TextField(
            controller: _searchCtl,
            decoration: InputDecoration(
              hintText: l10n.posSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              // Added Day 8 — opens the camera-based barcode scanner. The
              // manual barcode `TextField` from [OLD/SOURCE]'s AppBar
              // isn't reproduced here separately; BarcodeScannerScreen's
              // own manual-entry fallback covers that same need.
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                tooltip: l10n.barcodeScannerScreenTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const BarcodeScannerScreen()),
                ),
              ),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: PosTheme.spacingSm),
        CategoryTabs(
          categories: categories,
          selectedId: _selectedCategoryId,
          onSelected: _selectCategory,
        ),
        Expanded(
          child: _buildBody(productState),
        ),
      ],
    );
  }

  Widget _buildBody(ProductState state) {
    if (state.isLoading && state.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.products.isEmpty) {
      final l10n = context.l10n;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 40, color: PosTheme.textHintOf(context)),
            const SizedBox(height: PosTheme.spacingMd),
            Text(l10n.errorNotFound,
                style: TextStyle(color: PosTheme.textHintOf(context))),
            const SizedBox(height: PosTheme.spacingMd),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.commonRefresh),
              onPressed: () =>
                  ref.read(productsProvider.notifier).loadProducts(),
            ),
          ],
        ),
      );
    }
    if (state.products.isEmpty) {
      final l10n = context.l10n;
      return Center(
        child: Text(l10n.errorNotFound,
            style: TextStyle(color: PosTheme.textHintOf(context))),
      );
    }

    final cart = ref.watch(cartProvider);
    return ProductGrid(
      products: state.products,
      hasMore: state.hasMore,
      isLoadingMore: state.isLoadingMore,
      onLoadMore: () => ref.read(productsProvider.notifier).loadMore(),
      onProductTap: _handleProductTap,
      onProductQuickAdd: _handleProductTap,
      onProductLongPress: _handleProductLongPress,
      cartQtyFor: (product) => cart.items
          .where((i) => i.product.id == product.id)
          .fold(0, (sum, i) => sum + i.qty),
    );
  }
}
