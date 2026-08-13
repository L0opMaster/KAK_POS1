// Coverage for the new Units feature (POS drawer -> Items -> Units), which
// previously had no screen/route at all — tapping it in the drawer led
// nowhere. Covers: Unit.fromJson, UnitService's REST calls (list/create/
// update/status), and UnitManagementScreen's empty/list/toggle behavior.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/unit_models.dart';
import 'package:frontend_flutter_pos/features/pos/screens/unit_management_screen.dart';
import 'package:frontend_flutter_pos/features/pos/services/unit_service.dart';

import 'test_l10n_helper.dart';

class _FakeApiService extends ApiService {
  final List<String> calls = [];
  List<Map<String, dynamic>> units = [];
  bool failNextWrite = false;

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('GET $path $queryParameters');
    if (path == '/api/units') {
      final q = (queryParameters?['q'] as String? ?? '').toLowerCase();
      final active = queryParameters?['active'] as bool?;
      final filtered = units.where((u) {
        final matchesQuery = q.isEmpty ||
            (u['nameEn'] as String).toLowerCase().contains(q) ||
            (u['code'] as String).toLowerCase().contains(q);
        final matchesActive = active == null || u['active'] == active;
        return matchesQuery && matchesActive;
      }).toList();
      return {'content': filtered, 'totalElements': filtered.length} as T;
    }
    return <String, dynamic>{} as T;
  }

  @override
  Future<T> post<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('POST $path $data');
    if (failNextWrite) {
      throw ApiException('Code already exists', statusCode: 400);
    }
    final map = Map<String, dynamic>.from(data as Map);
    map['id'] = units.length + 1;
    units.add(map);
    return map as T;
  }

  @override
  Future<T> put<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('PUT $path $data');
    if (failNextWrite) {
      throw ApiException('Code already exists', statusCode: 400);
    }
    final id = int.parse(path.split('/').last);
    final map = Map<String, dynamic>.from(data as Map)..['id'] = id;
    final idx = units.indexWhere((u) => u['id'] == id);
    if (idx != -1) units[idx] = map;
    return map as T;
  }

  @override
  Future<T> patch<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('PATCH $path $data');
    final id = int.parse(path.split('/')[3]);
    final idx = units.indexWhere((u) => u['id'] == id);
    if (idx != -1) units[idx]['active'] = (data as Map)['active'];
    return units[idx] as T;
  }
}

Map<String, dynamic> _unitJson({
  int id = 1,
  String code = 'kg',
  String nameEn = 'Kilogram',
  String nameKm = 'គីឡូក្រាម',
  String symbol = 'kg',
  String baseUnitGroup = 'weight',
  bool baseUnit = true,
  int? baseUnitId,
  String? baseUnitCode,
  double conversionFactor = 1,
  bool active = true,
}) =>
    {
      'id': id,
      'code': code,
      'name': nameEn,
      'nameEn': nameEn,
      'nameKm': nameKm,
      'symbol': symbol,
      'baseUnitGroup': baseUnitGroup,
      'baseUnit': baseUnit,
      'baseUnitId': baseUnitId,
      'baseUnitCode': baseUnitCode,
      'conversionFactor': conversionFactor,
      'active': active,
      'usageCount': 0,
    };

