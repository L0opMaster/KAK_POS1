import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/features/pos/models/table_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/table_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/table_service.dart';

/// Fake TableService — deterministic in-memory data, no network. Mirrors
/// `product_provider_test.dart`'s `_FakeProductService` pattern.
class _FakeTableService extends TableService {
  final List<RestaurantTable> tables;
  bool throwOnSearch = false;
  bool throwOnDelete = false;

  _FakeTableService({required this.tables}) : super(ApiService());

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
    if (throwOnSearch) throw Exception('boom');
    final needle = (search ?? '').trim().toLowerCase();
    final matches = tables.where((t) {
      final matchesSearch = needle.isEmpty ||
          t.tableNumber.toLowerCase().contains(needle) ||
          t.displayName.toLowerCase().contains(needle);
      final matchesStatus = status == null || t.status == status;
      return matchesSearch && matchesStatus;
    }).toList();
    return TablePage(
      content: matches,
      number: page,
      size: size,
      totalElements: matches.length,
      totalPages: 1,
    );
  }

  @override
  Future<TableStats> getStats() async => TableStats(
        totalTables: tables.length,
        activeTables: tables.where((t) => t.isActive).length,
        availableTables: tables.where((t) => t.status == 'AVAILABLE').length,
        occupiedTables: tables.where((t) => t.status == 'OCCUPIED').length,
        reservedTables: tables.where((t) => t.status == 'RESERVED').length,
      );

  @override
  Future<RestaurantTable> createTable(TableCreateRequest request) async {
    final table = RestaurantTable(
      id: tables.length + 1,
      tableNumber: request.tableNumber,
      displayName: request.displayName?.isNotEmpty == true
          ? request.displayName!
          : request.tableNumber,
      status: 'AVAILABLE',
      capacity: request.capacity,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      section: request.section,
      notes: request.notes,
    );
    tables.add(table);
    return table;
  }

  @override
  Future<RestaurantTable> updateTable(
      int id, TableUpdateRequest request) async {
    final index = tables.indexWhere((t) => t.id == id);
    if (index == -1) throw Exception('Table not found');
    final updated = tables[index].copyWith(
      displayName: request.displayName,
      capacity: request.capacity,
      section: request.section,
      notes: request.notes,
      status: request.status,
      isActive: request.isActive,
      updatedAt: DateTime.now(),
    );
    tables[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteTable(int id) async {
    if (throwOnDelete) throw Exception('cannot delete');
    tables.removeWhere((t) => t.id == id);
  }
}

RestaurantTable _table(
  int id, {
  String tableNumber = 'A1',
  String? displayName,
  String status = 'AVAILABLE',
  bool isActive = true,
}) =>
    RestaurantTable(
      id: id,
      tableNumber: tableNumber,
      displayName: displayName ?? tableNumber,
      status: status,
      capacity: 4,
      isActive: isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  group('TableNotifier.search (regression guard — used by the table picker)', () {
    test('populates state.data on success', () async {
      final service = _FakeTableService(
        tables: [_table(1, tableNumber: 'A1'), _table(2, tableNumber: 'B2')],
      );
      final notifier = TableNotifier(service);

      await notifier.search();

      expect(notifier.state.hasError, isFalse);
      expect(notifier.state.value?.content.length, 2);
    });

    test('filters by query, matching the picker\'s narrow search calls',
        () async {
      final service = _FakeTableService(
        tables: [_table(1, tableNumber: 'A1'), _table(2, tableNumber: 'B2')],
      );
      final notifier = TableNotifier(service);

      await notifier.search(query: 'A1');

      expect(notifier.state.value?.content.length, 1);
      expect(notifier.state.value?.content.single.tableNumber, 'A1');
    });

    test('sets state.error on failure', () async {
      final service = _FakeTableService(tables: [])..throwOnSearch = true;
      final notifier = TableNotifier(service);

      await notifier.search();

      expect(notifier.state.hasError, isTrue);
    });
  });

  group('TableNotifier admin CRUD', () {
    test('create() adds a table and refreshes state', () async {
      final service = _FakeTableService(tables: [_table(1)]);
      final notifier = TableNotifier(service);
      await notifier.search();

      final created = await notifier.create(
        TableCreateRequest(tableNumber: 'C3', capacity: 2),
      );

      expect(created.tableNumber, 'C3');
      expect(created.status, 'AVAILABLE');
      expect(notifier.state.value?.content.length, 2);
    });

    test('update() modifies the table and refreshes state', () async {
      final service = _FakeTableService(tables: [_table(1, tableNumber: 'A1')]);
      final notifier = TableNotifier(service);
      await notifier.search();

      final updated = await notifier.update(
        1,
        TableUpdateRequest(capacity: 8, status: 'RESERVED', isActive: false),
      );

      expect(updated.capacity, 8);
      expect(updated.status, 'RESERVED');
      expect(updated.isActive, isFalse);
      // Table number is immutable — untouched by the update.
      expect(updated.tableNumber, 'A1');
      expect(notifier.state.value?.content.single.status, 'RESERVED');
    });

    test('delete() removes the table and refreshes state', () async {
      final service = _FakeTableService(
        tables: [_table(1, tableNumber: 'A1'), _table(2, tableNumber: 'B2')],
      );
      final notifier = TableNotifier(service);
      await notifier.search();

      await notifier.delete(1);

      expect(notifier.state.value?.content.length, 1);
      expect(notifier.state.value?.content.single.tableNumber, 'B2');
    });

    test('delete() propagates service failures (e.g. occupied table)',
        () async {
      final service = _FakeTableService(tables: [_table(1)])
        ..throwOnDelete = true;
      final notifier = TableNotifier(service);

      expect(() => notifier.delete(1), throwsException);
    });

    test('loadStats() returns TableStats without touching state', () async {
      final service = _FakeTableService(
        tables: [
          _table(1, status: 'AVAILABLE'),
          _table(2, status: 'OCCUPIED'),
        ],
      );
      final notifier = TableNotifier(service);

      final stats = await notifier.loadStats();

      expect(stats.totalTables, 2);
      expect(stats.availableTables, 1);
      expect(stats.occupiedTables, 1);
      // search() was never called — state is still the initial loading value.
      expect(notifier.state.isLoading, isTrue);
    });
  });
}
