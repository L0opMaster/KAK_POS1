import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/screens/pos_screen.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/demo_product_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/held_ticket_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/product_service.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/product_card.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/product_grid.dart';

import 'test_l10n_helper.dart';

// status_bar and category_tabs widgets no longer used by POS screen
// imports retained for legacy tests or removed if unused.

// simple fake implementations used across tests
class FakeCartService extends CartService {
  @override
  Future<void> clearCart() async {}

  @override
  Future<List<CartItem>> getCartItems() async => [];

  @override
  Future<void> removeCartItem(String id) async {}

  @override
  Future<void> saveCartItems(List<CartItem> items) async {}
}

// fake product service returns provided list and can update it.  It also
// optionally serves a list of categories so tests can exercise the new
// categoriesProvider behaviour.
class FakeProductService extends ProductService {
  final List<Product> _list;
  final List<Category> _categories;
  FakeProductService(this._list, {List<Category>? categories})
      : _categories = categories ?? [];

  @override
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    int page = 0,
    int size = 100,
  }) async {
    var results = <Product>[..._list];
    if (categoryId != null) {
      results = results
          .where((final Product p) => p.categoryId == categoryId)
          .toList();
    }
    if (query != null && query.isNotEmpty) {
      final String q = query.toLowerCase();
      results = results
          .where(
            (final Product p) =>
                p.nameEn.toLowerCase().contains(q) ||
                p.nameKm.toLowerCase().contains(q),
          )
          .toList();
    }
    return results;
  }

  @override
  Future<List<Category>> getCategories() async => _categories;

  @override
  Future<List<Product>> getPopularProducts({int limit = 10}) async =>
      _list.take(limit).toList();

  @override
  Future<List<Product>> getLowStockProducts() async => _list;

  @override
  Future<Product> createProduct(final Product product) async => product;

  @override
  Future<Product> updateProduct(final Product product) async {
    final int idx = _list.indexWhere((final Product p) => p.id == product.id);
    if (idx != -1) {
      _list[idx] = product;
    }
    return product;
  }

  @override
  Future<void> deleteProduct(final int id) async {}
}

// simple in-memory held ticket service for tests
class LocalHeldService implements HeldTicketService {
  final Map<String, Map<String, dynamic>> store = {};
  int _next = 1;

  @override
  ApiService get api => throw UnimplementedError();
  @override
  final CartService cartService;

  LocalHeldService(this.cartService);

  @override
  Future<List<Map<String, dynamic>>> fetchHeldTickets() async =>
      store.values.toList();

  @override
  Future<Map<String, dynamic>?> holdTicket(
      {required final Map<String, dynamic> ticketData}) async {
    final String id = (_next++).toString();
    final Map<String, dynamic> copy = Map<String, dynamic>.from(ticketData);
    copy['id'] = id;
    store[id] = copy;
    return copy;
  }

  @override
  Future<bool> releaseTicket({required final String ticketId}) async {
    store.remove(ticketId);
    return true;
  }
}

