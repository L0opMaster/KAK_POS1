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
  Product? product;
  final TextEditingController qtyCtl = TextEditingController(text: '1');
}

class CreateTransferOrder extends ConsumerStatefulWidget {
  const CreateTransferOrder({super.key});

  @override
  ConsumerState<CreateTransferOrder> createState() => _CreateTransferOrderState();
}

class _CreateTransferOrderState extends ConsumerState<CreateTransferOrder> {
  final _notesCtl = TextEditingController();
  int? _fromStoreId;
  int? _toStoreId;
  final List<_DraftLine> _lines = [_DraftLine()];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(locationsProvider.notifier).loadLocations();
      await ref.read(productsProvider.notifier).loadProducts();
    });
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    for (final line in _lines) {
      line.qtyCtl.dispose();
    }
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_DraftLine()));

  void _removeLine(int index) {
    setState(() {
      _lines[index].qtyCtl.dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_fromStoreId == null || _toStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createTransferOrderSelectBothStores), backgroundColor: PosTheme.errorRed),
      );
      return;
    }
    if (_fromStoreId == _toStoreId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.createTransferOrderStoresMustDiffer), backgroundColor: PosTheme.errorRed),
      );
      return;
    }

    final validLines = <TransferOrderLine>[];
    for (final line in _lines) {
      final qty = double.tryParse(line.qtyCtl.text.trim());
      if (line.product == null || qty == null || qty <= 0) continue;
      validLines.add(TransferOrderLine(productId: line.product!.id, quantity: qty));
    }
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.inventoryLinesAddAtLeastOne), backgroundColor: PosTheme.errorRed),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(transferOrdersProvider.notifier).createOrder(
            TransferOrder(
              fromStoreId: _fromStoreId!,
              toStoreId: _toStoreId!,
              notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
              lines: validLines,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createTransferOrderCreated), backgroundColor: PosTheme.successGreen),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.inventoryFailedToSave('$e')), backgroundColor: PosTheme.errorRed),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider).valueOrNull ?? const <StoreLocation>[];
    final products = ref.watch(productsProvider).products;
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.createTransferOrderTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.l10n.commonSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _fromStoreId,
                  decoration: InputDecoration(labelText: context.l10n.createTransferOrderFromStore, border: const OutlineInputBorder()),
                  items: locations
                      .where((l) => l.id != null)
                      .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _fromStoreId = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _toStoreId,
                  decoration: InputDecoration(labelText: context.l10n.createTransferOrderToStore, border: const OutlineInputBorder()),
                  items: locations
                      .where((l) => l.id != null)
                      .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _toStoreId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesCtl,
            decoration: InputDecoration(labelText: context.l10n.inventoryNotesLabel, border: const OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(context.l10n.inventoryLinesLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        ],
      ),
    );
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
              decoration: InputDecoration(labelText: context.l10n.inventoryProductLabel, border: const OutlineInputBorder(), isDense: true),
              items: products
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.localizedName(lang), overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => line.product = value),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: line.qtyCtl,
              decoration: InputDecoration(labelText: context.l10n.cartQty, border: const OutlineInputBorder(), isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
