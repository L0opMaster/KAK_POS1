import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/cash_event_model.dart';
import 'package:frontend_flutter_pos/features/pos/models/shift_model.dart';
import 'package:frontend_flutter_pos/features/pos/screens/shift_screen.dart';
import 'package:frontend_flutter_pos/features/pos/services/cash_event_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/shift_service.dart';

import 'test_l10n_helper.dart';

class _FakeShiftService extends ShiftService {
  _FakeShiftService() : super(ApiService());

  Shift? current;

  @override
  Future<Shift?> getCurrentShift() async => current;

  @override
  Future<Shift> openShift(double openingCash) async {
    final shift = Shift(
      id: 7,
      status: 'OPEN',
      startTime: DateTime.now(),
      openingFloat: openingCash,
    );
    current = shift;
    return shift;
  }

  @override
  Future<Shift> closeShift(int shiftId, double closingCash) async {
    final closed = Shift(
      id: shiftId,
      status: 'CLOSED',
      startTime: current?.startTime ?? DateTime.now(),
      openingFloat: current?.openingFloat ?? 0,
      closedAt: DateTime.now(),
      closingCash: closingCash,
      expectedCash: closingCash,
      variance: 0,
    );
    // Mirrors the real /api/shifts/current, which only ever returns OPEN
    // shifts — a fresh reload after this would see no active shift.
    current = null;
    return closed;
  }

  @override
  Future<Map<String, dynamic>> getClosePrecheck(int shiftId) async => const {};

  @override
  Future<List<Shift>> getShiftHistory() async => const [];
}

class _FakeCashEventService extends CashEventService {
  @override
  Future<List<CashEvent>> fetchByShift(int shiftId) async => [];

  @override
  Future<CashEvent> createForShift({
    required int shiftId,
    required CashEventType type,
    required double amount,
    String? reason,
  }) =>
      throw UnimplementedError();
}

Widget _buildScreen() => ProviderScope(
      overrides: [
        shiftServiceProvider.overrideWithValue(_FakeShiftService()),
        cashEventServiceProvider.overrideWithValue(_FakeCashEventService()),
      ],
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: ShiftScreen(),
      ),
    );

void main() {
  testWidgets(
      'Open Shift then Close Shift updates the screen immediately, '
      'with no navigation or reload', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('No open shift'), findsOneWidget);
    expect(find.text('Close Shift'), findsNothing);

    // Open a shift.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open Shift'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open'));
    await tester.pumpAndSettle();

    expect(find.text('No open shift'), findsNothing);
    expect(find.text('Shift #7'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Close Shift'), findsOneWidget);

    // Close it — this is the bug this test guards: the screen used to keep
    // showing the active-shift card (with live Cash In/Out/Close buttons)
    // until the screen was reopened, because it branched on
    // `currentShift == null` instead of `isShiftOpen`.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Close Shift'));
    await tester.pumpAndSettle();
    // Two "Close Shift" buttons are now on screen: the one that opened the
    // dialog (underneath) and the dialog's own confirm button (on top).
    await tester.tap(find.widgetWithText(ElevatedButton, 'Close Shift').last);
    await tester.pumpAndSettle();

    expect(find.text('No open shift'), findsOneWidget);
    expect(find.text('Shift #7'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Close Shift'), findsNothing);
  });
}
