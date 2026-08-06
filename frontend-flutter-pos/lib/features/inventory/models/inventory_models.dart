/// Models for Advanced Inventory Management — Stock Adjustments, Inventory
/// Counts, Transfer Orders, Purchase Orders, Suppliers, Inventory History
/// and Valuation. Field shapes are matched directly against the backend
/// DTOs (InventoryDtos, SupplierDtos, PurchasingWorkflowDtos, TransferDtos)
/// rather than guessed — see each class for which backend DTO it mirrors.

// ─────────────────────────────────────────────────────────────
// Stock Movement (backs both Stock Adjustments and Inventory History —
// same backend shape: InventoryDtos.StockMovementResponse, from
// GET /api/inventory/movements).
// ─────────────────────────────────────────────────────────────
class StockMovementEntry {
  final int? id;
  final int productId;
  final String productName;
  final int? storeId;
  final String? storeName;
  final String movementType;
  final double quantity;
  final String? reason;
  final String? createdBy;
  final DateTime createdAt;

  StockMovementEntry({
    this.id,
    required this.productId,
    required this.productName,
    this.storeId,
    this.storeName,
    required this.movementType,
    required this.quantity,
    this.reason,
    this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StockMovementEntry.fromJson(Map<String, dynamic> json) {
    return StockMovementEntry(
      id: (json['id'] as num?)?.toInt(),
      productId: (json['productId'] as num?)?.toInt() ?? 0,
      productName: json['productNameEn'] as String? ?? '',
      storeId: (json['storeId'] as num?)?.toInt(),
      storeName: json['storeName'] as String?,
      movementType: json['movementType'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Request payload to record a manual stock adjustment.
/// Mirrors InventoryDtos.StockAdjustRequest (POST /api/inventory/adjust).
class StockAdjustmentRequest {
  final int productId;
  final double quantity;
  final int? storeId;
  final String? reason;

  StockAdjustmentRequest({
    required this.productId,
    required this.quantity,
    this.storeId,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        if (storeId != null) 'storeId': storeId,
        if (reason != null) 'reason': reason,
      };
}

// ─────────────────────────────────────────────────────────────
// Inventory Count
// ─────────────────────────────────────────────────────────────
enum CountStatus { draft, inProgress, completed, cancelled }

extension CountStatusExt on CountStatus {
  String get label {
    switch (this) {
      case CountStatus.draft:
        return 'Draft';
      case CountStatus.inProgress:
        return 'In Progress';
      case CountStatus.completed:
        return 'Completed';
      case CountStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class InventoryCountItem {
  final int? snapshotId;
  final int productId;
  final String productName;
  final double expectedStock;
  final double countedStock;
  final double discrepancy;
  final String? countStatus;

  InventoryCountItem({
    this.snapshotId,
    required this.productId,
    required this.productName,
    required this.expectedStock,
    required this.countedStock,
    required this.discrepancy,
    this.countStatus,
  });

  factory InventoryCountItem.fromJson(Map<String, dynamic> json) {
    return InventoryCountItem(
      snapshotId: (json['snapshotId'] as num?)?.toInt(),
      productId: (json['productId'] as num?)?.toInt() ?? 0,
      productName: json['productNameEn'] as String? ?? '',
      expectedStock: (json['expectedQuantity'] as num?)?.toDouble() ?? 0,
      countedStock: (json['countedQuantity'] as num?)?.toDouble() ??
          (json['expectedQuantity'] as num?)?.toDouble() ??
          0,
      discrepancy: (json['varianceQuantity'] as num?)?.toDouble() ?? 0,
      countStatus: json['countStatus'] as String?,
    );
  }
}

/// A day's inventory count — grouped client-side from InventoryCountItem
/// entries returned by GET /api/inventory/counts?date=...&storeId=....
/// There's no single backend "count" entity; a count is just "the set of
/// snapshot entries for a given date".
class InventoryCount {
  final String snapshotDate;
  final CountStatus status;
  final List<InventoryCountItem> items;

  InventoryCount({
    required this.snapshotDate,
    required this.status,
    this.items = const [],
  });

  int get totalDiscrepancies =>
      items.fold(0, (sum, item) => sum + item.discrepancy.abs().round());

  int get itemCount => items.length;
}

// ─────────────────────────────────────────────────────────────
// Supplier — mirrors SupplierDtos.SupplierRequest / SupplierResponse.
// ─────────────────────────────────────────────────────────────
class Supplier {
  final int? id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? paymentTerms;
  final int? leadTimeDays;
  final String? taxId;
  final String defaultCurrency;
  final bool active;
  final String? notes;

  // Response-only fields (ignored on create/update).
  final int? catalogItemCount;
  final double? openPayable;
  final String? lastPurchaseDate;

  Supplier({
    this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.paymentTerms,
    this.leadTimeDays,
    this.taxId,
    this.defaultCurrency = 'KHR',
    this.active = true,
    this.notes,
    this.catalogItemCount,
    this.openPayable,
    this.lastPurchaseDate,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: (json['id'] as num?)?.toInt(),
        name: json['name'] as String? ?? '',
        contactPerson: json['contactPerson'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        paymentTerms: json['paymentTerms'] as String?,
        leadTimeDays: (json['leadTimeDays'] as num?)?.toInt(),
        taxId: json['taxId'] as String?,
        defaultCurrency: json['defaultCurrency'] as String? ?? 'KHR',
        active: json['active'] as bool? ?? true,
        notes: json['notes'] as String?,
        catalogItemCount: (json['catalogItemCount'] as num?)?.toInt(),
        openPayable: (json['openPayable'] as num?)?.toDouble(),
        lastPurchaseDate: json['lastPurchaseDate'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (contactPerson != null) 'contactPerson': contactPerson,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (paymentTerms != null) 'paymentTerms': paymentTerms,
        if (leadTimeDays != null) 'leadTimeDays': leadTimeDays,
        if (taxId != null) 'taxId': taxId,
        'defaultCurrency': defaultCurrency,
        'active': active,
        if (notes != null) 'notes': notes,
      };
}

// ─────────────────────────────────────────────────────────────
// Purchase Order — mirrors PurchasingWorkflowDtos.PurchaseOrderRequest /
// PurchaseOrderResponse (POST/GET/PUT /api/purchase-orders, transitions
// via POST /api/purchase-orders/{id}/{action}).
// ─────────────────────────────────────────────────────────────
class PurchaseOrderLine {
  final int? id;
  final int productId;
  final String? productNameEn;
  final double quantity;
  final double? receivedQuantity;
  final double unitCost;
  final double? lineTotal;
  final String? lineNote;

  PurchaseOrderLine({
    this.id,
    required this.productId,
    this.productNameEn,
    required this.quantity,
    this.receivedQuantity,
    required this.unitCost,
    this.lineTotal,
    this.lineNote,
  });

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> json) =>
      PurchaseOrderLine(
        id: (json['id'] as num?)?.toInt(),
        productId: (json['productId'] as num?)?.toInt() ?? 0,
        productNameEn: json['productNameEn'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        receivedQuantity: (json['receivedQuantity'] as num?)?.toDouble(),
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0,
        lineTotal: (json['lineTotal'] as num?)?.toDouble(),
        lineNote: json['lineNote'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'unitCost': unitCost,
        if (lineNote != null) 'lineNote': lineNote,
      };
}

class PurchaseOrder {
  final int? id;
  final String? referenceNumber;
  final int supplierId;
  final String? supplierName;
  final int? storeId;
  final String? storeName;
  final String status;
  final DateTime? orderDeadline;
  final DateTime? expectedArrival;
  final double taxRate;
  final double? subtotal;
  final double? taxAmount;
  final double? totalAmount;
  final String? notes;
  final List<PurchaseOrderLine> lines;

  PurchaseOrder({
    this.id,
    this.referenceNumber,
    required this.supplierId,
    this.supplierName,
    this.storeId,
    this.storeName,
    this.status = 'DRAFT',
    this.orderDeadline,
    this.expectedArrival,
    this.taxRate = 0,
    this.subtotal,
    this.taxAmount,
    this.totalAmount,
    this.notes,
    this.lines = const [],
  });

  int get totalItems => lines.length;

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) => PurchaseOrder(
        id: (json['id'] as num?)?.toInt(),
        referenceNumber: json['referenceNumber'] as String?,
        supplierId: (json['supplierId'] as num?)?.toInt() ?? 0,
        supplierName: json['supplierName'] as String?,
        storeId: (json['storeId'] as num?)?.toInt(),
        storeName: json['storeName'] as String?,
        status: json['status'] as String? ?? 'DRAFT',
        orderDeadline: json['orderDeadline'] != null
            ? DateTime.tryParse(json['orderDeadline'] as String)
            : null,
        expectedArrival: json['expectedArrival'] != null
            ? DateTime.tryParse(json['expectedArrival'] as String)
            : null,
        taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0,
        subtotal: (json['subtotal'] as num?)?.toDouble(),
        taxAmount: (json['taxAmount'] as num?)?.toDouble(),
        totalAmount: (json['totalAmount'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        lines: (json['lines'] as List<dynamic>?)
                ?.map((e) =>
                    PurchaseOrderLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// Request payload for create/update (PurchaseOrderRequest shape).
  Map<String, dynamic> toJson() => {
        'supplierId': supplierId,
        if (storeId != null) 'storeId': storeId,
        if (orderDeadline != null)
          'orderDeadline': _dateOnly(orderDeadline!),
        if (expectedArrival != null)
          'expectedArrival': _dateOnly(expectedArrival!),
        'taxRate': taxRate,
        if (notes != null) 'notes': notes,
        'lines': lines.map((e) => e.toJson()).toList(),
      };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────
// Transfer Order — mirrors TransferDtos.TransferCreateRequest /
// TransferResponse (POST/GET /api/inventory/transfers,
// POST /{id}/complete, POST /{id}/cancel — no arbitrary update).
// ─────────────────────────────────────────────────────────────
class TransferOrderLine {
  final int productId;
  final String? productNameEn;
  final String? stockUnitCode;
  final double quantity;

  TransferOrderLine({
    required this.productId,
    this.productNameEn,
    this.stockUnitCode,
    required this.quantity,
  });

  factory TransferOrderLine.fromJson(Map<String, dynamic> json) =>
      TransferOrderLine(
        productId: (json['productId'] as num?)?.toInt() ?? 0,
        productNameEn: json['productNameEn'] as String?,
        stockUnitCode: json['stockUnitCode'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
      };
}

class TransferOrder {
  final int? id;
  final String? transferNumber;
  final int fromStoreId;
  final String? fromStoreName;
  final int toStoreId;
  final String? toStoreName;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final List<TransferOrderLine> lines;

  TransferOrder({
    this.id,
    this.transferNumber,
    required this.fromStoreId,
    this.fromStoreName,
    required this.toStoreId,
    this.toStoreName,
    this.status = 'DRAFT',
    this.notes,
    this.createdAt,
    this.completedAt,
    this.lines = const [],
  });

  int get totalItems => lines.length;

  factory TransferOrder.fromJson(Map<String, dynamic> json) => TransferOrder(
        id: (json['id'] as num?)?.toInt(),
        transferNumber: json['transferNumber'] as String?,
        fromStoreId: (json['fromStoreId'] as num?)?.toInt() ?? 0,
        fromStoreName: json['fromStoreName'] as String?,
        toStoreId: (json['toStoreId'] as num?)?.toInt() ?? 0,
        toStoreName: json['toStoreName'] as String?,
        status: json['status'] as String? ?? 'DRAFT',
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'] as String)
            : null,
        lines: (json['lines'] as List<dynamic>?)
                ?.map((e) =>
                    TransferOrderLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  /// Request payload for create (TransferCreateRequest shape).
  Map<String, dynamic> toJson() => {
        'fromStoreId': fromStoreId,
        'toStoreId': toStoreId,
        if (notes != null) 'notes': notes,
        'lines': lines.map((e) => e.toJson()).toList(),
      };
}

// ─────────────────────────────────────────────────────────────
// Inventory Valuation — mirrors InventoryDtos.StockValuationResponse,
// whose `items` are plain StockResponse rows.
// ─────────────────────────────────────────────────────────────
class InventoryValuationItem {
  final int productId;
  final String productName;
  final String sku;
  final double stock;
  final double cost;
  final double totalValue;

  InventoryValuationItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.stock,
    required this.cost,
    required this.totalValue,
  });

  factory InventoryValuationItem.fromJson(Map<String, dynamic> json) =>
      InventoryValuationItem(
        productId: (json['productId'] as num?)?.toInt() ?? 0,
        productName: json['productNameEn'] as String? ?? '',
        sku: json['productCode'] as String? ?? '',
        stock: (json['quantity'] as num?)?.toDouble() ?? 0,
        cost: (json['unitCost'] as num?)?.toDouble() ?? 0,
        totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      );
}

class InventoryValuationReport {
  final String? valuedAt;
  final List<InventoryValuationItem> items;
  final double totalValue;

  InventoryValuationReport({
    this.valuedAt,
    this.items = const [],
    this.totalValue = 0,
  });

  int get totalProducts => items.length;
  double get totalStock => items.fold(0, (sum, i) => sum + i.stock);

  factory InventoryValuationReport.fromJson(Map<String, dynamic> json) =>
      InventoryValuationReport(
        valuedAt: json['valuedAt'] as String?,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) => InventoryValuationItem.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            [],
        totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────
// Store / Location
// ─────────────────────────────────────────────────────────────
class StoreLocation {
  final int? id;
  final String name;
  final String? address;
  final bool active;

  StoreLocation({
    this.id,
    required this.name,
    this.address,
    this.active = true,
  });

  factory StoreLocation.fromJson(Map<String, dynamic> json) => StoreLocation(
        id: (json['id'] as num?)?.toInt(),
        name: json['name'] as String? ?? '',
        address: json['address'] as String?,
        active: json['active'] as bool? ?? true,
      );

  static StoreLocation sample() => StoreLocation(id: 1, name: 'Main Store');
}
