import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';
import 'create_transfer_order.dart';

class TransferOrdersScreen extends ConsumerStatefulWidget {
  const TransferOrdersScreen({super.key});

  @override
  ConsumerState<TransferOrdersScreen> createState() => _TransferOrdersScreenState();
}

class _TransferOrdersScreenState extends ConsumerState<TransferOrdersScreen> {
  static const int _pageSize = 8;
  int _currentPage = 0;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(transferOrdersProvider.notifier).loadOrders();
      if (mounted) setState(() => _hasLoadedOnce = true);
    });
  }

  Future<void> _openCreate() async {
    final result = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const CreateTransferOrder()));
    if (result == true && mounted) setState(() => _currentPage = 0);
  }

  Future<void> _complete(TransferOrder order) async {
    try {
      await ref.read(transferOrdersProvider.notifier).completeOrder(order.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.transferOrdersCompletedSnackbar),
              backgroundColor: PosTheme.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.transferOrdersFailedToComplete('$e')),
              backgroundColor: PosTheme.errorRed),
        );
      }
    }
  }

  Future<void> _cancel(TransferOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.transferOrdersCancelTitle),
        content: Text(context.l10n
            .transferOrdersCancelConfirm(order.transferNumber ?? '#${order.id}')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.inventoryKeepButton)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.transferOrdersCancelTransferButton,
                style: const TextStyle(color: Colors.red)),
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
              content: Text(context.l10n.transferOrdersFailedToCancel('$e')),
              backgroundColor: PosTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.transferOrdersTitle),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            onPressed: () => ref.read(transferOrdersProvider.notifier).loadOrders(),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          data: (orders) {
            if (orders.isEmpty && _hasLoadedOnce) return _buildEmptyState();
            return _buildList(orders, loading: false);
          },
          loading: () {
            if (!_hasLoadedOnce) return const Center(child: CircularProgressIndicator());
            return _buildList(const [], loading: true);
          },
          error: (e, _) => _buildErrorState('$e'),
        ),
      ),
    );
  }

  Widget _buildList(List<TransferOrder> allOrders, {required bool loading}) {
    final sorted = [...allOrders]
      ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    final totalItems = sorted.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);
    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageOrders = sorted.sublist(startIndex, endIndex);

    return RefreshIndicator(
      onRefresh: () => ref.read(transferOrdersProvider.notifier).loadOrders(),
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
                      ElevatedButton.icon(
                        onPressed: _openCreate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(180, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.transferOrdersNewButton,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(context.l10n.transferOrdersCount('${sorted.length}'),
                          style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (pageOrders.isEmpty)
                  _buildNoResults(loading: loading)
                else
                  ...pageOrders.map(_buildRow),
                if (pageOrders.isNotEmpty)
                  _buildPagination(currentPage: safeCurrentPage, totalPages: totalPages, totalItems: totalItems),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults({required bool loading}) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(context.l10n.transferOrdersNoTransfersFound,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(TransferOrder order) {
    final status = order.status.toUpperCase();
    final canAct = status == 'DRAFT' || status == 'PENDING' || status == 'IN_TRANSIT';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF99D267),
                child: Icon(Icons.swap_horiz, color: Colors.white),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        order.transferNumber ??
                            context.l10n.transferOrdersTransferFallback('${order.id}'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${order.fromStoreName ?? order.fromStoreId} → ${order.toStoreName ?? order.toStoreId} • '
                      '${context.l10n.inventoryLineCount('${order.totalItems}')}',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status))),
              ),
              if (canAct && order.id != null) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'complete') _complete(order);
                    if (value == 'cancel') _cancel(order);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: 'complete',
                        child: Text(context.l10n.transferOrdersMarkComplete)),
                    PopupMenuItem(
                        value: 'cancel', child: Text(context.l10n.commonCancel)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RECEIVED':
      case 'COMPLETED':
        return PosTheme.successGreen;
      case 'CANCELLED':
        return PosTheme.errorRed;
      case 'IN_TRANSIT':
        return PosTheme.warningAmber;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPagination({required int currentPage, required int totalPages, required int totalItems}) {
    final firstItem = totalItems == 0 ? 0 : currentPage * _pageSize + 1;
    final lastItem = math.min((currentPage + 1) * _pageSize, totalItems);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
              context.l10n
                  .inventoryPaginationRange('$firstItem', '$lastItem', '$totalItems'),
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 20),
          IconButton(
            onPressed: currentPage == 0 ? null : () => setState(() => _currentPage = 0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            onPressed: currentPage == 0 ? null : () => setState(() => _currentPage = currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 100),
            alignment: Alignment.center,
            child: Text(
                context.l10n.inventoryPaginationPage('${currentPage + 1}', '$totalPages'),
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          IconButton(
            onPressed: currentPage >= totalPages - 1 ? null : () => setState(() => _currentPage = currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            onPressed: currentPage >= totalPages - 1 ? null : () => setState(() => _currentPage = totalPages - 1),
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Card(
            color: Colors.white,
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 45),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                    child: const Icon(Icons.swap_horiz, size: 52, color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
                  Text(context.l10n.transferOrdersTitle,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 18),
                  Text(context.l10n.transferOrdersEmptySubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.black54)),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _openCreate,
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(180, 54)),
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.transferOrdersNewButton,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
              onPressed: () => ref.read(transferOrdersProvider.notifier).loadOrders(),
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
