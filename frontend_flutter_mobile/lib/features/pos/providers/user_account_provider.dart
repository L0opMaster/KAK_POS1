import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_account_model.dart';
import '../services/user_account_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// user_account_provider.dart` — COPY/ADAPT NEARLY EXACTLY. `load()` takes
/// no arguments (search/filter is purely client-side in the screen); both
/// `create()` and `setStatus()` re-fetch the whole list afterward instead
/// of patching state locally, matching source.
class UserAccountState {
  final bool loading;
  final List<UserAccountResponse> users;
  final String? error;

  const UserAccountState({
    required this.loading,
    required this.users,
    this.error,
  });

  factory UserAccountState.initial() =>
      const UserAccountState(loading: false, users: []);

  UserAccountState copyWith({
    bool? loading,
    List<UserAccountResponse>? users,
    String? error,
    bool clearError = false,
  }) {
    return UserAccountState(
      loading: loading ?? this.loading,
      users: users ?? this.users,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class UserAccountNotifier extends StateNotifier<UserAccountState> {
  final UserAccountService _service;

  UserAccountNotifier(this._service) : super(UserAccountState.initial());

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final users = await _service.listUsers();
      state = state.copyWith(loading: false, clearError: true, users: users);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<UserAccountResponse> create(UserAccountCreateRequest request) async {
    final created = await _service.createUser(request);
    await load();
    return created;
  }

  Future<void> setStatus(int id, bool active) async {
    await _service.setUserStatus(id, active);
    await load();
  }
}

final userAccountProvider =
    StateNotifierProvider<UserAccountNotifier, UserAccountState>((ref) {
  return UserAccountNotifier(ref.watch(userAccountServiceProvider));
});
