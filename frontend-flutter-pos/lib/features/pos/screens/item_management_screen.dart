import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/product_provider.dart';
import '../models/modifier_models.dart';
import '../models/product_models.dart';
import '../models/unit_models.dart';
import '../services/category_service.dart';
import '../services/demo_product_service.dart';
import '../services/modifier_service.dart';
import '../services/unit_service.dart';

/// Full end-to-end Item management screen — follows the same list UI as
/// Employees: inline ADD button, checkbox multi-select + bulk delete,
/// search box, and client-side pagination.
///
/// - Lists all products with search & category filter
/// - Create / Edit / Delete products
/// - Syncs with backend API via ProductService
class ItemManagementScreen extends ConsumerStatefulWidget {
  const ItemManagementScreen({super.key});

  @override
  ConsumerState<ItemManagementScreen> createState() =>
      _ItemManagementScreenState();
}

class _ItemManagementScreenState extends ConsumerState<ItemManagementScreen> {
  static const int _pageSize = 6;

  final TextEditingController _searchCtl = TextEditingController();
  int? _filterCategoryId;
  int _currentPage = 0;

  // Selected product IDs remain selected when changing pages.
  final Set<int> _selectedProductIds = {};

  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadAll();
      if (mounted) setState(() => _hasLoadedOnce = true);
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  /// The product provider paginates from the backend in chunks (for the POS
  /// grid's infinite scroll). The admin list needs the *full* matching set
  /// up front so it can paginate client-side like the Employees screen.
  Future<void> _loadAll({String? query}) async {
    final notifier = ref.read(productsProvider.notifier);
    await notifier.loadProducts(query: query, categoryId: _filterCategoryId);
    while (ref.read(productsProvider).hasMore) {
      await notifier.loadMore();
    }
  }

  Future<void> _refresh() async {
    await _loadAll(
        query: _searchCtl.text.trim().isEmpty ? null : _searchCtl.text.trim());
  }

  void _search(String query) {
    _loadAll(query: query.trim().isEmpty ? null : query.trim());
    setState(() => _currentPage = 0);
  }

