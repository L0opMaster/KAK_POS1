import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/models/modifier_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/modifier_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/modifier_service.dart';

/// Fake ModifierService — deterministic in-memory data, no network, no
/// dependency on ApiService/Dio at all. Mirrors `product_provider_test.dart`'s
/// fake-service pattern (`_FakeProductService`).
class _FakeModifierService extends ModifierService {
  int _nextGroupId = 1;
  int _nextOptionId = 1;

  final List<ModifierGroupResponse> _groups = [];
  final List<int> deletedOptionIds = [];
  final List<int> deletedGroupIds = [];
  bool throwOnGetGroups = false;

  @override
  Future<List<ModifierGroupResponse>> getGroups() async {
    if (throwOnGetGroups) throw Exception('boom');
    return List.of(_groups);
  }

  @override
  Future<ModifierGroupResponse> createGroup(
    ModifierGroupRequest request,
  ) async {
    final group = ModifierGroupResponse(
      id: _nextGroupId++,
      nameEn: request.nameEn,
      nameKm: request.nameKm,
      isRequired: request.isRequired,
      multiSelect: request.multiSelect,
      active: request.active,
      displayOrder: request.displayOrder,
      options: const [],
    );
    _groups.add(group);
    return group;
  }

  @override
  Future<ModifierGroupResponse> updateGroup({
    required int groupId,
    required ModifierGroupRequest request,
  }) async {
    final index = _groups.indexWhere((g) => g.id == groupId);
    final existingOptions =
        index == -1 ? const <ModifierOptionResponse>[] : _groups[index].options;

    final updated = ModifierGroupResponse(
      id: groupId,
      nameEn: request.nameEn,
      nameKm: request.nameKm,
      isRequired: request.isRequired,
      multiSelect: request.multiSelect,
      active: request.active,
      displayOrder: request.displayOrder,
      options: existingOptions,
    );

    if (index != -1) {
      _groups[index] = updated;
    }

    return updated;
  }

  @override
  Future<void> deleteGroup(int groupId) async {
    deletedGroupIds.add(groupId);
    _groups.removeWhere((g) => g.id == groupId);
  }

  @override
  Future<ModifierOptionResponse> addOption({
    required int groupId,
    required ModifierOptionRequest request,
  }) async {
    final option = ModifierOptionResponse(
      id: _nextOptionId++,
      nameEn: request.nameEn,
      nameKm: request.nameKm,
      priceDelta: request.priceDelta,
      active: request.active,
      displayOrder: request.displayOrder,
    );

    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index != -1) {
      _groups[index] = _groups[index].copyWith(
        options: [..._groups[index].options, option],
      );
    }

    return option;
  }

  @override
  Future<ModifierOptionResponse> updateOption({
    required int optionId,
    required ModifierOptionRequest request,
  }) async {
    final updated = ModifierOptionResponse(
      id: optionId,
      nameEn: request.nameEn,
      nameKm: request.nameKm,
      priceDelta: request.priceDelta,
      active: request.active,
      displayOrder: request.displayOrder,
    );

    for (var i = 0; i < _groups.length; i++) {
      final options = _groups[i].options;
      final optionIndex = options.indexWhere((o) => o.id == optionId);
      if (optionIndex != -1) {
        final newOptions = List<ModifierOptionResponse>.of(options);
        newOptions[optionIndex] = updated;
        _groups[i] = _groups[i].copyWith(options: newOptions);
      }
    }

    return updated;
  }

  @override
  Future<void> deleteOption(int optionId) async {
    deletedOptionIds.add(optionId);

    for (var i = 0; i < _groups.length; i++) {
      _groups[i] = _groups[i].copyWith(
        options: _groups[i].options.where((o) => o.id != optionId).toList(),
      );
    }
  }

  @override
  Future<List<int>> getGroupProducts(int groupId) async => const [];

  @override
  Future<void> updateGroupProducts({
    required int groupId,
    required List<int> productIds,
  }) async {}

  @override
  Future<List<ProductModifiersResponse>> getProductModifiers(
    int productId,
  ) async =>
      const [];
}

