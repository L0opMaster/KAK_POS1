import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/product_models.dart';
import '../providers/cart_provider.dart';

/// Loyverse-inspired product card — polished and performant.
///
/// - Tap scale animation for tactile feedback
/// - Category color accent strip at bottom of image
/// - Stock indicator integrated in info section
/// - Out-of-stock / low-stock visual states
/// - Minimal rebuild with const sub-widgets
class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final void Function(Product)? onTap;
  final void Function(Product)? onLongPress;
  final void Function(Product)? onQuickAdd;
  final void Function(Product)? onDelete;
  final int cartQty;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onLongPress,
    this.onQuickAdd,
    this.onDelete,
    this.cartQty = 0,
  });

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _pressed = false;

  Product get p => widget.product;

  /// Stock actually left to add, after subtracting what's already sitting
  /// in this cart for this product. `widget.cartQty` comes from
  /// `product_grid.dart`'s `itemBuilder` (`ref.watch(cartProvider)` under
  /// the hood), so it — and every getter derived from it below — rebuilds
  /// live on every +/-, tap-to-add, or held-ticket restore, with no server
  /// round-trip: the cashier sees Out of Stock/Low Stock and the stock
  /// count update the instant the cart changes, not only after payment
  /// completes and the product list is re-fetched. Prefers
  /// `availableSaleQty` over raw `stock` when present, same as the cap
  /// `CartNotifier` itself enforces (`_stockCapIfExceeded`), so this card
  /// can never show more room than the cart is actually allowed to use.
  double get _remainingStock =>
      ((p.availableSaleQty ?? p.stock) - widget.cartQty)
          .clamp(0, double.infinity);

  /// Whether this product can be tapped/added right now. An untracked
  /// product (the default for a newly created "no stock quantity needed"
  /// item, which leaves `stock` at its default 0) is never blocked here —
  /// only a tracked product whose remaining stock has hit zero is.
  /// Previously this read `p.stock != 0` directly, which ignored
  /// `trackInventory` entirely and showed every untracked product as
  /// permanently Out of Stock.
  bool get _hasStock => !p.trackInventory || _remainingStock > 0;
  bool get _hasImage => p.imageUrl != null && p.imageUrl!.isNotEmpty;

  /// Whether to show the numeric stock count next to the price — only
  /// meaningful for a tracked product; an untracked one has no stock
  /// quantity to show at all (not "0").
  bool get _showStockCount => p.trackInventory;

  /// Low-stock state against each product's own configured
  /// `lowStockThreshold`, recomputed from [_remainingStock] rather than the
  /// server's `p.lowStock` so it also updates live as the cart changes.
  bool get _isLowStock =>
      p.trackInventory &&
      _remainingStock > 0 &&
      _remainingStock <= p.lowStockThreshold;

  void _onTap() {
    if (!_hasStock || widget.onTap == null) return;
    setState(() => _pressed = true);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _pressed = false);
      widget.onTap!.call(p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final remainingStock = _remainingStock;
    final hasStock = _hasStock;
    final isLowStock = _isLowStock;
    final showStockCount = _showStockCount;
    final hasImage = _hasImage;
    final scale = _pressed ? 0.94 : 1.0;
    final lang = ref.watch(appLanguageProvider);

    return GestureDetector(
      onTap: _onTap,
      onLongPress: hasStock && widget.onLongPress != null
          ? () => widget.onLongPress!(p)
          : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: PosTheme.backgroundCardOf(context),
            borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
            border: Border.all(
              color: isLowStock
                  ? PosTheme.warningAmber.withOpacity(0.4)
                  : PosTheme.borderColorOf(context),
            ),
            boxShadow:
                _pressed ? [PosTheme.cardShadow.first] : PosTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Image area ──
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.network(
                        p.imageUrl!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        loadingBuilder: (ctx, child, lp) {
                          if (lp == null) return child;
                          return _CategoryPlaceholder(categoryId: p.categoryId);
                        },
                        errorBuilder: (c, e, s) =>
                            _CategoryPlaceholder(categoryId: p.categoryId),
                      )
                    else
                      _CategoryPlaceholder(categoryId: p.categoryId),

                    // Low stock badge (image overlay)
                    if (isLowStock)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _LowStockBadge(stock: remainingStock.toInt()),
                      ),

                    // Quick add button
                    if (widget.onQuickAdd != null && hasStock)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child:
                            _QuickAddButton(onTap: () => widget.onQuickAdd!(p)),
                      ),

                    // Cart item count badge (green pill top-right)
                    if (widget.cartQty > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: PosTheme.primaryGreen,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${widget.cartQty}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Out of stock overlay
                    if (!hasStock)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          alignment: Alignment.center,
                          child: const _OutOfStockLabel(),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Category color accent stripe ──
              Container(
                height: 3,
                color: _categoryColor(p.categoryId),
              ),

              // ── Product info ──
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      p.localizedName(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: PosTheme.textPrimaryOf(context),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Price + stock row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            formatAmount(p.price, watchCurrency(ref)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: PosTheme.errorRed,
                            ),
                          ),
                        ),
                        if (showStockCount) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${remainingStock.toInt()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isLowStock
                                  ? PosTheme.warningAmber
                                  : PosTheme.textHintOf(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryColor(int catId) {
    switch (catId) {
      case 1:
        return const Color(0xFF42A5F5);
      case 2:
        return const Color(0xFFFFA726);
      case 3:
        return const Color(0xFF66BB6A);
      case 4:
        return const Color(0xFFAB47BC);
      default:
        return PosTheme.dividerColorOf(context);
    }
  }
}

/// ── Sub-widgets ────────────────────────────────────────────────────

class _CategoryPlaceholder extends StatelessWidget {
  final int categoryId;
  const _CategoryPlaceholder({required this.categoryId});

  Color get _bgColor {
    switch (categoryId) {
      case 1:
        return const Color(0xFFE3F2FD);
      case 2:
        return const Color(0xFFFFF3E0);
      case 3:
        return const Color(0xFFE8F5E9);
      case 4:
        return const Color(0xFFF3E5F5);
      default:
        return PosTheme.backgroundPage;
    }
  }

  IconData get _icon {
    switch (categoryId) {
      case 1:
        return Icons.local_cafe;
      case 2:
        return Icons.restaurant;
      case 3:
        return Icons.cookie;
      case 4:
        return Icons.shopping_bag;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      child: Center(
        child: Icon(_icon, color: PosTheme.textHintOf(context), size: 34),
      ),
    );
  }
}

class _LowStockBadge extends StatelessWidget {
  final int stock;
  const _LowStockBadge({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: PosTheme.warningAmber,
        borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '$stock',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosTheme.primaryGreen,
      borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.add, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _OutOfStockLabel extends StatelessWidget {
  const _OutOfStockLabel();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 12, color: PosTheme.errorRed),
            const SizedBox(width: 4),
            Text(
              context.l10n.productCardOutOfStock,
              style: const TextStyle(
                color: PosTheme.errorRed,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
