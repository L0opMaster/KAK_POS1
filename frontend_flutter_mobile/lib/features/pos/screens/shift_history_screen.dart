import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/receipt_date_format.dart';
import '../models/shift_model.dart';
import '../providers/shift_provider.dart';

/// ADAPTED from `frontend-flutter-pos/lib/features/pos/screens/
/// shift_history_screen.dart` — already a single-column `ListView.builder`
/// in source, so this port is close to verbatim (unlike most other
/// screens' "MOBILE UI REIMPLEMENT" days).
class ShiftHistoryScreen extends ConsumerStatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  ConsumerState<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends ConsumerState<ShiftHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Reloads fresh every time this screen is navigated to, so it never
    // shows stale data from a shift opened/closed earlier in the session.
    Future.microtask(
      () => ref.read(shiftHistoryProvider.notifier).loadHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shiftHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.shiftHistoryScreenTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: state.loading
                ? null
                : () => ref.read(shiftHistoryProvider.notifier).loadHistory(),
          ),
        ],
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, ShiftHistoryState state) {
    if (state.loading && state.shifts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.shifts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.shiftHistoryLoadFailed(state.error!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(shiftHistoryProvider.notifier).loadHistory(),
                child: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (state.shifts.isEmpty) {
      return Center(child: Text(context.l10n.shiftHistoryEmpty));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(shiftHistoryProvider.notifier).loadHistory(),
      child: ListView.builder(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        itemCount: state.shifts.length,
        itemBuilder: (context, index) =>
            _ShiftHistoryCard(shift: state.shifts[index]),
      ),
    );
  }
}

class _ShiftHistoryCard extends ConsumerWidget {
  const _ShiftHistoryCard({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = watchCurrency(ref);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(PosTheme.spacingMd),
      decoration: BoxDecoration(
        color: PosTheme.backgroundCardOf(context),
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        border: Border.all(color: PosTheme.borderColorOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.shiftScreenShiftNumber(shift.id.toString()),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _StatusBadge(status: shift.status),
            ],
          ),
          if (shift.storeName != null) ...[
            const SizedBox(height: 4),
            Text(
              shift.storeName!,
              style: TextStyle(color: PosTheme.textSecondaryOf(context)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            context.l10n.shiftScreenOpened(
              '${formatReceiptDate(shift.startTime)} '
              '${formatReceiptTime(shift.startTime)}',
            ),
          ),
          if (shift.closedAt != null)
            Text(
              context.l10n.shiftHistoryClosed(
                '${formatReceiptDate(shift.closedAt!)} '
                '${formatReceiptTime(shift.closedAt!)}',
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                context.l10n.shiftScreenOpeningCash(
                  formatAmount(shift.openingFloat, cur),
                ),
              ),
              if (shift.salesTotal != null)
                Text(
                  context.l10n.shiftHistorySales(
                    formatAmount(shift.salesTotal!, cur),
                  ),
                ),
              if (shift.closingCash != null)
                Text(
                  context.l10n.shiftHistoryClosingCash(
                    formatAmount(shift.closingCash!, cur),
                  ),
                ),
              if (shift.expectedCash != null)
                Text(
                  context.l10n.shiftScreenExpectedCash(
                    formatAmount(shift.expectedCash!, cur),
                  ),
                ),
              if (shift.variance != null)
                Text(
                  context.l10n.shiftScreenVariance(
                    formatAmount(shift.variance!, cur),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final String label;
    final Color color;
    switch (normalized) {
      case 'OPEN':
        label = context.l10n.shiftHistoryStatusOpen;
        color = PosTheme.primaryGreen;
        break;
      case 'PENDING_APPROVAL':
        label = context.l10n.shiftHistoryStatusPendingApproval;
        color = PosTheme.warningAmber;
        break;
      default:
        label = context.l10n.shiftHistoryStatusClosed;
        color = PosTheme.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PosTheme.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
