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
  _DraftLine({String qty = '1', String cost = '0'})
    : qtyCtl = TextEditingController(text: qty),
      costCtl = TextEditingController(text: cost);

  Product? product;
  final TextEditingController qtyCtl;
  final TextEditingController costCtl;
}

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// create_purchase_order.dart` — COPY/ADAPT NEARLY EXACTLY: no supplier
/// selected → block with `createPurchaseOrderSelectSupplier`, no valid
/// line (product + qty>0; unitCost defaults to 0 if unparseable, never
/// blocks) → block with `inventoryLinesAddAtLeastOne`, product picker
/// filtered to `purchasable && trackInventory` (matching source's own
/// documented reasoning: the backend rejects any PO line for a product
/// that isn't both). Live subtotal = Σ(qty × cost), recomputed on every
/// field change, not server-derived. No edit mode — source's own
/// `CreatePurchaseOrder` is create-only too (status transitions, not
/// field edits, are how a PO changes after creation).
class MobileCreatePurchaseOrderScreen extends ConsumerStatefulWidget {
  const MobileCreatePurchaseOrderScreen({super.key});

  @override
  ConsumerState<MobileCreatePurchaseOrderScreen> createState() =>
      _MobileCreatePurchaseOrderScreenState();
}

class _MobileCreatePurchaseOrderScreenState
    extends ConsumerState<MobileCreatePurchaseOrderScreen> {
  int? _supplierId;
  int? _storeId;
  DateTime? _orderDeadline;
  DateTime? _expectedArrival;
  final _taxRateCtl = TextEditingController(text: '0');
  final _notesCtl = TextEditingController();
  final List<_DraftLine> _lines = [_DraftLine()];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(suppliersProvider.notifier).loadSuppliers();
      ref.read(locationsProvider.notifier).loadLocations();
    });
  }

  @override
  void dispose() {
    _taxRateCtl.dispose();
    _notesCtl.dispose();
    for (final l in _lines) {
      l.qtyCtl.dispose();
      l.costCtl.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold<double>(0, (sum, l) {
    final qty = double.tryParse(l.qtyCtl.text) ?? 0;
    final cost = double.tryParse(l.costCtl.text) ?? 0;
    return sum + qty * cost;
  });

  Future<void> _pickDate({required bool isDeadline}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isDeadline) {
        _orderDeadline = picked;
      } else {
        _expectedArrival = picked;
      }
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.createPurchaseOrderSelectSupplier),
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
          (l) => PurchaseOrderLine(
            productId: l.product!.id,
            quantity: double.parse(l.qtyCtl.text),
            unitCost: double.tryParse(l.costCtl.text) ?? 0,
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
          .read(purchaseOrdersProvider.notifier)
          .createOrder(
            PurchaseOrder(
              supplierId: _supplierId!,
              storeId: _storeId,
              orderDeadline: _orderDeadline,
              expectedArrival: _expectedArrival,
              taxRate: double.tryParse(_taxRateCtl.text) ?? 0,
              notes: _notesCtl.text.trim().isEmpty
                  ? null
                  : _notesCtl.text.trim(),
              lines: validLines,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.createPurchaseOrderCreated)),
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
    final suppliers = ref.watch(suppliersProvider).valueOrNull ?? const [];
    final stores = ref.watch(locationsProvider).valueOrNull ?? const [];
    final products = ref
        .watch(productsProvider)
        .products
        .where((p) => p.purchasable && p.trackInventory)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createPurchaseOrderTitle)),
      body: ListView(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _supplierId,
            decoration: InputDecoration(
              labelText: l10n.createPurchaseOrderSupplierLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final s in suppliers)
                if (s.id != null)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _supplierId = v),
          ),
          const SizedBox(height: PosTheme.spacingMd),
          DropdownButtonFormField<int>(
            initialValue: _storeId,
            decoration: InputDecoration(
              labelText: l10n.createPurchaseOrderDeliverToStore,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final s in stores)
                if (s.id != null)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _storeId = v),
          ),
          const SizedBox(height: PosTheme.spacingMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isDeadline: true),
                  child: Text(
                    _orderDeadline == null
                        ? l10n.createPurchaseOrderOrderDeadline
                        : '${l10n.createPurchaseOrderOrderDeadline}: '
                              '${_orderDeadline!.toIso8601String().split('T').first}',
                  ),
                ),
              ),
              const SizedBox(width: PosTheme.spacingSm),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isDeadline: false),
                  child: Text(
                    _expectedArrival == null
                        ? l10n.createPurchaseOrderExpectedArrival
                        : '${l10n.createPurchaseOrderExpectedArrival}: '
                              '${_expectedArrival!.toIso8601String().split('T').first}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PosTheme.spacingMd),
          TextField(
            controller: _taxRateCtl,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: l10n.createPurchaseOrderTaxRate,
              border: const OutlineInputBorder(),
            ),
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
                crossAxisAlignment: CrossAxisAlignment.center,
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
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.cartQty,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: PosTheme.spacingXs),
                  Expanded(
                    child: TextField(
                      controller: _lines[i].costCtl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.createPurchaseOrderUnitCost,
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
                            _lines[i].costCtl.dispose();
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
          const SizedBox(height: PosTheme.spacingMd),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${l10n.cartSubtotal}: ${_subtotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
