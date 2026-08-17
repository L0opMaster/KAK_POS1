import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/modifier_models.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/product_provider.dart';
import '../../pos/services/modifier_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/screens/
/// modifier_product_assignment_screen.dart` — BUSINESS LOGIC is COPY/ADAPT
/// NEARLY EXACTLY: loads the group's currently-assigned product ids via
/// `ModifierService.getGroupProducts`, lets the user check/uncheck
/// products, and on save calls `ModifierService.updateGroupProducts` once
/// with the FULL new selection (a full replace, not incremental). One
/// deliberate change from source: rather than a second, parallel
/// `getProducts` fetch + its own debounce timer, this reuses the already-
/// loaded `productsProvider` (`ref.read(productsProvider).products`) and
/// filters client-side, since the mobile app already keeps that catalog
/// warm for the sale screen. After a successful save, also refreshes
/// `productsProvider` so cached `Product.modifierGroups` stays accurate,
/// matching what `modifier_management.dart`'s caller already does.
class MobileModifierProductAssignmentScreen extends ConsumerStatefulWidget {
  final ModifierGroupResponse group;

  const MobileModifierProductAssignmentScreen({super.key, required this.group});

  @override
  ConsumerState<MobileModifierProductAssignmentScreen> createState() =>
      _MobileModifierProductAssignmentScreenState();
}

class _MobileModifierProductAssignmentScreenState
    extends ConsumerState<MobileModifierProductAssignmentScreen> {
  final TextEditingController _searchCtl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Product> _products = const [];
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final assignedIds =
          await ref.read(modifierServiceProvider).getGroupProducts(widget.group.id);

      var products = ref.read(productsProvider).products;
      if (products.isEmpty) {
        await ref.read(productsProvider.notifier).loadProducts();
        products = ref.read(productsProvider).products;
      }

      if (!mounted) return;

      setState(() {
        _selectedIds
          ..clear()
          ..addAll(assignedIds);
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toggle(int productId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(productId);
      } else {
        _selectedIds.remove(productId);
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(modifierServiceProvider).updateGroupProducts(
            groupId: widget.group.id,
            productIds: _selectedIds.toList(),
          );

      await ref.read(productsProvider.notifier).refresh();

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = ref.watch(appLanguageProvider);
    final groupName = widget.group.localizedName(lang);
    final query = _searchCtl.text.trim().toLowerCase();

    final visible = query.isEmpty
        ? _products
        : _products.where((p) {
            return p.nameEn.toLowerCase().contains(query) ||
                p.nameKm.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.modifierProductAssignmentTitle(groupName),
        ),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.commonSave),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _products.isEmpty
              ? _buildErrorState()
              : _buildContent(l10n, lang, visible),
    );
  }

  Widget _buildErrorState() {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PosTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: PosTheme.errorRed),
            const SizedBox(height: PosTheme.spacingMd),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: PosTheme.spacingLg),
            FilledButton(
              onPressed: _loadInitial,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(dynamic l10n, AppLanguage lang, List<Product> visible) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PosTheme.spacingMd,
            PosTheme.spacingMd,
            PosTheme.spacingMd,
            PosTheme.spacingSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.modifierProductAssignmentDescription,
                style: TextStyle(
                  fontSize: PosTheme.fontSizeXs,
                  color: PosTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: PosTheme.spacingMd),
              TextField(
                controller: _searchCtl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.posSearchProducts,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                  ),
                ),
              ),
              const SizedBox(height: PosTheme.spacingSm),
              Text(
                l10n.modifierProductAssignmentSelectedCount(_selectedIds.length),
                style: TextStyle(
                  fontSize: PosTheme.fontSizeXs,
                  color: PosTheme.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PosTheme.spacingMd),
            child: Text(
              _error!,
              style: TextStyle(color: PosTheme.errorRed, fontSize: PosTheme.fontSizeXs),
            ),
          ),
        Expanded(
          child: visible.isEmpty
              ? Center(child: Text(l10n.modifierProductAssignmentNoProducts))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PosTheme.spacingMd,
                    vertical: PosTheme.spacingSm,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    return _buildProductTile(visible[i], lang);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductTile(Product product, AppLanguage lang) {
    final selected = _selectedIds.contains(product.id);
    final name = product.localizedName(lang);
    final categoryName = product.localizedCategoryName(lang);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(
          color: selected ? PosTheme.primaryGreen : PosTheme.borderColorOf(context),
        ),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: (v) => _toggle(product.id, v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(name),
        subtitle: Text(
          '${formatAmount(product.price, watchCurrency(ref))}'
          '${categoryName != null ? ' · $categoryName' : ''}',
          style: const TextStyle(fontSize: PosTheme.fontSizeXs),
        ),
      ),
    );
  }
}
