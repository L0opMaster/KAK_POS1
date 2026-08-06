import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalCartService', () {
    late LocalCartService service;

    setUp(() async {
      // provide mock storage for shared_preferences plugin
      SharedPreferences.setMockInitialValues({});
      service = LocalCartService();
    });

    test('save and load items', () async {
      final item = CartItem.sample();
      await service.saveCartItems([item]);
      final loaded = await service.getCartItems();
      expect(loaded.length, 1);
      expect(loaded.first.id, item.id);
    });

    test('clearCart removes data', () async {
      final item = CartItem.sample();
      await service.saveCartItems([item]);
      await service.clearCart();
      final loaded = await service.getCartItems();
      expect(loaded, isEmpty);
    });

    test('removeCartItem deletes specific item', () async {
      final item1 = CartItem.sample();
      final item2 = CartItem(
        id: 'other',
        product: item1.product,
        qty: 1,
        addedAt: 0,
      );
      await service.saveCartItems([item1, item2]);
      await service.removeCartItem(item1.id);
      final loaded = await service.getCartItems();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'other');
    });
  });
}
