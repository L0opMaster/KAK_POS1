import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/shift_model.dart';
import 'package:frontend_flutter_pos/features/pos/providers/shift_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/shift_service.dart';

class _FakeShiftService extends ShiftService {
  _FakeShiftService() : super(ApiService());

  Shift? current;
  bool failOpen = false;
  bool failClose = false;
  int openCalls = 0;
  int closeCalls = 0;

  @override
  Future<Shift?> getCurrentShift() async => current;

  @override
  Future<Shift> openShift(double openingCash) async {
    openCalls++;
    if (failOpen) throw Exception('open failed');
    final shift = Shift(
      id: 1,
      status: 'OPEN',
      startTime: DateTime.now(),
      openingFloat: openingCash,
    );
    current = shift;
    return shift;
  }

  @override
  Future<Shift> closeShift(int shiftId, double closingCash) async {
    closeCalls++;
    if (failClose) throw Exception('close failed');
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
    // Mirrors the real backend: /api/shifts/current only ever returns
    // OPEN shifts, so once closed it drops out of "current".
    current = null;
    return closed;
  }

  @override
  Future<Map<String, dynamic>> getClosePrecheck(int shiftId) async => const {};

  @override
  Future<List<Shift>> getShiftHistory() async => const [];
}

void main() {
  group('ShiftNotifier', () {
    test('starts with no active shift when none is cached on the backend',
        () async {
      final notifier = ShiftNotifier(_FakeShiftService());
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.isShiftOpen, isFalse);
      expect(notifier.state.currentShift, isNull);
    });

    test('openShift success updates state to open immediately', () async {
      final service = _FakeShiftService();
      final notifier = ShiftNotifier(service);
      await Future<void>.delayed(Duration.zero);

      await notifier.openShift(openingFloat: 50);

      expect(notifier.state.isShiftOpen, isTrue);
      expect(notifier.state.currentShift?.status, 'OPEN');
      expect(notifier.state.currentShift?.openingFloat, 50);
    });

    test('closeShift success flips isShiftOpen to false immediately',
        () async {
      final service = _FakeShiftService();
      final notifier = ShiftNotifier(service);
      await Future<void>.delayed(Duration.zero);
      await notifier.openShift(openingFloat: 50);

      await notifier.closeShift(closingCash: 50);

      expect(notifier.state.isShiftOpen, isFalse);
      // currentShift is intentionally kept (holds the closing summary) —
      // the screen must key off isShiftOpen, not nullness, to decide which
      // UI to show. See shift_screen_test.dart for that half of the fix.
      expect(notifier.state.currentShift?.status, 'CLOSED');
    });

    test('failed openShift leaves the previous state unchanged', () async {
      final service = _FakeShiftService();
      final notifier = ShiftNotifier(service);
      await Future<void>.delayed(Duration.zero);
      await notifier.openShift(openingFloat: 50);
      final beforeShiftId = notifier.state.currentShift?.id;

      service.failOpen = true;
      await expectLater(
        () => notifier.openShift(openingFloat: 10),
        throwsException,
      );

      expect(notifier.state.isShiftOpen, isTrue);
      expect(notifier.state.currentShift?.id, beforeShiftId);
    });

    test('failed closeShift leaves the previous open state unchanged',
        () async {
      final service = _FakeShiftService();
      final notifier = ShiftNotifier(service);
      await Future<void>.delayed(Duration.zero);
      await notifier.openShift(openingFloat: 50);

      service.failClose = true;
      await expectLater(
        () => notifier.closeShift(closingCash: 50),
        throwsException,
      );

      expect(notifier.state.isShiftOpen, isTrue);
      expect(notifier.state.currentShift?.status, 'OPEN');
    });
  });
}
