import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/user_account_model.dart';

abstract class UserAccountService {
  Future<List<UserAccountResponse>> listUsers();
  Future<UserAccountResponse> createUser(UserAccountCreateRequest request);
  Future<UserAccountResponse> setUserStatus(int id, bool active);
}

class ApiUserAccountService extends UserAccountService {
  ApiUserAccountService(this._api);

  final ApiService _api;

  @override
  Future<List<UserAccountResponse>> listUsers() async {
    final response = await _api.get<List<dynamic>>('/api/users');
    return response
        .cast<Map<String, dynamic>>()
        .map(UserAccountResponse.fromJson)
        .toList();
  }

  @override
  Future<UserAccountResponse> createUser(
      UserAccountCreateRequest request) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/users',
      data: request.toJson(),
    );
    return UserAccountResponse.fromJson(response);
  }

  @override
  Future<UserAccountResponse> setUserStatus(int id, bool active) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/api/users/$id/status',
      data: {'active': active},
    );
    return UserAccountResponse.fromJson(response);
  }
}

final Provider<UserAccountService> userAccountServiceProvider =
    Provider<UserAccountService>((final ref) {
  return ApiUserAccountService(ref.read(apiServiceProvider));
});
