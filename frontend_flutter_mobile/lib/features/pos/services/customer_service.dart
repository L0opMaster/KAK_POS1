import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../models/customer_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// customer_service.dart` — PARTIAL PORT. `listCustomers`/`getCustomer`
/// only — `createCustomer`/`updateCustomer`/`deleteCustomer` are admin
/// CRUD, out of scope (same reasoning as every other service ported in
/// this task).
abstract class CustomerService {
  Future<List<Customer>> listCustomers({String query = ''});
  Future<Customer?> getCustomer(int id);
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
}

final Provider<CustomerService> customerServiceProvider =
    Provider<CustomerService>((final ref) {
  return ApiCustomerService(ref.read(apiServiceProvider));
});
