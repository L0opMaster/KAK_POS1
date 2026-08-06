import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/modifier_models.dart';

abstract class ModifierService {
  Future<List<ModifierGroupResponse>> getGroups();

  Future<ModifierGroupResponse> createGroup(
    ModifierGroupRequest request,
  );

  Future<ModifierGroupResponse> updateGroup({
    required int groupId,
    required ModifierGroupRequest request,
  });

  Future<void> deleteGroup(int groupId);

  Future<ModifierOptionResponse> addOption({
    required int groupId,
    required ModifierOptionRequest request,
  });

  Future<ModifierOptionResponse> updateOption({
    required int optionId,
    required ModifierOptionRequest request,
  });

  Future<void> deleteOption(int optionId);

  Future<List<int>> getGroupProducts(int groupId);

  Future<void> updateGroupProducts({
    required int groupId,
    required List<int> productIds,
  });

  Future<List<ProductModifiersResponse>> getProductModifiers(
    int productId,
  );
}

class ApiModifierService extends ModifierService {
  final ApiService _api;

  ApiModifierService(this._api);

  @override
  Future<List<ModifierGroupResponse>> getGroups() async {
    final response = await _api.get<List<dynamic>>(
      '/api/modifiers/groups',
    );

    return response
        .whereType<Map>()
        .map(
          (item) => ModifierGroupResponse.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  @override
  Future<ModifierGroupResponse> createGroup(
    ModifierGroupRequest request,
  ) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/modifiers/groups',
      data: request.toJson(),
    );

    return ModifierGroupResponse.fromJson(response);
  }

  @override
  Future<ModifierGroupResponse> updateGroup({
    required int groupId,
    required ModifierGroupRequest request,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/api/modifiers/groups/$groupId',
      data: request.toJson(),
    );

    return ModifierGroupResponse.fromJson(response);
  }

  @override
  Future<void> deleteGroup(int groupId) async {
    await _api.delete<void>(
      '/api/modifiers/groups/$groupId',
    );
  }

  @override
  Future<ModifierOptionResponse> addOption({
    required int groupId,
    required ModifierOptionRequest request,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/modifiers/groups/$groupId/options',
      data: request.toJson(),
    );

    return ModifierOptionResponse.fromJson(response);
  }

  @override
  Future<ModifierOptionResponse> updateOption({
    required int optionId,
    required ModifierOptionRequest request,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/api/modifiers/options/$optionId',
      data: request.toJson(),
    );

    return ModifierOptionResponse.fromJson(response);
  }

  @override
  Future<void> deleteOption(int optionId) async {
    await _api.delete<void>(
      '/api/modifiers/options/$optionId',
    );
  }

  @override
  Future<List<int>> getGroupProducts(int groupId) async {
    final response = await _api.get<List<dynamic>>(
      '/api/modifiers/groups/$groupId/products',
    );

    return response
        .map(
          (item) => item is num
              ? item.toInt()
              : int.parse(item.toString()),
        )
        .toList();
  }

  @override
  Future<void> updateGroupProducts({
    required int groupId,
    required List<int> productIds,
  }) async {
    await _api.put<void>(
      '/api/modifiers/groups/$groupId/products',
      data: productIds,
    );
  }

  @override
  Future<List<ProductModifiersResponse>> getProductModifiers(
    int productId,
  ) async {
    final response = await _api.get<List<dynamic>>(
      '/api/modifiers/products/$productId',
    );

    return response
        .whereType<Map>()
        .map(
          (item) => ProductModifiersResponse.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}

final modifierServiceProvider = Provider<ModifierService>((ref) {
  final apiService = ref.watch(apiServiceProvider);

  return ApiModifierService(apiService);
});