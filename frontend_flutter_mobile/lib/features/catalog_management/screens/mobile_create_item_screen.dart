import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/modifier_models.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/category_provider.dart';
import '../../pos/providers/modifier_provider.dart';
import '../../pos/providers/product_provider.dart';
import '../../pos/providers/unit_provider.dart';
import '../../pos/services/modifier_service.dart';

/// Product types offered on this form — deliberately excludes
/// VARIANT_PARENT/VARIANT/BUNDLE, matching desktop's
/// `item_management_screen.dart`: those need parent/bundle UI this form
/// doesn't have, and offering them here would just produce a confusing
/// backend validation failure.
const List<String> _kProductTypes = [
  'SALE_ITEM',
  'STOCK_ITEM',
  'SERVICE',
  'INGREDIENT',
  'CONVERSION_ONLY',
];

/// Create/edit a product (admin CRUD). Ported business logic from
/// `frontend-flutter-pos/lib/features/pos/screens/item_management_screen.dart`
/// (`ProductFormScreen`): same fields, same save flow (product save, then a
/// separate step syncing this product's modifier-group membership via
/// `ModifierService.getGroupProducts`/`updateGroupProducts`, since that link
/// lives on the modifier group, not as a field on the product itself).
///
/// Desktop's fixed-width multi-column form becomes a single scrollable
/// column here (mobile UI reimplement), grouped into the same sections
/// desktop's own l10n strings already name (Basic Info, Pricing, Units,
/// Inventory, Status, Modifiers, Image), following this app's established
/// `mobile_create_supplier_screen.dart`/`mobile_create_table_screen.dart`
/// save/error-handling flow (`FilledButton`, loading state, `SnackBar`,
/// `Navigator.pop(true)` on success).
class MobileCreateItemScreen extends ConsumerStatefulWidget {
  const MobileCreateItemScreen({super.key, this.initialProduct});

  final Product? initialProduct;

  @override
  ConsumerState<MobileCreateItemScreen> createState() =>
      _MobileCreateItemScreenState();
}

