import '../../../core/utils/receipt_date_format.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// shift_model.dart` — COPY/ADAPT NEARLY EXACTLY.
class Shift {
  final int id;
  final String status;
  final DateTime startTime;
  final double openingFloat;
  final DateTime? closedAt;
  final DateTime? endTime;
  final double? closingCash;
  final double? expectedCash;
  final double? variance;
  final String? storeName;
  final double? salesTotal;

  Shift({
    required this.id,
    required this.status,
    required this.startTime,
    required this.openingFloat,
    this.closedAt,
    this.endTime,
    this.closingCash,
    this.expectedCash,
    this.variance,
    this.storeName,
    this.salesTotal,
  });

  /// Backend timestamps (`openedAt`/`closedAt`) are `java.time.Instant`,
  /// serialized as UTC — parsed via [parseBackendTimestamp] and converted to
  /// local time here, the one place this happens.
  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
    id: json['id'] as int,
    status: json['status'] as String,
    startTime:
        parseBackendTimestamp(
          (json['startTime'] ?? json['openedAt']) as String?,
        ) ??
        DateTime.now(),
    openingFloat: ((json['openingFloat'] ?? json['openingCash']) as num)
        .toDouble(),
    closedAt: parseBackendTimestamp(json['closedAt'] as String?),
    endTime: parseBackendTimestamp(
      (json['endTime'] ?? json['closedAt']) as String?,
    ),
    closingCash: json['closingCash'] != null
        ? (json['closingCash'] as num).toDouble()
        : null,
    expectedCash: json['expectedCash'] != null
        ? (json['expectedCash'] as num).toDouble()
        : null,
    variance: json['variance'] != null
        ? (json['variance'] as num).toDouble()
        : null,
    storeName: json['storeName'] as String?,
    salesTotal: json['salesTotal'] != null
        ? (json['salesTotal'] as num).toDouble()
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'startTime': startTime.toIso8601String(),
    'openingFloat': openingFloat,
    'closedAt': closedAt?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'closingCash': closingCash,
    'expectedCash': expectedCash,
    'variance': variance,
    'storeName': storeName,
    'salesTotal': salesTotal,
  };

  Shift copyWith({
    int? id,
    String? status,
    DateTime? startTime,
    double? openingFloat,
    DateTime? closedAt,
    DateTime? endTime,
    double? closingCash,
    double? expectedCash,
    double? variance,
    String? storeName,
    double? salesTotal,
  }) {
    return Shift(
      id: id ?? this.id,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      openingFloat: openingFloat ?? this.openingFloat,
      closedAt: closedAt ?? this.closedAt,
      endTime: endTime ?? this.endTime,
      closingCash: closingCash ?? this.closingCash,
      expectedCash: expectedCash ?? this.expectedCash,
      variance: variance ?? this.variance,
      storeName: storeName ?? this.storeName,
      salesTotal: salesTotal ?? this.salesTotal,
    );
  }

  static Shift sample() => Shift(
    id: 1,
    status: 'open',
    startTime: DateTime.now(),
    openingFloat: 100.0,
  );
}

/// State model for shift status.
class ShiftState {
  final bool isShiftOpen;
  final Shift? currentShift;

  ShiftState({required this.isShiftOpen, this.currentShift});
}
