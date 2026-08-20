import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/table_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/table_selection_provider.dart';
import 'package:frontend_flutter_pos/features/pos/screens/table_selection_screen.dart';
import 'package:frontend_flutter_pos/features/pos/services/table_service.dart';
import 'package:frontend_flutter_pos/l10n/generated/app_localizations.dart';

/// Fake service returning a fixed set of tables across two sections, so
/// tests can exercise both the section filter and the plain grid.
class FakeTableService extends TableService {
  final List<RestaurantTable> tables;

  FakeTableService(this.tables) : super(ApiService());

  @override
  Future<TablePage> searchTables({
    String? search,
    String? status,
    String? section,
    bool? isActive,
    int page = 0,
    int size = 20,
    String? sortBy,
  }) async {
    final matches =
        section == null ? tables : tables.where((t) => t.section == section).toList();
    return TablePage(
      content: matches,
      number: 0,
      size: matches.length,
      totalElements: matches.length,
      totalPages: 1,
    );
  }

  @override
  Future<TableStats> getStats() async => TableStats.sample();

  @override
  Future<RestaurantTable> createTable(TableCreateRequest request) =>
      throw UnimplementedError();

  @override
  Future<RestaurantTable> updateTable(int id, TableUpdateRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTable(int id) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RestaurantTable table(int id, String number, {String? section}) =>
      RestaurantTable.sample().copyWith(
        id: id,
        tableNumber: number,
        displayName: 'Table $number',
        status: 'AVAILABLE',
        section: section,
      );

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    required List<RestaurantTable> tables,
    RestaurantTable? initialSelection,
  }) async {
    final container = ProviderContainer(overrides: [
      tableServiceProvider.overrideWithValue(FakeTableService(tables)),
      tableSelectionProvider
          .overrideWith((ref) => TableSelectionNotifier.withValue(initialSelection)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TableSelectionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('confirming a tapped table applies it to selection and cart',
      (tester) async {
    final t1 = table(1, 'A1');
    final t2 = table(2, 'A2');
    final container = await pumpScreen(tester, tables: [t1, t2]);

    await tester.tap(find.text('Table A2'));
    await tester.pumpAndSettle();

    // Not applied yet — only staged locally until CONFIRM.
    expect(container.read(tableSelectionProvider), isNull);
    expect(container.read(cartProvider).tableId, isNull);

    await tester.tap(find.text('CONFIRM'));
    await tester.pumpAndSettle();

    expect(container.read(tableSelectionProvider)?.id, 2);
    expect(container.read(cartProvider).tableId, 2);
  });

  testWidgets('pressing back without confirming leaves the cart untouched',
      (tester) async {
    final t1 = table(1, 'A1');
    final t2 = table(2, 'A2');
    final container =
        await pumpScreen(tester, tables: [t1, t2], initialSelection: t1);
    container.read(cartProvider.notifier).setTable(t1.id);

    await tester.tap(find.text('Table A2'));
    await tester.pumpAndSettle();

    // Simulate the back button by popping the navigator directly.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    expect(container.read(tableSelectionProvider)?.id, 1);
    expect(container.read(cartProvider).tableId, 1);
  });

  testWidgets('section filter only shows matching tables', (tester) async {
    final first = table(1, 'A1', section: 'First Floor');
    final second = table(2, 'B1', section: 'VIP');
    await pumpScreen(tester, tables: [first, second]);

    expect(find.text('Table A1'), findsOneWidget);
    expect(find.text('Table B1'), findsOneWidget);

    await tester.tap(find.text('VIP'));
    await tester.pumpAndSettle();

    expect(find.text('Table A1'), findsNothing);
    expect(find.text('Table B1'), findsOneWidget);
  });
}
