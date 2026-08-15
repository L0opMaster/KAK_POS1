import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/shift_model.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// shift_service.dart` — COPY/ADAPT NEARLY EXACTLY. Same 5 shared-backend
/// endpoints (current/open/close/close-precheck/history) as source.
abstract class ShiftService {
  final ApiService api;
  ShiftService(this.api);

  /// Gets the current shift, or null if none is open.
  Future<Shift?> getCurrentShift();

  /// Opens a new shift with the provided opening cash.
  Future<Shift> openShift(double openingCash);

  Future<Shift> closeShift(int shiftId, double closingCash);

  Future<Map<String, dynamic>> getClosePrecheck(int shiftId);

  /// All shifts (any status, any cashier/store) — requires
  /// PERM_SHIFT_MANAGE on the backend, unlike the other methods above.
  Future<List<Shift>> getShiftHistory();
}

class ApiShiftService extends ShiftService {
  ApiShiftService(super.api);

  @override
  Future<Shift?> getCurrentShift() async {
    final response = await api.get('/api/shifts/current');
    if (response == null) return null;
    return Shift.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<Shift> openShift(double openingCash) async {
    final response = await api.post(
      '/api/shifts/open',
      data: {'openingCash': openingCash},
    );
    return Shift.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<Shift> closeShift(int shiftId, double closingCash) async {
    final response = await api.post(
      '/api/shifts/$shiftId/close',
      data: {'closingCash': closingCash, 'forceClose': false},
    );
    return Shift.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> getClosePrecheck(int shiftId) async {
    return api.get<Map<String, dynamic>>('/api/shifts/$shiftId/close-precheck');
  }

  @override
  Future<List<Shift>> getShiftHistory() async {
    final response = await api.get<List<dynamic>>('/api/shifts/history');
    return response
        .map((e) => Shift.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final Provider<ShiftService> shiftServiceProvider = Provider<ShiftService>((
  ref,
) {
  return ApiShiftService(ref.read(apiServiceProvider));
});
