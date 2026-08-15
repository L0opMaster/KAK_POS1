import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cash_event_model.dart';
import '../services/cash_event_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// cash_event_provider.dart` — COPY/ADAPT NEARLY EXACTLY.
class CashEventState {
  final bool loading;
  final String? error;
  final List<CashEvent> events;

  CashEventState({required this.loading, this.error, required this.events});

  factory CashEventState.initial() =>
      CashEventState(loading: false, events: [], error: null);

  CashEventState copyWith({
    bool? loading,
    String? error,
    List<CashEvent>? events,
    bool clearError = false,
  }) {
    return CashEventState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      events: events ?? this.events,
    );
  }
}

class CashEventNotifier extends StateNotifier<CashEventState> {
  final CashEventService service;

  CashEventNotifier(this.service) : super(CashEventState.initial());

  Future<void> loadByShift(int shiftId) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final events = await service.fetchByShift(shiftId);
      state = state.copyWith(loading: false, events: events, clearError: true);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> createForShift({
    required int shiftId,
    required CashEventType type,
    required double amount,
    String? reason,
  }) async {
    await service.createForShift(
      shiftId: shiftId,
      type: type,
      amount: amount,
      reason: reason,
    );
    await loadByShift(shiftId);
  }
}

final cashEventProvider =
    StateNotifierProvider<CashEventNotifier, CashEventState>((ref) {
      final service = ref.read(cashEventServiceProvider);
      return CashEventNotifier(service);
    });
