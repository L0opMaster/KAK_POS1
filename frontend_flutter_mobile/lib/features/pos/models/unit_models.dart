/// A unit of measure (e.g. "kg", "g", "box", "pcs"), matching the backend
/// `UnitDtos.UnitResponse` (`GET /api/units`). Units are grouped by
/// [baseUnitGroup] (e.g. "weight", "volume", "count") — within a group, one
/// unit is the [baseUnit] (conversionFactor fixed at 1), and every other
/// unit in that group stores how many of itself equal 1 of its
/// [baseUnitId] unit.
///
/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// unit_models.dart` — COPY/ADAPT NEARLY EXACTLY, with `toJson`/`copyWith`
/// added to match this project's model conventions (source only has
/// `fromJson`, since the desktop form builds its own raw save-payload map
/// instead of calling `toJson`).
class Unit {
  final int id;
  final String code;
  final String name;
  final String nameEn;
  final String nameKm;
  final String symbol;
  final String baseUnitGroup;
  final int? baseUnitId;
  final String? baseUnitCode;
  final String? baseUnitNameEn;
  final bool baseUnit;
  final double conversionFactor;
  final bool active;

  /// How many products/supplier catalog rows/derived units currently
  /// reference this unit — informational only, there is no delete-blocking
  /// logic since units have no delete capability.
  final int usageCount;

  const Unit({
    required this.id,
    required this.code,
    required this.name,
    required this.nameEn,
    required this.nameKm,
    required this.symbol,
    required this.baseUnitGroup,
    this.baseUnitId,
    this.baseUnitCode,
    this.baseUnitNameEn,
    required this.baseUnit,
    required this.conversionFactor,
    required this.active,
    this.usageCount = 0,
  });

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        id: (json['id'] as num).toInt(),
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        nameEn: json['nameEn'] as String? ?? '',
        nameKm: json['nameKm'] as String? ?? '',
        symbol: json['symbol'] as String? ?? '',
        baseUnitGroup: json['baseUnitGroup'] as String? ?? '',
        baseUnitId: (json['baseUnitId'] as num?)?.toInt(),
        baseUnitCode: json['baseUnitCode'] as String?,
        baseUnitNameEn: json['baseUnitNameEn'] as String?,
        baseUnit: json['baseUnit'] as bool? ?? true,
        conversionFactor:
            (json['conversionFactor'] as num?)?.toDouble() ?? 1,
        active: json['active'] as bool? ?? true,
        usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'nameEn': nameEn,
        'nameKm': nameKm,
        'symbol': symbol,
        'baseUnitGroup': baseUnitGroup,
        'baseUnitId': baseUnitId,
        'baseUnitCode': baseUnitCode,
        'baseUnitNameEn': baseUnitNameEn,
        'baseUnit': baseUnit,
        'conversionFactor': conversionFactor,
        'active': active,
        'usageCount': usageCount,
      };

  Unit copyWith({
    int? id,
    String? code,
    String? name,
    String? nameEn,
    String? nameKm,
    String? symbol,
    String? baseUnitGroup,
    int? baseUnitId,
    String? baseUnitCode,
    String? baseUnitNameEn,
    bool? baseUnit,
    double? conversionFactor,
    bool? active,
    int? usageCount,
  }) =>
      Unit(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        nameEn: nameEn ?? this.nameEn,
        nameKm: nameKm ?? this.nameKm,
        symbol: symbol ?? this.symbol,
        baseUnitGroup: baseUnitGroup ?? this.baseUnitGroup,
        baseUnitId: baseUnitId ?? this.baseUnitId,
        baseUnitCode: baseUnitCode ?? this.baseUnitCode,
        baseUnitNameEn: baseUnitNameEn ?? this.baseUnitNameEn,
        baseUnit: baseUnit ?? this.baseUnit,
        conversionFactor: conversionFactor ?? this.conversionFactor,
        active: active ?? this.active,
        usageCount: usageCount ?? this.usageCount,
      );
}
