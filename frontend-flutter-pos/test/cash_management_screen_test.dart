import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/features/pos/models/shift_model.dart';
import 'package:frontend_flutter_pos/features/pos/models/cash_event_model.dart';
import 'package:frontend_flutter_pos/features/pos/providers/shift_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cash_event_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/shift_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/cash_event_service.dart';
import 'package:frontend_flutter_pos/pos/screens/cash_management_screen.dart';

void main() {
  testWidgets('cash management screen open/close shift flows', (tester) async {
    // start with shift closed
    final shiftNotifier = ShiftNotifier(FakeShiftService());
    final cashNotifier = CashEventNotifier(FakeCashEventService());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        shiftProvider.overrideWith((ref) => shiftNotifier),
        cashEventProvider.overrideWith((ref) => cashNotifier),
      ],
      child: const MaterialApp(home: CashManagementScreen()),
    ));

    // button should say Open Shift initially
    expect(find.text('Open Shift'), findsOneWidget);

    // tap open shift
    await tester.tap(find.text('Open Shift'));
    await tester.pumpAndSettle();
    // after opening, label should change
    expect(find.text('Close Shift'), findsOneWidget);

    // verify that cash events were loaded for the new shift id
    expect(cashNotifier.state.loading, isFalse);
    // there should be at least the fake sample
    expect(cashNotifier.state.events, isNotEmpty);

    // tapping again closes shift
    await tester.tap(find.text('Close Shift'));
    await tester.pumpAndSettle();
    expect(find.text('Open Shift'), findsOneWidget);
  });
}

// Fake services for testing
class FakeShiftService implements ShiftService {
  @override
  late final api;

  FakeShiftService();

  @override
  Future<Shift?> getCurrentShift() async => null;

  @override
  Future<Shift> openShift(double openingCash) async => Shift.sample();

  @override
  Future<Shift> closeShift(int shiftId, double closingCash) async =>
      Shift.sample();

  @override
  Future<Map<String, dynamic>> getClosePrecheck(int shiftId) async => {};
}

class FakeCashEventService implements CashEventService {
  @override
  late final api;

  FakeCashEventService();

  @override
  Future<List<CashEvent>> fetchByShift(int shiftId) async {
    return [CashEvent.sample()];
  }

  @override
  Future<CashEvent> createForShift({
    required int shiftId,
    required CashEventType type,
    required double amount,
    String? reason,
  }) async =>
      CashEvent.sample();
}
