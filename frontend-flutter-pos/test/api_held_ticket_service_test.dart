import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/held_ticket_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';

// re-use FakeApiService from cart tests - duplicate minimal implementation here
class FakeApiService extends ApiService {
  final Map<String, dynamic> _getResponses = {};
  final Map<String, dynamic> _postResponses = {};
  final Map<String, dynamic> _deleteResponses = {};
  final List<String> calls = [];

  void whenGet(String path, dynamic response) => _getResponses[path] = response;
  void whenPost(String path, dynamic response) =>
      _postResponses[path] = response;
  void whenDelete(String path, dynamic response) =>
      _deleteResponses[path] = response;

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('GET $path');
    final resp = _getResponses[path];
    return (resp ?? []) as T;
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

  @override
  Future<T> delete<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('DELETE $path');
    final resp = _deleteResponses[path];
    return (resp ?? {}) as T;
  }
}

// Simple fake cart service since HeldTicketService requires it but doesn't use it
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

void main() {
  late FakeApiService fakeApi;
  late ApiHeldTicketService service;

  setUp(() {
    fakeApi = FakeApiService();
    service = ApiHeldTicketService(fakeApi, FakeCartService());
  });

  test('fetchHeldTickets calls GET endpoint and returns list', () async {
    fakeApi.whenGet('/api/pos/held-tickets', [
      {'id': '1', 'status': 'open', 'cart': []}
    ]);

    final list = await service.fetchHeldTickets();
    expect(list, isA<List>());
    expect(list, hasLength(1));
    expect(fakeApi.calls, contains('GET /api/pos/held-tickets'));
  });

  test('holdTicket posts to correct path including tableName', () async {
    fakeApi.whenPost('/api/pos/held-tickets', {'id': '10'});
    final payload = {'foo': 'bar', 'tableName': 'A1'};
    final ok = await service.holdTicket(ticketData: payload);
    expect(ok, isTrue);
    expect(fakeApi.calls, anyElement(startsWith('POST /api/pos/held-tickets')));
    // verify payload stringified contains 'tableName'
    expect(fakeApi.calls.any((c) => c.contains('tableName')), isTrue);
  });

  test('releaseTicket deletes using id', () async {
    fakeApi.whenDelete('/api/pos/held-tickets/99', null);
    final ok = await service.releaseTicket(ticketId: '99');
    expect(ok, isTrue);
    expect(fakeApi.calls.last, 'DELETE /api/pos/held-tickets/99');
  });
}
