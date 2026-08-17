import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../models/product_models.dart';
import '../services/settings_service.dart';
import 'product_card.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/widgets/
/// product_grid.dart` — ADAPTED, not a byte-for-byte port. Two real
/// differences from source, both explained here and in DAY_06.md section
/// 10:
///
/// 1. **Column count**: source reads `productGridColumns` from
///    `posSettingsProvider` and uses it AS a literal
///    `SliverGridDelegateWithFixedCrossAxisCount.crossAxisCount` — fine for
///    a desktop viewport, but a phone in portrait can't fit anywhere near
///    the typical 4-6 columns an admin configures with a wide screen in
///    mind. CONNECTED (this session): still reads the same setting via the
///    same `posSettingsProvider`, but treats `productGridColumns` as a
///    DENSITY knob rather than a literal count — it scales
///    `SliverGridDelegateWithMaxCrossAxisExtent`'s target card width, so
///    raising the setting still shrinks cards / fits more per row and
///    lowering it still grows cards, on every device, without reintroducing
///    the "5 tiny unusable cards on a phone" problem a literal column count
///    would. `saleScreenLayout` is honored too: `LIST` switches to a real
///    single-column list (wide, short rows); `COMPACT` keeps the responsive
///    grid but with shorter cards; `GRID` (default) is unchanged from
///    before this connection — at the settings screen's own default of 5
///    columns, the resulting extent is exactly today's previous hardcoded
///    160px, so nothing visually changes until an admin actually adjusts
///    the setting.
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

  /// Matches `mobile_pos_settings_screen.dart`'s own default so the grid
  /// looks identical to before this setting was connected until an admin
  /// actually changes it.
  static const int _defaultColumns = 5;

  SliverGridDelegate _gridDelegateFor(String layout, int configuredColumns) {
    if (layout == 'LIST') {
      // NOT source's 3.2 (a very wide, short row) — source's `ProductCard`
      // is laid out as a horizontal `Row` (thumbnail beside details), so an
      // extreme wide/short cell works there. Mobile's `ProductCard` is a
      // vertical `Column` (image on top, then a fixed-height name/price
      // block below, ~90-110px on its own) — forcing that same layout into
      // a ~3.2-ratio cell would leave less height than the card's own
      // non-flexible content needs and overflow. 1.5 keeps LIST a single
      // full-width column (still visually distinct from GRID/COMPACT — one
      // large card per row instead of several small ones) while staying
      // tall enough for the existing vertical card to render safely.
      return const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisSpacing: 8,
        childAspectRatio: 1.5,
      );
    }
    // `productGridColumns` as a density knob, not a literal column count —
    // see this file's header doc comment for why. 800/5 == 160, today's
    // previous hardcoded default, so the setting's own default (5) is a
    // visual no-op. COMPACT shrinks the target card width further (denser
    // grid, more cards per row) rather than changing the aspect ratio —
    // 0.78 is the one ratio already proven not to overflow `ProductCard`'s
    // fixed-height text block, so it's reused as-is instead of introducing
    // a second, untested ratio for a "more compact" card shape.
    final columns = configuredColumns.clamp(1, 12);
    final density = layout == 'COMPACT' ? 1.25 : 1.0;
    final maxExtent = (800 / (columns * density)).clamp(90.0, 220.0);
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: maxExtent,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.78,
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.products.length;
    final totalCount = widget.hasMore ? itemCount + 1 : itemCount;

    // Defensive, never-throwing parsing: a bad/missing/differently-typed
    // value from the backend must fall back to the previous hardcoded
    // layout, never break the grid's render. `as String?`/`as num?` would
    // THROW (not just return null) if the field came back as some other
    // type, taking the whole product grid down with it.
    final posSettings = ref.watch(posSettingsProvider).valueOrNull;
    final rawLayout = posSettings?['saleScreenLayout'];
    final layout = rawLayout is String ? rawLayout : 'GRID';
    final rawColumns = posSettings?['productGridColumns'];
    final configuredColumns = switch (rawColumns) {
      num n => n.toInt(),
      String s => int.tryParse(s) ?? _defaultColumns,
      _ => _defaultColumns,
    };

    return Container(
      color: PosTheme.backgroundPageOf(context),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        cacheExtent: 500,
        addAutomaticKeepAlives: true,
        gridDelegate: _gridDelegateFor(layout, configuredColumns),
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
