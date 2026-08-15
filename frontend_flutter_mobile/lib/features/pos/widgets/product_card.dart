import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/product_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/widgets/
/// product_card.dart` — COPY/ADAPT NEARLY EXACTLY. Visuals (image area,
/// low-stock badge, quick-add button, cart-quantity pill, out-of-stock
/// overlay, category color accent stripe, name/price/stock row) are
/// unchanged; only sizing was retuned slightly (name/price font sizes) for
/// the narrower cards a 2-column phone grid produces vs. source's 5-column
/// desktop grid — see DAY_06.md section 10 for the full grid-column
/// rationale. `widget.onTap`'s tap-scale animation and the tap-gated
/// (no-op when out of stock) behavior are identical to source.
class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final void Function(Product)? onTap;
  final void Function(Product)? onLongPress;
  final void Function(Product)? onQuickAdd;
  final int cartQty;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onLongPress,
    this.onQuickAdd,
    this.cartQty = 0,
  });

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard> {
  bool _pressed = false;

  Product get p => widget.product;

  bool get _hasStock => p.stock != 0;
  bool get _hasImage => p.imageUrl != null && p.imageUrl!.isNotEmpty;
  bool get _isLowStock => _hasStock && p.stock <= 5;

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
    final hasStock = _hasStock;
    final isLowStock = _isLowStock;
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
                  ? PosTheme.warningAmber.withValues(alpha: 0.4)
                  : PosTheme.borderColorOf(context),
            ),
            boxShadow:
                _pressed ? [PosTheme.cardShadow.first] : PosTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image area
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
                    if (isLowStock)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _LowStockBadge(stock: p.stock.toInt()),
                      ),
                    if (widget.onQuickAdd != null && hasStock)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child:
                            _QuickAddButton(onTap: () => widget.onQuickAdd!(p)),
                      ),
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
                                color: Colors.black.withValues(alpha: 0.2),
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
                    if (!hasStock)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.5),
                          alignment: Alignment.center,
                          child: const _OutOfStockLabel(),
                        ),
                      ),
                  ],
                ),
              ),
              // Category color accent stripe
              Container(
                height: 3,
                color: _categoryColor(p.categoryId),
              ),
              // Product info
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.localizedName(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: PosTheme.textPrimaryOf(context),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            formatAmount(p.price, watchCurrency(ref)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: PosTheme.errorRed,
                            ),
                          ),
                        ),
                        if (hasStock) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${p.stock.toInt()}',
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
            color: Colors.black.withValues(alpha: 0.15),
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
          padding: EdgeInsets.all(8),
          child: Icon(Icons.add, color: Colors.white, size: 20),
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
