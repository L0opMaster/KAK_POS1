import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';

Color _statusColor(CountStatus status) {
  switch (status) {
    case CountStatus.draft:
      return PosTheme.textSecondary;
    case CountStatus.inProgress:
      return PosTheme.warningAmber;
    case CountStatus.completed:
      return PosTheme.successGreen;
    case CountStatus.cancelled:
      return PosTheme.errorRed;
  }
}

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// inventory_counts_screen.dart` — logic COPY/ADAPT NEARLY EXACTLY: same
/// `inventoryCountProvider` workflow (Start Count when empty, per-item
/// counted-quantity entry gated on `snapshotId != null`, Post Count with a
/// confirmation dialog and — matching source exactly — no client-side
/// check that every item has been counted before allowing post). Status
/// label text (`CountStatusExt.label`) is deliberately not localized here
/// either — it isn't in source, which hardcodes English 'Draft'/'In
/// Progress'/etc. Desktop's paged rows become a plain scrolling list
/// (MOBILE UI REIMPLEMENT). Print/save-PDF (count sheet + count report)
/// deferred to Day 18.
class MobileInventoryCountsScreen extends ConsumerStatefulWidget {
  const MobileInventoryCountsScreen({super.key});

  @override
  ConsumerState<MobileInventoryCountsScreen> createState() =>
      _MobileInventoryCountsScreenState();
}

class _MobileInventoryCountsScreenState
    extends ConsumerState<MobileInventoryCountsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(inventoryCountProvider.notifier).load());
  }

  Future<void> _editCount(InventoryCountItem item) async {
    if (item.snapshotId == null) return;
    final l10n = context.l10n;
    final countedCtl = TextEditingController(
      text: item.countedStock.toStringAsFixed(0),
    );
    final notesCtl = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> save() async {
            final counted = double.tryParse(countedCtl.text.trim());
            if (counted == null || counted < 0) {
              setState(
                () => error = l10n.inventoryCountsEnterValidQuantity,
              );
              return;
            }
            try {
              await ref
                  .read(inventoryCountProvider.notifier)
                  .recordEntry(
                    snapshotId: item.snapshotId!,
                    countedQuantity: counted,
                    notes: notesCtl.text.trim().isEmpty
                        ? null
                        : notesCtl.text.trim(),
                  );
              if (context.mounted) Navigator.of(dialogContext).pop();
            } catch (e) {
              setState(() => error = l10n.inventoryFailedToSave('$e'));
            }
          }

          return AlertDialog(
            title: Text(item.productName),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${l10n.inventoryCountsExpectedPrefix} '
                  '${item.expectedStock.toStringAsFixed(0)}',
                  style: TextStyle(color: PosTheme.textSecondaryOf(context)),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextField(
                  controller: countedCtl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.inventoryCountsCountedQtyLabel,
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextField(
                  controller: notesCtl,
                  decoration: InputDecoration(
                    labelText: l10n.inventoryNotesLabel,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: PosTheme.spacingSm),
                  Text(error!, style: TextStyle(color: PosTheme.errorRed)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(onPressed: save, child: Text(l10n.commonSave)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmPost() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inventoryCountsPostDialogTitle),
        content: Text(l10n.inventoryCountsPostDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PosTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.inventoryCountsPostAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(inventoryCountProvider.notifier).post();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inventoryCountsPostedSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
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
    final state = ref.watch(inventoryCountProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inventoryCountsTitle)),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (count) {
          final items = count?.items ?? const <InventoryCountItem>[];
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.playlist_add_check_rounded,
                    size: 48,
                    color: PosTheme.textHintOf(context),
                  ),
                  const SizedBox(height: PosTheme.spacingMd),
                  Text(l10n.inventoryCountsEmptyTitle),
                  const SizedBox(height: PosTheme.spacingXs),
                  Text(
                    l10n.inventoryCountsEmptySubtitle,
                    style: TextStyle(
                      color: PosTheme.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: PosTheme.spacingLg),
                  FilledButton(
                    onPressed: () =>
                        ref.read(inventoryCountProvider.notifier).startCount(),
                    child: Text(l10n.inventoryCountsStartCount),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              if (count != null)
                Padding(
                  padding: const EdgeInsets.all(PosTheme.spacingMd),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(
                          count.status,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          PosTheme.radiusPill,
                        ),
                      ),
                      child: Text(
                        count.status.label.toUpperCase(),
                        style: TextStyle(
                          color: _statusColor(count.status),
                          fontWeight: FontWeight.w700,
                          fontSize: PosTheme.fontSizeXs,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(inventoryCountProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PosTheme.spacingMd,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final hasDiscrepancy = item.discrepancy != 0;
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
                          title: Text(item.productName),
                          subtitle: Text(
                            '${l10n.inventoryCountsExpectedPrefix} '
                            '${item.expectedStock.toStringAsFixed(0)} • '
                            '${item.countedStock.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: PosTheme.fontSizeXs,
                              color: PosTheme.textSecondaryOf(context),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasDiscrepancy)
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PosTheme.warningAmber.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      PosTheme.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    item.discrepancy > 0
                                        ? '+${item.discrepancy.toStringAsFixed(0)}'
                                        : item.discrepancy.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: PosTheme.warningAmber,
                                      fontWeight: FontWeight.w600,
                                      fontSize: PosTheme.fontSizeXs,
                                    ),
                                  ),
                                ),
                              IconButton(
                                tooltip: l10n.inventoryCountsEnterCountTooltip,
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: item.snapshotId == null
                                    ? null
                                    : () => _editCount(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (count != null && count.status != CountStatus.completed)
                Padding(
                  padding: const EdgeInsets.all(PosTheme.spacingMd),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _confirmPost,
                      child: Text(l10n.inventoryCountsPostCountButton),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
