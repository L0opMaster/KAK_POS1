// POS screen — Loyverse-inspired clean layout
import 'package:flutter/foundation.dart' hide Category;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../models/product_models.dart';
import '../models/cart_models.dart';
import '../widgets/product_grid.dart';
import '../widgets/product_modifier_sheet.dart';
import '../widgets/cart_panel.dart';
import './_pos_drawer.dart';
import '../widgets/phone_scanner_receiver_button.dart';
import '../widgets/customer_display_status_button.dart';
import '../providers/customer_display_provider.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/providers/company_provider.dart';

/// Main POS screen with Loyverse-inspired design:
/// - Clean white header with store branding, search, notifications
/// - Horizontal category pills below header
/// - Product grid (main area, scrollable)
/// - Fixed cart sidebar (380px) on the left with totals and Charge button
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productsProvider.notifier).loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prodState = ref.watch(productsProvider);
    final notifier = ref.read(productsProvider.notifier);
    final l10n = context.l10n;

    final String storeCurrency = watchCurrency(ref);
    ref.listen<CartState>(cartProvider, (previous, next) {
      ref.read(customerDisplayProvider.notifier).broadcastCartState(
            next,
            currencySymbol: currencySymbol(storeCurrency),
          );
    });

    Widget productArea;

    if (prodState.isLoading) {
      productArea = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: PosTheme.primaryGreen),
            const SizedBox(height: 16),
            Text(
              l10n.commonLoading,
              style: TextStyle(
                color: PosTheme.textSecondaryOf(context),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    } else if (prodState.error != null) {
      productArea = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PosTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: PosTheme.errorRed, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.errorNetwork,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: PosTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.errorSomethingWentWrong,
              style: TextStyle(
                  fontSize: 13, color: PosTheme.textSecondaryOf(context)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.commonRetry),
                  onPressed: () => notifier.loadProducts(),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings, size: 18),
                  label: Text(l10n.navSettings),
                  onPressed: () => Navigator.of(context).pushNamed('/settings'),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (prodState.products.isEmpty) {
      productArea = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 56, color: PosTheme.textHintOf(context)),
            const SizedBox(height: 16),
            Text(
              l10n.posEmptyCart,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: PosTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.errorNotFound,
              style:
                  TextStyle(fontSize: 13, color: PosTheme.textHintOf(context)),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.commonRefresh),
              onPressed: () => notifier.loadProducts(),
            ),
          ],
        ),
      );
    } else {
      productArea = ProductGrid(
        products: prodState.products,
        hasMore: prodState.hasMore,
        isLoadingMore: prodState.isLoadingMore,
        onLoadMore: () => notifier.loadMore(),
        // Tap is handled directly by ProductGrid → addItemFromProduct
        // onProductTap: used as modifier sheet trigger via onQuickAdd
        onProductTap: (prod) async {
          final result = await showModalBottomSheet<CartItem>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(PosTheme.radiusLarge)),
            ),
            builder: (_) => ProductModifierSheet(product: prod),
          );
          if (result != null) {
            ref.read(cartProvider.notifier).addItem(result);
          }
        },
        // Long-press opens modifier sheet too (for mobile users)
        onProductLongPress: (prod) async {
          final result = await showModalBottomSheet<CartItem>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(PosTheme.radiusLarge)),
            ),
            builder: (_) => ProductModifierSheet(product: prod),
          );
          if (result != null) {
            ref.read(cartProvider.notifier).addItem(result);
          }
        },
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        // The only text fields on this screen (search/barcode) live in the
        // app bar, which is always pinned above the keyboard — so there's
        // nothing here that the keyboard would ever cover. Without this,
        // Flutter shrinks the whole body (including the fixed-width cart
        // sidebar) to avoid the keyboard, which squeezes the cart panel
        // enough to overflow its content.
        resizeToAvoidBottomInset: false,
        appBar: _PosAppBar(),
        drawer: PosDrawer(),
        body: Row(
          children: [
            // ── Product area (left / main) ──
            Expanded(
              child: Column(
                children: [
                  const _CategoryFilterBar(),
                  Expanded(child: productArea),
                ],
              ),
            ),
            // ── Cart sidebar (fixed 380px, right side — Loyverse standard) ──
            Container(
              width: 380,
              decoration: BoxDecoration(
                color: PosTheme.backgroundCardOf(context),
                border: Border(
                  left: BorderSide(color: PosTheme.dividerColorOf(context)),
                ),
              ),
              child: const CartPanel(),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// App Bar — Loyverse-inspired clean top bar
// ═══════════════════════════════════════════════════════════════════
class _PosAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  @override
  ConsumerState<_PosAppBar> createState() => _PosAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(64);
}

class _PosAppBarState extends ConsumerState<_PosAppBar> {
  final TextEditingController _searchCtl = TextEditingController();
  final TextEditingController _barcodeCtl = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode(debugLabel: 'barcode-input');
  Timer? _searchDebounce;
  bool _barcodeLookupInProgress = false;

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(_onSearchChanged);

    // Deliberately NOT auto-focused on open: the barcode field used to grab
    // focus (and show an active cursor) the instant POS opened, before the
    // cashier had touched anything. A physical USB/Bluetooth/2.4GHz scanner
    // still works — it just needs the field armed first, either by tapping
    // the field directly or the scanner icon inside it (_focusScannerInput,
    // below), which is also what _submitBarcode re-arms after every scan.
  }

  @override
  void dispose() {
    _searchCtl.removeListener(_onSearchChanged);
    _searchDebounce?.cancel();
    _searchCtl.dispose();
    _barcodeCtl.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final String query = _searchCtl.text.trim();
      ref.read(productsProvider.notifier).searchProducts(query);
    });
  }

  Future<void> _submitBarcode() async {
    if (_barcodeLookupInProgress) {
      return;
    }

    final String barcode = _barcodeCtl.text.trim();
    if (barcode.isEmpty) {
      _showBarcodeMessage(context.l10n.posBarcodeHint, isError: true);
      _barcodeFocusNode.requestFocus();
      return;
    }

    setState(() {
      _barcodeLookupInProgress = true;
    });

    final BarcodeAddResult result =
        await ref.read(cartProvider.notifier).addProductByBarcode(barcode);

    if (!mounted) {
      return;
    }

    setState(() {
      _barcodeLookupInProgress = false;
    });

    if (result.added) {
      _barcodeCtl.clear();
    } else {
      // Keep an unsuccessful manually typed value easy to replace.
      _barcodeCtl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _barcodeCtl.text.length,
      );
    }

    _barcodeFocusNode.requestFocus();
    _showBarcodeMessage(result.message, isError: !result.added);
  }

  void _focusScannerInput() {
    _barcodeFocusNode.requestFocus();
    _showBarcodeMessage(context.l10n.posScannerReady);
  }

  void _showBarcodeMessage(String message, {bool isError = false}) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? PosTheme.errorRed : PosTheme.primaryGreen,
          duration: Duration(milliseconds: isError ? 1800 : 900),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // This bar is always brand green (see PosTheme.lightTheme/darkTheme
    // appBarTheme) regardless of light/dark mode, so every foreground
    // element here is a fixed white/near-white — not the theme-aware
    // `...Of(context)` colors, which would go dark-on-dark against it.
    final l10n = context.l10n;
    // Live business name from Settings → Company Profile, reactive via
    // companyProfileProvider — falls back to the generic app name while
    // loading/offline/unset so the bar is never blank. See
    // core/providers/company_provider.dart's doc comment for why this
    // updates immediately after a Company Profile save with no reload.
    final companyName =
        watchCompanyName(ref, fallback: '${l10n.appName} ${l10n.navPos}');
    return AppBar(
      elevation: 0,
      toolbarHeight: 64,
      title: SizedBox(
        height: 64,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
              ),
              child: Icon(
                Icons.point_of_sale,
                color: PosTheme.primaryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 2,
              child: Text(
                companyName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Flexible(
              flex: 3,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: TextField(
                  controller: _searchCtl,
                  decoration: InputDecoration(
                    hintText: l10n.posSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(PosTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 3,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: TextField(
                  key: const Key('barcode_input'),
                  controller: _barcodeCtl,
                  focusNode: _barcodeFocusNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitBarcode(),
                  decoration: InputDecoration(
                    hintText: l10n.posBarcodeHint,
                    prefixIcon: const Icon(Icons.qr_code_scanner, size: 20),
                    suffixIcon: _barcodeLookupInProgress
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            key: const Key('scanner_connect'),
                            tooltip: l10n.posConnectScanner,
                            icon: const Icon(Icons.usb, size: 20),
                            onPressed: _focusScannerInput,
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(PosTheme.radiusMedium),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none,
            color: Colors.white,
          ),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.posNotificationsComingSoon),
              duration: const Duration(seconds: 1),
            ),
          ),
        ),
        // Phone scanner icon
        const PhoneScannerReceiverButton(),
        // Customer display pairing icon
        const CustomerDisplayStatusButton(),
        PopupMenuButton<AppLanguage>(
          key: const Key('language_switcher'),
          tooltip: l10n.languageLabel,
          icon: const Icon(Icons.language, color: Colors.white),
          initialValue: ref.watch(appLanguageProvider),
          onSelected: (language) =>
              ref.read(appLanguageProvider.notifier).setLanguage(language),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: AppLanguage.en,
              child: Text(l10n.languageEnglish),
            ),
            PopupMenuItem(
              value: AppLanguage.km,
              child: Text(l10n.languageKhmer),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
          ),
          tooltip: l10n.navSettings,
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            radius: 16,
            // Initial of the live business name — was a hardcoded 'K',
            // which never reflected the actual Company Profile name.
            child: Text(
              companyName.trim().isEmpty
                  ? '?'
                  : companyName.trim()[0].toUpperCase(),
              style: TextStyle(
                color: PosTheme.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// // ═══════════════════════════════════════════════════════════════════
// // Category Filter Bar — Horizontal scrollable pills (Loyverse style)
// // ═══════════════════════════════════════════════════════════════════
// class _CategoryFilterBar extends ConsumerStatefulWidget {
//   const _CategoryFilterBar({super.key});

//   @override
//   ConsumerState<_CategoryFilterBar> createState() => _CategoryFilterBarState();
// }

// class _CategoryFilterBarState extends ConsumerState<_CategoryFilterBar> {
//   int? _selectedCategory;

//   void _applyCategory(int? id) {
//     final categoryId = (id == null || id <= 0) ? null : id;
//     ref.read(productsProvider.notifier).filterByCategory(categoryId);
//     setState(() => _selectedCategory = categoryId);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final l10n = context.l10n;
//     final language = ref.watch(appLanguageProvider);
//     final catState = ref.watch(categoriesProvider);
//     final productsState = ref.watch(productsProvider);
//     final products = productsState.products;
//     final apiCats = catState.asData?.value ?? [];

//     final List<Category> baseCats;
//     if (apiCats.isNotEmpty) {
//       baseCats = [];
//       for (final c in apiCats) {
//         baseCats.add(
//           c is Category
//               ? c
//               : Category(
//                   id: (c as dynamic).id as int,
//                   nameEn: (c as dynamic).nameEn ?? 'Cat ${(c as dynamic).id}',
//                   nameKm:
//                       (c as dynamic).nameKm ?? 'កាតេកូរី ${(c as dynamic).id}',
//                   active: true,
//                 ),
//         );
//       }
//     } else {
//       baseCats = <Category>{
//         for (var p in products)
//           Category(
//             id: p.categoryId,
//             nameEn: 'Cat ${p.categoryId}',
//             nameKm: 'កាតេកូរី ${p.categoryId}',
//             active: true,
//           )
//       }.toList();
//     }

//     final usedCats = [
//       Category(
//           id: -1, nameEn: l10n.commonAll, nameKm: l10n.commonAll, active: true),
//       ...baseCats,
//     ];

//     final selectedId = _selectedCategory;

//     return Container(
//       height: 56,
//       decoration: BoxDecoration(
//         color: PosTheme.backgroundCardOf(context),
//         border:
//             Border(bottom: BorderSide(color: PosTheme.dividerColorOf(context))),
//       ),
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         // shrinkWrap: true,
//         physics: AlwaysScrollableScrollPhysics(),
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//         itemCount: usedCats.length,
//         itemBuilder: (context, index) {
//           final cat = usedCats[index];
//           final isSelected =
//               (cat.id <= 0 && selectedId == null) || cat.id == selectedId;
//           return Padding(
//             padding: const EdgeInsets.only(right: 8),
//             child: GestureDetector(
//               onTap: () => _applyCategory(cat.id <= 0 ? null : cat.id),
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: isSelected
//                       ? PosTheme.primaryGreen
//                       : PosTheme.backgroundPageOf(context),
//                   borderRadius: BorderRadius.circular(PosTheme.radiusPill),
//                   border: Border.all(
//                     color: isSelected
//                         ? PosTheme.primaryGreen
//                         : PosTheme.borderColorOf(context),
//                     width: 1,
//                   ),
//                 ),
//                 child: Center(
//                   child: Text(
//                     cat.localizedName(language),
//                     style: TextStyle(
//                       color: isSelected
//                           ? Colors.white
//                           : PosTheme.textSecondaryOf(context),
//                       fontWeight:
//                           isSelected ? FontWeight.w600 : FontWeight.w400,
//                       fontSize: 13,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// ═══════════════════════════════════════════════════════════════════
// Category Filter Bar — Horizontal scrollable pills
// ═══════════════════════════════════════════════════════════════════

class _CategoryFilterBar extends ConsumerStatefulWidget {
  const _CategoryFilterBar({super.key});

  @override
  ConsumerState<_CategoryFilterBar> createState() => _CategoryFilterBarState();
}

class _CategoryFilterBarState extends ConsumerState<_CategoryFilterBar> {
  int? _selectedCategory;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyCategory(int? id) {
    final int? categoryId = (id == null || id <= 0) ? null : id;

    ref.read(productsProvider.notifier).filterByCategory(categoryId);

    setState(() {
      _selectedCategory = categoryId;
    });
  }

  void _handleMouseWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    if (!_scrollController.hasClients) {
      return;
    }

    final double currentOffset = _scrollController.offset;

    // Mouse wheel normally gives vertical delta.
    // We use that value to move the horizontal category list.
    final double newOffset = currentOffset + event.scrollDelta.dy;

    final double minOffset = _scrollController.position.minScrollExtent;

    final double maxOffset = _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      newOffset.clamp(minOffset, maxOffset),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);

    final catState = ref.watch(categoriesProvider);
    final productsState = ref.watch(productsProvider);

    final products = productsState.products;
    final apiCats = catState.asData?.value ?? [];

    final List<Category> baseCats;

    if (apiCats.isNotEmpty) {
      baseCats = [];

      for (final category in apiCats) {
        if (category is Category) {
          baseCats.add(category);
        } else {
          final dynamic dynamicCategory = category;

          baseCats.add(
            Category(
              id: dynamicCategory.id as int,
              nameEn: dynamicCategory.nameEn ?? 'Cat ${dynamicCategory.id}',
              nameKm:
                  dynamicCategory.nameKm ?? 'កាតេកូរី ${dynamicCategory.id}',
              active: true,
            ),
          );
        }
      }
    } else {
      // Create categories from products when category API data
      // is unavailable.
      final Map<int, Category> uniqueCategories = {};

      for (final product in products) {
        uniqueCategories[product.categoryId] = Category(
          id: product.categoryId,
          nameEn: 'Cat ${product.categoryId}',
          nameKm: 'កាតេកូរី ${product.categoryId}',
          active: true,
        );
      }

      baseCats = uniqueCategories.values.toList();
    }

    final List<Category> usedCats = [
      Category(
        id: -1,
        nameEn: l10n.commonAll,
        nameKm: l10n.commonAll,
        active: true,
      ),
      ...baseCats,
    ];

    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: PosTheme.backgroundCardOf(context),
        border: Border(
          bottom: BorderSide(
            color: PosTheme.dividerColorOf(context),
          ),
        ),
      ),
      child: Listener(
        onPointerSignal: _handleMouseWheel,
        child: ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: false,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              itemCount: usedCats.length,
              itemBuilder: (context, index) {
                final Category category = usedCats[index];

                final bool isAllCategory = category.id <= 0;

                final bool isSelected =
                    (isAllCategory && _selectedCategory == null) ||
                        category.id == _selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        PosTheme.radiusPill,
                      ),
                      onTap: () {
                        _applyCategory(
                          isAllCategory ? null : category.id,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? PosTheme.primaryGreen
                              : PosTheme.backgroundPageOf(
                                  context,
                                ),
                          borderRadius: BorderRadius.circular(
                            PosTheme.radiusPill,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? PosTheme.primaryGreen
                                : PosTheme.borderColorOf(
                                    context,
                                  ),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            category.localizedName(language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : PosTheme.textSecondaryOf(
                                      context,
                                    ),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
