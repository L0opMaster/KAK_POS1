import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/models/unit_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/unit_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/unit_service.dart';

/// Fake UnitService — deterministic in-memory data, no network, no
/// dependency on ApiService/Dio at all. Mirrors `test/product_provider_test.
/// dart`'s `_FakeProductService` pattern: `implements` (not `extends`) the
/// real service so no `ApiService` needs to be constructed just to satisfy
/// a constructor no fake method ever calls.
class _FakeUnitService implements UnitService {
  final List<Unit> units;
  bool throwOnList = false;
  int _nextId;

  _FakeUnitService(this.units)
      : _nextId = units.isEmpty
            ? 1
            : units.map((u) => u.id).reduce((a, b) => a > b ? a : b) + 1;

  @override
  Future<List<Unit>> list({
    String query = '',
    bool? active,
    int page = 0,
    int size = 200,
  }) async {
    if (throwOnList) throw Exception('network down');
    var results = units;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      results = results
          .where((u) =>
              u.nameEn.toLowerCase().contains(q) ||
              u.code.toLowerCase().contains(q))
          .toList();
    }
    if (active != null) {
      results = results.where((u) => u.active == active).toList();
    }
    return List.of(results);
  }

  @override
  Future<Unit> create(Map<String, dynamic> data) async {
    final unit = Unit(
      id: _nextId++,
      code: data['code'] as String,
      name: data['name'] as String? ?? data['nameEn'] as String,
      nameEn: data['nameEn'] as String,
      nameKm: (data['nameKm'] as String?)?.isNotEmpty == true
          ? data['nameKm'] as String
          : data['nameEn'] as String,
      symbol: data['symbol'] as String,
      baseUnitGroup: data['baseUnitGroup'] as String,
      baseUnitId: data['baseUnitId'] as int?,
      baseUnit: data['baseUnit'] as bool? ?? true,
      conversionFactor: (data['conversionFactor'] as num?)?.toDouble() ?? 1,
      active: data['active'] as bool? ?? true,
    );
    units.add(unit);
    return unit;
  }

  @override
  Future<Unit> update(int id, Map<String, dynamic> data) async {
    final index = units.indexWhere((u) => u.id == id);
    final updated = units[index].copyWith(
      code: data['code'] as String?,
      name: data['name'] as String?,
      nameEn: data['nameEn'] as String?,
      nameKm: data['nameKm'] as String?,
      symbol: data['symbol'] as String?,
      baseUnitGroup: data['baseUnitGroup'] as String?,
      baseUnit: data['baseUnit'] as bool?,
      conversionFactor: (data['conversionFactor'] as num?)?.toDouble(),
      active: data['active'] as bool?,
    );
    units[index] = updated;
    return updated;
  }

  @override
  Future<Unit> updateStatus(int id, bool active) async {
    final index = units.indexWhere((u) => u.id == id);
    final updated = units[index].copyWith(active: active);
    units[index] = updated;
    return updated;
  }
}

final _kg = Unit(
  id: 1,
  code: 'kg',
  name: 'Kilogram',
  nameEn: 'Kilogram',
  nameKm: 'គីឡូក្រាម',
  symbol: 'kg',
  baseUnitGroup: 'weight',
  baseUnit: true,
  conversionFactor: 1,
  active: true,
);

final _g = Unit(
  id: 2,
  code: 'g',
  name: 'Gram',
  nameEn: 'Gram',
  nameKm: 'ក្រាម',
  symbol: 'g',
  baseUnitGroup: 'weight',
  baseUnitId: 1,
  baseUnitCode: 'kg',
  baseUnit: false,
  conversionFactor: 0.001,
  active: true,
);

void main() {
  group('UnitNotifier', () {
    test('loadUnits() populates state.data on success', () async {
      final container = ProviderContainer(overrides: [
        unitServiceProvider.overrideWithValue(_FakeUnitService([_kg, _g])),
      ]);
      addTearDown(container.dispose);

      await container.read(unitProvider.notifier).loadUnits();

      final state = container.read(unitProvider);
      expect(state.hasValue, isTrue);
      expect(state.value!.length, 2);
    });

    test('loadUnits() sets AsyncValue.error on failure', () async {
      final service = _FakeUnitService([])..throwOnList = true;
      final container = ProviderContainer(overrides: [
        unitServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);

      await container.read(unitProvider.notifier).loadUnits();

      expect(container.read(unitProvider).hasError, isTrue);
    });

    test('createUnit adds an item to the list', () async {
      final service = _FakeUnitService([_kg]);
      final container = ProviderContainer(overrides: [
        unitServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);
      await container.read(unitProvider.notifier).loadUnits();

      await container.read(unitProvider.notifier).createUnit({
        'code': 'g',
        'nameEn': 'Gram',
        'nameKm': 'ក្រាម',
        'name': 'Gram',
        'symbol': 'g',
        'baseUnitGroup': 'weight',
        'baseUnit': false,
        'baseUnitId': 1,
        'conversionFactor': 0.001,
        'active': true,
      });

      final list = container.read(unitProvider).value!;
      expect(list.length, 2);
      expect(list.any((u) => u.code == 'g' && u.conversionFactor == 0.001),
          isTrue);
    });

    test('updateUnit modifies an existing item', () async {
      final service = _FakeUnitService([_kg]);
      final container = ProviderContainer(overrides: [
        unitServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);
      await container.read(unitProvider.notifier).loadUnits();

      await container.read(unitProvider.notifier).updateUnit(_kg.id, {
        'code': 'kg',
        'nameEn': 'Kilogram (updated)',
        'nameKm': 'គីឡូក្រាម',
        'name': 'Kilogram (updated)',
        'symbol': 'kg',
        'baseUnitGroup': 'weight',
        'baseUnit': true,
        'conversionFactor': 1,
        'active': true,
      });

      final updated =
          container.read(unitProvider).value!.firstWhere((u) => u.id == _kg.id);
      expect(updated.nameEn, 'Kilogram (updated)');
    });

    test('toggleActive flips the active flag', () async {
      final service = _FakeUnitService([_kg]);
      final container = ProviderContainer(overrides: [
        unitServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);
      await container.read(unitProvider.notifier).loadUnits();
      expect(container.read(unitProvider).value!.single.active, isTrue);

      await container.read(unitProvider.notifier).toggleActive(_kg.id, false);

      expect(container.read(unitProvider).value!.single.active, isFalse);
    });
  });
}
