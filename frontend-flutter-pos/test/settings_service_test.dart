import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/settings_service.dart';

class FakeApiService extends ApiService {
  final Map<String, dynamic> _getResponses = {};
  final Map<String, dynamic> _putResponses = {};
  final Map<String, dynamic> _patchResponses = {};
  final List<String> calls = [];

  void whenGet(String path, dynamic response) => _getResponses[path] = response;
  void whenPut(String path, dynamic response) => _putResponses[path] = response;
  void whenPatch(String path, dynamic response) =>
      _patchResponses[path] = response;

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('GET $path');
    final resp = _getResponses[path];
    return (resp ?? <String, dynamic>{}) as T;
  }

  @override
  Future<T> put<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('PUT $path $data');
    final resp = _putResponses[path];
    return (resp ?? <String, dynamic>{}) as T;
  }

  @override
  Future<T> patch<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('PATCH $path $data');
    final resp = _patchResponses[path];
    return (resp ?? <String, dynamic>{}) as T;
  }
}

void main() {
  late FakeApiService fakeApi;
  late SettingsService service;

  setUp(() {
    fakeApi = FakeApiService();
    service = SettingsService(fakeApi);
  });

  test('getGeneral/updateGeneral hit /api/settings/general', () async {
    fakeApi.whenGet('/api/settings/general', {'currency': 'USD'});
    final result = await service.getGeneral();
    expect(result['currency'], 'USD');

    await service.updateGeneral({'currency': 'KHR'});
    expect(
      fakeApi.calls,
      contains('PUT /api/settings/general {currency: KHR}'),
    );
  });

  test('getTax/updateTax hit /api/settings/tax', () async {
    fakeApi.whenGet('/api/settings/tax', {'taxRate': 0.1, 'showTax': true});
    final result = await service.getTax();
    expect(result['taxRate'], 0.1);

    await service.updateTax({'taxRate': 0.05, 'showTax': false});
    expect(
      fakeApi.calls,
      contains('PUT /api/settings/tax {taxRate: 0.05, showTax: false}'),
    );
  });

  test('getPrinters/updatePrinters hit /api/settings/printers', () async {
    fakeApi.whenGet(
      '/api/settings/printers',
      {'invoiceFooter': 'Thank you'},
    );
    final result = await service.getPrinters();
    expect(result['invoiceFooter'], 'Thank you');

    await service.updatePrinters({'invoiceFooter': 'See you again'});
    expect(
      fakeApi.calls,
      contains(
        'PUT /api/settings/printers {invoiceFooter: See you again}',
      ),
    );
  });

  test('getPaymentMethods unwraps paged content', () async {
    fakeApi.whenGet('/api/settings/payment-methods', {
      'content': [
        {'id': 1, 'code': 'CASH', 'name': 'Cash', 'active': true},
      ],
    });
    final list = await service.getPaymentMethods();
    expect(list, hasLength(1));
    expect(list.first['code'], 'CASH');
  });

  test('updatePaymentMethodStatus PATCHes the status sub-path', () async {
    await service.updatePaymentMethodStatus(1, false);
    expect(
      fakeApi.calls,
      contains('PATCH /api/settings/payment-methods/1/status {active: false}'),
    );
  });

  test('getCurrencies unwraps paged content', () async {
    fakeApi.whenGet('/api/settings/currencies', {
      'content': [
        {'id': 2, 'code': 'USD', 'active': true},
      ],
    });
    final list = await service.getCurrencies();
    expect(list, hasLength(1));
    expect(list.first['code'], 'USD');
  });

  test('updateCurrencyStatus PATCHes the status sub-path', () async {
    await service.updateCurrencyStatus(2, true);
    expect(
      fakeApi.calls,
      contains('PATCH /api/settings/currencies/2/status {active: true}'),
    );
  });
}
