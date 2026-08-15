import 'modifier_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// product_models.dart` — COPY/ADAPT NEARLY EXACTLY (`Category`/`Product`
/// only — source's file is exactly these two classes, nothing else, so
/// this is effectively a full port).
///
/// Matches backend CategoryResponse DTO.
class Category {
  final int id;
  final String nameEn;
  final String nameKm;
  final int? parentId;
  final bool active;

  Category({
    required this.id,
    required this.nameEn,
    required this.nameKm,
    this.parentId,
    required this.active,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['id'] as num).toInt(),
        nameEn: json['nameEn'] as String,
        nameKm: json['nameKm'] as String,
        parentId:
            json['parentId'] == null ? null : (json['parentId'] as num).toInt(),
        active: json['active'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameEn': nameEn,
        'nameKm': nameKm,
        'parentId': parentId,
        'active': active,
      };
}

/// Matches backend ProductResponse DTO.
class Product {
  /// Modifier groups applicable to this product (e.g. Size, Toppings).
  final List<ModifierGroupResponse> modifierGroups;

  final int id;
  final String sku;
  final String barcode;
  final String nameEn;
  final String nameKm;
  final String? imageUrl;
  final String? description;
  final double cost;
  final double price;
  final double? resolvedPrice;
  final bool active;
  final bool sellable;
  final bool purchasable;
  final bool trackInventory;
  final String productType;
  final double lowStockThreshold;
  final int categoryId;
  final String? categoryNameEn;
  final String? categoryNameKm;
  final int? parentProductId;
  final String? parentProductNameEn;
  final String? variantLabel;
  final double stock;
  final double? availableSaleQty;
  final bool outOfStock;
  final bool lowStock;
  final int? saleUnitId;
  final String? saleUnitCode;
  final int? purchaseUnitId;
  final String? purchaseUnitCode;
  final int? stockUnitId;
  final String? stockUnitCode;

  Product({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.nameEn,
    required this.nameKm,
    this.imageUrl,
    this.description,
    required this.cost,
    required this.price,
    this.resolvedPrice,
    required this.active,
    this.sellable = true,
    this.purchasable = false,
    this.trackInventory = false,
    this.productType = 'SALE_ITEM',
    this.lowStockThreshold = 5,
    required this.categoryId,
    this.categoryNameEn,
    this.categoryNameKm,
    this.parentProductId,
    this.parentProductNameEn,
    this.variantLabel,
    this.stock = 0,
    this.availableSaleQty,
    this.outOfStock = false,
    this.lowStock = false,
    this.saleUnitId,
    this.saleUnitCode,
    this.purchaseUnitId,
    this.purchaseUnitCode,
    this.stockUnitId,
    this.stockUnitCode,
    this.modifierGroups = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: (json['id'] as num).toInt(),
        sku: json['sku'] as String? ?? '',
        barcode: json['barcode'] as String? ?? '',
        nameEn: json['nameEn'] as String? ?? '',
        nameKm: json['nameKm'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        description: json['description'] as String?,
        cost: (json['cost'] as num?)?.toDouble() ?? 0,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        resolvedPrice: (json['resolvedPrice'] as num?)?.toDouble(),
        active: json['active'] as bool? ?? true,
        sellable: json['sellable'] as bool? ?? true,
        purchasable: json['purchasable'] as bool? ?? false,
        trackInventory: json['trackInventory'] as bool? ?? false,
        productType: json['productType'] as String? ?? 'SALE_ITEM',
        lowStockThreshold:
            (json['lowStockThreshold'] as num?)?.toDouble() ?? 5,
        categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
        categoryNameEn: json['categoryNameEn'] as String?,
        categoryNameKm: json['categoryNameKm'] as String?,
        parentProductId: (json['parentProductId'] as num?)?.toInt(),
        parentProductNameEn: json['parentProductNameEn'] as String?,
        variantLabel: json['variantLabel'] as String?,
        stock: (json['stock'] as num?)?.toDouble() ?? 0,
        availableSaleQty: (json['availableSaleQty'] as num?)?.toDouble(),
        outOfStock: json['outOfStock'] as bool? ?? false,
        lowStock: json['lowStock'] as bool? ?? false,
        saleUnitId: (json['saleUnitId'] as num?)?.toInt(),
        saleUnitCode: json['saleUnitCode'] as String?,
        purchaseUnitId: (json['purchaseUnitId'] as num?)?.toInt(),
        purchaseUnitCode: json['purchaseUnitCode'] as String?,
        stockUnitId: (json['stockUnitId'] as num?)?.toInt(),
        stockUnitCode: json['stockUnitCode'] as String?,
        modifierGroups: json['modifierGroups'] is List
            ? (json['modifierGroups'] as List<dynamic>)
                .whereType<Map>()
                .map((e) =>
                    ModifierGroupResponse.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'barcode': barcode,
        'nameEn': nameEn,
        'nameKm': nameKm,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (description != null) 'description': description,
        'cost': cost,
        'price': price,
        'active': active,
        'sellable': sellable,
        'purchasable': purchasable,
        'trackInventory': trackInventory,
        'productType': productType,
        'lowStockThreshold': lowStockThreshold,
        'categoryId': categoryId,
        if (variantLabel != null) 'variantLabel': variantLabel,
        'initialStock': stock,
        if (parentProductId != null) 'parentProductId': parentProductId,
        if (saleUnitId != null) 'saleUnitId': saleUnitId,
        if (purchaseUnitId != null) 'purchaseUnitId': purchaseUnitId,
        if (stockUnitId != null) 'stockUnitId': stockUnitId,
      };
}
