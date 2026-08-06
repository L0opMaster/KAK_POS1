import 'package:flutter/material.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';

/// Loyverse-inspired status bar showing shift info, staff name, online status,
/// and quick action buttons (Cash, Transactions, Bills).
///
/// This widget is purely visual — it just displays whatever `online` value
/// its caller passes in (see the cloud icon / "Online"/"Offline" label
/// below); it contains no SharedPreferences logic and does not itself check
/// network status. NOTE: as of writing, `PosStatusBar` is not instantiated
/// anywhere else in the app, so `online` currently always falls back to its
/// default (`true`). To make this reflect real connectivity, a caller would
/// need to feed it from core/providers/connectivity_provider.dart's
/// `connectivityProvider` (see the SWITCH POINT note there).
class PosStatusBar extends StatelessWidget {
  final String shiftStatus;
  final String staffName;
  /// Purely a display flag — see the class doc comment above.
  final bool online;
  final VoidCallback? onMenuToggle;

  const PosStatusBar({
    super.key,
    this.shiftStatus = 'CLOSED',
    this.staffName = '',
    this.online = true,
    this.onMenuToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosTheme.backgroundCardOf(context),
        border: Border(
          bottom: BorderSide(color: PosTheme.dividerColorOf(context)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.menu, color: PosTheme.textSecondaryOf(context)),
                tooltip: context.l10n.statusBarToggleMenu,
                onPressed: onMenuToggle,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              _statusChip(
                Icons.sync,
                '${context.l10n.statusBarShiftLabel}: $shiftStatus',
                shiftStatus == 'OPEN'
                    ? PosTheme.primaryGreen
                    : PosTheme.textSecondaryOf(context),
              ),
              const SizedBox(width: 16),
              Text(
                staffName,
                style: TextStyle(
                  fontSize: 13,
                  color: PosTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              // Display-only online/offline indicator (see class doc comment).
              Icon(
                online ? Icons.cloud_done : Icons.cloud_off,
                size: 18,
                color: online ? PosTheme.primaryGreen : PosTheme.errorRed,
              ),
              const SizedBox(width: 4),
              Text(
                online ? context.l10n.statusBarOnline : context.l10n.statusBarOffline,
                style: TextStyle(
                  fontSize: 11,
                  color: online ? PosTheme.primaryGreen : PosTheme.errorRed,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _actionButton(Icons.attach_money, context.l10n.cartCash),
              const SizedBox(width: 4),
              _actionButton(Icons.bar_chart, context.l10n.statusBarTransactions),
              const SizedBox(width: 4),
              _actionButton(Icons.description, context.l10n.statusBarBills),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(PosTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label) {
    return TextButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 16, color: PosTheme.textSecondary),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, color: PosTheme.textSecondary),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
