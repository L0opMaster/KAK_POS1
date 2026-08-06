import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shift_model.dart';
import '../services/shift_service.dart';

class ShiftNotifier extends StateNotifier<ShiftState> {
  final ShiftService service;
  ShiftNotifier(this.service) : super(ShiftState(isShiftOpen: false)) {
    loadCurrentShift();
  }

  Future<void> loadCurrentShift() async {
    try {
      final current = await service.getCurrentShift();
      state = ShiftState(
        isShiftOpen: current != null && current.status.toUpperCase() == 'OPEN',
        currentShift: current,
      );
    } catch (_) {
      state = ShiftState(isShiftOpen: false, currentShift: null);
    }
  }

  /// Open a new shift with optional opening float.
  Future<void> openShift({double openingFloat = 0.0}) async {
    final newShift = await service.openShift(openingFloat);
    state = ShiftState(isShiftOpen: true, currentShift: newShift);
  }

  /// Close the current shift.
  Future<void> closeShift({double? closingCash}) async {
    if (state.currentShift != null) {
      final closed = await service.closeShift(
        state.currentShift!.id,
        closingCash ?? state.currentShift!.openingFloat,
      );
      state = ShiftState(isShiftOpen: false, currentShift: closed);
    }
  }

  Future<Map<String, dynamic>> getClosePrecheck() async {
    final current = state.currentShift;
    if (current == null) return const {};
    return service.getClosePrecheck(current.id);
  }
}

final StateNotifierProvider<ShiftNotifier, ShiftState> shiftProvider =
    StateNotifierProvider<ShiftNotifier, ShiftState>((final ref) {
  final ShiftService service = ref.watch(shiftServiceProvider);
  return ShiftNotifier(service);
});
