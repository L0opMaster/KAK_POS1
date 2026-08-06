import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend_flutter_pos/pos/models/cart_model.dart';
import 'package:frontend_flutter_pos/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/pos/screens/cart_screen.dart';
import 'package:frontend_flutter_pos/pos/services/cart_service.dart';
import 'cart_screen_test.mocks.dart';

@GenerateMocks([CartService])
void main() {
  group('CartScreen', () {
    late MockCartService mockCartService;

    setUp(() {
      mockCartService = MockCartService();
    });

    testWidgets('shows loading indicator when loading', (WidgetTester tester) async {
      when(mockCartService.getCart(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return Cart(id: '123', items: [], totalAmount: 0);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartServiceProvider.overrideWithValue(mockCartService),
          ],
          child: const MaterialApp(home: CartScreen()),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('shows empty cart message when cart is empty', (WidgetTester tester) async {
      when(mockCartService.getCart(any)).thenAnswer((_) async {
        return Cart(id: '123', items: [], totalAmount: 0);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartServiceProvider.overrideWithValue(mockCartService),
          ],
          child: const MaterialApp(home: CartScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Your Cart is Empty'), findsOneWidget);
    });

    testWidgets('shows error message on error', (WidgetTester tester) async {
      when(mockCartService.getCart(any)).thenThrow(Exception('Failed to load cart'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartServiceProvider.overrideWithValue(mockCartService),
          ],
          child: const MaterialApp(home: CartScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Oops, something went wrong!'), findsOneWidget);
    });

    testWidgets('shows cart items when cart is not empty', (WidgetTester tester) async {
      final cart = Cart(
        id: '123',
        items: [
          CartItem(id: 1, name: 'Product 1', quantity: 2, price: 10.0, totalPrice: 20.0),
          CartItem(id: 2, name: 'Product 2', quantity: 1, price: 15.0, totalPrice: 15.0),
        ],
        totalAmount: 35.0,
      );
      when(mockCartService.getCart(any)).thenAnswer((_) async => cart);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartServiceProvider.overrideWithValue(mockCartService),
          ],
          child: const MaterialApp(home: CartScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Product 1'), findsOneWidget);
      expect(find.text('Product 2'), findsOneWidget);
    });
  });
}