  Future<void> _openCreateItem() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ProductFormScreen(isEdit: false),
      ),
    );
    if (result == true) {
      await _refresh();
      if (mounted) setState(() => _currentPage = 0);
    }
  }

  Future<void> _openEditItem(Product product) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(isEdit: true, product: product),
      ),
    );
    if (result == true) await _refresh();
  }

  void _toggleProduct(int productId, bool selected) {
    setState(() {
      if (selected) {
        _selectedProductIds.add(productId);
      } else {
        _selectedProductIds.remove(productId);
      }
    });
  }

  void _toggleCurrentPage(List<Product> pageProducts) {
    final pageIds = pageProducts.map((p) => p.id).toSet();
    final allPageItemsSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedProductIds.contains);

    setState(() {
      if (allPageItemsSelected) {
        _selectedProductIds.removeAll(pageIds);
      } else {
        _selectedProductIds.addAll(pageIds);
      }
    });
  }

  Future<void> _deleteSelectedProducts() async {
    if (_selectedProductIds.isEmpty) return;

    final numberSelected = _selectedProductIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.l10n.itemManagementDeleteItemsTitle),
          content: Text(
            dialogContext.l10n.itemManagementDeleteItemsMessage(numberSelected),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.commonCancel.toUpperCase()),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.l10n.commonDelete.toUpperCase(),
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final idsToDelete = _selectedProductIds.toList();

    try {
      for (final productId in idsToDelete) {
        await ref.read(productsProvider.notifier).deleteProduct(productId);
      }

      if (!mounted) return;

      final remaining = ref.read(productsProvider).products;
      final totalPages =
          remaining.isEmpty ? 1 : (remaining.length / _pageSize).ceil();

      setState(() {
        _selectedProductIds.clear();
        if (_currentPage >= totalPages) {
          _currentPage = totalPages - 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n
              .itemManagementItemsDeletedSuccess(idsToDelete.length)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(context.l10n.itemManagementFailedToDeleteItems('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.navItems),
          elevation: 0.5,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: context.l10n.commonRefresh,
              onPressed: _refresh,
            ),
          ],
        ),
        body: SafeArea(child: Builder(builder: (context) {
          if (!_hasLoadedOnce) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return _buildErrorState(state.error!);
            }
          }

          final isSearching = _searchCtl.text.trim().isNotEmpty;

          if (!state.isLoading && !isSearching && state.products.isEmpty) {
            if (state.error != null) {
              return _buildErrorState(state.error!);
            }
            return _buildEmptyState();
          }

          return _buildItemList(state.products, loading: state.isLoading);
        })),
      ),
    );
  }

  Widget _buildItemList(List<Product> allProducts, {required bool loading}) {
    final totalItems = allProducts.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);

    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageProducts = allProducts.sublist(startIndex, endIndex);

    final pageIds = pageProducts.map((p) => p.id).toSet();
    final allPageItemsSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedProductIds.contains);
    final somePageItemsSelected = pageIds.any(_selectedProductIds.contains);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          Card(
            color: Colors.white,
            elevation: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 22),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openCreateItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(160, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          context.l10n.itemManagementAddItem.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: context
                            .l10n.itemManagementDeleteSelectedItemsTooltip,
                        onPressed: _selectedProductIds.isEmpty
                            ? null
                            : _deleteSelectedProducts,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          foregroundColor: Colors.red,
                          disabledForegroundColor: Colors.grey.shade400,
                          side: BorderSide(
                            color: _selectedProductIds.isEmpty
                                ? Colors.grey.shade300
                                : Colors.red,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      if (_selectedProductIds.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.itemManagementSelectedCount(
                              _selectedProductIds.length),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: 260,
                        height: 42,
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: _search,
                          decoration: InputDecoration(
                            hintText: context.l10n.itemManagementSearchHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchCtl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchCtl.clear();
                                      _search('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: PosTheme.backgroundPage,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(PosTheme.radiusMedium),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 12,
                            ),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: Checkbox(
                          tristate: true,
                          value: allPageItemsSelected
                              ? true
                              : somePageItemsSelected
                                  ? null
                                  : false,
                          onChanged: (_) => _toggleCurrentPage(pageProducts),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.navItems,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Text(
                        context.l10n.itemManagementShowingCount(
                            pageProducts.length, totalItems),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (pageProducts.isEmpty)
                  _buildNoResultsRow(loading: loading)
                else
                  ...pageProducts.map(_buildItemRow),
                if (pageProducts.isNotEmpty)
                  _buildPaginationControls(
                    currentPage: safeCurrentPage,
                    totalPages: totalPages,
                    totalItems: totalItems,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsRow({required bool loading}) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              context.l10n.itemManagementNoItemsFound,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(Product product) {
    final p = product;
    final selected = _selectedProductIds.contains(p.id);

    final subtitleParts = [
      if (p.sku.isNotEmpty) '${context.l10n.formSku}: ${p.sku}',
      if (p.categoryNameEn != null) p.categoryNameEn!,
    ];
    final subtitle = subtitleParts.isEmpty
        ? context.l10n.itemManagementNoCategorySet
        : subtitleParts.join(' • ');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Checkbox(
                  value: selected,
                  onChanged: (value) => _toggleProduct(p.id, value ?? false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _openEditItem(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF99D267),
                            borderRadius: BorderRadius.circular(24),
                            image: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(p.imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: (p.imageUrl == null || p.imageUrl!.isEmpty)
                              ? const Icon(Icons.inventory_2,
                                  color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.localizedName(ref.watch(appLanguageProvider)),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatAmount(p.price, watchCurrency(ref)),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: PosTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: p.active
                          ? PosTheme.successGreen.withValues(alpha: 0.12)
                          : PosTheme.errorRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      p.active
                          ? context.l10n.commonActive.toUpperCase()
                          : context.l10n.commonInactive.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: p.active
                            ? PosTheme.successGreen
                            : PosTheme.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required int totalItems,
  }) {
    final firstItem = totalItems == 0 ? 0 : currentPage * _pageSize + 1;
    final lastItem = math.min((currentPage + 1) * _pageSize, totalItems);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            context.l10n
                .itemManagementRangeOfTotal(firstItem, lastItem, totalItems),
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(width: 20),
          IconButton(
            tooltip: context.l10n.itemManagementFirstPage,
            onPressed: currentPage == 0
                ? null
                : () => setState(() => _currentPage = 0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: context.l10n.itemManagementPreviousPage,
            onPressed: currentPage == 0
                ? null
                : () => setState(() => _currentPage = currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 100),
            alignment: Alignment.center,
            child: Text(
              context.l10n
                  .itemManagementPageOfPages(currentPage + 1, totalPages),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            tooltip: context.l10n.itemManagementNextPage,
            onPressed: currentPage >= totalPages - 1
                ? null
                : () => setState(() => _currentPage = currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: context.l10n.itemManagementLastPage,
            onPressed: currentPage >= totalPages - 1
                ? null
                : () => setState(() => _currentPage = totalPages - 1),
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Card(
              color: Colors.white,
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 45,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 105,
                      height: 105,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 52,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      context.l10n.navItems,
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.itemManagementEmptyStateDescription,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _openCreateItem,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(165, 54),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        context.l10n.itemManagementAddItem.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refresh,
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Product types selectable from the form — limited to the ones
/// ProductService.validateProduct accepts with no other linked data
/// (VARIANT_PARENT/VARIANT need a parent product, BUNDLE needs a bundle
/// mode + components — this form has no UI for either, so offering them
/// here would let a save fail with a confusing backend validation error).
const List<String> _productTypeOptions = [
  'SALE_ITEM',
  'STOCK_ITEM',
  'SERVICE',
  'INGREDIENT',
  'CONVERSION_ONLY',
];

String _productTypeLabel(BuildContext context, String type) {
  switch (type) {
    case 'STOCK_ITEM':
      return context.l10n.itemManagementProductTypeStockItem;
    case 'SERVICE':
      return context.l10n.itemManagementProductTypeService;
    case 'INGREDIENT':
      return context.l10n.itemManagementProductTypeIngredient;
    case 'CONVERSION_ONLY':
      return context.l10n.itemManagementProductTypeConversionOnly;
    case 'SALE_ITEM':
    default:
      return context.l10n.itemManagementProductTypeSaleItem;
  }
}

/// Full-screen form for creating or editing a product.
/// Integrates with backend API via ProductService.
class ProductFormScreen extends ConsumerStatefulWidget {
  final bool isEdit;
  final Product? product;

  const ProductFormScreen({
    required this.isEdit,
    this.product,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => ProductFormScreenState();
}

class ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameEnCtl;
  late final TextEditingController _nameKmCtl;
  late final TextEditingController _skuCtl;
  late final TextEditingController _barcodeCtl;
  late final TextEditingController _priceCtl;
  late final TextEditingController _costCtl;
  late final TextEditingController _taxRateCtl;
  late final TextEditingController _initialStockCtl;
  late final TextEditingController _lowStockCtl;
  late final TextEditingController _imageUrlCtl;
  late final TextEditingController _descriptionCtl;

  bool _active = true;
  bool _sellable = true;
  bool _purchasable = false;
  bool _trackInventory = false;
  int _categoryId = 0;
  String _productType = 'SALE_ITEM';
  bool _saving = false;
  List<Category> _categories = [];

  // ── Units ──
  // null means "use the store default (EACH)" — matches
  // ProductService.resolveUnit's backend fallback, so leaving these unset
  // is a valid, intentional choice, not a validation error.
  int? _saleUnitId;
  int? _purchaseUnitId;
  int? _stockUnitId;
  List<Unit> _units = [];

  // ── Modifiers ──
  // A modifier GROUP (e.g. "Size", "Toppings") is applied to a product with
  // a switch here; the customer picks individual OPTIONS from that group
  // when the product is added to the cart (see ProductModifierSheet).
  List<ModifierGroupResponse> _modifierGroups = [];
  bool _loadingModifiers = true;
  late Set<int> _initialModifierGroupIds;
  late Set<int> _selectedModifierGroupIds;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _initialModifierGroupIds =
        p?.modifierGroups.map((g) => g.id).toSet() ?? <int>{};
    _selectedModifierGroupIds = {..._initialModifierGroupIds};
    _loadModifierGroups();
    _nameEnCtl = TextEditingController(text: p?.nameEn ?? '');
    _nameKmCtl = TextEditingController(text: p?.nameKm ?? '');
    _skuCtl = TextEditingController(text: p?.sku ?? '');
    _barcodeCtl = TextEditingController(text: p?.barcode ?? '');
    _priceCtl = TextEditingController(
        text: p != null ? p.price.toStringAsFixed(2) : '');
    _costCtl =
        TextEditingController(text: p != null ? p.cost.toStringAsFixed(2) : '');
    // Shown/entered as a percentage (e.g. "8"), stored as a fraction (0.08)
    // — matches the convention the old store-wide Settings → Tax field used.
    _taxRateCtl = TextEditingController(
        text: p != null ? (p.taxRate * 100).toStringAsFixed(2) : '');
    _initialStockCtl = TextEditingController(
        text: p != null ? p.stock.toInt().toString() : '0');
    _lowStockCtl = TextEditingController(
        text: p != null ? p.lowStockThreshold.toInt().toString() : '5');
    _imageUrlCtl = TextEditingController(text: p?.imageUrl ?? '');
    _descriptionCtl = TextEditingController(text: p?.description ?? '');
    if (p != null) {
      _active = p.active;
      _sellable = p.sellable;
      _purchasable = p.purchasable;
      _trackInventory = p.trackInventory;
      _categoryId = p.categoryId;
      _productType = p.productType;
      _saleUnitId = p.saleUnitId;
      _purchaseUnitId = p.purchaseUnitId;
      _stockUnitId = p.stockUnitId;
    }
    // Load categories
    Future.microtask(() async {
      try {
        final service = ref.read(categoryServiceProvider);
        final cats = await service.list();
        if (mounted) {
          setState(() {
            _categories = cats.where((c) => c.active).toList();
          });
        }
      } catch (_) {}
    });
    // Load units (for the Sale/Purchase/Stock unit dropdowns).
    Future.microtask(() async {
      try {
        final units = await ref.read(unitServiceProvider).list(active: true);
        if (mounted) setState(() => _units = units);
      } catch (_) {}
    });
  }

  int? _safeUnitValue(int? id) =>
      id != null && _units.any((u) => u.id == id) ? id : null;

  Future<void> _loadModifierGroups() async {
    try {
      final groups = await ref.read(modifierServiceProvider).getGroups();
      if (mounted) {
        setState(() {
          _modifierGroups = groups;
          _loadingModifiers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingModifiers = false);
    }
  }

  @override
  void dispose() {
    _nameEnCtl.dispose();
    _nameKmCtl.dispose();
    _skuCtl.dispose();
    _barcodeCtl.dispose();
    _priceCtl.dispose();
    _costCtl.dispose();
    _taxRateCtl.dispose();
    _initialStockCtl.dispose();
    _lowStockCtl.dispose();
    _imageUrlCtl.dispose();
    _descriptionCtl.dispose();
    super.dispose();
  }

  /// Pick an image: show dialog with URL entry or upload from file.
  Future<void> _pickImage(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final urlCtl = TextEditingController();
        return AlertDialog(
          title: Text(ctx.l10n.itemManagementProductImageTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtl,
                decoration: InputDecoration(
                  labelText: ctx.l10n.itemManagementImageUrlLabel,
                  hintText: 'https://...',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(ctx.l10n.itemManagementUseUrl),
                  onPressed: () {
                    final url = urlCtl.text.trim();
                    if (url.isNotEmpty) Navigator.of(ctx).pop(url);
                  },
                ),
              ),
              const Divider(height: 24),
              Text(ctx.l10n.itemManagementOrUploadFromDevice,
                  style:
                      TextStyle(fontSize: 12, color: PosTheme.textSecondary)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(ctx.l10n.itemManagementUploadImage),
                  onPressed: () async {
                    // Start upload — backend returns the URL
                    try {
                      Navigator.of(ctx).pop('__uploading__');
                      // Will be handled after dialog closes
                    } catch (e) {
                      Navigator.of(ctx).pop(null);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(ctx.l10n.commonCancel),
            ),
          ],
        );
      },
    );

    if (result != null && result != '__uploading__') {
      setState(() => _imageUrlCtl.text = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields (backend @NotBlank / @NotNull)
    if (_skuCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.itemManagementSkuRequired),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }
    if (_barcodeCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.itemManagementBarcodeRequired),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }
    if (_nameKmCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.itemManagementKhmerNameRequired),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }
    if (_categoryId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.itemManagementPleaseSelectCategory),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final service = ref.read(productServiceProvider);
      final price = double.tryParse(_priceCtl.text) ?? 0;
      final cost = double.tryParse(_costCtl.text) ?? 0;
      final taxRatePercent = double.tryParse(_taxRateCtl.text) ?? 0;
      final stock = int.tryParse(_initialStockCtl.text) ?? 0;

      final product = Product(
        id: widget.product?.id ?? 0,
        sku: _skuCtl.text.trim(),
        barcode: _barcodeCtl.text.trim(),
        nameEn: _nameEnCtl.text.trim(),
        nameKm: _nameKmCtl.text.trim(),
        imageUrl:
            _imageUrlCtl.text.trim().isEmpty ? null : _imageUrlCtl.text.trim(),
        description: _descriptionCtl.text.trim().isEmpty
            ? null
            : _descriptionCtl.text.trim(),
        cost: cost,
        price: price,
        taxRate: taxRatePercent / 100,
        active: _active,
        sellable: _sellable,
        purchasable: _purchasable,
        trackInventory: _trackInventory,
        productType: _productType,
        lowStockThreshold: (int.tryParse(_lowStockCtl.text) ?? 5).toDouble(),
        categoryId: _categoryId,
        stock: stock.toDouble(),
        // This form has no UI for parent/variant — carry the existing
        // product's values through unchanged rather than dropping them,
        // which previously reset them to null (clearing the parent link)
        // on every edit.
        parentProductId: widget.product?.parentProductId,
        variantLabel: widget.product?.variantLabel,
        saleUnitId: _saleUnitId,
        purchaseUnitId: _purchaseUnitId,
        stockUnitId: _stockUnitId,
      );

      final saved = widget.isEdit
          ? await service.updateProduct(product)
          : await service.createProduct(product);

      await _syncModifierGroups(saved.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEdit
                ? context.l10n.itemManagementItemUpdated(product.nameEn)
                : context.l10n.itemManagementItemCreated(product.nameEn)),
            backgroundColor: PosTheme.successGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.itemManagementFailedToSave('$e')),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Applies any modifier-switch changes to the saved product. `updateGroupProducts`
  /// replaces a whole group's product list, so each changed group's current list is
  /// read first and this product's id is added to or removed from it.
  ///
  /// The product itself has already been saved by the time this runs, so a
  /// failure here is reported as a non-fatal warning rather than failing the
  /// whole save.
  Future<void> _syncModifierGroups(int productId) async {
    final added =
        _selectedModifierGroupIds.difference(_initialModifierGroupIds);
    final removed =
        _initialModifierGroupIds.difference(_selectedModifierGroupIds);
    if (added.isEmpty && removed.isEmpty) return;

    final service = ref.read(modifierServiceProvider);
    try {
      for (final groupId in {...added, ...removed}) {
        final currentIds = (await service.getGroupProducts(groupId)).toSet();
        if (added.contains(groupId)) {
          currentIds.add(productId);
        } else {
          currentIds.remove(productId);
        }
        await service.updateGroupProducts(
          groupId: groupId,
          productIds: currentIds.toList(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.itemManagementModifiersNotUpdated('$e')),
            backgroundColor: PosTheme.warningAmber,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEdit;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? context.l10n.itemManagementEditItemTitle
            : context.l10n.itemManagementNewItemTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.commonSave,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Basic Info ──
            _sectionHeader(context.l10n.itemManagementSectionBasicInfo),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameEnCtl,
              decoration: InputDecoration(
                labelText: '${context.l10n.formNameEn} *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.commonRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameKmCtl,
              decoration: InputDecoration(
                labelText: '${context.l10n.formNameKm} *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.commonRequired
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuCtl,
                    decoration: InputDecoration(
                      labelText: '${context.l10n.formSku} *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.commonRequired
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeCtl,
                    decoration: InputDecoration(
                      labelText: '${context.l10n.formBarcode} *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.commonRequired
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Category (Loyverse-style dropdown) ──
            _sectionHeader(context.l10n.formCategory),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _categoryId > 0 ? _categoryId : null,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: context.l10n.itemManagementSelectCategoryHint,
              ),
              items: _categories
                  .map((cat) => DropdownMenuItem(
                        value: cat.id,
                        child: Text(
                            cat.localizedName(ref.watch(appLanguageProvider))),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _categoryId = v);
              },
              validator: (v) =>
                  (v == null || v <= 0) ? context.l10n.commonRequired : null,
            ),
            const SizedBox(height: 16),

            // ── Product Type ──
            _sectionHeader(context.l10n.itemManagementProductTypeLabel),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _productType,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _productTypeOptions
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(_productTypeLabel(context, t)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _productType = v);
              },
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.itemManagementProductTypeSubtitle,
              style:
                  const TextStyle(fontSize: 12, color: PosTheme.textSecondary),
            ),
            const SizedBox(height: 16),

            // ── Description (Loyverse-style) ──
            _sectionHeader(
                context.l10n.itemManagementSectionDescriptionOptional),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionCtl,
              decoration: InputDecoration(
                hintText: context.l10n.itemManagementDescriptionHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
              maxLength: 255,
            ),
            const SizedBox(height: 16),

            // ── Pricing ──
            _sectionHeader(context.l10n.itemManagementSectionPricing),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtl,
                    decoration: InputDecoration(
                      labelText: context.l10n.itemManagementSellPriceLabel,
                      prefixText: '${currencySymbol(watchCurrency(ref))} ',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return context.l10n.commonRequired;
                      }
                      if (double.tryParse(v.trim()) == null) {
                        return context.l10n.itemManagementInvalidNumber;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costCtl,
                    decoration: InputDecoration(
                      labelText: context.l10n.formCost,
                      prefixText: '${currencySymbol(watchCurrency(ref))} ',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Every item carries its own tax rate — there is no more
            // store-wide fallback (see Sale.taxRate/Product.taxRate on the
            // backend), so this is required just like Sell Price.
            TextFormField(
              controller: _taxRateCtl,
              decoration: InputDecoration(
                labelText: context.l10n.settingsTaxRateLabel,
                suffixText: '%',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return context.l10n.commonRequired;
                }
                final parsed = double.tryParse(v.trim());
                if (parsed == null) {
                  return context.l10n.itemManagementInvalidNumber;
                }
                if (parsed < 0 || parsed > 100) {
                  return context.l10n.itemManagementInvalidNumber;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Units ──
            // Leaving a dropdown unset (null) is a valid choice — the
            // backend resolves it to the store's default unit ("EACH"),
            // it's not a validation error.
            //
            // `initialValue` must be null or match exactly one item in
            // `items`, or DropdownButtonFormField throws — which would
            // happen on the very first frame (units haven't finished
            // loading yet) or if a product's unit was since deactivated.
            // _safeUnitValue only shows a selection once it can actually be
            // rendered; the real _saleUnitId/etc. is still what gets saved.
            _sectionHeader(context.l10n.itemManagementSectionUnits),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _safeUnitValue(_saleUnitId),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.l10n.itemManagementSaleUnitLabel,
                hintText: context.l10n.itemManagementUnitDefaultOption,
                border: const OutlineInputBorder(),
              ),
              items: _units
                  .map((u) => DropdownMenuItem<int?>(
                        value: u.id,
                        child: Text('${u.nameEn} (${u.code})',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _saleUnitId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _safeUnitValue(_purchaseUnitId),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.l10n.itemManagementPurchaseUnitLabel,
                hintText: context.l10n.itemManagementUnitDefaultOption,
                border: const OutlineInputBorder(),
              ),
              items: _units
                  .map((u) => DropdownMenuItem<int?>(
                        value: u.id,
                        child: Text('${u.nameEn} (${u.code})',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _purchaseUnitId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _safeUnitValue(_stockUnitId),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.l10n.itemManagementStockUnitLabel,
                hintText: context.l10n.itemManagementUnitDefaultOption,
                border: const OutlineInputBorder(),
              ),
              items: _units
                  .map((u) => DropdownMenuItem<int?>(
                        value: u.id,
                        child: Text('${u.nameEn} (${u.code})',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _stockUnitId = v),
            ),
            const SizedBox(height: 16),

            // ── Inventory ──
            _sectionHeader(context.l10n.itemManagementSectionInventory),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _trackInventory,
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.itemManagementTrackInventoryTitle),
              subtitle:
                  Text(context.l10n.itemManagementManageStockQuantitySubtitle),
              onChanged: (v) => setState(() {
                _trackInventory = v;
                // The backend only allows a Purchase Order line for a
                // product that is BOTH purchasable AND inventory-tracked
                // (PurchasingWorkflowService) — turning tracking off would
                // otherwise leave a stale, hidden "purchasable = true"
                // that the PO screen can no longer show a control for.
                if (!v) _purchasable = false;
              }),
            ),
            if (_trackInventory) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _initialStockCtl,
                      decoration: InputDecoration(
                        labelText: context.l10n.itemManagementInitialStockLabel,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lowStockCtl,
                      decoration: InputDecoration(
                        labelText:
                            context.l10n.itemManagementLowStockAlertLabel,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _purchasable,
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.itemManagementPurchasableTitle),
                subtitle: Text(context.l10n.itemManagementPurchasableSubtitle),
                onChanged: (v) => setState(() => _purchasable = v),
              ),
            ],
            const SizedBox(height: 16),

            // ── Status ──
            _sectionHeader(context.l10n.itemManagementSectionStatus),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _active,
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.commonActive),
              subtitle:
                  Text(context.l10n.itemManagementProductAvailableSubtitle),
              onChanged: (v) => setState(() => _active = v),
            ),
            SwitchListTile(
              value: _sellable,
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.itemManagementSellableTitle),
              subtitle: Text(context.l10n.itemManagementCanBeSoldInPosSubtitle),
              onChanged: (v) => setState(() => _sellable = v),
            ),
            const SizedBox(height: 16),

            // ── Modifiers ──
            _sectionHeader(context.l10n.itemManagementSectionModifiers),
            const SizedBox(height: 8),
            if (_loadingModifiers)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_modifierGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.l10n.itemManagementNoModifiersYet,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              )
            else
              ..._modifierGroups.map((group) {
                final lang = ref.watch(appLanguageProvider);
                final name = group.localizedName(lang);
                final optionNames = group.options.isEmpty
                    ? context.l10n.itemManagementNoOptions
                    : group.options
                        .map((o) => o.localizedName(lang))
                        .join(', ');
                return SwitchListTile(
                  value: _selectedModifierGroupIds.contains(group.id),
                  contentPadding: EdgeInsets.zero,
                  title: Text(name),
                  subtitle: Text(optionNames,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onChanged: (v) => setState(() {
                    if (v) {
                      _selectedModifierGroupIds.add(group.id);
                    } else {
                      _selectedModifierGroupIds.remove(group.id);
                    }
                  }),
                );
              }),
            const SizedBox(height: 16),

            // ── Image ──
            _sectionHeader(context.l10n.itemManagementSectionImage),
            const SizedBox(height: 8),
            // Image preview
            if (_imageUrlCtl.text.isNotEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                  image: DecorationImage(
                    image: NetworkImage(_imageUrlCtl.text),
                    fit: BoxFit.cover,
                    onError: (_, __) {},
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _imageUrlCtl,
                    decoration: InputDecoration(
                      labelText: context.l10n.itemManagementImageUrlLabel,
                      hintText: 'https://example.com/image.jpg',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // Upload button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _pickImage(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PosTheme.backgroundPage,
                      foregroundColor: PosTheme.textPrimary,
                      side: BorderSide(color: PosTheme.borderColor),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.upload, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Save button ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving
                    ? context.l10n.itemManagementSavingEllipsis
                    : (isEdit
                        ? context.l10n.itemManagementUpdateItem
                        : context.l10n.itemManagementCreateItem)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: PosTheme.textSecondary,
      ),
    );
  }
}
