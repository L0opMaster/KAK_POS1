import 'modifier_models.dart';

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
        parentId: json['parentId'] == null ? null : (json['parentId'] as num).toInt(),
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
/// Documentation comment.
class Product {
  /// Modifier groups applicable to this product (e.g. Size, Toppings).
  /// Parsed from the `modifierGroups` field the backend `ProductResponse`
  /// includes. Reuses [ModifierGroupResponse]/[ModifierOptionResponse] from
  /// `modifier_models.dart` since the JSON shape matches (management CRUD
  /// screens already use those classes).
  final List<ModifierGroupResponse> modifierGroups;

  /// Documentation comment.
  final int id;
  /// Documentation comment.
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
        parentProductId:
            (json['parentProductId'] as num?)?.toInt(),
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
        // Backend only acts on this for a brand-new product with
        // trackInventory on (ProductService.create); ignored on update. Was
        // previously never sent at all, so "Initial Stock" entered on the
        // create form silently did nothing — every new product started at
        // zero stock regardless of what was typed here.
        'initialStock': stock,
        if (parentProductId != null) 'parentProductId': parentProductId,
        if (saleUnitId != null) 'saleUnitId': saleUnitId,
        if (purchaseUnitId != null) 'purchaseUnitId': purchaseUnitId,
        if (stockUnitId != null) 'stockUnitId': stockUnitId,
      };

  static Product sample() => Product(
        id: 1,
        sku: 'SKU001',
        barcode: 'BARCODE001',
        nameEn: 'Sample Product',
        nameKm: 'ទំនិញប្រើប្រាស់',
        price: 10.0,
        cost: 5.0,
        active: true,
        trackInventory: true,
        categoryId: 1,
        stock: 100,
      );

  Product copyWith({
    int? id,
    String? sku,
    String? barcode,
    String? nameEn,
    String? nameKm,
    String? imageUrl,
    String? description,
    double? cost,
    double? price,
    double? resolvedPrice,
    bool? active,
    bool? sellable,
    bool? purchasable,
    bool? trackInventory,
    String? productType,
    double? lowStockThreshold,
    int? categoryId,
    String? categoryNameEn,
    String? categoryNameKm,
    int? parentProductId,
    String? parentProductNameEn,
    String? variantLabel,
    double? stock,
    double? availableSaleQty,
    bool? outOfStock,
    bool? lowStock,
    int? saleUnitId,
    String? saleUnitCode,
    int? purchaseUnitId,
    String? purchaseUnitCode,
    int? stockUnitId,
    String? stockUnitCode,
    List<ModifierGroupResponse>? modifierGroups,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      nameEn: nameEn ?? this.nameEn,
      nameKm: nameKm ?? this.nameKm,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      cost: cost ?? this.cost,
      price: price ?? this.price,
      resolvedPrice: resolvedPrice ?? this.resolvedPrice,
      active: active ?? this.active,
      sellable: sellable ?? this.sellable,
      purchasable: purchasable ?? this.purchasable,
      trackInventory: trackInventory ?? this.trackInventory,
      productType: productType ?? this.productType,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      categoryId: categoryId ?? this.categoryId,
      categoryNameEn: categoryNameEn ?? this.categoryNameEn,
      categoryNameKm: categoryNameKm ?? this.categoryNameKm,
      parentProductId: parentProductId ?? this.parentProductId,
      parentProductNameEn: parentProductNameEn ?? this.parentProductNameEn,
      variantLabel: variantLabel ?? this.variantLabel,
      stock: stock ?? this.stock,
      availableSaleQty: availableSaleQty ?? this.availableSaleQty,
      outOfStock: outOfStock ?? this.outOfStock,
      lowStock: lowStock ?? this.lowStock,
      saleUnitId: saleUnitId ?? this.saleUnitId,
      saleUnitCode: saleUnitCode ?? this.saleUnitCode,
      purchaseUnitId: purchaseUnitId ?? this.purchaseUnitId,
      purchaseUnitCode: purchaseUnitCode ?? this.purchaseUnitCode,
      stockUnitId: stockUnitId ?? this.stockUnitId,
      stockUnitCode: stockUnitCode ?? this.stockUnitCode,
      modifierGroups: modifierGroups ?? this.modifierGroups,
    );
  }
}
