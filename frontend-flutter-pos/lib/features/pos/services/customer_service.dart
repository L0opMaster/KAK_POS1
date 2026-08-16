import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../models/customer_models.dart';

/// Abstract service for customer operations in POS.
/// Extend this class to provide concrete implementations.
///
/// Consider returning a Result/Either type for error handling.
abstract class CustomerService {
  Future<List<Customer>> listCustomers({String query = ''});
  Future<Customer?> getCustomer(int id);
  Future<Customer> createCustomer(CreateCustomerRequest request);
  Future<Customer> updateCustomer(int id, CreateCustomerRequest request);
  Future<void> deleteCustomer(int id);
  Future<CreditLedgerResponse> getCreditLedger(int customerId);
}

/// Concrete implementation of CustomerService using API calls.
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
      final response = await _api.get<Map<String, dynamic>>('/api/customers/$id');
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
    await _api.delete<void>('/api/customers/$id');
  }

  @override
  Future<CreditLedgerResponse> getCreditLedger(int customerId) async {
    final response = await _api
        .get<Map<String, dynamic>>('/api/customers/$customerId/credit-ledger');
    return CreditLedgerResponse.fromJson(response);
  }
}

/// Provider for CustomerService using ApiCustomerService.
final Provider<CustomerService> customerServiceProvider =
    Provider<CustomerService>((final ref) {
  return ApiCustomerService(ref.read(apiServiceProvider));
});

// For testing, create a FakeCustomerService or MockCustomerService.
// Example:
// class FakeCustomerService extends CustomerService {
//   // Implement methods for testing.
// }
