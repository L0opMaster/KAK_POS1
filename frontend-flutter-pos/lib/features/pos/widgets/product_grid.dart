import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../models/product_models.dart';
import '../providers/cart_provider.dart';
import 'product_card.dart';

/// High-performance product grid with item count badges.
class ProductGrid extends ConsumerStatefulWidget {
  final List<Product> products;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final void Function(Product)? onProductTap;
  final void Function(Product)? onProductLongPress;
  final void Function(Product)? onDelete;

  const ProductGrid({
    super.key,
    required this.products,
    this.hasMore = false,
    this.isLoadingMore = false,
    required this.onLoadMore,
    this.onProductTap,
    this.onProductLongPress,
    this.onDelete,
  });

  @override
  ConsumerState<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends ConsumerState<ProductGrid> {
  final ScrollController _scrollController = ScrollController();

  static const int _fixedColumns = 5;

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

  /// Triggers loadMore when scrolled within 200px of the bottom.
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
    // Add one extra item for the loading indicator when paginating
    final totalCount = widget.hasMore ? itemCount + 1 : itemCount;

    return Container(
      color: PosTheme.backgroundPageOf(context),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        // Cache extent so off-screen items aren't rebuilt from scratch
        cacheExtent: 500,
        // Keep grid children alive during scrolling
        addAutomaticKeepAlives: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _fixedColumns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.95,
        ),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          // Last item is the loading indicator
          if (index >= itemCount) {
            return const _LoadMoreIndicator();
          }

          final product = widget.products[index];
          // Look up how many of this product are in the cart
          final cart = ref.watch(cartProvider);
          final cartQty = cart.items
              .where((i) => i.product.id == product.id)
              .fold(0, (int sum, i) => sum + i.qty);
          return ProductCard(
            key: ValueKey('product_${product.id}_${product.stock}'),
            product: product,
            cartQty: cartQty,
            // Tap → quick-add directly to cart (Loyverse behaviour), even
            // for products with modifier groups. To choose a modifier
            // (e.g. Sugar Level on an Ice Latte), tap "Modifier" on the
            // cart line afterward.
            onTap: (p) => ref.read(cartProvider.notifier).addItemFromProduct(p),
            // + icon → same as tap.
            onQuickAdd: (p) =>
                ref.read(cartProvider.notifier).addItemFromProduct(p),
            // Long-press → open modifier sheet for customization before
            // adding, for anyone who prefers to pick options up front.
            onLongPress: widget.onProductLongPress ?? widget.onProductTap,
            onDelete: widget.onDelete,
          );
        },
      ),
    );
  }
}

/// Compact loading indicator shown at the bottom of the grid when loading more.
class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosTheme.backgroundPageOf(context),
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
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
