import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/shift_model.dart';

/// Abstract service for shift operations in POS.
/// Extend this class to provide concrete implementations.
///
/// Consider returning a Result/Either type for error handling.
abstract class ShiftService {
  /// API service dependency
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

/// Concrete implementation of ShiftService using ApiService.
class ApiShiftService extends ShiftService {
  ApiShiftService(super.api);

  @override
  Future<Shift?> getCurrentShift() async {
    final response = await api.get('/api/shifts/current');
    if (response == null) return null;
    return Shift.fromJson(response);
  }

  @override
  Future<Shift> openShift(double openingCash) async {
    final response = await api.post(
      '/api/shifts/open',
      data: {'openingCash': openingCash},
    );
    return Shift.fromJson(response);
  }

  @override
  Future<Shift> closeShift(int shiftId, double closingCash) async {
    final response = await api.post(
      '/api/shifts/$shiftId/close',
      data: {
        'closingCash': closingCash,
        'forceClose': false,
      },
    );
    return Shift.fromJson(response);
  }

  @override
  Future<Map<String, dynamic>> getClosePrecheck(int shiftId) async {
    final response = await api.get<Map<String, dynamic>>(
      '/api/shifts/$shiftId/close-precheck',
    );
    return response;
  }

  @override
  Future<List<Shift>> getShiftHistory() async {
    final response = await api.get<List<dynamic>>('/api/shifts/history');
    return response
        .map((e) => Shift.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Provider for ShiftService using ApiShiftService.
final Provider<ShiftService> shiftServiceProvider =
    Provider<ShiftService>((final ref) {
  final ApiService api = ref.read(apiServiceProvider);
  return ApiShiftService(api);
});

// For testing, create a FakeShiftService or MockShiftService.
// Example:
// class FakeShiftService extends ShiftService {
//   FakeShiftService() : super(FakeApiService());
//   @override
//   Future<Shift?> getCurrentShift() async => null;
//   @override
//   Future<Shift> openShift(double openingCash) async => Shift(...);
// }
