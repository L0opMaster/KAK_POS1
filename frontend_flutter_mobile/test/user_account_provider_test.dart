import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/models/user_account_model.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/user_account_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/user_account_service.dart';

/// Fake UserAccountService — in-memory list/create/status-toggle, no real
/// HTTP. Implements the abstract `UserAccountService` directly (mirrors
/// `product_provider_test.dart`'s `_FakeProductService extends
/// ProductService` pattern).
class _FakeUserAccountService extends UserAccountService {
  final List<UserAccountResponse> store;
  int _nextId;
  bool throwOnList = false;
  bool throwOnCreate = false;
  bool throwOnSetStatus = false;

  _FakeUserAccountService({List<UserAccountResponse>? initial})
      : store = initial ?? [],
        _nextId =
            ((initial ?? []).map((u) => u.id).fold<int>(0, (a, b) => a > b ? a : b)) +
                1;

  @override
  Future<List<UserAccountResponse>> listUsers() async {
    if (throwOnList) throw Exception('list failed');
    return List.of(store);
  }

  @override
  Future<UserAccountResponse> createUser(
      UserAccountCreateRequest request) async {
    if (throwOnCreate) throw Exception('create failed');
    final user = UserAccountResponse(
      id: _nextId++,
      email: request.email,
      fullName: request.fullName,
      active: true,
      roles: request.roles,
    );
    store.add(user);
    return user;
  }

  @override
  Future<UserAccountResponse> setUserStatus(int id, bool active) async {
    if (throwOnSetStatus) throw Exception('status update failed');
    final index = store.indexWhere((u) => u.id == id);
    if (index < 0) throw Exception('not found');
    final updated = UserAccountResponse(
      id: store[index].id,
      email: store[index].email,
      fullName: store[index].fullName,
      active: active,
      roles: store[index].roles,
    );
    store[index] = updated;
    return updated;
  }
}

void main() {
  group('UserAccountNotifier', () {
    test('load() populates state.users', () async {
      final service = _FakeUserAccountService(initial: [
        UserAccountResponse(
            id: 1,
            email: 'a@example.com',
            fullName: 'Alice',
            active: true,
            roles: const ['Manager']),
        UserAccountResponse(
            id: 2,
            email: 'b@example.com',
            fullName: 'Bob',
            active: false,
            roles: const ['Cashier']),
      ]);
      final notifier = UserAccountNotifier(service);

      await notifier.load();

      expect(notifier.state.loading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.users.length, 2);
      expect(notifier.state.users.map((u) => u.fullName), containsAll(['Alice', 'Bob']));
    });

    test('create() appends a user and refreshes state', () async {
      final service = _FakeUserAccountService();
      final notifier = UserAccountNotifier(service);
      await notifier.load();
      expect(notifier.state.users, isEmpty);

      final created = await notifier.create(UserAccountCreateRequest(
        email: 'new@example.com',
        fullName: 'New User',
        password: 'secret123',
        roles: const ['Admin'],
      ));

      expect(created.fullName, 'New User');
      expect(notifier.state.users.length, 1);
      expect(notifier.state.users.first.email, 'new@example.com');
      expect(notifier.state.users.first.roles, ['Admin']);
    });

    test('setStatus() flips the active flag', () async {
      final service = _FakeUserAccountService(initial: [
        UserAccountResponse(
            id: 1,
            email: 'a@example.com',
            fullName: 'Alice',
            active: true,
            roles: const ['Manager']),
      ]);
      final notifier = UserAccountNotifier(service);
      await notifier.load();

      await notifier.setStatus(1, false);

      expect(notifier.state.users.single.active, isFalse);
    });

    test('load() failure sets state.error', () async {
      final service = _FakeUserAccountService()..throwOnList = true;
      final notifier = UserAccountNotifier(service);

      await notifier.load();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.loading, isFalse);
      expect(notifier.state.users, isEmpty);
    });

    test('create() failure throws and leaves state unchanged', () async {
      final service = _FakeUserAccountService()..throwOnCreate = true;
      final notifier = UserAccountNotifier(service);
      await notifier.load();

      await expectLater(
        notifier.create(UserAccountCreateRequest(
          email: 'fail@example.com',
          fullName: 'Fail User',
          password: 'secret123',
          roles: const ['Admin'],
        )),
        throwsException,
      );

      expect(notifier.state.users, isEmpty);
    });
  });
}
