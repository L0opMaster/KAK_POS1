import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/product_provider.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';

class _DraftLine {
  _DraftLine() : qtyCtl = TextEditingController(text: '1');
  Product? product;
  final TextEditingController qtyCtl;
}

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// create_transfer_order.dart` — COPY/ADAPT NEARLY EXACTLY: no from/to
/// store selected → block with `createTransferOrderSelectBothStores`,
/// same store on both sides → block with
/// `createTransferOrderStoresMustDiffer`, no valid line (product + qty>0)
/// → block with `inventoryLinesAddAtLeastOne`. Product picker is
/// UNFILTERED (uses the full product catalog, unlike Purchase Orders'
/// `purchasable && trackInventory` filter — matching source exactly:
/// `TransferOrderLine` has no `unitCost`/line-note field, so there's no
/// cost field here either, only quantity. Create-only — source's
/// `CreateTransferOrder` has no edit mode.
class MobileCreateTransferOrderScreen extends ConsumerStatefulWidget {
  const MobileCreateTransferOrderScreen({super.key});

  @override
  ConsumerState<MobileCreateTransferOrderScreen> createState() =>
      _MobileCreateTransferOrderScreenState();
}

class _MobileCreateTransferOrderScreenState
    extends ConsumerState<MobileCreateTransferOrderScreen> {
  int? _fromStoreId;
  int? _toStoreId;
  final _notesCtl = TextEditingController();
  final List<_DraftLine> _lines = [_DraftLine()];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(locationsProvider.notifier).loadLocations(),
    );
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    for (final l in _lines) {
      l.qtyCtl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_fromStoreId == null || _toStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.createTransferOrderSelectBothStores),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }
    if (_fromStoreId == _toStoreId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.createTransferOrderStoresMustDiffer),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }
    final validLines = _lines
        .where((l) {
          final qty = double.tryParse(l.qtyCtl.text);
          return l.product != null && qty != null && qty > 0;
        })
        .map(
          (l) => TransferOrderLine(
            productId: l.product!.id,
            quantity: double.parse(l.qtyCtl.text),
          ),
        )
        .toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.inventoryLinesAddAtLeastOne),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(transferOrdersProvider.notifier)
          .createOrder(
            TransferOrder(
              fromStoreId: _fromStoreId!,
              toStoreId: _toStoreId!,
              notes: _notesCtl.text.trim().isEmpty
                  ? null
                  : _notesCtl.text.trim(),
              lines: validLines,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.createTransferOrderCreated)),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.inventoryFailedToSave('$e')),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final stores = ref.watch(locationsProvider).valueOrNull ?? const [];
    final products = ref.watch(productsProvider).products;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createTransferOrderTitle)),
      body: ListView(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _fromStoreId,
            decoration: InputDecoration(
              labelText: l10n.createTransferOrderFromStore,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final s in stores)
                if (s.id != null)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _fromStoreId = v),
          ),
          const SizedBox(height: PosTheme.spacingMd),
          DropdownButtonFormField<int>(
            initialValue: _toStoreId,
            decoration: InputDecoration(
              labelText: l10n.createTransferOrderToStore,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final s in stores)
                if (s.id != null)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _toStoreId = v),
          ),
          const SizedBox(height: PosTheme.spacingMd),
          TextField(
            controller: _notesCtl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.inventoryNotesLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PosTheme.spacingLg),
          Text(
            l10n.inventoryLinesLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: PosTheme.spacingSm),
          for (var i = 0; i < _lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: PosTheme.spacingSm),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<Product>(
                      initialValue: _lines[i].product,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.inventoryProductLabel,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final p in products)
                          DropdownMenuItem(
                            value: p,
                            child: Text(
                              p.localizedName(language),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _lines[i].product = v),
                    ),
                  ),
                  const SizedBox(width: PosTheme.spacingXs),
                  Expanded(
                    child: TextField(
                      controller: _lines[i].qtyCtl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.cartQty,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: PosTheme.errorRed,
                    onPressed: _lines.length <= 1
                        ? null
                        : () => setState(() {
                            _lines[i].qtyCtl.dispose();
                            _lines.removeAt(i);
                          }),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _lines.add(_DraftLine())),
            icon: const Icon(Icons.add),
            label: Text(l10n.inventoryAddLine),
          ),
          const SizedBox(height: PosTheme.spacingLg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
