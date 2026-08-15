/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// modifier_models.dart` — PARTIAL PORT, not the full file. Source's
/// 333-line file is mostly modifier-group CRUD request/response classes for
/// the back-office "manage modifier groups" admin screens — out of this
/// task's Day 4-10 scope entirely (no admin/management screens are being
/// built). Only `ModifierOptionResponse`/`ModifierGroupResponse` are
/// ported, because `Product.modifierGroups` (product_models.dart) needs
/// them to parse the backend's `ProductResponse.modifierGroups` field
/// correctly — byte-identical logic to source for exactly these two
/// classes and their three parsing helpers.
double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

int _toInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _toBool(dynamic value, {bool defaultValue = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = value?.toString().toLowerCase();
  if (text == 'true' || text == '1') {
    return true;
  }
  if (text == 'false' || text == '0') {
    return false;
  }
  return defaultValue;
}

class ModifierOptionResponse {
  final int id;
  final String nameEn;
  final String nameKm;
  final double priceDelta;
  final bool active;
  final int displayOrder;

  const ModifierOptionResponse({
    required this.id,
    required this.nameEn,
    required this.nameKm,
    required this.priceDelta,
    required this.active,
    required this.displayOrder,
  });

  factory ModifierOptionResponse.fromJson(Map<String, dynamic> json) {
    return ModifierOptionResponse(
      id: _toInt(json['id']),
      nameEn: json['nameEn']?.toString() ?? '',
      nameKm: json['nameKm']?.toString() ?? '',
      priceDelta: _toDouble(json['priceDelta']),
      active: _toBool(json['active']),
      displayOrder: _toInt(json['displayOrder']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameEn': nameEn,
      'nameKm': nameKm,
      'priceDelta': priceDelta,
      'active': active,
      'displayOrder': displayOrder,
    };
  }
}

class ModifierGroupResponse {
  final int id;
  final String nameEn;
  final String nameKm;
  final bool isRequired;
  final bool multiSelect;
  final bool active;
  final int displayOrder;
  final List<ModifierOptionResponse> options;

  const ModifierGroupResponse({
    required this.id,
    required this.nameEn,
    required this.nameKm,
    required this.isRequired,
    required this.multiSelect,
    required this.active,
    required this.displayOrder,
    this.options = const [],
  });

  factory ModifierGroupResponse.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return ModifierGroupResponse(
      id: _toInt(json['id']),
      nameEn: json['nameEn']?.toString() ?? '',
      nameKm: json['nameKm']?.toString() ?? '',
      isRequired: _toBool(json['required']),
      multiSelect: _toBool(json['multiSelect']),
      active: _toBool(json['active']),
      displayOrder: _toInt(json['displayOrder']),
      options: rawOptions is List
          ? rawOptions
              .whereType<Map>()
              .map((item) =>
                  ModifierOptionResponse.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameEn': nameEn,
      'nameKm': nameKm,
      'required': isRequired,
      'multiSelect': multiSelect,
      'active': active,
      'displayOrder': displayOrder,
      'options': options.map((o) => o.toJson()).toList(),
    };
  }
}
