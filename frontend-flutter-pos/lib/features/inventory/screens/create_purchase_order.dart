import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/product_provider.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';

class _DraftLine {
  Product? product;
  final TextEditingController qtyCtl = TextEditingController(text: '1');
  final TextEditingController costCtl = TextEditingController(text: '0');
}

class CreatePurchaseOrder extends ConsumerStatefulWidget {
  const CreatePurchaseOrder({super.key});

  @override
  ConsumerState<CreatePurchaseOrder> createState() =>
      _CreatePurchaseOrderState();
}

class _CreatePurchaseOrderState extends ConsumerState<CreatePurchaseOrder> {
  final _notesCtl = TextEditingController();
  final _taxRateCtl = TextEditingController(text: '0');
  int? _supplierId;
  int? _storeId;
  DateTime? _orderDeadline;
  DateTime? _expectedArrival;
  final List<_DraftLine> _lines = [_DraftLine()];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(suppliersProvider.notifier).loadSuppliers();
      await ref.read(locationsProvider.notifier).loadLocations();
      await ref.read(productsProvider.notifier).loadProducts();
    });
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    _taxRateCtl.dispose();
    for (final line in _lines) {
      line.qtyCtl.dispose();
      line.costCtl.dispose();
    }
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_DraftLine()));

  void _removeLine(int index) {
    setState(() {
      _lines[index].qtyCtl.dispose();
      _lines[index].costCtl.dispose();
      _lines.removeAt(index);
    });
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
  }

  Future<void> _save() async {
    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.createPurchaseOrderSelectSupplier),
            backgroundColor: PosTheme.errorRed),
      );
      return;
    }

    final validLines = <PurchaseOrderLine>[];
    for (final line in _lines) {
      final qty = double.tryParse(line.qtyCtl.text.trim());
      final cost = double.tryParse(line.costCtl.text.trim());
      if (line.product == null || qty == null || qty <= 0) continue;
      validLines.add(PurchaseOrderLine(
        productId: line.product!.id,
        quantity: qty,
        unitCost: cost ?? 0,
      ));
    }
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.inventoryLinesAddAtLeastOne),
            backgroundColor: PosTheme.errorRed),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(purchaseOrdersProvider.notifier).createOrder(
            PurchaseOrder(
              supplierId: _supplierId!,
              storeId: _storeId,
              orderDeadline: _orderDeadline,
              expectedArrival: _expectedArrival,
              taxRate: double.tryParse(_taxRateCtl.text.trim()) ?? 0,
              notes:
                  _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
              lines: validLines,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.createPurchaseOrderCreated),
            backgroundColor: PosTheme.successGreen),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.inventoryFailedToSave('$e')),
            backgroundColor: PosTheme.errorRed),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final suppliers =
        ref.watch(suppliersProvider).valueOrNull ?? const <Supplier>[];
    final locations =
        ref.watch(locationsProvider).valueOrNull ?? const <StoreLocation>[];
    // Only products the backend will actually accept on a PO line
    // (PurchasingWorkflowService requires purchasable AND trackInventory)
    // — otherwise a product could be selected here and only rejected on
    // Save, with the user having no idea why.
    final products = ref
        .watch(productsProvider)
        .products
        .where((p) => p.purchasable && p.trackInventory)
        .toList();
    final lang = ref.watch(appLanguageProvider);
    final currencyCode = watchCurrency(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.createPurchaseOrderTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    context.l10n.commonSave,
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _supplierId,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: context.l10n.createPurchaseOrderSupplierLabel,
                border: const OutlineInputBorder()),
            items: suppliers
                .where((s) => s.id != null)
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _supplierId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _storeId,
            decoration: InputDecoration(
                labelText: context.l10n.createPurchaseOrderDeliverToStore,
                border: const OutlineInputBorder()),
            items: locations
                .where((l) => l.id != null)
                .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                .toList(),
            onChanged: (v) => setState(() => _storeId = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await _pickDate(_orderDeadline);
                    if (picked != null) setState(() => _orderDeadline = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.l10n.createPurchaseOrderOrderDeadline,
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(_orderDeadline == null
                        ? context.l10n.inventoryNotSet
                        : _fmtDate(_orderDeadline!)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await _pickDate(_expectedArrival);
                    if (picked != null)
                      setState(() => _expectedArrival = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.l10n.createPurchaseOrderExpectedArrival,
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(_expectedArrival == null
                        ? context.l10n.inventoryNotSet
                        : _fmtDate(_expectedArrival!)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _taxRateCtl,
                  decoration: InputDecoration(
                      labelText: context.l10n.createPurchaseOrderTaxRate,
                      border: const OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _notesCtl,
                  decoration: InputDecoration(
                      labelText: context.l10n.inventoryNotesLabel,
                      border: const OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(context.l10n.inventoryLinesLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.inventoryAddLine),
              ),
            ],
          ),
          const Divider(),
          for (int i = 0; i < _lines.length; i++) _buildLineRow(i, products, lang),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${context.l10n.cartSubtotal}: ${formatAmount(_computeSubtotal(), currencyCode)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  double _computeSubtotal() {
    double total = 0;
    for (final line in _lines) {
      final qty = double.tryParse(line.qtyCtl.text.trim()) ?? 0;
      final cost = double.tryParse(line.costCtl.text.trim()) ?? 0;
      total += qty * cost;
    }
    return total;
  }

  Widget _buildLineRow(int index, List<Product> products, AppLanguage lang) {
    final line = _lines[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<Product>(
              initialValue: line.product,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: context.l10n.inventoryProductLabel,
                  border: const OutlineInputBorder(),
                  isDense: true),
              items: products
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.localizedName(lang),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => line.product = value),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: line.qtyCtl,
              decoration: InputDecoration(
                  labelText: context.l10n.cartQty,
                  border: const OutlineInputBorder(),
                  isDense: true),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: line.costCtl,
              decoration: InputDecoration(
                  labelText: context.l10n.createPurchaseOrderUnitCost,
                  border: const OutlineInputBorder(),
                  isDense: true),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: PosTheme.errorRed),
            onPressed: _lines.length > 1 ? () => _removeLine(index) : null,
          ),
        ],
      ),
    );
  }
}
