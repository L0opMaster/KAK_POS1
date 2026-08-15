import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/features/pos/models/shift_model.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/shift_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/shift_service.dart';

class _FakeShiftService extends ShiftService {
  _FakeShiftService() : super(ApiService());

  Shift? current;
  bool throwOnGetCurrent = false;
  Shift Function(int shiftId, double closingCash)? closeImpl;
  List<Shift> history = const [];
  Map<String, dynamic> precheck = const {};

  @override
  Future<Shift?> getCurrentShift() async {
    if (throwOnGetCurrent) throw Exception('network down');
    return current;
  }

  @override
  Future<Shift> openShift(double openingCash) async {
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
    final closed =
        closeImpl?.call(shiftId, closingCash) ??
        Shift(
          id: shiftId,
          status: 'CLOSED',
          startTime: DateTime.now(),
          openingFloat: closingCash,
          closingCash: closingCash,
        );
    current = closed;
    return closed;
  }

  @override
  Future<Map<String, dynamic>> getClosePrecheck(int shiftId) async => precheck;

  @override
  Future<List<Shift>> getShiftHistory() async => history;
}

void main() {
  group('ShiftNotifier', () {
    test('loadCurrentShift with an OPEN shift sets isShiftOpen true', () async {
      final service = _FakeShiftService()
        ..current = Shift(
          id: 3,
          status: 'OPEN',
          startTime: DateTime.now(),
          openingFloat: 50,
        );
      final container = ProviderContainer(
        overrides: [shiftServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      // The constructor's own loadCurrentShift() call races the explicit
      // one below — read once to let it settle first.
      await container.read(shiftProvider.notifier).loadCurrentShift();

      final state = container.read(shiftProvider);
      expect(state.isShiftOpen, isTrue);
      expect(state.currentShift?.id, 3);
    });

    test('loadCurrentShift with no shift sets isShiftOpen false', () async {
      final service = _FakeShiftService();
      final container = ProviderContainer(
        overrides: [shiftServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(shiftProvider.notifier).loadCurrentShift();

      expect(container.read(shiftProvider).isShiftOpen, isFalse);
    });

    test('loadCurrentShift on a network error falls back to isShiftOpen '
        'false rather than throwing', () async {
      final service = _FakeShiftService()..throwOnGetCurrent = true;
      final container = ProviderContainer(
        overrides: [shiftServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(shiftProvider.notifier).loadCurrentShift();

      expect(container.read(shiftProvider).isShiftOpen, isFalse);
      expect(container.read(shiftProvider).currentShift, isNull);
    });

    test('openShift stores the new shift and marks isShiftOpen true', () async {
      final service = _FakeShiftService();
      final container = ProviderContainer(
        overrides: [shiftServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(shiftProvider.notifier).openShift(openingFloat: 75);

      final state = container.read(shiftProvider);
      expect(state.isShiftOpen, isTrue);
      expect(state.currentShift?.openingFloat, 75);
    });

    test('closeShift with a small variance sets isShiftOpen false and status '
        'CLOSED', () async {
      final service = _FakeShiftService();
      final container = ProviderContainer(
        overrides: [shiftServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(shiftProvider.notifier).openShift(openingFloat: 100);
      await container.read(shiftProvider.notifier).closeShift(closingCash: 105);

      final state = container.read(shiftProvider);
      expect(state.isShiftOpen, isFalse);
      expect(state.currentShift?.status, 'CLOSED');
    });

    test('closeShift sets isShiftOpen false UNCONDITIONALLY even when the '
        'backend returns PENDING_APPROVAL (large variance, non-owner '
        'account) — callers must read currentShift.status, not just '
        'isShiftOpen, to tell the two apart', () async {
      final service = _FakeShiftService()
        ..closeImpl = (id, closingCash) => Shift(
          id: id,
          status: 'PENDING_APPROVAL',
          startTime: DateTime.now(),
          openingFloat: 100,
          closingCash: closingCash,
          variance: closingCash - 100,
        );
      final container = ProviderContainer(
        overrides: [shiftServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(shiftProvider.notifier).openShift(openingFloat: 100);
      await container.read(shiftProvider.notifier).closeShift(closingCash: 250);

      final state = container.read(shiftProvider);
      // isShiftOpen goes false regardless of the real backend decision...
      expect(state.isShiftOpen, isFalse);
      // ...so the UI must branch on this instead to show the right thing.
      expect(state.currentShift?.status, 'PENDING_APPROVAL');
    });

    test('getClosePrecheck returns the backend precheck for the current '
        'shift', () async {
      final service = _FakeShiftService()
        ..precheck = {
          'blockers': ['2 open tickets'],
        };
      final container = ProviderContainer(
        overrides: [shiftServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(shiftProvider.notifier).openShift(openingFloat: 0);
      final precheck = await container
          .read(shiftProvider.notifier)
          .getClosePrecheck();

      expect(precheck['blockers'], ['2 open tickets']);
    });

    test('getClosePrecheck with no current shift returns empty, does not '
        'call the service', () async {
      final container = ProviderContainer(
        overrides: [
          shiftServiceProvider.overrideWithValue(_FakeShiftService()),
        ],
      );
      addTearDown(container.dispose);

      final precheck = await container
          .read(shiftProvider.notifier)
          .getClosePrecheck();

      expect(precheck, isEmpty);
    });
  });

  group('ShiftHistoryNotifier', () {
    test('loadHistory sorts newest-first', () async {
      final older = Shift(
        id: 1,
        status: 'CLOSED',
        startTime: DateTime(2026, 1, 1),
        openingFloat: 0,
      );
      final newer = Shift(
        id: 2,
        status: 'CLOSED',
        startTime: DateTime(2026, 6, 1),
        openingFloat: 0,
      );
      final service = _FakeShiftService()..history = [older, newer];
      final container = ProviderContainer(
        overrides: [shiftServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(shiftHistoryProvider.notifier).loadHistory();

      final shifts = container.read(shiftHistoryProvider).shifts;
      expect(shifts.map((s) => s.id).toList(), [2, 1]);
    });

    test('loadHistory records an error on failure', () async {
      final container = ProviderContainer(
        overrides: [
          shiftServiceProvider.overrideWithValue(_ThrowingShiftService()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(shiftHistoryProvider.notifier).loadHistory();

      expect(container.read(shiftHistoryProvider).error, isNotNull);
      expect(container.read(shiftHistoryProvider).shifts, isEmpty);
    });
  });
}

class _ThrowingShiftService extends ShiftService {
  _ThrowingShiftService() : super(ApiService());

  @override
  Future<Shift?> getCurrentShift() async => null;

  @override
  Future<Shift> openShift(double openingCash) async =>
      throw UnimplementedError();

  @override
  Future<Shift> closeShift(int shiftId, double closingCash) async =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getClosePrecheck(int shiftId) async => {};

  @override
  Future<List<Shift>> getShiftHistory() async =>
      throw Exception('history unreachable');
}
