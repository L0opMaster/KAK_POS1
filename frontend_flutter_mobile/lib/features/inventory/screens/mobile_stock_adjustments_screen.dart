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
import '../services/inventory_service.dart';

const List<String> _kAdjustmentReasons = [
  'Received',
  'Damaged',
  'Lost',
  'Found',
  'Returned',
  'Manual Count',
  'Other',
];

String _reasonLabel(BuildContext context, String reason) {
  final l10n = context.l10n;
  switch (reason) {
    case 'Received':
      return l10n.stockAdjustmentReasonReceived;
    case 'Damaged':
      return l10n.stockAdjustmentReasonDamaged;
    case 'Lost':
      return l10n.stockAdjustmentReasonLost;
    case 'Found':
      return l10n.stockAdjustmentReasonFound;
    case 'Returned':
      return l10n.stockAdjustmentReasonReturned;
    case 'Manual Count':
      return l10n.stockAdjustmentReasonManualCount;
    case 'Other':
      return l10n.stockAdjustmentReasonOther;
    default:
      return reason;
  }
}

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// stock_adjustments_screen.dart` — logic (validation, request shape,
/// fixed reason list) is COPY/ADAPT NEARLY EXACTLY; the desktop's paged
/// `DataTable` + search bar becomes a plain scrolling list (MOBILE UI
/// REIMPLEMENT), search kept as the same client-side product-name/reason
/// filter. Print/save-PDF (an A4 landscape report over the full filtered
/// dataset) is deferred until Day 18 builds the shared `A4ReportPdf`
/// builder this would reuse — not built speculatively ahead of it.
class MobileStockAdjustmentsScreen extends ConsumerStatefulWidget {
  const MobileStockAdjustmentsScreen({super.key});

  @override
  ConsumerState<MobileStockAdjustmentsScreen> createState() =>
      _MobileStockAdjustmentsScreenState();
}

class _MobileStockAdjustmentsScreenState
    extends ConsumerState<MobileStockAdjustmentsScreen> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(movementsProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  /// Ported from source's `_showAddAdjustmentDialog`: the save call itself
  /// runs inside the dialog (not after it closes), with an inline error
  /// message on failure rather than a snackbar — so the cashier can retry
  /// without reopening the dialog and re-entering everything.
  Future<void> _openNewAdjustmentDialog() async {
    final l10n = context.l10n;
    final products = ref.read(productsProvider).products;
    final language = ref.read(appLanguageProvider);
    Product? product;
    String reason = _kAdjustmentReasons.first;
    final qtyCtl = TextEditingController();
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> save() async {
            final qty = double.tryParse(qtyCtl.text.trim());
            if (product == null || qty == null || qty == 0) {
              setState(() => error = l10n.stockAdjustmentsPickProductError);
              return;
            }
            setState(() {
              saving = true;
              error = null;
            });
            try {
              await ref
                  .read(movementsProvider.notifier)
                  .createAdjustment(
                    StockAdjustmentRequest(
                      productId: product!.id,
                      quantity: qty,
                      storeId: defaultInventoryStoreId,
                      reason: reason,
                    ),
                  );
              if (context.mounted) Navigator.of(dialogContext).pop();
            } catch (e) {
              setState(() {
                saving = false;
                error = l10n.inventoryFailedToSave('$e');
              });
            }
          }

          return AlertDialog(
            title: Text(l10n.stockAdjustmentsNewTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Product>(
                    initialValue: product,
                    decoration: InputDecoration(
                      labelText: l10n.stockAdjustmentsProductLabel,
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
                    onChanged: (v) => setState(() => product = v),
                  ),
                  const SizedBox(height: PosTheme.spacingMd),
                  TextField(
                    controller: qtyCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.stockAdjustmentsQuantityChangeLabel,
                      hintText: l10n.stockAdjustmentsQuantityHint,
                    ),
                  ),
                  const SizedBox(height: PosTheme.spacingMd),
                  DropdownButtonFormField<String>(
                    initialValue: reason,
                    decoration: InputDecoration(
                      labelText: l10n.stockAdjustmentsReasonLabel,
                    ),
                    items: [
                      for (final r in _kAdjustmentReasons)
                        DropdownMenuItem(
                          value: r,
                          child: Text(_reasonLabel(ctx, r)),
                        ),
                    ],
                    onChanged: (v) => setState(() => reason = v!),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: PosTheme.spacingSm),
                    Text(error!, style: TextStyle(color: PosTheme.errorRed)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(l10n.commonSave),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(movementsProvider);
    final query = _searchCtl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.posDrawerStockAdjustments)),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewAdjustmentDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PosTheme.spacingMd),
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.stockAdjustmentsSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (movements) {
                final sorted = [...movements]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final visible = query.isEmpty
                    ? sorted
                    : sorted
                          .where(
                            (m) =>
                                m.productName.toLowerCase().contains(query) ||
                                (m.reason ?? '').toLowerCase().contains(query),
                          )
                          .toList();
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      query.isEmpty
                          ? l10n.stockAdjustmentsNoMovements
                          : l10n.stockAdjustmentsNoMatchingMovements,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(movementsProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      PosTheme.spacingMd,
                      0,
                      PosTheme.spacingMd,
                      PosTheme.spacingMd,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final m = visible[i];
                      final positive = m.quantity >= 0;
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(
                          bottom: PosTheme.spacingSm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PosTheme.radiusMedium,
                          ),
                          side: BorderSide(
                            color: PosTheme.borderColorOf(context),
                          ),
                        ),
                        child: ListTile(
                          title: Text(m.productName),
                          subtitle: Text(
                            [
                              m.movementType.replaceAll('_', ' '),
                              if (m.reason != null) m.reason!,
                              if (m.createdBy != null) m.createdBy!,
                            ].join(' • '),
                            style: TextStyle(
                              fontSize: PosTheme.fontSizeXs,
                              color: PosTheme.textSecondaryOf(context),
                            ),
                          ),
                          trailing: Text(
                            '${positive ? '+' : ''}${m.quantity.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: positive
                                  ? PosTheme.successGreen
                                  : PosTheme.errorRed,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
