import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/cash_event_model.dart';

/// Abstract service for cash event operations in POS.
/// Extend this class to provide concrete implementations.
///
/// Consider returning a Result/Either type for error handling.
abstract class CashEventService {
  /// Fetch all events for the given shift id.
  Future<List<CashEvent>> fetchByShift(int shiftId);

  Future<CashEvent> createForShift({
    required int shiftId,
    required CashEventType type,
    required double amount,
    String? reason,
  });
}

/// Concrete implementation of CashEventService using API calls.
class ApiCashEventService extends CashEventService {
  ApiCashEventService(this._api);

  final ApiService _api;

  @override
  Future<List<CashEvent>> fetchByShift(int shiftId) async {
    final response = await _api.get<List<dynamic>>('/api/shifts/$shiftId/cash-events');
    return response.map((e) => CashEvent.fromJson(e)).toList();
  }

  @override
  Future<CashEvent> createForShift({
    required int shiftId,
    required CashEventType type,
    required double amount,
    String? reason,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/shifts/$shiftId/cash-events',
      data: {
        'type': _mapType(type),
        'amount': amount,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return CashEvent.fromJson(response);
  }

  String _mapType(CashEventType type) {
    switch (type) {
      case CashEventType.cashIn:
        return 'CASH_IN';
      case CashEventType.cashOut:
        return 'CASH_OUT';
      case CashEventType.openDrawer:
        return 'DRAWER_OPEN';
      case CashEventType.openShift:
        return 'SHIFT_OPEN';
      case CashEventType.closeShift:
        return 'SHIFT_CLOSE';
      case CashEventType.saleCash:
        return 'SALE_CASH';
      case CashEventType.refundCash:
        return 'REFUND_CASH';
    }
  }
}

/// Provider for CashEventService using ApiCashEventService.
final Provider<CashEventService> cashEventServiceProvider =
    Provider<CashEventService>((final ref) {
  return ApiCashEventService(ref.read(apiServiceProvider));
});
