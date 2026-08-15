import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';

class SettingsService {
  SettingsService(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> getGeneral() async {
    return _api.get<Map<String, dynamic>>('/api/settings/general');
  }

  Future<Map<String, dynamic>> updateGeneral(
      Map<String, dynamic> request) async {
    return _api.put<Map<String, dynamic>>(
      '/api/settings/general',
      data: request,
    );
  }

  Future<Map<String, dynamic>> getCompanyProfile() async {
    return _api.get<Map<String, dynamic>>('/api/settings/company-profile');
  }

  Future<Map<String, dynamic>> updateCompanyProfile(
    Map<String, dynamic> request,
  ) async {
    return _api.put<Map<String, dynamic>>(
      '/api/settings/company-profile',
      data: request,
    );
  }

  Future<Map<String, dynamic>> getTax() async {
    return _api.get<Map<String, dynamic>>('/api/settings/tax');
  }

  Future<Map<String, dynamic>> updateTax(Map<String, dynamic> request) async {
    return _api.put<Map<String, dynamic>>('/api/settings/tax', data: request);
  }

  Future<Map<String, dynamic>> getPrinters() async {
    return _api.get<Map<String, dynamic>>('/api/settings/printers');
  }

  Future<Map<String, dynamic>> updatePrinters(
    Map<String, dynamic> request,
  ) async {
    return _api.put<Map<String, dynamic>>(
      '/api/settings/printers',
      data: request,
    );
  }

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/settings/payment-methods',
    );
    final content = (response['content'] as List<dynamic>? ?? const []);
    return content.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updatePaymentMethodStatus(
    Object id,
    bool active,
  ) async {
    return _api.patch<Map<String, dynamic>>(
      '/api/settings/payment-methods/$id/status',
      data: {'active': active},
    );
  }

  Future<List<Map<String, dynamic>>> getCurrencies() async {
    final response =
        await _api.get<Map<String, dynamic>>('/api/settings/currencies');
    final content = (response['content'] as List<dynamic>? ?? const []);
    return content.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateCurrencyStatus(
    Object id,
    bool active,
  ) async {
    return _api.patch<Map<String, dynamic>>(
      '/api/settings/currencies/$id/status',
      data: {'active': active},
    );
  }

  /// Updates a currency's editable fields — including the exchange rate
  /// (units of this currency per 1 USD, e.g. 4000 for KHR). The backend's
  /// `CurrencyRequest` requires code/name/symbol/exchangeRate together on
  /// every PUT, so callers must send the full record, not just the field
  /// that changed.
  Future<Map<String, dynamic>> updateCurrency(
    Object id,
    Map<String, dynamic> request,
  ) async {
    return _api.put<Map<String, dynamic>>(
      '/api/settings/currencies/$id',
      data: request,
    );
  }

  // ── POS Layout settings (Loyverse-inspired) ───────────────────────────────

  Future<Map<String, dynamic>> getPosLayout() async {
    return _api.get<Map<String, dynamic>>('/api/settings/pos-layout');
  }

  Future<Map<String, dynamic>> updatePosLayout(
      Map<String, dynamic> request) async {
    return _api.put<Map<String, dynamic>>(
      '/api/settings/pos-layout',
      data: request,
    );
  }

  // ── POS operational settings (Loyverse-inspired) ──────────────────────────

  Future<Map<String, dynamic>> getPosSettings() async {
    return _api.get<Map<String, dynamic>>('/api/settings/pos');
  }

  Future<Map<String, dynamic>> updatePosSettings(
      Map<String, dynamic> request) async {
    return _api.put<Map<String, dynamic>>(
      '/api/settings/pos',
      data: request,
    );
  }

  // ── Discount presets ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDiscountPresets() async {
    return _api.get<Map<String, dynamic>>('/api/settings/discount-presets');
  }

  Future<Map<String, dynamic>> updateDiscountPresets(
      Map<String, dynamic> request) async {
    return _api.put<Map<String, dynamic>>(
      '/api/settings/discount-presets',
      data: request,
    );
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.read(apiServiceProvider));
});

/// POS operational settings (sale screen layout, grid columns, etc).
/// Invalidate after `updatePosLayout`/`updatePosSettings` to refresh consumers.
final posSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(settingsServiceProvider).getPosSettings();
});
