import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/held_ticket_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/cart_panel.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';

// Fake cart service used in multiple tests
class FakeCartService extends CartService {
  // simple in-memory backup to mimic persistence
  List<CartItem> _items = [];

  @override
  Future<void> clearCart() async {
    _items = [];
  }

  @override
  Future<List<CartItem>> getCartItems() async => List.unmodifiable(_items);

  @override
  Future<void> removeCartItem(String id) async {
    _items.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> saveCartItems(List<CartItem> items) async {
    _items = List.of(items);
  }
}

// (FakeNotifier removed; using LocalHeldTicketService below instead)
// simple in-memory held-ticket service used in second test
// use the production local implementation for held tickets
// which is effectively the same in-memory store used previously.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CartPanel shows held tickets dialog on button tap',
      (tester) async {
    final heldService = LocalHeldTicketService(ApiService(), FakeCartService());
    final sampleItem = CartItem.sample();
    await heldService.holdTicket(ticketData: {
      'status': 'open',
      'cart': [sampleItem.toJson()],
      'tableName': 'A1',
    });

    late CartNotifier cartNotifier;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        heldTicketServiceProvider.overrideWith((ref) => heldService),
        cartProvider.overrideWith((ref) {
          cartNotifier = CartNotifier(FakeCartService(), ref);
          return cartNotifier;
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: CartPanel())),
    ));

    expect(find.text('Open Held Tickets'), findsOneWidget);
    await tester.tap(find.text('Open Held Tickets'));
    await tester.pumpAndSettle();

    expect(find.text('Held Tickets'), findsOneWidget);
    expect(find.text('Ticket #1'), findsOneWidget);

    await tester.tap(find.text('Ticket #1'));
    await tester.pumpAndSettle();
    expect(cartNotifier.state.items.length, 1);
  });

  testWidgets('holdCurrentCart and restore via dialog work', (tester) async {
    final heldService = LocalHeldTicketService(ApiService(), FakeCartService());

    late CartNotifier cartNotifier;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        heldTicketServiceProvider.overrideWith((ref) => heldService),
        cartProvider.overrideWith((ref) {
          cartNotifier = CartNotifier(FakeCartService(), ref);
          return cartNotifier;
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: CartPanel())),
    ));
    await cartNotifier.addItem(CartItem.sample());
    await tester.pumpAndSettle();

    // hold the current cart via the real "Hold" button
    await tester.tap(find.widgetWithText(OutlinedButton, 'Hold'));
    await tester.pumpAndSettle();
    expect(cartNotifier.state.items, isEmpty);

    // now dialog should show the held ticket
    await tester.tap(find.text('Open Held Tickets'));
    await tester.pumpAndSettle();
    final ticketTile = find.widgetWithText(ListTile, 'Ticket #1');
    expect(ticketTile, findsOneWidget);
    // restore ticket
    await tester.tap(ticketTile);
    await tester.pumpAndSettle();
    expect(cartNotifier.state.items.length, 1);
  });

  testWidgets('stepper buttons increment and decrement quantity',
      (tester) async {
    final product = CartItem.sample().product;
    final item = CartItem.sample();
    late CartNotifier cartNotifier;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        cartProvider.overrideWith((ref) {
          cartNotifier = CartNotifier(FakeCartService(), ref);
          return cartNotifier;
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: CartPanel())),
    ));
    await cartNotifier.loadCart();
    await cartNotifier.addItem(item);
    await tester.pumpAndSettle();
    // verify initial quantity (sample item starts at 2)
    expect(find.text(product.nameEn), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    // increment
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(cartNotifier.state.items.first.qty, 3);
    expect(find.text('3'), findsWidgets);

    // decrement back to 2
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(cartNotifier.state.items.first.qty, 2);
    expect(find.text('2'), findsWidgets);

    // verify totals section renders
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.textContaining('Charge'), findsOneWidget);

    // add a note to the item via the note button
    await tester.tap(find.byIcon(Icons.sticky_note_2_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Add Note'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Special request');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();
    expect(cartNotifier.state.items.first.note, 'Special request');
    expect(find.text('Special request'), findsOneWidget);

    // remove item using delete icon
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(cartNotifier.state.items, isEmpty);
  });
}
