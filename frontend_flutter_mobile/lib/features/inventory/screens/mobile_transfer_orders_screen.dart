import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/widgets/mobile_status_action_sheet.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';
import 'mobile_create_transfer_order_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// transfer_orders_screen.dart` — COPY/ADAPT NEARLY EXACTLY: an order is
/// actionable (`DRAFT`/`PENDING`/`IN_TRANSIT`) shows exactly the same two
/// fixed actions (`complete`, `cancel`) regardless of which of those three
/// statuses it's in — no separate `_actionsFor`-per-status table exists in
/// source for transfers, unlike Purchase Orders. `complete` fires
/// immediately (no confirm dialog) with a success snackbar on completion;
/// `cancel` requires a confirm dialog and — matching a real asymmetry in
/// source, preserved deliberately rather than "fixed" — has NO success
/// snackbar on completion, only a failure one. List sorted client-side by
/// `createdAt` descending. Desktop's per-row `PopupMenuButton` becomes
/// `showStatusActionSheet` (MOBILE UI REIMPLEMENT). Print/save-PDF
/// deferred to Day 18.
class MobileTransferOrdersScreen extends ConsumerStatefulWidget {
  const MobileTransferOrdersScreen({super.key});

  @override
  ConsumerState<MobileTransferOrdersScreen> createState() =>
      _MobileTransferOrdersScreenState();
}

class _MobileTransferOrdersScreenState
    extends ConsumerState<MobileTransferOrdersScreen> {
  static const _actionableStatuses = {'DRAFT', 'PENDING', 'IN_TRANSIT'};

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(transferOrdersProvider.notifier).loadOrders(),
    );
  }

  Future<void> _complete(TransferOrder order) async {
    final l10n = context.l10n;
    try {
      await ref
          .read(transferOrdersProvider.notifier)
          .completeOrder(order.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.transferOrdersCompletedSnackbar)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.transferOrdersFailedToComplete}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _cancel(TransferOrder order) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.transferOrdersCancelTitle),
        content: Text(
          l10n.transferOrdersCancelConfirm(
            order.transferNumber ?? '#${order.id}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.inventoryKeepButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PosTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.transferOrdersCancelTransferButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(transferOrdersProvider.notifier).cancelOrder(order.id!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.transferOrdersFailedToCancel}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(transferOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transferOrdersTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.transferOrdersNewButton,
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const MobileCreateTransferOrderScreen(),
            ),
          );
          if (created == true) {
            ref.read(transferOrdersProvider.notifier).loadOrders();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.transferOrdersNoTransfersFound),
                  const SizedBox(height: PosTheme.spacingXs),
                  Text(
                    l10n.transferOrdersEmptySubtitle,
                    style: TextStyle(
                      color: PosTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            );
          }
          final sorted = [...orders]..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(transferOrdersProvider.notifier).loadOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final order = sorted[i];
                final canAct =
                    _actionableStatuses.contains(order.status.toUpperCase()) &&
                    order.id != null;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      PosTheme.radiusMedium,
                    ),
                    side: BorderSide(color: PosTheme.borderColorOf(context)),
                  ),
                  child: ListTile(
                    title: Text(
                      order.transferNumber ??
                          l10n.transferOrdersTransferFallback('${order.id}'),
                    ),
                    subtitle: Text(
                      '${order.fromStoreName ?? order.fromStoreId} → '
                      '${order.toStoreName ?? order.toStoreId} • '
                      '${order.status}',
                      style: TextStyle(
                        fontSize: PosTheme.fontSizeXs,
                        color: PosTheme.textSecondaryOf(context),
                      ),
                    ),
                    trailing: !canAct
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () async {
                              final action = await showStatusActionSheet(
                                context,
                                title:
                                    order.transferNumber ??
                                    l10n.transferOrdersTransferFallback(
                                      '${order.id}',
                                    ),
                                actions: const ['complete', 'cancel'],
                                labelFor: (a) => a == 'complete'
                                    ? l10n.transferOrdersMarkComplete
                                    : l10n.commonCancel,
                                iconFor: (a) => a == 'complete'
                                    ? Icons.task_alt_outlined
                                    : Icons.cancel_outlined,
                                destructiveActions: const {'cancel'},
                              );
                              if (action == 'complete') _complete(order);
                              if (action == 'cancel') _cancel(order);
                            },
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
