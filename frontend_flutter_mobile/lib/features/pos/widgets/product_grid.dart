import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../models/product_models.dart';
import 'product_card.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/widgets/
/// product_grid.dart` — ADAPTED, not a byte-for-byte port. Two real
/// differences from source, both explained here and in DAY_06.md section
/// 10:
///
/// 1. **Column count**: source hardcodes `_fixedColumns = 5` for a desktop
///    viewport. A phone in portrait can't fit 5 usable product cards
///    per row, so this uses `SliverGridDelegateWithMaxCrossAxisExtent`
///    (≈160px max card width) instead of a fixed count — 2 columns on a
///    typical phone width, more on a tablet/landscape, without a
///    per-device special case.
/// 2. **Tap wiring**: source's `ProductGrid` calls
///    `ref.read(cartProvider.notifier).addItemFromProduct(p)` DIRECTLY
///    inside its own `onTap`/`onQuickAdd` — `cartProvider` doesn't exist
///    in `frontend_flutter_mobile` yet (Day 7 scope). This port instead
///    requires the caller to supply `onProductTap`/`onProductQuickAdd`
///    callbacks (bubbled up to `PosRegisterScreen`), and `cartQty` is
///    always 0 for now. Day 7 should either (a) wire the real
///    `cartProvider` calls directly into this widget to match source
///    exactly, restoring parity, or (b) keep the callback shape and wire
///    it from `PosRegisterScreen` instead — either is a reasonable choice
///    for Day 7 to make, but the callback-shape workaround here must not
///    be mistaken for finished cart integration.
class ProductGrid extends ConsumerStatefulWidget {
  final List<Product> products;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final void Function(Product) onProductTap;
  final void Function(Product)? onProductLongPress;
  final void Function(Product) onProductQuickAdd;
  final int Function(Product product)? cartQtyFor;

  const ProductGrid({
    super.key,
    required this.products,
    this.hasMore = false,
    this.isLoadingMore = false,
    required this.onLoadMore,
    required this.onProductTap,
    this.onProductLongPress,
    required this.onProductQuickAdd,
    this.cartQtyFor,
  });

  @override
  ConsumerState<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends ConsumerState<ProductGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Triggers loadMore when scrolled within 200px of the bottom — same
  /// threshold as `[OLD/SOURCE]`.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200 &&
        widget.hasMore &&
        !widget.isLoadingMore) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.products.length;
    final totalCount = widget.hasMore ? itemCount + 1 : itemCount;

    return Container(
      color: PosTheme.backgroundPageOf(context),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        cacheExtent: 500,
        addAutomaticKeepAlives: true,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (index >= itemCount) {
            return const _LoadMoreIndicator();
          }

          final product = widget.products[index];
          return ProductCard(
            key: ValueKey('product_${product.id}_${product.stock}'),
            product: product,
            cartQty: widget.cartQtyFor?.call(product) ?? 0,
            onTap: widget.onProductTap,
            onQuickAdd: widget.onProductQuickAdd,
            onLongPress: widget.onProductLongPress,
          );
        },
      ),
    );
  }
}

/// Compact loading indicator shown at the bottom of the grid when loading
/// more — byte-identical to `[OLD/SOURCE]`.
class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosTheme.backgroundPageOf(context),
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: PosTheme.primaryGreen,
            ),
          ),
        ),
      ),
    );
  }
}
