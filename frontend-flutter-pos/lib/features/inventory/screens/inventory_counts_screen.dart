import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';

/// Inventory Counts — today's stock take: start a count (snapshots every
/// active product's expected quantity), enter what was actually counted
/// per product, then post to apply the variances to stock.
class InventoryCountsScreen extends ConsumerStatefulWidget {
  const InventoryCountsScreen({super.key});

  @override
  ConsumerState<InventoryCountsScreen> createState() =>
      _InventoryCountsScreenState();
}

class _InventoryCountsScreenState extends ConsumerState<InventoryCountsScreen> {
  bool _hasLoadedOnce = false;
  bool _starting = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(inventoryCountProvider.notifier).load();
      if (mounted) setState(() => _hasLoadedOnce = true);
    });
  }

  Future<void> _startCount() async {
    setState(() => _starting = true);
    try {
      await ref.read(inventoryCountProvider.notifier).startCount();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.inventoryCountsFailedToStart('$e')), backgroundColor: PosTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _editCount(InventoryCountItem item) async {
    if (item.snapshotId == null) return;
    final ctl = TextEditingController(
      text: item.countedStock.toStringAsFixed(item.countedStock.truncateToDouble() == item.countedStock ? 0 : 2),
    );
    final notesCtl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final counted = double.tryParse(ctl.text.trim());
              if (counted == null || counted < 0) {
                setDialogState(() => error = context.l10n.inventoryCountsEnterValidQuantity);
                return;
              }
              setDialogState(() {
                saving = true;
                error = null;
              });
              try {
                await ref.read(inventoryCountProvider.notifier).recordEntry(
                      snapshotId: item.snapshotId!,
                      countedQuantity: counted,
                      notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
                    );
                if (context.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() {
                  saving = false;
                  error = context.l10n.inventoryFailedToSave('$e');
                });
              }
            }

            return AlertDialog(
              title: Text(item.productName),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${context.l10n.inventoryCountsExpectedPrefix}: ${item.expectedStock.toStringAsFixed(item.expectedStock.truncateToDouble() == item.expectedStock ? 0 : 2)}',
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.inventoryCountsCountedQtyLabel,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtl,
                      decoration: InputDecoration(
                        labelText: context.l10n.inventoryNotesLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: PosTheme.errorRed)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonCancel.toUpperCase()),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PosTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(context.l10n.commonSave.toUpperCase()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _postCount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.inventoryCountsPostDialogTitle),
        content: Text(
          context.l10n.inventoryCountsPostDialogMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.inventoryCountsPostAction.toUpperCase(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _posting = true);
    try {
      await ref.read(inventoryCountProvider.notifier).post();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.inventoryCountsPostedSuccess), backgroundColor: PosTheme.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.inventoryCountsFailedToPost('$e')), backgroundColor: PosTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryCountProvider);
    final notifier = ref.read(inventoryCountProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.inventoryCountsTitle),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            onPressed: () => notifier.load(),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          data: (count) => _buildContent(count, notifier.snapshotDate),
          loading: () => _hasLoadedOnce
              ? _buildContent(null, notifier.snapshotDate)
              : const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildErrorState('$e'),
        ),
      ),
    );
  }

  Widget _buildContent(InventoryCount? count, String snapshotDate) {
    final items = count?.items ?? const <InventoryCountItem>[];
    final status = count?.status ?? CountStatus.draft;

    return RefreshIndicator(
      onRefresh: () => ref.read(inventoryCountProvider.notifier).load(),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.inventoryCountsForDate(snapshotDate),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.label.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status)),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (items.isEmpty)
                        ElevatedButton.icon(
                          onPressed: _starting ? null : _startCount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PosTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(160, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          ),
                          icon: _starting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.playlist_add_check),
                          label: Text(context.l10n.inventoryCountsStartCount.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        )
                      else if (status != CountStatus.completed)
                        ElevatedButton.icon(
                          onPressed: _posting ? null : _postCount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PosTheme.warningAmber,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(140, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          ),
                          icon: _posting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(context.l10n.inventoryCountsPostCountButton.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.playlist_add_check, size: 44, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(context.l10n.inventoryCountsEmptyTitle,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(context.l10n.inventoryCountsEmptySubtitle,
                              style: const TextStyle(fontSize: 13, color: Colors.black45)),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(context.l10n.navItems,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                        ),
                        Text('${context.l10n.inventoryCountsProductsCount('${count!.itemCount}')} • ${context.l10n.inventoryCountsUnitsOff('${count.totalDiscrepancies}')}',
                            style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...items.map(_buildRow),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(CountStatus status) {
    switch (status) {
      case CountStatus.draft:
        return Colors.grey;
      case CountStatus.inProgress:
        return PosTheme.warningAmber;
      case CountStatus.completed:
        return PosTheme.successGreen;
      case CountStatus.cancelled:
        return PosTheme.errorRed;
    }
  }

  Widget _buildRow(InventoryCountItem item) {
    final discrepancy = item.discrepancy;
    final hasDiscrepancy = discrepancy != 0;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
          title: Text(item.productName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Text(
            'Expected ${_fmt(item.expectedStock)} • Counted ${_fmt(item.countedStock)}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasDiscrepancy)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PosTheme.errorRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${discrepancy > 0 ? '+' : ''}${_fmt(discrepancy)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PosTheme.errorRed),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: context.l10n.inventoryCountsEnterCountTooltip,
                onPressed: () => _editCount(item),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

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
              onPressed: () => ref.read(inventoryCountProvider.notifier).load(),
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
