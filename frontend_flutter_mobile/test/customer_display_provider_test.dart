import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/customer_display_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/customer_display_relay.dart';

void main() {
  group('buildCustomerDisplayWebSocketUri', () {
    test('maps http scheme to ws and builds the expected shape', () {
      final Uri uri = buildCustomerDisplayWebSocketUri(
        serverBaseUrl: 'http://192.168.1.13:8081',
        sessionCode: 'abcd2345',
        role: CustomerDisplayRole.pos,
      );

      expect(uri.scheme, 'ws');
      expect(uri.host, '192.168.1.13');
      expect(uri.port, 8081);
      expect(uri.path, '/ws/customer-display');
      expect(uri.queryParameters['session'], 'ABCD2345');
      expect(uri.queryParameters['role'], 'pos');
    });

    test('maps https scheme to wss', () {
      final Uri uri = buildCustomerDisplayWebSocketUri(
        serverBaseUrl: 'https://pos.example.com',
        sessionCode: 'zzzz9999',
        role: CustomerDisplayRole.display,
      );

      expect(uri.scheme, 'wss');
      expect(uri.host, 'pos.example.com');
      expect(uri.path, '/ws/customer-display');
      expect(uri.queryParameters['session'], 'ZZZZ9999');
      expect(uri.queryParameters['role'], 'display');
    });

    test('uppercases and trims the session code', () {
      final Uri uri = buildCustomerDisplayWebSocketUri(
        serverBaseUrl: 'http://localhost:8081',
        sessionCode: '  a1b2c3d4  ',
        role: CustomerDisplayRole.pos,
      );

      expect(uri.queryParameters['session'], 'A1B2C3D4');
    });

    test('throws a FormatException when the base URL has no host', () {
      expect(
        () => buildCustomerDisplayWebSocketUri(
          serverBaseUrl: 'not a url',
          sessionCode: 'ABCD2345',
          role: CustomerDisplayRole.pos,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CustomerDisplayNotifier broadcasts (no active session)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      // Force-read the provider so its notifier (and relay client) exist.
      container.read(customerDisplayProvider);
    });

    tearDown(() {
      container.dispose();
    });

    CustomerDisplayNotifier notifier() =>
        container.read(customerDisplayProvider.notifier);

    test('starts disconnected/inactive with no session code', () {
      final CustomerDisplayStatus status =
          container.read(customerDisplayProvider);
      expect(status.isActive, isFalse);
      expect(status.sessionCode, isNull);
      expect(status.displayConnected, isFalse);
      expect(status.connectionState, CustomerDisplayConnectionState.disconnected);
    });

    test('broadcastIdle is a safe no-op and never mutates state', () {
      final CustomerDisplayStatus before =
          container.read(customerDisplayProvider);

      expect(() => notifier().broadcastIdle(), returnsNormally);

      final CustomerDisplayStatus after =
          container.read(customerDisplayProvider);
      expect(after.isActive, isFalse);
      expect(after.connectionState, before.connectionState);
      expect(after.displayConnected, before.displayConnected);
    });

    test('broadcastPaymentPending is a safe no-op', () {
      expect(
        () => notifier().broadcastPaymentPending(12.5, currencySymbol: r'$'),
        returnsNormally,
      );
      expect(container.read(customerDisplayProvider).isActive, isFalse);
    });

    test('broadcastPaymentSplitUpdate is a safe no-op', () {
      expect(
        () => notifier().broadcastPaymentSplitUpdate(
          splits: const <Map<String, dynamic>>[
            {'method': 'CASH', 'amount': 5.0},
          ],
          remaining: 7.5,
          currencySymbol: r'$',
        ),
        returnsNormally,
      );
      expect(container.read(customerDisplayProvider).isActive, isFalse);
    });

    test('broadcastPaymentCompleted is a safe no-op', () {
      expect(
        () => notifier().broadcastPaymentCompleted(
          receiptNumber: 'INV-1',
          total: 12.5,
          amountPaid: 12.5,
          change: 0,
          currencySymbol: r'$',
        ),
        returnsNormally,
      );
      expect(container.read(customerDisplayProvider).isActive, isFalse);
    });

    test('broadcastCartState is a safe no-op and does not throw building '
        'the JSON payload from a real CartState/CartItem', () {
      final Product product = Product(
        id: 1,
        sku: 'SKU-0001',
        nameEn: 'Iced Coffee',
        nameKm: 'កាហ្វេទឹកកក',
        barcode: '0001',
        price: 2.5,
        cost: 1.0,
        categoryId: 1,
        active: true,
      );
      final CartItem item = CartItem(
        id: 'item-1',
        product: product,
        qty: 2,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      );
      final CartState cart = CartState(items: <CartItem>[item]);

      expect(
        () => notifier().broadcastCartState(cart, currencySymbol: r'$'),
        returnsNormally,
      );
      expect(container.read(customerDisplayProvider).isActive, isFalse);
    });

    test('dispose after never connecting is also a safe no-op', () async {
      final CustomerDisplayNotifier n = notifier();
      await expectLater(n.stopSession(), completes);
    });
  });
}
