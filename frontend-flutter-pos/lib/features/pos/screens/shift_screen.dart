import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../models/cash_event_model.dart';
import '../providers/cash_event_provider.dart';
import '../providers/shift_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/receipt_date_format.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  int? _loadedShiftId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(shiftProvider.notifier).loadCurrentShift());
  }

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final currentShift = shiftState.currentShift;
    // `currentShift` stays populated with the closed shift's data right
    // after Close Shift (so its closing summary is available) — whether a
    // shift is actually open for business is `isShiftOpen`, not merely
    // `currentShift != null`. Branching on presence alone kept showing the
    // active-shift card (with live Cash In/Out/Close buttons) for a shift
    // that had already been closed, until the screen was reopened and
    // re-fetched `/api/shifts/current`, which already filters to OPEN only.
    final bool shiftIsInactive = currentShift == null || !shiftState.isShiftOpen;
    if (!shiftIsInactive && _loadedShiftId != currentShift.id) {
      _loadedShiftId = currentShift.id;
      Future.microtask(
        () => ref.read(cashEventProvider.notifier).loadByShift(currentShift.id),
      );
    } else if (shiftIsInactive) {
      _loadedShiftId = null;
    }
    final cashState = ref.watch(cashEventProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.shiftScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (shiftIsInactive)
            _ShiftSummaryCard(
              title: context.l10n.shiftScreenNoOpenShiftTitle,
              subtitle: context.l10n.shiftScreenNoOpenShiftSubtitle,
              child: ElevatedButton.icon(
                onPressed: () => _showOpenShiftDialog(context),
                icon: const Icon(Icons.lock_open),
                label: Text(context.l10n.shiftScreenOpenShift),
              ),
            )
          else ...[
            _ShiftSummaryCard(
              title: context.l10n.shiftScreenShiftNumber(
                currentShift.id.toString(),
              ),
              // shiftScreenOpened interpolates its argument as a raw string
              // (no ICU date format), so `currentShift.startTime` (already
              // local, see Shift.fromJson) must be pre-formatted here rather
              // than passed as a DateTime — otherwise it shows
              // DateTime.toString() output instead of a readable date/time.
              subtitle: context.l10n.shiftScreenOpened(
                '${formatReceiptDate(currentShift.startTime)} '
                '${formatReceiptTime(currentShift.startTime)}',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.shiftScreenOpeningCash(
                      '\$${currentShift.openingFloat.toStringAsFixed(2)}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (currentShift.expectedCash != null)
                    Text(
                      context.l10n.shiftScreenExpectedCash(
                        '\$${currentShift.expectedCash!.toStringAsFixed(2)}',
                      ),
                    ),
                  if (currentShift.variance != null)
                    Text(
                      context.l10n.shiftScreenVariance(
                        '\$${currentShift.variance!.toStringAsFixed(2)}',
                      ),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showCashEventDialog(
                          context,
                          currentShift.id,
                          CashEventType.cashIn,
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(context.l10n.shiftScreenCashIn),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showCashEventDialog(
                          context,
                          currentShift.id,
                          CashEventType.cashOut,
                        ),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: Text(context.l10n.shiftScreenCashOut),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showCloseShiftDialog(context),
                        icon: const Icon(Icons.task_alt),
                        label: Text(context.l10n.shiftScreenCloseShift),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.shiftScreenCashEvents,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (cashState.loading)
              const Center(child: CircularProgressIndicator())
            else if (cashState.events.isEmpty)
              Text(context.l10n.shiftScreenNoCashEvents)
            else
              ...cashState.events.map(
                (event) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: PosTheme.primaryGreenLight,
                    child: Icon(
                      event.type == CashEventType.cashOut
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: PosTheme.primaryGreen,
                    ),
                  ),
                  title: Text(event.type.label),
                  subtitle: Text(event.reason),
                  trailing: Text('\$${event.amount.toStringAsFixed(2)}'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _showOpenShiftDialog(BuildContext context) async {
    final controller = TextEditingController(text: '0');
    bool submitting = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.shiftScreenOpenShift),
          content: TextField(
            controller: controller,
            enabled: !submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.shiftScreenOpeningCashLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            ElevatedButton(
              // Guards against a double-tap/slow-network firing a second
              // POST /api/shifts/open before the first one returns.
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      try {
                        await ref.read(shiftProvider.notifier).openShift(
                              openingFloat: double.tryParse(controller.text) ?? 0,
                            );
                        if (mounted) Navigator.of(context).pop();
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.shiftScreenOpenShiftFailed(e.toString()),
                            ),
                          ),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.shiftScreenOpen),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCloseShiftDialog(BuildContext context) async {
    final shiftNotifier = ref.read(shiftProvider.notifier);
    Map<String, dynamic> precheck = const {};
    try {
      precheck = await shiftNotifier.getClosePrecheck();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.shiftScreenPrecheckFailed(e.toString()),
            ),
          ),
        );
      }
    }
    final controller = TextEditingController(
      text: '${ref.read(shiftProvider).currentShift?.openingFloat ?? 0}',
    );
    bool submitting = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.shiftScreenCloseShift),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((precheck['blockers'] as List<dynamic>? ?? const [])
                  .isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  color: Colors.amber.shade50,
                  child: Text(
                    context.l10n.shiftScreenBlockers(
                      (precheck['blockers'] as List<dynamic>).join(', '),
                    ),
                  ),
                ),
              TextField(
                controller: controller,
                enabled: !submitting,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: context.l10n.shiftScreenClosingCashLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            ElevatedButton(
              // Guards against a double-tap/slow-network firing a second
              // POST /api/shifts/{id}/close before the first one returns.
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      try {
                        await shiftNotifier.closeShift(
                          closingCash: double.tryParse(controller.text) ?? 0,
                        );
                        if (mounted) Navigator.of(context).pop();
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.shiftScreenCloseShiftFailed(e.toString()),
                            ),
                          ),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.shiftScreenCloseShift),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCashEventDialog(
    BuildContext context,
    int shiftId,
    CashEventType type,
  ) async {
    final amountCtl = TextEditingController();
    final reasonCtl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.l10n.receiptAmount,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtl,
              decoration: InputDecoration(
                labelText: context.l10n.shiftScreenReasonLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(cashEventProvider.notifier).createForShift(
                      shiftId: shiftId,
                      type: type,
                      amount: double.tryParse(amountCtl.text) ?? 0,
                      reason: reasonCtl.text.trim(),
                    );
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n.shiftScreenSaveCashEventFailed(
                        e.toString(),
                      ),
                    ),
                  ),
                );
              }
            },
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

class _ShiftSummaryCard extends StatelessWidget {
  const _ShiftSummaryCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        border: Border.all(color: PosTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: PosTheme.textSecondary)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
