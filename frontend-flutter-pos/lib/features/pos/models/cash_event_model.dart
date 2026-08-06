/// Model definitions for cash events used in cash management.

/// Types of cash events that can occur during a shift.
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
  /// Human-readable label for the event type.
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

/// Data class representing a cash event record.
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
    final typeString = (json['type'] as String? ?? '')
        .toLowerCase()
        .replaceAll('_', '');
    CashEventType type = CashEventType.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == typeString,
      orElse: () => CashEventType.cashIn,
    );
    return CashEvent(
      id: json['id'].toString(),
      type: type,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString().split('.').last,
        'amount': amount,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Creates a sample event for testing.
  static CashEvent sample({
    String? id,
    CashEventType type = CashEventType.cashIn,
    double amount = 10.0,
    String reason = 'sample',
  }) {
    return CashEvent(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      amount: amount,
      reason: reason,
      createdAt: DateTime.now(),
    );
  }
}
