import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/shift_model.dart';
import 'package:frontend_flutter_pos/features/pos/providers/shift_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/shift_service.dart';

class _FakeShiftService extends ShiftService {
  _FakeShiftService(this.history) : super(ApiService());

  List<Shift> history;
  bool fail = false;

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
  Future<List<Shift>> getShiftHistory() async {
    if (fail) throw Exception('history failed');
    return history;
  }
}

Shift _shift(int id, DateTime startTime, {String status = 'CLOSED'}) => Shift(
      id: id,
      status: status,
      startTime: startTime,
      openingFloat: 50,
    );

void main() {
  group('ShiftHistoryNotifier', () {
    test('loadHistory populates shifts sorted most-recent-first', () async {
      final now = DateTime(2026, 1, 10);
      final service = _FakeShiftService([
        _shift(1, now.subtract(const Duration(days: 2))),
        _shift(2, now),
        _shift(3, now.subtract(const Duration(days: 1))),
      ]);
      final notifier = ShiftHistoryNotifier(service);

      await notifier.loadHistory();

      expect(notifier.state.loading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.shifts.map((s) => s.id).toList(), [2, 3, 1]);
    });

    test('failure surfaces an error and does not clear prior data', () async {
      final service = _FakeShiftService([_shift(1, DateTime(2026, 1, 1))]);
      final notifier = ShiftHistoryNotifier(service);
      await notifier.loadHistory();
      expect(notifier.state.shifts, hasLength(1));

      service.fail = true;
      await notifier.loadHistory();

      expect(notifier.state.loading, isFalse);
      expect(notifier.state.error, isNotNull);
      // Previous list is preserved rather than wiped on a failed refresh.
      expect(notifier.state.shifts, hasLength(1));
    });
  });
}
