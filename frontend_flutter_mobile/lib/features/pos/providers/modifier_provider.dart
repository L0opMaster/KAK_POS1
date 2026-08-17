import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modifier_models.dart';
import '../services/modifier_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// modifier_provider.dart` — COPY/ADAPT EXACTLY (business logic
/// unchanged; only the exported provider name differs — `modifierProvider`
/// here vs. `modifiersProvider` on desktop).
class ModifierState {
  final List<ModifierGroupResponse> groups;
  final bool isLoading;
  final bool isSaving;
  final bool isDeleting;
  final String? error;

  const ModifierState({
    this.groups = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.isDeleting = false,
    this.error,
  });

  ModifierState copyWith({
    List<ModifierGroupResponse>? groups,
    bool? isLoading,
    bool? isSaving,
    bool? isDeleting,
    String? error,
    bool clearError = false,
  }) {
    return ModifierState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isDeleting: isDeleting ?? this.isDeleting,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final modifierProvider =
    StateNotifierProvider<ModifierNotifier, ModifierState>((ref) {
  final service = ref.watch(modifierServiceProvider);

  return ModifierNotifier(service);
});

class ModifierNotifier extends StateNotifier<ModifierState> {
  final ModifierService _service;

  ModifierNotifier(this._service)
      : super(
          const ModifierState(
            isLoading: true,
          ),
        );

  Future<void> loadGroups() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final groups = await _service.getGroups();

      groups.sort(
        (first, second) =>
            first.displayOrder.compareTo(second.displayOrder),
      );

      state = state.copyWith(
        groups: groups,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _errorMessage(error),
      );
    }
  }

  Future<ModifierGroupResponse> createModifier({
    required ModifierGroupRequest groupRequest,
    required List<ModifierOptionRequest> optionRequests,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
    );

    try {
      // Step 1: create the modifier group.
      final createdGroup = await _service.createGroup(
        groupRequest,
      );

      // Step 2: create every option under the returned group ID.
      final createdOptions = <ModifierOptionResponse>[];

      for (final optionRequest in optionRequests) {
        final createdOption = await _service.addOption(
          groupId: createdGroup.id,
          request: optionRequest,
        );

        createdOptions.add(createdOption);
      }

      final result = createdGroup.copyWith(
        options: createdOptions,
      );

      state = state.copyWith(
        groups: [
          ...state.groups,
          result,
        ],
        isSaving: false,
        clearError: true,
      );

      return result;
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        error: _errorMessage(error),
      );

      rethrow;
    }
  }

  Future<ModifierGroupResponse> updateModifier({
    required int groupId,
    required ModifierGroupRequest groupRequest,
    required List<ModifierOptionUpsert> optionUpserts,
    required List<int> deletedOptionIds,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
    );

    try {
      final updatedGroup = await _service.updateGroup(
        groupId: groupId,
        request: groupRequest,
      );

      for (final optionId in deletedOptionIds) {
        await _service.deleteOption(optionId);
      }

      final updatedOptions = <ModifierOptionResponse>[];

      for (final upsert in optionUpserts) {
        if (upsert.id == null) {
          final createdOption = await _service.addOption(
            groupId: groupId,
            request: upsert.request,
          );

          updatedOptions.add(createdOption);
        } else {
          final updatedOption = await _service.updateOption(
            optionId: upsert.id!,
            request: upsert.request,
          );

          updatedOptions.add(updatedOption);
        }
      }

      final result = updatedGroup.copyWith(
        options: updatedOptions,
      );

      final updatedGroups = state.groups.map((group) {
        if (group.id == groupId) {
          return result;
        }

        return group;
      }).toList();

      state = state.copyWith(
        groups: updatedGroups,
        isSaving: false,
        clearError: true,
      );

      return result;
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        error: _errorMessage(error),
      );

      rethrow;
    }
  }

  Future<void> deleteModifier(int groupId) async {
    state = state.copyWith(
      isDeleting: true,
      clearError: true,
    );

    try {
      await _service.deleteGroup(groupId);

      state = state.copyWith(
        groups: state.groups
            .where(
              (group) => group.id != groupId,
            )
            .toList(),
        isDeleting: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isDeleting: false,
        error: _errorMessage(error),
      );

      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(
      clearError: true,
    );
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;

      if (statusCode == 400) {
        return 'Please check all required fields.';
      }

      if (statusCode == 401) {
        return 'Your login session has expired.';
      }

      if (statusCode == 403) {
        return 'You do not have permission to manage modifiers.';
      }

      if (statusCode == 404) {
        return 'Modifier was not found.';
      }

      if (data is Map) {
        final message = data['message'];

        if (message != null) {
          return message.toString();
        }
      }

      return error.message ?? 'Unable to connect to the server.';
    }

    return error.toString();
  }
}
