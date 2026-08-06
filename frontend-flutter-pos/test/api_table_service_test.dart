import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/table_models.dart';
import 'package:frontend_flutter_pos/features/pos/services/table_service.dart';

/// A tiny fake API service used just for these unit tests.
class FakeApiService extends ApiService {
  final Map<String, dynamic> _getResponses = {};
  final Map<String, dynamic> _postResponses = {};
  final List<String> calls = [];

  void whenGet(String path, dynamic response) => _getResponses[path] = response;
  void whenPost(String path, dynamic response) =>
      _postResponses[path] = response;

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('GET $path');
    final resp = _getResponses[path];
    if (resp == null) throw Exception('no response for $path');
    return resp as T;
  }

  @override
  Future<T> post<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('POST $path ${data ?? ''}');
    final resp = _postResponses[path];
    return (resp ?? {}) as T;
  }
}

void main() {
  late FakeApiService fakeApi;
  late ApiTableService service;

  setUp(() {
    fakeApi = FakeApiService();
    service = ApiTableService(fakeApi);
  });

  test('searchTables forwards parameters and parses response', () async {
    fakeApi.whenGet('/tables', {
      'content': [RestaurantTable.sample().toJson()],
      'number': 0,
      'size': 1,
      'totalElements': 1,
      'totalPages': 1,
    });

    final page = await service.searchTables(search: 'foo', page: 1, size: 10);
    expect(page.content, hasLength(1));
    expect(page.number, 0); // because we ignore query parameters in fake
    expect(fakeApi.calls, contains('GET /tables'));
  });

  test('getStats returns decoded TableStats', () async {
    fakeApi.whenGet('/tables/stats', {
      'totalTables': 5,
      'activeTables': 4,
      'availableTables': 3,
      'occupiedTables': 1,
      'reservedTables': 1,
    });

    final stats = await service.getStats();
    expect(stats.totalTables, 5);
    expect(fakeApi.calls.last, 'GET /tables/stats');
  });

  group('LocalTableService', () {
    late LocalTableService local;
    setUp(() {
      local = LocalTableService();
    });

    test('searchTables returns sample page regardless of args', () async {
      final page = await local.searchTables(search: 'whatever');
      expect(page.content.first.displayName, 'Table A1');
    });

    test('getStats returns the sample stats', () async {
      final stats = await local.getStats();
      expect(stats.availableTables, isNonZero);
    });
  });
}
