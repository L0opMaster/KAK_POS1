import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

/// Ported from `frontend-flutter-pos/lib/core/providers/currency_provider.dart`
/// — `currencyCodeProvider` COPY/ADAPT NEARLY EXACTLY since Day 6.
/// `TenderCurrency`/`tenderCurrenciesProvider` (backs cash-tendering
/// exchange-rate math) added Day 11 now that `payment_screen.dart` needs
/// them — COPY/ADAPT NEARLY EXACTLY too.
const _cachedCurrencyCodeKey = 'cached_currency_code';

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
final tenderCurrenciesProvider = FutureProvider<Map<String, TenderCurrency>>((
  ref,
) async {
  final api = ref.read(apiServiceProvider);
  try {
    final data = await api.get<Map<String, dynamic>>(
      '/api/settings/currencies',
    );
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
