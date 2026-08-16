import 'package:flutter/material.dart';

import '../../../core/config/pos_theme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Localized label for a credit sale's computed status (OPEN/PARTIALLY_PAID/
/// PAID/OVERDUE/EXPIRED/CANCELLED — see the backend's
/// `SaleService.computeCreditStatus`). Falls back to the raw string for any
/// value not in that set, so an unexpected status still displays rather than
/// disappearing.
String creditStatusLabel(AppLocalizations l10n, String? status) {
  switch (status) {
    case 'OPEN':
      return l10n.creditStatusOpen;
    case 'PARTIALLY_PAID':
      return l10n.creditStatusPartiallyPaid;
    case 'PAID':
      return l10n.creditStatusPaid;
    case 'OVERDUE':
      return l10n.creditStatusOverdue;
    case 'EXPIRED':
      return l10n.creditStatusExpired;
    case 'CANCELLED':
      return l10n.creditStatusCancelled;
    default:
      return status ?? '';
  }
}

/// Color to pair with [creditStatusLabel] — red for anything urgent
/// (overdue/expired), green once fully paid, amber while still open/
/// partially paid, grey once cancelled.
Color creditStatusColor(String? status) {
  switch (status) {
    case 'OVERDUE':
    case 'EXPIRED':
      return PosTheme.errorRed;
    case 'PAID':
      return PosTheme.primaryGreen;
    case 'CANCELLED':
      return PosTheme.textSecondary;
    case 'OPEN':
    case 'PARTIALLY_PAID':
    default:
      return PosTheme.warningAmber;
  }
}
