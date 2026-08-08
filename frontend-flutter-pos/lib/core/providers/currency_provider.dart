import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

const _cachedCurrencyCodeKey = 'cached_currency_code';

/// Fetches the store's currency code from the backend settings
/// (e.g., "KHR", "USD") once and caches it for the lifetime of the app.
///
/// The last successfully-fetched code is also mirrored into
/// SharedPreferences under `_cachedCurrencyCodeKey`. If the backend request
/// fails (e.g. a transient network hiccup on cold start) we fall back to
/// that last-known-good value instead of silently hardcoding 'KHR' — since
/// this provider only ever runs once per app session, a single failed
/// request used to lock in the wrong currency for the whole session even
/// after the user had saved a different one.
final currencyCodeProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_cachedCurrencyCodeKey);
  final api = ref.read(apiServiceProvider);
  try {
    final data = await api.get<Map<String, dynamic>>('/api/settings/general');
    final code = (data['currency'] as String?) ?? cached ?? 'KHR';
    await prefs.setString(_cachedCurrencyCodeKey, code);
    return code;
  } catch (_) {
    return cached ?? 'KHR';
  }
});

/// A currency a cashier can accept cash in, with its exchange rate
/// expressed as "units of this currency per 1 USD" (e.g. KHR -> 4100).
class TenderCurrency {
  const TenderCurrency({
    required this.code,
    required this.symbol,
    required this.ratePerUsd,
  });

  final String code;
  final String symbol;
  final double ratePerUsd;
}

/// The active currencies customers can pay cash in, keyed by code. Backed
/// by `/api/settings/currencies` (each row's `exchangeRate` is per-USD), so
/// changing the rate in Settings updates change calculations everywhere.
/// Falls back to the standard USD/KHR pairing at 4,100 riel per dollar if
/// the backend is unreachable.
final tenderCurrenciesProvider =
    FutureProvider<Map<String, TenderCurrency>>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    final data =
        await api.get<Map<String, dynamic>>('/api/settings/currencies');
    final content = (data['content'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((c) => c['active'] == true);
    if (content.isEmpty) throw Exception('no active currencies');
    return {
      for (final c in content)
        '${c['code']}': TenderCurrency(
          code: '${c['code']}',
          symbol: '${c['symbol'] ?? ''}',
          ratePerUsd: (c['exchangeRate'] as num?)?.toDouble() ?? 1,
        ),
    };
  } catch (_) {
    return const {
      'USD': TenderCurrency(code: 'USD', symbol: r'$', ratePerUsd: 1),
      'KHR': TenderCurrency(code: 'KHR', symbol: '៛', ratePerUsd: 4100),
    };
  }
});
