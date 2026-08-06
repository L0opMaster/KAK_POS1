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

bool _toBool(
  dynamic value, {
  bool defaultValue = false,
}) {
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

// ─────────────────────────────────────────────
// Requests
// ─────────────────────────────────────────────

class ModifierGroupRequest {
  final String nameEn;
  final String nameKm;
  final bool isRequired;
  final bool multiSelect;
  final bool active;
  final int displayOrder;

  const ModifierGroupRequest({
    required this.nameEn,
    required this.nameKm,
    this.isRequired = false,
    this.multiSelect = false,
    this.active = true,
    this.displayOrder = 0,
  });

  factory ModifierGroupRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    return ModifierGroupRequest(
      nameEn: json['nameEn']?.toString() ?? '',
      nameKm: json['nameKm']?.toString() ?? '',
      isRequired: _toBool(json['required']),
      multiSelect: _toBool(json['multiSelect']),
      active: _toBool(
        json['active'],
        defaultValue: true,
      ),
      displayOrder: _toInt(json['displayOrder']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nameEn': nameEn,
      'nameKm': nameKm,
      'required': isRequired,
      'multiSelect': multiSelect,
      'active': active,
      'displayOrder': displayOrder,
    };
  }
}

class ModifierOptionRequest {
  final String nameEn;
  final String nameKm;
  final double priceDelta;
  final bool active;
  final int displayOrder;

  const ModifierOptionRequest({
    required this.nameEn,
    required this.nameKm,
    required this.priceDelta,
    this.active = true,
    this.displayOrder = 0,
  });

  factory ModifierOptionRequest.fromJson(
    Map<String, dynamic> json,
  ) {
    return ModifierOptionRequest(
      nameEn: json['nameEn']?.toString() ?? '',
      nameKm: json['nameKm']?.toString() ?? '',
      priceDelta: _toDouble(json['priceDelta']),
      active: _toBool(
        json['active'],
        defaultValue: true,
      ),
      displayOrder: _toInt(json['displayOrder']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nameEn': nameEn,
      'nameKm': nameKm,
      'priceDelta': priceDelta,
      'active': active,
      'displayOrder': displayOrder,
    };
  }
}

// Used when updating existing options or adding new options.
class ModifierOptionUpsert {
  final int? id;
  final ModifierOptionRequest request;

  const ModifierOptionUpsert({
    required this.id,
    required this.request,
  });

  bool get isNew => id == null;
}

// ─────────────────────────────────────────────
// Responses
// ─────────────────────────────────────────────

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

  factory ModifierOptionResponse.fromJson(
    Map<String, dynamic> json,
  ) {
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

  factory ModifierGroupResponse.fromJson(
    Map<String, dynamic> json,
  ) {
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
              .map(
                (item) => ModifierOptionResponse.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }

  ModifierGroupResponse copyWith({
    int? id,
    String? nameEn,
    String? nameKm,
    bool? isRequired,
    bool? multiSelect,
    bool? active,
    int? displayOrder,
    List<ModifierOptionResponse>? options,
  }) {
    return ModifierGroupResponse(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameKm: nameKm ?? this.nameKm,
      isRequired: isRequired ?? this.isRequired,
      multiSelect: multiSelect ?? this.multiSelect,
      active: active ?? this.active,
      displayOrder: displayOrder ?? this.displayOrder,
      options: options ?? this.options,
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
      'options': options
          .map(
            (option) => option.toJson(),
          )
          .toList(),
    };
  }
}

class ProductModifiersResponse {
  final int groupId;
  final String groupNameEn;
  final String groupNameKm;
  final bool isRequired;
  final bool multiSelect;
  final List<ModifierOptionResponse> options;

  const ProductModifiersResponse({
    required this.groupId,
    required this.groupNameEn,
    required this.groupNameKm,
    required this.isRequired,
    required this.multiSelect,
    this.options = const [],
  });

  factory ProductModifiersResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawOptions = json['options'];

    return ProductModifiersResponse(
      groupId: _toInt(json['groupId']),
      groupNameEn: json['groupNameEn']?.toString() ?? '',
      groupNameKm: json['groupNameKm']?.toString() ?? '',
      isRequired: _toBool(json['required']),
      multiSelect: _toBool(json['multiSelect']),
      options: rawOptions is List
          ? rawOptions
              .whereType<Map>()
              .map(
                (item) => ModifierOptionResponse.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'groupNameEn': groupNameEn,
      'groupNameKm': groupNameKm,
      'required': isRequired,
      'multiSelect': multiSelect,
      'options': options
          .map(
            (option) => option.toJson(),
          )
          .toList(),
    };
  }
}
