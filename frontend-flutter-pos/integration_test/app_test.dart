import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart'; // If this fails, try: import '../integration_test_driver/integration_test.dart';
import 'package:frontend_flutter_pos/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E App Flow', () {
    testWidgets('Login -> POS Screen -> Search -> Add to Cart',
        (final WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. If login screen is visible, perform login; otherwise assume already on POS
      if (find.text('KAKNNEA POS').evaluate().isNotEmpty) {
        // Verify login screen title and button
        expect(find.text('KAKNNEA POS'), findsOneWidget);
        expect(
            find.byWidgetPredicate((final widget) =>
                widget is Text &&
                widget.data == 'Sign in' &&
                widget.style?.fontSize == 24.0),
            findsOneWidget);

        final signInButton = find.byType(ElevatedButton);
        expect(signInButton, findsOneWidget);
        await tester.tap(signInButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // now we should be on POS screen
      expect(find.text('ProPOS'), findsOneWidget);

      // ensure data loaded without error
      expect(find.textContaining('Failed to load data'), findsNothing);
      expect(find.textContaining('Connection Error'), findsNothing);

      // search field should be present
      expect(find.byType(TextField), findsOneWidget);

      // 6. Verify Search Functionality
      // Find the search field
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Enter a search query
      await tester.enterText(searchField, 'Test Search');
      await tester.pumpAndSettle(
        const Duration(milliseconds: 600),
      ); // Wait for debounce

      // Clear search to ensure products are visible for the next step
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      // 7. Verify cart initially empty
      expect(find.text('Cart is empty'), findsOneWidget);

      // 8. Add Item to Cart
      await tester.pumpAndSettle(const Duration(seconds: 2));
      if (find.text('No products found').evaluate().isEmpty) {
        final productPrice = find.textContaining(r'$');
        if (productPrice.evaluate().isNotEmpty) {
          await tester.tap(productPrice.first);
          await tester.pumpAndSettle();

          // cart should no longer indicate empty
          expect(find.text('Cart is empty'), findsNothing);
          expect(find.text('1'), findsWidgets); // quantity or count
        }
      }
    });
  });
}
