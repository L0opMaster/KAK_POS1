import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';

class FailingCartService extends CartService {
  @override
  Future<void> clearCart() async {
    throw Exception('clear failed');
  }

  @override
  Future<List<CartItem>> getCartItems() async {
    throw Exception('load failed');
  }

  @override
  Future<void> removeCartItem(String id) async {
    throw Exception('remove failed');
  }

  @override
  Future<void> saveCartItems(List<CartItem> items) async {
    throw Exception('save failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cart notifier keeps app responsive when storage/service fails', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        cartServiceProvider.overrideWithValue(FailingCartService()),
      ],
    );
    addTearDown(container.dispose);

    final CartNotifier notifier = container.read(cartProvider.notifier);

    await notifier.loadCart();
    expect(container.read(cartProvider).loading, isFalse);

    await notifier.addItem(CartItem.sample());
    expect(container.read(cartProvider).loading, isFalse);

    await notifier.clear();
    expect(container.read(cartProvider).loading, isFalse);
  });
}
