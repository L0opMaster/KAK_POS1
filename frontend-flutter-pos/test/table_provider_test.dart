import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_pos/features/pos/models/table_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/table_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/table_service.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';

// simple service implementation that always throws; used by one of the
// tests below.  Declared at top level because Dart does not permit nested
// class declarations inside functions.
class BrokenService extends TableService {
  BrokenService() : super(ApiService());

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
    throw Exception('fail');
  }

  @override
  Future<TableStats> getStats() async {
    throw Exception('fail');
  }
}

void main() {
  test('tableProvider uses local service and returns sample data', () async {
    final container = ProviderContainer(overrides: [
      tableServiceProvider.overrideWithValue(LocalTableService()),
    ]);

    // initial state should be loading
    expect(container.read(tableProvider), isA<AsyncLoading>());

    // trigger a search
    await container.read(tableProvider.notifier).search(query: 'test');

    final state = container.read(tableProvider);
    expect(state, isA<AsyncData<TablePage>>());
    expect(state.asData!.value.content, isNotEmpty);
  });

  test('tableProvider propagates errors from service', () async {
    final container = ProviderContainer(overrides: [
      tableServiceProvider.overrideWithValue(BrokenService()),
    ]);

    await container.read(tableProvider.notifier).search();
    final state = container.read(tableProvider);
    expect(state.hasError, isTrue);
  });
}
