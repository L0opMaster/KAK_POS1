import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../models/customer_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// customer_service.dart` — now the full surface: admin CRUD
/// (`createCustomer`/`updateCustomer`/`deleteCustomer`) plus the credit
/// ledger and purchase-history reads used by the customer detail screen.
abstract class CustomerService {
  Future<List<Customer>> listCustomers({String query = ''});
  Future<Customer?> getCustomer(int id);
  Future<Customer> createCustomer(CreateCustomerRequest request);
  Future<Customer> updateCustomer(int id, CreateCustomerRequest request);
  Future<void> deleteCustomer(int id);
  Future<CreditLedgerResponse> getCreditLedger(int customerId);
  Future<List<CustomerSaleHistoryEntry>> getCustomerHistory(int customerId);
}

class ApiCustomerService extends CustomerService {
  ApiCustomerService(this._api);

  final ApiService _api;

  @override
  Future<List<Customer>> listCustomers({String query = ''}) async {
    final response = await _api.get<List<dynamic>>(
      '/api/customers',
      queryParameters: {'q': query},
    );
    return response
        .cast<Map<String, dynamic>>()
        .map(Customer.fromJson)
        .toList();
  }

  @override
  Future<Customer?> getCustomer(int id) async {
    try {
      final response =
          await _api.get<Map<String, dynamic>>('/api/customers/$id');
      return Customer.fromJson(response);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Customer> createCustomer(CreateCustomerRequest request) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/customers',
      data: request.toJson(),
    );
    return Customer.fromJson(response);
  }

  @override
  Future<Customer> updateCustomer(int id, CreateCustomerRequest request) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/api/customers/$id',
      data: request.toJson(),
    );
    return Customer.fromJson(response);
  }

  @override
  Future<void> deleteCustomer(int id) async {
    await _api.delete<dynamic>('/api/customers/$id');
  }

  @override
  Future<CreditLedgerResponse> getCreditLedger(int customerId) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/customers/$customerId/credit-ledger',
    );
    return CreditLedgerResponse.fromJson(response);
  }

  @override
  Future<List<CustomerSaleHistoryEntry>> getCustomerHistory(int customerId) async {
    final response = await _api.get<List<dynamic>>(
      '/api/customers/$customerId/history',
    );
    return response
        .cast<Map<String, dynamic>>()
        .map(CustomerSaleHistoryEntry.fromJson)
        .toList();
  }
}

final Provider<CustomerService> customerServiceProvider =
    Provider<CustomerService>((final ref) {
  return ApiCustomerService(ref.read(apiServiceProvider));
});