void main() {
  group('Unit.fromJson', () {
    test('parses a base unit', () {
      final unit = Unit.fromJson(_unitJson());
      expect(unit.id, 1);
      expect(unit.code, 'kg');
      expect(unit.nameEn, 'Kilogram');
      expect(unit.nameKm, 'គីឡូក្រាម');
      expect(unit.baseUnit, isTrue);
      expect(unit.baseUnitId, isNull);
      expect(unit.conversionFactor, 1);
      expect(unit.active, isTrue);
    });

    test('parses a derived (non-base) unit', () {
      final unit = Unit.fromJson(_unitJson(
        id: 2,
        code: 'g',
        nameEn: 'Gram',
        nameKm: 'ក្រាម',
        symbol: 'g',
        baseUnit: false,
        baseUnitId: 1,
        baseUnitCode: 'kg',
        conversionFactor: 0.001,
      ));
      expect(unit.baseUnit, isFalse);
      expect(unit.baseUnitId, 1);
      expect(unit.baseUnitCode, 'kg');
      expect(unit.conversionFactor, 0.001);
    });
  });

  group('UnitService', () {
    late _FakeApiService fakeApi;
    late UnitService service;

    setUp(() {
      fakeApi = _FakeApiService();
      service = UnitService(fakeApi);
    });

    test('list() unwraps the paged content array into Unit objects',
        () async {
      fakeApi.units = [_unitJson(), _unitJson(id: 2, code: 'g', nameEn: 'Gram')];

      final result = await service.list();

      expect(result, hasLength(2));
      expect(result.map((u) => u.code), containsAll(['kg', 'g']));
    });

    test('list() forwards query/active/page/size as query parameters',
        () async {
      await service.list(query: 'kilo', active: true, page: 1, size: 50);

      expect(
        fakeApi.calls.single,
        'GET /api/units {q: kilo, active: true, page: 1, size: 50}',
      );
    });

    test('create() posts to /api/units and returns the created Unit',
        () async {
      final created = await service.create({
        'code': 'box',
        'nameEn': 'Box',
        'nameKm': 'ប្រអប់',
        'symbol': 'box',
        'baseUnitGroup': 'count',
        'baseUnit': true,
        'conversionFactor': 1,
        'active': true,
      });

      expect(created.code, 'box');
      expect(fakeApi.calls.single, startsWith('POST /api/units'));
    });

    test('update() puts to /api/units/{id}', () async {
      fakeApi.units = [_unitJson()];

      await service.update(1, {'code': 'kg', 'nameEn': 'Kilogram (updated)'});

      expect(fakeApi.calls.single, startsWith('PUT /api/units/1'));
    });

    test('updateStatus() patches /api/units/{id}/status with the new value',
        () async {
      fakeApi.units = [_unitJson(active: true)];

      await service.updateStatus(1, false);

      expect(fakeApi.calls.single, 'PATCH /api/units/1/status {active: false}');
    });

    test('a failed write surfaces the backend ApiException message',
        () async {
      fakeApi.failNextWrite = true;

      expect(
        () => service.create({'code': 'kg'}),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Code already exists')),
      );
    });
  });

  group('UnitManagementScreen', () {
    Widget buildScreen(_FakeApiService fakeApi) {
      return ProviderScope(
        overrides: [
          unitServiceProvider.overrideWithValue(UnitService(fakeApi)),
        ],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: UnitManagementScreen(),
        ),
      );
    }

    testWidgets('shows the empty state when there are no units yet',
        (tester) async {
      await tester.pumpWidget(buildScreen(_FakeApiService()));
      await tester.pumpAndSettle();

      expect(find.text('No units yet'), findsOneWidget);
    });

    testWidgets('lists loaded units with code and symbol', (tester) async {
      final fakeApi = _FakeApiService()
        ..units = [_unitJson(), _unitJson(id: 2, code: 'g', nameEn: 'Gram', symbol: 'g')];
      await tester.pumpWidget(buildScreen(fakeApi));
      await tester.pumpAndSettle();

      expect(find.textContaining('Kilogram (kg)'), findsOneWidget);
      expect(find.textContaining('Gram (g)'), findsOneWidget);
    });

    testWidgets('toggling the active switch calls the status PATCH endpoint',
        (tester) async {
      final fakeApi = _FakeApiService()..units = [_unitJson(active: true)];
      await tester.pumpWidget(buildScreen(fakeApi));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(
        fakeApi.calls,
        contains('PATCH /api/units/1/status {active: false}'),
      );
    });

    testWidgets(
        'tapping + opens the new-unit form, and creating one with a '
        'required field missing shows a validation error, not a crash',
        (tester) async {
      final fakeApi = _FakeApiService();
      await tester.pumpWidget(buildScreen(fakeApi));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('New Unit'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsWidgets);
      // The initial list load (GET) happened, but validation must have
      // blocked the save before any write call reached the API.
      expect(fakeApi.calls.any((c) => c.startsWith('POST')), isFalse);
    });
  });
}
