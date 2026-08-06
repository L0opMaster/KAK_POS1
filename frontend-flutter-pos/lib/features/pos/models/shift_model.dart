/// Model for a shift in the POS system.
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
  });

  /// Creates Shift from JSON.
  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
        id: json['id'] as int,
        status: json['status'] as String,
        startTime: DateTime.parse(
          (json['startTime'] ?? json['openedAt']) as String,
        ),
        openingFloat: ((json['openingFloat'] ?? json['openingCash']) as num)
            .toDouble(),
        closedAt: json['closedAt'] != null
            ? DateTime.parse(json['closedAt'] as String)
            : null,
        endTime: (json['endTime'] ?? json['closedAt']) != null
            ? DateTime.parse((json['endTime'] ?? json['closedAt']) as String)
            : null,
        closingCash: json['closingCash'] != null
            ? (json['closingCash'] as num).toDouble()
            : null,
        expectedCash: json['expectedCash'] != null
            ? (json['expectedCash'] as num).toDouble()
            : null,
        variance: json['variance'] != null
            ? (json['variance'] as num).toDouble()
            : null,
      );

  /// Converts Shift to JSON.
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
      };

  /// Creates a copy of the shift optionally overriding fields.
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
    );
  }

  /// Sample data for testing.
  static Shift sample() => Shift(
        id: 1,
        status: 'open',
        startTime: DateTime.now(),
        openingFloat: 100.0,
        closedAt: null,
        endTime: null,
        closingCash: null,
        expectedCash: null,
        variance: null,
      );
}

/// State model for shift status in the POS system.
class ShiftState {
  final bool isShiftOpen;
  final Shift? currentShift;
  // Add other fields as needed

  ShiftState({
    required this.isShiftOpen,
    this.currentShift,
  });

  /// Creates ShiftState from JSON.
  factory ShiftState.fromJson(Map<String, dynamic> json) => ShiftState(
        isShiftOpen: json['isShiftOpen'] as bool,
        currentShift: json['currentShift'] != null
            ? Shift.fromJson(json['currentShift'] as Map<String, dynamic>)
            : null,
      );

  /// Converts ShiftState to JSON.
  Map<String, dynamic> toJson() => {
        'isShiftOpen': isShiftOpen,
        'currentShift': currentShift?.toJson(),
      };

  /// Sample data for testing.
  static ShiftState sample() => ShiftState(
        isShiftOpen: true,
        currentShift: Shift.sample(),
      );
}
