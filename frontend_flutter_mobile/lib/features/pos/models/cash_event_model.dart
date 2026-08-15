/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// cash_event_model.dart` — COPY/ADAPT NEARLY EXACTLY.
library;

import '../../../core/utils/receipt_date_format.dart';

enum CashEventType {
  openShift,
  closeShift,
  openDrawer,
  cashIn,
  cashOut,
  saleCash,
  refundCash,
}

extension CashEventTypeExtension on CashEventType {
  String get label {
    switch (this) {
      case CashEventType.openShift:
        return 'Open Shift';
      case CashEventType.closeShift:
        return 'Close Shift';
      case CashEventType.openDrawer:
        return 'Open Drawer';
      case CashEventType.cashIn:
        return 'Cash In';
      case CashEventType.cashOut:
        return 'Cash Out';
      case CashEventType.saleCash:
        return 'Sale Cash';
      case CashEventType.refundCash:
        return 'Refund Cash';
    }
  }
}

class CashEvent {
  final String id;
  final CashEventType type;
  final double amount;
  final String reason;
  final DateTime createdAt;

  CashEvent({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  factory CashEvent.fromJson(Map<String, dynamic> json) {
    final typeString = (json['type'] as String? ?? '').toLowerCase().replaceAll(
      '_',
      '',
    );
    final type = CashEventType.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == typeString,
      orElse: () => CashEventType.cashIn,
    );
    return CashEvent(
      id: json['id'].toString(),
      type: type,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      createdAt:
          parseBackendTimestamp(json['createdAt'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString().split('.').last,
    'amount': amount,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
  };
}
