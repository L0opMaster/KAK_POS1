import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer_models.dart';
import '../services/customer_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// customer_provider.dart`. `load()` is unchanged — `customer_picker_
/// screen.dart` depends on its exact signature/behavior. `create()`/
/// `update()`/`delete()` (admin CRUD) call the service then reload the
/// current query, matching source. `customerByIdProvider` (resolve a
/// single customer by id, e.g. to show the name already attached to the
/// cart) is unchanged.
class CustomerState {
  const CustomerState({
    required this.loading,
    required this.customers,
    this.error,
    this.query = '',
  });

  final bool loading;
  final List<Customer> customers;
  final String? error;
  final String query;

  factory CustomerState.initial() =>
      const CustomerState(loading: false, customers: []);

  CustomerState copyWith({
    bool? loading,
    List<Customer>? customers,
    String? error,
    String? query,
    bool clearError = false,
  }) {
    return CustomerState(
      loading: loading ?? this.loading,
      customers: customers ?? this.customers,
      error: clearError ? null : error ?? this.error,
      query: query ?? this.query,
    );
  }
}

class CustomerNotifier extends StateNotifier<CustomerState> {
  CustomerNotifier(this._service) : super(CustomerState.initial());

  final CustomerService _service;

  Future<void> load({String query = ''}) async {
    state = state.copyWith(loading: true, query: query, clearError: true);
    try {
      final customers = await _service.listCustomers(query: query);
      state = state.copyWith(
        loading: false,
        customers: customers,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<Customer> create(CreateCustomerRequest request) async {
    final created = await _service.createCustomer(request);
    await load(query: state.query);
    return created;
  }

  Future<Customer> update(int id, CreateCustomerRequest request) async {
    final updated = await _service.updateCustomer(id, request);
    await load(query: state.query);
    return updated;
  }

  Future<void> delete(int id) async {
    await _service.deleteCustomer(id);
    await load(query: state.query);
  }
}

final customerProvider =
    StateNotifierProvider<CustomerNotifier, CustomerState>((ref) {
  return CustomerNotifier(ref.watch(customerServiceProvider));
});

/// Resolves a single customer by id (e.g. to show the name of the
/// customer already attached to the cart). Always ONLINE — there is no
/// local customer cache.
final customerByIdProvider =
    FutureProvider.family<Customer?, int>((ref, id) {
  return ref.watch(customerServiceProvider).getCustomer(id);
});
