import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/receipt_models.dart';

/// Service for receipt operations. Returns a typed [ReceiptResponse].
class ReceiptService {
  final ApiService _api;

  ReceiptService(this._api);

  /// Fetch a typed receipt for a completed sale.
  Future<ReceiptResponse> fetchReceiptSummary(int saleId) async {
    final raw =
        await _api.get<Map<String, dynamic>>('/api/pos/sales/$saleId/receipt');
    return ReceiptResponse.fromJson(raw);
  }
}

/// Provider for ReceiptService.
final receiptServiceProvider = Provider<ReceiptService>((final ref) {
  final ApiService api = ref.read(apiServiceProvider);
  return ReceiptService(api);
});
