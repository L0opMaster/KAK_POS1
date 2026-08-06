/// Production models — mirrors backend ProductionDtos exactly
/// (GET/POST /api/production/recipes, GET/POST /api/production/orders,
/// plus the order lifecycle actions: check-availability/start/complete/
/// cancel).

class RecipeLine {
  final int? id;
  final int componentProductId;
  final String? componentProductNameEn;
  final double componentQuantity;
  final String? componentStockUnitCode;

  RecipeLine({
    this.id,
    required this.componentProductId,
    this.componentProductNameEn,
    required this.componentQuantity,
    this.componentStockUnitCode,
  });

  factory RecipeLine.fromJson(Map<String, dynamic> json) => RecipeLine(
        id: (json['id'] as num?)?.toInt(),
        componentProductId: (json['componentProductId'] as num?)?.toInt() ?? 0,
        componentProductNameEn: json['componentProductNameEn'] as String?,
        componentQuantity:
            (json['componentQuantity'] as num?)?.toDouble() ?? 0,
        componentStockUnitCode: json['componentStockUnitCode'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'componentProductId': componentProductId,
        'componentQuantity': componentQuantity,
      };
}

class Recipe {
  final int? id;
  final String name;
  final int outputProductId;
  final String? outputProductNameEn;
  final double outputQuantity;
  final bool active;
  final String? notes;
  final List<RecipeLine> lines;

  Recipe({
    this.id,
    required this.name,
    required this.outputProductId,
    this.outputProductNameEn,
    required this.outputQuantity,
    this.active = true,
    this.notes,
    this.lines = const [],
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: (json['id'] as num?)?.toInt(),
        name: json['name'] as String? ?? '',
        outputProductId: (json['outputProductId'] as num?)?.toInt() ?? 0,
        outputProductNameEn: json['outputProductNameEn'] as String?,
        outputQuantity: (json['outputQuantity'] as num?)?.toDouble() ?? 0,
        active: json['active'] as bool? ?? true,
        notes: json['notes'] as String?,
        lines: (json['lines'] as List<dynamic>?)
                ?.map((e) => RecipeLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// Create request shape (RecipeRequest — includes outputProductId).
  Map<String, dynamic> toCreateJson() => {
        'name': name,
        'outputProductId': outputProductId,
        'outputQuantity': outputQuantity,
        'active': active,
        if (notes != null) 'notes': notes,
        'lines': lines.map((e) => e.toJson()).toList(),
      };

  /// Update request shape (RecipeUpdateRequest — output product is fixed).
  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'outputQuantity': outputQuantity,
        'active': active,
        if (notes != null) 'notes': notes,
        'lines': lines.map((e) => e.toJson()).toList(),
      };
}

class ProductionOrderLine {
  final int? id;
  final int componentProductId;
  final String? componentProductNameEn;
  final double plannedQuantity;
  final double? consumedQuantity;

  ProductionOrderLine({
    this.id,
    required this.componentProductId,
    this.componentProductNameEn,
    required this.plannedQuantity,
    this.consumedQuantity,
  });

  factory ProductionOrderLine.fromJson(Map<String, dynamic> json) =>
      ProductionOrderLine(
        id: (json['id'] as num?)?.toInt(),
        componentProductId: (json['componentProductId'] as num?)?.toInt() ?? 0,
        componentProductNameEn: json['componentProductNameEn'] as String?,
        plannedQuantity: (json['plannedQuantity'] as num?)?.toDouble() ?? 0,
        consumedQuantity: (json['consumedQuantity'] as num?)?.toDouble(),
      );
}

class ProductionOrder {
  final int? id;
  final String? orderNumber;
  final int recipeId;
  final String? recipeName;
  final int? storeId;
  final String? storeName;
  final String status;
  final double plannedQuantity;
  final double? producedQuantity;
  final double? wasteQuantity;
  final double? yieldPercent;
  final String? startedAt;
  final String? completedAt;
  final String? cancelledAt;
  final String? cancelReason;
  final String? notes;
  final String? createdBy;
  final List<ProductionOrderLine> lines;

  ProductionOrder({
    this.id,
    this.orderNumber,
    required this.recipeId,
    this.recipeName,
    this.storeId,
    this.storeName,
    this.status = 'DRAFT',
    required this.plannedQuantity,
    this.producedQuantity,
    this.wasteQuantity,
    this.yieldPercent,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
    this.notes,
    this.createdBy,
    this.lines = const [],
  });

  factory ProductionOrder.fromJson(Map<String, dynamic> json) =>
      ProductionOrder(
        id: (json['id'] as num?)?.toInt(),
        orderNumber: json['orderNumber'] as String?,
        recipeId: (json['recipeId'] as num?)?.toInt() ?? 0,
        recipeName: json['recipeName'] as String?,
        storeId: (json['storeId'] as num?)?.toInt(),
        storeName: json['storeName'] as String?,
        status: json['status'] as String? ?? 'DRAFT',
        plannedQuantity: (json['plannedQuantity'] as num?)?.toDouble() ?? 0,
        producedQuantity: (json['producedQuantity'] as num?)?.toDouble(),
        wasteQuantity: (json['wasteQuantity'] as num?)?.toDouble(),
        yieldPercent: (json['yieldPercent'] as num?)?.toDouble(),
        startedAt: json['startedAt'] as String?,
        completedAt: json['completedAt'] as String?,
        cancelledAt: json['cancelledAt'] as String?,
        cancelReason: json['cancelReason'] as String?,
        notes: json['notes'] as String?,
        createdBy: json['createdBy'] as String?,
        lines: (json['lines'] as List<dynamic>?)
                ?.map((e) =>
                    ProductionOrderLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// Create request shape (ProductionOrderRequest).
  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        if (storeId != null) 'storeId': storeId,
        'plannedQuantity': plannedQuantity,
        if (notes != null) 'notes': notes,
      };
}

class ComponentAvailability {
  final int productId;
  final String? productName;
  final String? stockUnitCode;
  final double required;
  final double onHand;
  final bool sufficient;

  ComponentAvailability({
    required this.productId,
    this.productName,
    this.stockUnitCode,
    required this.required,
    required this.onHand,
    required this.sufficient,
  });

  factory ComponentAvailability.fromJson(Map<String, dynamic> json) =>
      ComponentAvailability(
        productId: (json['productId'] as num?)?.toInt() ?? 0,
        productName: json['productNameEn'] as String?,
        stockUnitCode: json['stockUnitCode'] as String?,
        required: (json['required'] as num?)?.toDouble() ?? 0,
        onHand: (json['onHand'] as num?)?.toDouble() ?? 0,
        sufficient: json['sufficient'] as bool? ?? false,
      );
}

class AvailabilityCheckResult {
  final bool available;
  final List<ComponentAvailability> components;

  AvailabilityCheckResult({required this.available, this.components = const []});

  factory AvailabilityCheckResult.fromJson(Map<String, dynamic> json) =>
      AvailabilityCheckResult(
        available: json['available'] as bool? ?? false,
        components: (json['components'] as List<dynamic>?)
                ?.map((e) => ComponentAvailability.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