void main() {
  testWidgets('simulate scan button adds first product to cart',
      (final WidgetTester tester) async {
    // create provider container with known single product
    final List<Product> products = [
      Product.sample().copyWith(barcode: 'SIM123')
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productServiceProvider
              .overrideWithValue(FakeProductService(products)),
          cartProvider.overrideWith(
            (final Ref<CartState> ref) => CartNotifier(FakeCartService(), ref),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: SizedBox(width: 800, height: 600, child: PosScreen()),
        ),
      ),
    );
    // allow initial product load to complete
    await tester.pumpAndSettle();

    // status bar widget removed from design; verify app title instead
    expect(find.text('ProPOS'), findsOneWidget);

    // ensure simulate button exists
    final Finder simButton = find.byKey(const Key('simulate_scan'));
    expect(simButton, findsOneWidget);

    await tester.tap(simButton);
    await tester.pumpAndSettle();

    // snackbar shown
    expect(find.text('Simulated scan SIM123'), findsOneWidget);
  });

  testWidgets('Search bar filters products', (final WidgetTester tester) async {
    final List<Product> products = [
      Product.sample().copyWith(id: 5, nameEn: 'Coffee', categoryId: 1),
      Product.sample().copyWith(id: 6, nameEn: 'Tea', categoryId: 2),
    ];
    final FakeProductService service = FakeProductService(products);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productServiceProvider.overrideWithValue(service),
          cartProvider.overrideWith(
            (final Ref<CartState> ref) => CartNotifier(FakeCartService(), ref),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: SizedBox(width: 800, height: 600, child: PosScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // both products should appear initially in grid tiles as text labels
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Tea'), findsOneWidget);

    // enter search term 'Tea'
    await tester.enterText(find.byType(TextField).first, 'Tea');
    await tester.pumpAndSettle();
    // only tea tile should remain (search field also contains text)
    final Finder teaCard = find.descendant(
      of: find.byType(ProductCard),
      matching: find.text('Tea'),
    );
    expect(teaCard, findsOneWidget);
    expect(find.text('Coffee'), findsNothing);
  });

  testWidgets('Category tabs filter products',
      (final WidgetTester tester) async {
    final List<Product> products = [
      Product.sample().copyWith(id: 5, nameEn: 'Coffee', categoryId: 1),
      Product.sample().copyWith(id: 6, nameEn: 'Tea', categoryId: 2),
    ];
    // include API categories so tabs appear immediately with human names
    final FakeProductService service = FakeProductService(
      products,
      categories: [
        Category(id: 1, nameEn: 'Coffee', nameKm: 'កាហ្វេ', active: true),
        Category(id: 2, nameEn: 'Tea', nameKm: 'តែ', active: true),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productServiceProvider.overrideWithValue(service),
          cartProvider.overrideWith(
            (final Ref<CartState> ref) => CartNotifier(FakeCartService(), ref),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: SizedBox(width: 800, height: 600, child: PosScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // category chips should render (first is "All Items" plus API cats)
    expect(find.byType(Chip), findsWidgets);

    // tap the tea chip directly
    final Finder teaChip = find.widgetWithText(Chip, 'Tea');
    expect(teaChip, findsOneWidget);
    await tester.tap(teaChip);
    await tester.pumpAndSettle();

    // grid filters accordingly
    expect(
      find.descendant(
        of: find.byType(ProductGrid),
        matching: find.text('Tea'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ProductGrid),
        matching: find.text('Coffee'),
      ),
      findsNothing,
    );

    // clear by tapping All Items chip
    final Finder allChip = find.widgetWithText(Chip, 'All Items');
    if (allChip.evaluate().isNotEmpty) {
      await tester.tap(allChip);
      await tester.pumpAndSettle();
    }
    expect(
      find.descendant(
        of: find.byType(ProductGrid),
        matching: find.text('Coffee'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ProductGrid),
        matching: find.text('Tea'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Long press product in POS edits it',
      (final WidgetTester tester) async {
    final List<Product> products = [
      Product.sample().copyWith(id: 5, nameEn: 'Coffee')
    ];
    final FakeProductService service = FakeProductService(products);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productServiceProvider.overrideWithValue(service),
          cartProvider.overrideWith(
            (final Ref<CartState> ref) => CartNotifier(FakeCartService(), ref),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: SizedBox(width: 800, height: 600, child: PosScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // long press tile
    final Finder tileFinder = find.text('Coffee');
    await tester.longPress(tileFinder);
    await tester.pumpAndSettle();

    // edit dialog should appear
    expect(find.text('Edit Product'), findsOneWidget);
    // restrict textfields to those inside AlertDialog
    final Finder dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFields.at(0), 'Espresso');
    await tester.enterText(dialogFields.at(1), '4.20');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    // grid shows updated name; service data changed
    expect(find.text('Espresso'), findsOneWidget);
    expect(service._list.first.nameEn, 'Espresso');
  });

  // table selector no longer part of POS dashboard; UI test removed

  // hold order logic moved; UI no longer exposes 'Hold Order' button.
  // skipping detailed test for now.

  // dialog and hold tests removed
}
