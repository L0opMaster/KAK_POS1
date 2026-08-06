import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/models/table_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/table_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/table_selection_provider.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/table_selector.dart';
import 'package:frontend_flutter_pos/features/pos/services/table_service.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';

// Minimal fake service that returns a predetermined table page.  We
// accept the table object so that tests can assert identity rather than just
// comparing fields.
class FakeTableService extends TableService {
  final RestaurantTable table;

  FakeTableService(this.table) : super(ApiService());

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
    return TablePage(
      content: [table],
      number: 0,
      size: 1,
      totalElements: 1,
      totalPages: 1,
    );
  }

  @override
  Future<TableStats> getStats() async {
    return TableStats.sample();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TableSelector shows tables and updates selection',
      (tester) async {
    final table = RestaurantTable.sample();
    final container = ProviderContainer(overrides: [
      tableServiceProvider.overrideWithValue(FakeTableService(table)),
      tableSelectionProvider
          .overrideWith((ref) => TableSelectionNotifier.withValue(null)),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: MaterialApp(
          home: Builder(builder: (context) => const TableSelector()),
        ),
      ),
    );

    // initial build will create the provider in loading state; a post-frame
    // callback triggers the search.
    await tester.pump();
    // wait for the fake future to resolve and UI to settle
    await tester.pumpAndSettle();

    expect(find.text(table.displayText), findsOneWidget);

    // tap the table and ensure the dialog closes
    await tester.tap(find.text(table.displayText));
    await tester.pumpAndSettle();

    final selected = container.read(tableSelectionProvider);
    expect(selected, same(table));
  });
}
