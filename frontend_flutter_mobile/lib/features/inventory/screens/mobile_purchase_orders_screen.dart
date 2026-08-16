import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/widgets/mobile_status_action_sheet.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';
import 'mobile_create_purchase_order_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// purchase_orders_screen.dart` — `_actionsFor(status)` is COPY/ADAPT
/// NEARLY EXACTLY, copied verbatim (it encodes a real backend-enforced
/// workflow: DRAFT --submit--> SUBMITTED --approve--> APPROVED, any of
/// SUBMITTED/APPROVED --send--> unchanged status (sets sentAt),
/// RECEIVED/PARTIALLY_RECEIVED --close-->; RECEIVED itself only happens
/// via a separate Goods Receipt flow, not built here). Desktop's
/// per-row `PopupMenuButton` becomes `showStatusActionSheet` (MOBILE UI
/// REIMPLEMENT — see that widget's doc comment). Print/save-PDF deferred
/// to Day 18.
class MobilePurchaseOrdersScreen extends ConsumerStatefulWidget {
  const MobilePurchaseOrdersScreen({super.key});

  @override
  ConsumerState<MobilePurchaseOrdersScreen> createState() =>
      _MobilePurchaseOrdersScreenState();
}

List<String> _actionsFor(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT':
      return ['submit', 'cancel'];
    case 'SUBMITTED':
      return ['approve', 'send', 'cancel'];
    case 'APPROVED':
      return ['send', 'cancel'];
    case 'RECEIVED':
    case 'PARTIALLY_RECEIVED':
      return ['send', 'close'];
    default:
      return [];
  }
}

class _MobilePurchaseOrdersScreenState
    extends ConsumerState<MobilePurchaseOrdersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(purchaseOrdersProvider.notifier).loadOrders(),
    );
  }

  String _actionLabel(String action) {
    final l10n = context.l10n;
    switch (action) {
      case 'submit':
        return l10n.commonSubmit;
      case 'approve':
        return l10n.purchaseOrdersActionApprove;
      case 'send':
        return l10n.purchaseOrdersActionSendToSupplier;
      case 'close':
        return l10n.commonClose;
      case 'cancel':
        return l10n.commonCancel;
      default:
        return action;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'submit':
        return Icons.send_outlined;
      case 'approve':
        return Icons.check_circle_outline;
      case 'send':
        return Icons.local_shipping_outlined;
      case 'close':
        return Icons.task_alt_outlined;
      case 'cancel':
        return Icons.cancel_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  Future<void> _handleAction(PurchaseOrder order, String action) async {
    final l10n = context.l10n;
    if (action == 'cancel') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.purchaseOrdersCancelTitle),
          content: Text(
            l10n.purchaseOrdersCancelConfirm(
              order.referenceNumber ?? '#${order.id}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.inventoryKeepButton),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PosTheme.errorRed,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.inventoryCancelOrderButton),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref
          .read(purchaseOrdersProvider.notifier)
          .transition(order.id!, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseOrdersActionDoneSnackbar(action)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.inventoryActionFailed('$e')),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchaseOrdersTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.purchaseOrdersNewButton,
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const MobileCreatePurchaseOrderScreen(),
            ),
          );
          if (created == true) {
            ref.read(purchaseOrdersProvider.notifier).loadOrders();
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
                  Text(l10n.purchaseOrdersNoOrdersFound),
                  const SizedBox(height: PosTheme.spacingXs),
                  Text(
                    l10n.purchaseOrdersEmptySubtitle,
                    style: TextStyle(
                      color: PosTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(purchaseOrdersProvider.notifier).loadOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              itemCount: orders.length,
              itemBuilder: (context, i) {
                final order = orders[i];
                final actions = _actionsFor(order.status);
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
                      order.referenceNumber ??
                          l10n.purchaseOrdersPoFallback('${order.id}'),
                    ),
                    subtitle: Text(
                      '${order.supplierName ?? l10n.purchaseOrdersSupplierFallback('${order.supplierId}')} • '
                      '${order.status}',
                      style: TextStyle(
                        fontSize: PosTheme.fontSizeXs,
                        color: PosTheme.textSecondaryOf(context),
                      ),
                    ),
                    trailing: order.id == null || actions.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () async {
                              final action = await showStatusActionSheet(
                                context,
                                title:
                                    order.referenceNumber ??
                                    l10n.purchaseOrdersPoFallback(
                                      '${order.id}',
                                    ),
                                actions: actions,
                                labelFor: _actionLabel,
                                iconFor: _actionIcon,
                                destructiveActions: const {'cancel'},
                              );
                              if (action != null) {
                                _handleAction(order, action);
                              }
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
