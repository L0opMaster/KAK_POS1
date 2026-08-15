import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/models/customer_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/customer_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/customer_service.dart';

class _FakeCustomerService extends CustomerService {
  List<Customer> customers;
  bool throwOnList = false;

  _FakeCustomerService(this.customers);

  @override
  Future<List<Customer>> listCustomers({String query = ''}) async {
    if (throwOnList) throw Exception('network down');
    if (query.isEmpty) return customers;
    final q = query.toLowerCase();
    return customers
        .where((c) => c.resolvedDisplayName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<Customer?> getCustomer(int id) async {
    try {
      return customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}

const _alice = Customer(
  id: 1,
  creditLimit: 0,
  creditBalance: 0,
  type: 'RETAIL',
  status: 'ACTIVE',
  nameEn: 'Alice',
  displayName: 'Alice',
);
const _bob = Customer(
  id: 2,
  creditLimit: 0,
  creditBalance: 0,
  type: 'RETAIL',
  status: 'ACTIVE',
  nameEn: 'Bob',
  displayName: 'Bob',
);

void main() {
  group('CustomerNotifier', () {
    test('load() populates state.customers', () async {
      final container = ProviderContainer(overrides: [
        customerServiceProvider
            .overrideWithValue(_FakeCustomerService([_alice, _bob])),
      ]);
      addTearDown(container.dispose);

      await container.read(customerProvider.notifier).load();

      expect(container.read(customerProvider).customers.length, 2);
      expect(container.read(customerProvider).loading, isFalse);
    });

    test('load(query) filters the result', () async {
      final container = ProviderContainer(overrides: [
        customerServiceProvider
            .overrideWithValue(_FakeCustomerService([_alice, _bob])),
      ]);
      addTearDown(container.dispose);

      await container.read(customerProvider.notifier).load(query: 'ali');

      expect(container.read(customerProvider).customers.single.id, 1);
      expect(container.read(customerProvider).query, 'ali');
    });

    test('load() failure sets state.error and clears loading', () async {
      final service = _FakeCustomerService([])..throwOnList = true;
      final container = ProviderContainer(overrides: [
        customerServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);

      await container.read(customerProvider.notifier).load();

      expect(container.read(customerProvider).error, isNotNull);
      expect(container.read(customerProvider).loading, isFalse);
    });
  });

  group('customerByIdProvider', () {
    test('resolves an existing customer by id', () async {
      final container = ProviderContainer(overrides: [
        customerServiceProvider
            .overrideWithValue(_FakeCustomerService([_alice, _bob])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(customerByIdProvider(2).future);
      expect(result?.resolvedDisplayName, 'Bob');
    });

    test('resolves to null for an unknown id', () async {
      final container = ProviderContainer(overrides: [
        customerServiceProvider.overrideWithValue(_FakeCustomerService([])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(customerByIdProvider(999).future);
      expect(result, isNull);
    });
  });

  group('Customer.resolvedDisplayName', () {
    test('prefers displayName, then nameKm, then nameEn', () {
      const withDisplayName = Customer(
        id: 1,
        creditLimit: 0,
        creditBalance: 0,
        type: 'RETAIL',
        status: 'ACTIVE',
        nameEn: 'English Name',
        nameKm: 'Khmer Name',
        displayName: 'Preferred Name',
      );
      expect(withDisplayName.resolvedDisplayName, 'Preferred Name');

      const withKmOnly = Customer(
        id: 2,
        creditLimit: 0,
        creditBalance: 0,
        type: 'RETAIL',
        status: 'ACTIVE',
        nameEn: 'English Name',
        nameKm: 'Khmer Name',
        displayName: '',
      );
      expect(withKmOnly.resolvedDisplayName, 'Khmer Name');

      const withNeither = Customer(
        id: 3,
        creditLimit: 0,
        creditBalance: 0,
        type: 'RETAIL',
        status: 'ACTIVE',
        nameEn: 'English Name',
        displayName: '',
      );
      expect(withNeither.resolvedDisplayName, 'English Name');
    });
  });
}
