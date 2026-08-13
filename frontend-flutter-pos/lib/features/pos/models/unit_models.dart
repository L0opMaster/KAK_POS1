/// A unit of measure (e.g. "kg", "g", "box", "pcs"), matching the backend
/// `UnitDtos.UnitResponse` (`GET /api/units`). Units are grouped by
/// [baseUnitGroup] (e.g. "weight", "volume", "count") — within a group, one
/// unit is the [baseUnit] (conversionFactor fixed at 1), and every other
/// unit in that group stores how many of itself equal 1 of its
/// [baseUnitId] unit.
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
  /// reference this unit — used to warn before deactivating one still in
  /// use, mirroring the usage-count fields the backend already computes.
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
}
