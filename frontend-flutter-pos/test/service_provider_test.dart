import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/core/config/app_config.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/held_ticket_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/table_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A minimal fake API service that records calls and allows canned responses.
class FakeApiService extends ApiService {
  final List<String> calls = [];
  final Map<String, dynamic> _get = {};
  final Map<String, dynamic> _post = {};
  final Map<String, dynamic> _delete = {};

  void whenGet(String path, dynamic response) => _get[path] = response;
  void whenPost(String path, dynamic response) => _post[path] = response;
  void whenDelete(String path, dynamic response) => _delete[path] = response;

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('GET:$path');
    if (_get.containsKey(path)) {
      return _get[path] as T;
    }
    // return empty by default
    return Future.value({} as T);
  }

  @override
  Future<T> post<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('POST:$path');
    if (_post.containsKey(path)) {
      return _post[path] as T;
    }
    return Future.value({} as T);
  }

  @override
  Future<T> delete<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('DELETE:$path');
    if (_delete.containsKey(path)) {
      return _delete[path] as T;
    }
    return Future.value({} as T);
  }
}

void main() {
  // ensure shared_preferences binding is initialized when tests run
  TestWidgetsFlutterBinding.ensureInitialized();

  group('service providers', () {
    late ProviderContainer container;
    late FakeApiService fakeApi;

    setUp(() {
      fakeApi = FakeApiService();
      // make SharedPreferences available in tests
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      container.dispose();
    });

    test('cartServiceProvider returns LocalCartService when flag false', () {
      AppConfig.useApiCartService = false;
      container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(fakeApi),
      ]);

      final service = container.read(cartServiceProvider);
      expect(service, isA<LocalCartService>());
    });

    test('cartServiceProvider returns ApiCartService when flag true', () async {
      AppConfig.useApiCartService = true;
      container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(fakeApi),
      ]);

      final service = container.read(cartServiceProvider);
      expect(service, isA<ApiCartService>());

      final apiCart = service as ApiCartService;
      fakeApi.whenPost('/api/carts', {'id': 1});
      fakeApi.whenGet('/api/carts/1', {'items': []});
      await apiCart.getCartItems();
      expect(fakeApi.calls, contains('GET:/api/carts/1'));
    });

    test('heldTicketServiceProvider selects implementation based on flag', () {
      AppConfig.enableHeldTicketSync = false;
      container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(fakeApi),
      ]);
      final local = container.read(heldTicketServiceProvider);
      expect(local, isA<LocalHeldTicketService>());

      AppConfig.enableHeldTicketSync = true;
      container.dispose();
      container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(fakeApi),
      ]);
      final api = container.read(heldTicketServiceProvider);
      expect(api, isA<ApiHeldTicketService>());
    });

    test('tableServiceProvider selects implementation based on flag', () {
      AppConfig.useApiTableService = false;
      container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(fakeApi),
      ]);
      final local = container.read(tableServiceProvider);
      expect(local, isA<LocalTableService>());

      AppConfig.useApiTableService = true;
      container.dispose();
      container = ProviderContainer(overrides: [
        apiServiceProvider.overrideWithValue(fakeApi),
      ]);
      final apiTab = container.read(tableServiceProvider);
      expect(apiTab, isA<ApiTableService>());
    });
  });
}