void main() {
  group('ModifierNotifier', () {
    test('loadGroups populates state.groups sorted by displayOrder',
        () async {
      final service = _FakeModifierService();
      await service.createGroup(
        const ModifierGroupRequest(
          nameEn: 'Size',
          nameKm: 'Size',
          displayOrder: 1,
        ),
      );
      await service.createGroup(
        const ModifierGroupRequest(
          nameEn: 'Toppings',
          nameKm: 'Toppings',
          displayOrder: 0,
        ),
      );

      final notifier = ModifierNotifier(service);
      await notifier.loadGroups();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.groups.length, 2);
      expect(notifier.state.groups.first.nameEn, 'Toppings');
      expect(notifier.state.groups.last.nameEn, 'Size');
    });

    test('loadGroups sets state.error on failure, keeps groups empty',
        () async {
      final service = _FakeModifierService()..throwOnGetGroups = true;
      final notifier = ModifierNotifier(service);

      await notifier.loadGroups();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.groups, isEmpty);
    });

    test('createModifier creates the group then every option in order',
        () async {
      final service = _FakeModifierService();
      final notifier = ModifierNotifier(service);

      final result = await notifier.createModifier(
        groupRequest: const ModifierGroupRequest(
          nameEn: 'Size',
          nameKm: 'Size',
          isRequired: true,
        ),
        optionRequests: const [
          ModifierOptionRequest(nameEn: 'Small', nameKm: 'Small', priceDelta: 0),
          ModifierOptionRequest(nameEn: 'Large', nameKm: 'Large', priceDelta: 1.5),
        ],
      );

      expect(result.nameEn, 'Size');
      expect(result.isRequired, isTrue);
      expect(result.options.length, 2);
      expect(result.options[0].nameEn, 'Small');
      expect(result.options[1].nameEn, 'Large');
      expect(result.options[1].priceDelta, 1.5);

      expect(notifier.state.isSaving, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.groups.length, 1);
      expect(notifier.state.groups.single.options.length, 2);
    });

    test(
        'updateModifier updates the group, deletes removed options, and '
        'upserts the rest', () async {
      final service = _FakeModifierService();
      final notifier = ModifierNotifier(service);

      final created = await notifier.createModifier(
        groupRequest: const ModifierGroupRequest(nameEn: 'Size', nameKm: 'Size'),
        optionRequests: const [
          ModifierOptionRequest(nameEn: 'Small', nameKm: 'Small', priceDelta: 0),
          ModifierOptionRequest(nameEn: 'Medium', nameKm: 'Medium', priceDelta: 1),
        ],
      );

      final keptOption = created.options[0];
      final removedOption = created.options[1];

      final updated = await notifier.updateModifier(
        groupId: created.id,
        groupRequest: const ModifierGroupRequest(
          nameEn: 'Size Updated',
          nameKm: 'Size Updated',
          multiSelect: true,
        ),
        optionUpserts: [
          // Existing option kept, with an edited price.
          ModifierOptionUpsert(
            id: keptOption.id,
            request: const ModifierOptionRequest(
              nameEn: 'Small',
              nameKm: 'Small',
              priceDelta: 0.5,
            ),
          ),
          // A newly-added row (no id yet).
          const ModifierOptionUpsert(
            id: null,
            request: ModifierOptionRequest(
              nameEn: 'Large',
              nameKm: 'Large',
              priceDelta: 2,
            ),
          ),
        ],
        deletedOptionIds: [removedOption.id],
      );

      expect(updated.nameEn, 'Size Updated');
      expect(updated.multiSelect, isTrue);
      expect(updated.options.length, 2);
      expect(updated.options[0].id, keptOption.id);
      expect(updated.options[0].priceDelta, 0.5);
      expect(updated.options[1].nameEn, 'Large');
      expect(updated.options[1].id, isNot(keptOption.id));

      expect(service.deletedOptionIds, contains(removedOption.id));
      expect(notifier.state.groups.single.options.length, 2);
      expect(notifier.state.isSaving, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('deleteModifier removes the group from state and calls the service',
        () async {
      final service = _FakeModifierService();
      final notifier = ModifierNotifier(service);

      final created = await notifier.createModifier(
        groupRequest: const ModifierGroupRequest(nameEn: 'Size', nameKm: 'Size'),
        optionRequests: const [
          ModifierOptionRequest(nameEn: 'Small', nameKm: 'Small', priceDelta: 0),
        ],
      );

      await notifier.deleteModifier(created.id);

      expect(notifier.state.groups, isEmpty);
      expect(notifier.state.isDeleting, isFalse);
      expect(notifier.state.error, isNull);
      expect(service.deletedGroupIds, contains(created.id));
    });
  });
}
