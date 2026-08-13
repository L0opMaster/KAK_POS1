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

/// State for the Shift History screen.
class ShiftHistoryState {
  final bool loading;
  final String? error;
  final List<Shift> shifts;

  ShiftHistoryState({
    required this.loading,
    this.error,
    required this.shifts,
  });

  factory ShiftHistoryState.initial() =>
      ShiftHistoryState(loading: false, shifts: const []);

  ShiftHistoryState copyWith({
    bool? loading,
    String? error,
    List<Shift>? shifts,
    bool clearError = false,
  }) {
    return ShiftHistoryState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      shifts: shifts ?? this.shifts,
    );
  }
}

class ShiftHistoryNotifier extends StateNotifier<ShiftHistoryState> {
  final ShiftService service;
  ShiftHistoryNotifier(this.service) : super(ShiftHistoryState.initial());

  Future<void> loadHistory() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      // Sorts a copy — the list `service.getShiftHistory()` returns isn't
      // guaranteed to be growable/mutable.
      final shifts = [...await service.getShiftHistory()]
        ..sort((a, b) => b.startTime.compareTo(a.startTime));
      state = state.copyWith(loading: false, shifts: shifts, clearError: true);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final StateNotifierProvider<ShiftHistoryNotifier, ShiftHistoryState>
    shiftHistoryProvider =
    StateNotifierProvider<ShiftHistoryNotifier, ShiftHistoryState>(
        (final ref) {
  final ShiftService service = ref.watch(shiftServiceProvider);
  return ShiftHistoryNotifier(service);
});