class _MobileCreateItemScreenState extends ConsumerState<MobileCreateItemScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameEnCtl;
  late final TextEditingController _nameKmCtl;
  late final TextEditingController _skuCtl;
  late final TextEditingController _barcodeCtl;
  late final TextEditingController _descriptionCtl;
  late final TextEditingController _priceCtl;
  late final TextEditingController _costCtl;
  late final TextEditingController _taxRateCtl;
  late final TextEditingController _initialStockCtl;
  late final TextEditingController _lowStockCtl;
  late final TextEditingController _imageUrlCtl;

  int? _categoryId;
  String _productType = _kProductTypes.first;
  int? _saleUnitId;
  int? _purchaseUnitId;
  int? _stockUnitId;
  bool _trackInventory = false;
  bool _purchasable = false;
  bool _active = true;
  bool _sellable = true;
  final Set<int> _selectedModifierGroupIds = {};
  bool _saving = false;

  bool get _isEditing => widget.initialProduct != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    _nameEnCtl = TextEditingController(text: p?.nameEn ?? '');
    _nameKmCtl = TextEditingController(text: p?.nameKm ?? '');
    _skuCtl = TextEditingController(text: p?.sku ?? '');
    _barcodeCtl = TextEditingController(text: p?.barcode ?? '');
    _descriptionCtl = TextEditingController(text: p?.description ?? '');
    _priceCtl = TextEditingController(text: p == null ? '' : '${p.price}');
    _costCtl = TextEditingController(text: p == null ? '' : '${p.cost}');
    _taxRateCtl = TextEditingController(
      text: p == null ? '0' : '${p.taxRateResolvedPercent}',
    );
    _initialStockCtl = TextEditingController(text: p == null ? '0' : '${p.stock.toInt()}');
    _lowStockCtl =
        TextEditingController(text: '${p?.lowStockThreshold.toInt() ?? 5}');
    _imageUrlCtl = TextEditingController(text: p?.imageUrl ?? '');

    _categoryId = p?.categoryId;
    _productType = (p != null && _kProductTypes.contains(p.productType))
        ? p.productType
        : _kProductTypes.first;
    _saleUnitId = p?.saleUnitId;
    _purchaseUnitId = p?.purchaseUnitId;
    _stockUnitId = p?.stockUnitId;
    _trackInventory = p?.trackInventory ?? false;
    _purchasable = p?.purchasable ?? false;
    _active = p?.active ?? true;
    _sellable = p?.sellable ?? true;
    _selectedModifierGroupIds
        .addAll((p?.modifierGroups ?? const []).map((g) => g.id));

    Future.microtask(() {
      ref.read(categoriesProvider.notifier).loadCategories();
      ref.read(unitProvider.notifier).loadUnits();
      ref.read(modifierProvider.notifier).loadGroups();
    });
  }

  @override
  void dispose() {
    _nameEnCtl.dispose();
    _nameKmCtl.dispose();
    _skuCtl.dispose();
    _barcodeCtl.dispose();
    _descriptionCtl.dispose();
    _priceCtl.dispose();
    _costCtl.dispose();
    _taxRateCtl.dispose();
    _initialStockCtl.dispose();
    _lowStockCtl.dispose();
    _imageUrlCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _saving = true);

    final product = Product(
      id: widget.initialProduct?.id ?? 0,
      sku: _skuCtl.text.trim(),
      barcode: _barcodeCtl.text.trim(),
      nameEn: _nameEnCtl.text.trim(),
      nameKm: _nameKmCtl.text.trim(),
      imageUrl: _imageUrlCtl.text.trim().isEmpty ? null : _imageUrlCtl.text.trim(),
      description:
          _descriptionCtl.text.trim().isEmpty ? null : _descriptionCtl.text.trim(),
      cost: double.tryParse(_costCtl.text.trim()) ?? 0,
      price: double.parse(_priceCtl.text.trim()),
      active: _active,
      sellable: _sellable,
      purchasable: _trackInventory ? _purchasable : false,
      trackInventory: _trackInventory,
      productType: _productType,
      lowStockThreshold: double.tryParse(_lowStockCtl.text.trim()) ?? 5,
      categoryId: _categoryId!,
      stock: double.tryParse(_initialStockCtl.text.trim()) ?? 0,
      saleUnitId: _saleUnitId,
      purchaseUnitId: _purchaseUnitId,
      stockUnitId: _stockUnitId,
      taxRate: (double.tryParse(_taxRateCtl.text.trim()) ?? 0) / 100,
    );

    try {
      final Product saved;
      if (_isEditing) {
        saved = await ref.read(productsProvider.notifier).updateProduct(product);
      } else {
        saved = await ref.read(productsProvider.notifier).createProduct(product);
      }

      await _syncModifierGroups(saved.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _isEditing
              ? l10n.itemManagementItemUpdated(saved.nameEn)
              : l10n.itemManagementItemCreated(saved.nameEn),
        ),
        backgroundColor: PosTheme.successGreen,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          l10n.itemManagementFailedToSave(e is ApiException ? e.message : '$e'),
        ),
        backgroundColor: PosTheme.errorRed,
      ));
    }
  }

  /// The product<->modifier-group link lives on the modifier group (a
  /// separate `/api/modifiers/groups/{id}/products` full-list endpoint),
  /// not as a field on the product — so after saving the product itself,
  /// diff the switches against the groups it started with and rewrite only
  /// the groups that actually changed, reading-then-rewriting each group's
  /// full product list (never a per-product add/remove endpoint) so other
  /// products' assignments to that group aren't clobbered.
  Future<void> _syncModifierGroups(int productId) async {
    final initialIds =
        (widget.initialProduct?.modifierGroups ?? const <ModifierGroupResponse>[])
            .map((g) => g.id)
            .toSet();
    final changed = initialIds.difference(_selectedModifierGroupIds)
      ..addAll(_selectedModifierGroupIds.difference(initialIds));
    if (changed.isEmpty) return;

    final service = ref.read(modifierServiceProvider);
    final l10n = context.l10n;
    try {
      for (final groupId in changed) {
        final productIds = (await service.getGroupProducts(groupId)).toSet();
        if (_selectedModifierGroupIds.contains(groupId)) {
          productIds.add(productId);
        } else {
          productIds.remove(productId);
        }
        await service.updateGroupProducts(
          groupId: groupId,
          productIds: productIds.toList(),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.itemManagementModifiersNotUpdated('$e')),
        backgroundColor: PosTheme.warningAmber,
      ));
    }
  }

  int? _safeValue(int? value, Iterable<int> validIds) {
    return validIds.contains(value) ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categoriesState = ref.watch(categoriesProvider);
    final unitsState = ref.watch(unitProvider);
    final modifierState = ref.watch(modifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.itemManagementEditItemTitle : l10n.itemManagementNewItemTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PosTheme.spacingMd),
          children: [
            _SectionHeader(l10n.itemManagementSectionBasicInfo),
            TextFormField(
              controller: _nameEnCtl,
              decoration: InputDecoration(
                labelText: l10n.formNameEn,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _nameKmCtl,
              decoration: InputDecoration(
                labelText: l10n.formNameKm,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.itemManagementKhmerNameRequired
                  : null,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuCtl,
                    decoration: InputDecoration(
                      labelText: l10n.formSku,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.itemManagementSkuRequired
                        : null,
                  ),
                ),
                const SizedBox(width: PosTheme.spacingMd),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeCtl,
                    decoration: InputDecoration(
                      labelText: l10n.formBarcode,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.itemManagementBarcodeRequired
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: PosTheme.spacingMd),
            categoriesState.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('${l10n.commonError}: $e'),
              data: (categories) {
                final active = categories.where((c) => c.active).toList();
                final withCurrent = active.any((c) => c.id == _categoryId) ||
                        _categoryId == null
                    ? active
                    : [
                        ...active,
                        ...categories.where((c) => c.id == _categoryId),
                      ];
                return DropdownButtonFormField<int>(
                  initialValue: _safeValue(
                    _categoryId,
                    withCurrent.map((c) => c.id),
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.formCategory,
                    hintText: l10n.itemManagementSelectCategoryHint,
                    border: const OutlineInputBorder(),
                  ),
                  items: withCurrent
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nameEn),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                  validator: (v) =>
                      v == null ? l10n.itemManagementPleaseSelectCategory : null,
                );
              },
            ),
            const SizedBox(height: PosTheme.spacingMd),
            DropdownButtonFormField<String>(
              initialValue: _productType,
              decoration: InputDecoration(
                labelText: l10n.itemManagementProductTypeLabel,
                helperText: l10n.itemManagementProductTypeSubtitle,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'SALE_ITEM',
                  child: Text(l10n.itemManagementProductTypeSaleItem),
                ),
                DropdownMenuItem(
                  value: 'STOCK_ITEM',
                  child: Text(l10n.itemManagementProductTypeStockItem),
                ),
                DropdownMenuItem(
                  value: 'SERVICE',
                  child: Text(l10n.itemManagementProductTypeService),
                ),
                DropdownMenuItem(
                  value: 'INGREDIENT',
                  child: Text(l10n.itemManagementProductTypeIngredient),
                ),
                DropdownMenuItem(
                  value: 'CONVERSION_ONLY',
                  child: Text(l10n.itemManagementProductTypeConversionOnly),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _productType = v);
              },
            ),
            const SizedBox(height: PosTheme.spacingLg),
            _SectionHeader(l10n.itemManagementSectionDescriptionOptional),
            TextFormField(
              controller: _descriptionCtl,
              maxLength: 255,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: l10n.itemManagementDescriptionHint,
                border: const OutlineInputBorder(),
              ),
            ),
            _SectionHeader(l10n.itemManagementSectionPricing),
            TextFormField(
              controller: _priceCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.itemManagementSellPriceLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => double.tryParse((v ?? '').trim()) == null
                  ? l10n.itemManagementInvalidNumber
                  : null,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _costCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.formCost,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _taxRateCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.createPurchaseOrderTaxRate,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').trim());
                if (parsed == null || parsed < 0 || parsed > 100) {
                  return l10n.itemManagementInvalidNumber;
                }
                return null;
              },
            ),
            const SizedBox(height: PosTheme.spacingLg),
            _SectionHeader(l10n.itemManagementSectionUnits),
            unitsState.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('${l10n.commonError}: $e'),
              data: (units) {
                final active = units.where((u) => u.active).toList();
                List<DropdownMenuItem<int?>> itemsFor() => [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(l10n.itemManagementUnitDefaultOption),
                      ),
                      ...active.map((u) => DropdownMenuItem<int?>(
                            value: u.id,
                            child: Text('${u.nameEn} (${u.symbol})'),
                          )),
                    ];
                final ids = active.map((u) => u.id);
                return Column(
                  children: [
                    DropdownButtonFormField<int?>(
                      initialValue: _safeValue(_saleUnitId, ids),
                      decoration: InputDecoration(
                        labelText: l10n.itemManagementSaleUnitLabel,
                        border: const OutlineInputBorder(),
                      ),
                      items: itemsFor(),
                      onChanged: (v) => setState(() => _saleUnitId = v),
                    ),
                    const SizedBox(height: PosTheme.spacingMd),
                    DropdownButtonFormField<int?>(
                      initialValue: _safeValue(_purchaseUnitId, ids),
                      decoration: InputDecoration(
                        labelText: l10n.itemManagementPurchaseUnitLabel,
                        border: const OutlineInputBorder(),
                      ),
                      items: itemsFor(),
                      onChanged: (v) => setState(() => _purchaseUnitId = v),
                    ),
                    const SizedBox(height: PosTheme.spacingMd),
                    DropdownButtonFormField<int?>(
                      initialValue: _safeValue(_stockUnitId, ids),
                      decoration: InputDecoration(
                        labelText: l10n.itemManagementStockUnitLabel,
                        border: const OutlineInputBorder(),
                      ),
                      items: itemsFor(),
                      onChanged: (v) => setState(() => _stockUnitId = v),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: PosTheme.spacingLg),
            _SectionHeader(l10n.itemManagementSectionInventory),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _trackInventory,
              title: Text(l10n.itemManagementTrackInventoryTitle),
              subtitle: Text(l10n.itemManagementManageStockQuantitySubtitle),
              onChanged: (v) => setState(() {
                _trackInventory = v;
                if (!v) _purchasable = false;
              }),
            ),
            if (_trackInventory) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _purchasable,
                title: Text(l10n.itemManagementPurchasableTitle),
                subtitle: Text(l10n.itemManagementPurchasableSubtitle),
                onChanged: (v) => setState(() => _purchasable = v),
              ),
              const SizedBox(height: PosTheme.spacingSm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _initialStockCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.itemManagementInitialStockLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: PosTheme.spacingMd),
                  Expanded(
                    child: TextFormField(
                      controller: _lowStockCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.itemManagementLowStockAlertLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: PosTheme.spacingLg),
            _SectionHeader(l10n.itemManagementSectionStatus),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              title: Text(l10n.commonActive),
              subtitle: Text(l10n.itemManagementProductAvailableSubtitle),
              onChanged: (v) => setState(() => _active = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _sellable,
              title: Text(l10n.itemManagementSellableTitle),
              subtitle: Text(l10n.itemManagementCanBeSoldInPosSubtitle),
              onChanged: (v) => setState(() => _sellable = v),
            ),
            const SizedBox(height: PosTheme.spacingLg),
            _SectionHeader(l10n.itemManagementSectionModifiers),
            if (modifierState.isLoading)
              const LinearProgressIndicator()
            else if (modifierState.groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: PosTheme.spacingSm),
                child: Text(
                  l10n.itemManagementNoModifiersYet,
                  style: TextStyle(color: PosTheme.textSecondaryOf(context)),
                ),
              )
            else
              ...modifierState.groups.map((group) {
                final optionNames = group.options.isEmpty
                    ? l10n.itemManagementNoOptions
                    : group.options.map((o) => o.nameEn).join(', ');
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selectedModifierGroupIds.contains(group.id),
                  title: Text(group.nameEn),
                  subtitle: Text(optionNames),
                  onChanged: (v) => setState(() {
                    if (v) {
                      _selectedModifierGroupIds.add(group.id);
                    } else {
                      _selectedModifierGroupIds.remove(group.id);
                    }
                  }),
                );
              }),
            const SizedBox(height: PosTheme.spacingLg),
            _SectionHeader(l10n.itemManagementSectionImage),
            TextFormField(
              controller: _imageUrlCtl,
              decoration: InputDecoration(
                labelText: l10n.itemManagementImageUrlLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_imageUrlCtl.text.trim().isNotEmpty) ...[
              const SizedBox(height: PosTheme.spacingSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                child: AspectRatio(
                  aspectRatio: 1.6,
                  child: Image.network(
                    _imageUrlCtl.text.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: PosTheme.backgroundPageOf(context),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: PosTheme.spacingLg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? l10n.itemManagementSavingEllipsis
                    : (_isEditing
                        ? l10n.itemManagementUpdateItem
                        : l10n.itemManagementCreateItem),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PosTheme.spacingSm),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: PosTheme.fontSizeMd,
          color: PosTheme.primaryGreen,
        ),
      ),
    );
  }
}

extension on Product {
  /// UI convenience — `taxRate` is stored as a fraction (0.08 = 8%) but the
  /// form edits it as a whole percentage.
  double get taxRateResolvedPercent => taxRate * 100;
}
