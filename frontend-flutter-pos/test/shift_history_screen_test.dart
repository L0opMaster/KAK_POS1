import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/shift_model.dart';
import 'package:frontend_flutter_pos/features/pos/screens/shift_history_screen.dart';
import 'package:frontend_flutter_pos/features/pos/services/shift_service.dart';

import 'test_l10n_helper.dart';

class _FakeShiftService extends ShiftService {
  _FakeShiftService(this.history) : super(ApiService());

  final List<Shift> history;

  @override
  Future<Shift?> getCurrentShift() async => null;

  @override
  Future<Shift> openShift(double openingCash) async => throw UnimplementedError();

  @override
  Future<Shift> closeShift(int shiftId, double closingCash) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getClosePrecheck(int shiftId) async => const {};

  @override
  Future<List<Shift>> getShiftHistory() async => history;
}

Widget _buildScreen(ShiftService service) => ProviderScope(
      overrides: [shiftServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: ShiftHistoryScreen(),
      ),
    );

void main() {
  testWidgets('shows an empty state when there are no shifts', (tester) async {
    await tester.pumpWidget(_buildScreen(_FakeShiftService(const [])));
    await tester.pumpAndSettle();

    expect(find.text('No shifts yet'), findsOneWidget);
  });

  testWidgets('lists shifts with status badges once loaded', (tester) async {
    final closed = Shift(
      id: 3,
      status: 'CLOSED',
      startTime: DateTime(2026, 1, 5, 9),
      openingFloat: 100,
      closedAt: DateTime(2026, 1, 5, 17),
      closingCash: 500,
      expectedCash: 480,
      variance: 20,
      salesTotal: 380,
    );
    final open = Shift(
      id: 4,
      status: 'OPEN',
      startTime: DateTime(2026, 1, 6, 9),
      openingFloat: 100,
    );
    await tester.pumpWidget(_buildScreen(_FakeShiftService([closed, open])));
    await tester.pumpAndSettle();

    expect(find.text('Shift #3'), findsOneWidget);
    expect(find.text('Shift #4'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('No shifts yet'), findsNothing);
  });
}
