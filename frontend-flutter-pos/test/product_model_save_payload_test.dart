// Regression coverage for the product create/update form silently dropping
// or clobbering fields: `toJson()` never sent `initialStock` (new products
// always started at zero stock regardless of what was typed on the create
// form) or `description` (collected in the UI but never sent — and the
// backend's ProductRequest didn't even accept it), and never sent
// parentProductId/saleUnitId/purchaseUnitId/stockUnitId at all — which the
// backend interprets as "clear this", silently wiping them on every edit
// even though the form has no UI to change them.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';

void main() {
  group('Product.toJson', () {
    test('always includes initialStock, mirroring the stock field', () {
      final product = Product(
        id: 0,
        sku: 'SKU1',
        barcode: 'BC1',
        nameEn: 'Widget',
        nameKm: 'ធីវីជិត',
        cost: 1,
        taxRate: 0,
        price: 2,
        active: true,
        categoryId: 1,
        stock: 50,
      );

      expect(product.toJson()['initialStock'], 50.0);
    });

    test('includes initialStock as 0 when no stock was entered (not '
        'omitted — 0 is a meaningful "no seed" value on create)', () {
      final product = Product(
        id: 0,
        sku: 'SKU1',
        barcode: 'BC1',
        nameEn: 'Widget',
        nameKm: 'ធីវីជិត',
        cost: 1,
        taxRate: 0,
        price: 2,
        active: true,
        categoryId: 1,
      );

      expect(product.toJson()['initialStock'], 0.0);
    });

    test('includes description when present', () {
      final product = Product(
        id: 1,
        sku: 'SKU1',
        barcode: 'BC1',
        nameEn: 'Widget',
        nameKm: 'ធីវីជិត',
        description: 'A very fine widget',
        cost: 1,
        taxRate: 0,
        price: 2,
        active: true,
        categoryId: 1,
      );

      expect(product.toJson()['description'], 'A very fine widget');
    });

    test('omits description when null (does not send an empty string that '
        'would overwrite a real value some other client set)', () {
      final product = Product(
        id: 1,
        sku: 'SKU1',
        barcode: 'BC1',
        nameEn: 'Widget',
        nameKm: 'ធីវីជិត',
        cost: 1,
        taxRate: 0,
        price: 2,
        active: true,
        categoryId: 1,
      );

      expect(product.toJson().containsKey('description'), isFalse);
    });

    test('preserves parentProductId/saleUnitId/purchaseUnitId/stockUnitId '
        'when carried over from an existing product (the edit-wipes-units '
        'bug)', () {
      final product = Product(
        id: 5,
        sku: 'SKU1',
        barcode: 'BC1',
        nameEn: 'Widget',
        nameKm: 'ធីវីជិត',
        cost: 1,
        taxRate: 0,
        price: 2,
        active: true,
        categoryId: 1,
        parentProductId: 9,
        saleUnitId: 2,
        purchaseUnitId: 3,
        stockUnitId: 4,
      );

      final json = product.toJson();
      expect(json['parentProductId'], 9);
      expect(json['saleUnitId'], 2);
      expect(json['purchaseUnitId'], 3);
      expect(json['stockUnitId'], 4);
    });

    test('omits parentProductId/unit ids when null, rather than sending a '
        'literal null that would still count as "present" to some servers',
        () {
      final product = Product(
        id: 1,
        sku: 'SKU1',
        barcode: 'BC1',
        nameEn: 'Widget',
        nameKm: 'ធីវីជិត',
        cost: 1,
        taxRate: 0,
        price: 2,
        active: true,
        categoryId: 1,
      );

      final json = product.toJson();
      expect(json.containsKey('parentProductId'), isFalse);
      expect(json.containsKey('saleUnitId'), isFalse);
      expect(json.containsKey('purchaseUnitId'), isFalse);
      expect(json.containsKey('stockUnitId'), isFalse);
    });
  });

  group('Product.fromJson / copyWith', () {
    test('description round-trips through fromJson', () {
      final product = Product.fromJson({
        'id': 1,
        'sku': 'SKU1',
        'barcode': 'BC1',
        'nameEn': 'Widget',
        'nameKm': 'ធីវីជិត',
        'description': 'From the backend',
        'cost': 1,
        'price': 2,
        'categoryId': 1,
      });

      expect(product.description, 'From the backend');
    });

    test('copyWith updates description independently of nameKm', () {
      final product = Product(
        id: 1,
        sku: 'SKU1',
        barcode: 'BC1',
        nameEn: 'Widget',
        nameKm: 'ធីវីជិត',
        cost: 1,
        taxRate: 0,
        price: 2,
        active: true,
        categoryId: 1,
      );

      final updated = product.copyWith(description: 'New description');
      expect(updated.description, 'New description');
      expect(updated.nameKm, 'ធីវីជិត');
    });
  });
}
