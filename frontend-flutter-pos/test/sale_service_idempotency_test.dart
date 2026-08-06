import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/sale_service.dart';

/// Captures the body posted to the sale endpoint so we can assert the
/// idempotency key (`clientRef`) is forwarded unchanged to the backend, which
/// dedupes on it (SaleService.findByClientRef) to prevent duplicate sales on
/// retry.
class CapturingApiService extends ApiService {
  Object? lastPostData;
  String? lastPostPath;

  @override
  Future<T> post<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    lastPostPath = path;
    lastPostData = data;
    return <String, dynamic>{
      'id': 1,
      'status': 'OPEN',
      'grandTotal': 0,
      'paidAmount': 0,
    } as T;
  }
}

void main() {
  test('createSale posts to the sale endpoint and forwards clientRef', () async {
    final api = CapturingApiService();
    final service = SaleService(api);

    const clientRef = 'test-ref-123';
    await service.createSale(<String, dynamic>{
      'lines': <dynamic>[],
      'clientRef': clientRef,
    });

    expect(api.lastPostPath, '/api/pos/sales');
    final body = api.lastPostData as Map<String, dynamic>;
    expect(body['clientRef'], clientRef,
        reason: 'clientRef must reach the backend so retries dedupe');
  });

  test('the same clientRef is reused across retries of one checkout', () async {
    final api = CapturingApiService();
    final service = SaleService(api);

    const clientRef = 'stable-key';
    final request = <String, dynamic>{'lines': <dynamic>[], 'clientRef': clientRef};

    // Simulate a retry: two submits of the *same* request map.
    await service.createSale(request);
    final first = (api.lastPostData as Map<String, dynamic>)['clientRef'];
    await service.createSale(request);
    final second = (api.lastPostData as Map<String, dynamic>)['clientRef'];

    expect(first, second);
  });
}
