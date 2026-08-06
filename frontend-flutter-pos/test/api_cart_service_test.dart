import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';

/// A very small fake implementation of [ApiService] that allows tests to
/// register canned responses and record calls. We only override the handful of
/// methods that `ApiCartService` actually uses.
class FakeApiService extends ApiService {
  final Map<String, dynamic> _getResponses = {};
  final Map<String, dynamic> _postResponses = {};
  final Map<String, dynamic> _deleteResponses = {};
  final List<String> calls = [];

  void whenGet(String path, dynamic response) {
    _getResponses[path] = response;
  }

  void whenPost(String path, dynamic response) {
    _postResponses[path] = response;
  }

  void whenDelete(String path, dynamic response) {
    _deleteResponses[path] = response;
  }

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('GET $path');
    final resp = _getResponses[path];
    if (resp == null) {
      throw Exception('no get response for $path');
    }
    return resp as T;
  }

  @override
  Future<T> post<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('POST $path ${data ?? ''}');
    final resp = _postResponses[path];
    if (resp == null) {
      // default to empty map/void so tests need not stub every single call
      return {} as T;
    }
    return resp as T;
  }

  @override
  Future<T> delete<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('DELETE $path');
    final resp = _deleteResponses[path];
    if (resp == null) {
      // allow void
      return Future.value() as T;
    }
    return resp as T;
  }
}

void main() {
  late FakeApiService fakeApi;
  late ApiCartService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeApi = FakeApiService();
    service = ApiCartService(fakeApi);
  });

  test('getCartItems creates server cart and returns items', () async {
    fakeApi.whenPost('/api/carts', {'id': 42});
    fakeApi.whenGet('/api/carts/42', {
      'items': [
        {
          'id': 'abc',
          'productId': 1,
          'productNameEn': 'Test',
          'productNameKm': 'ពិសេស',
          'productSku': 'T1',
          'quantity': 2,
          'unitPrice': 3.5,
        }
      ]
    });

    final items = await service.getCartItems();
    expect(items, hasLength(1));
    expect(items.first.qty, 2);
    expect(items.first.product.price, 3.5);

    // cart id should be persisted
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('api_cart_id'), 42);
    expect(fakeApi.calls, contains('GET /api/carts/42'));
  });

  test('add and remove items use correct endpoints', () async {
    fakeApi.whenPost('/api/carts', {'id': 5});
    // first call to getCartItems will create cart
    fakeApi.whenGet('/api/carts/5', {'items': []});

    final item = CartItem.sample();
    await service.saveCartItems([item]);
    // clearCart will be called internally
    expect(fakeApi.calls, anyElement(contains('DELETE /api/carts/5')));
    expect(fakeApi.calls, anyElement(contains('POST /api/carts/5/items')));

    // remove single
    await service.removeCartItem('foo');
    expect(fakeApi.calls.last, 'DELETE /api/carts/5/items/foo');
  });

  test('clearCart sends delete and resets stored id', () async {
    fakeApi.whenPost('/api/carts', {'id': 99});
    fakeApi.whenGet('/api/carts/99', {'items': []});
    fakeApi.whenDelete('/api/carts/99', null);

    await service.getCartItems();
    await service.clearCart();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('api_cart_id'), isNull);
    expect(fakeApi.calls, contains('DELETE /api/carts/99'));
  });
}
