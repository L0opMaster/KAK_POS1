import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/currency_provider.dart';

/// Ported from `frontend-flutter-pos/lib/core/config/currency_utils.dart` —
/// COPY/ADAPT NEARLY EXACTLY, re-synced to source's KHR-formatting fix
/// (zero-decimal, thousands-grouped KHR display, e.g. "៛1,000" not
/// "៛1000.00") — source's Cambodian Riel default currency work.
const Map<String, String> _currencySymbols = {
  'USD': r'$',
  'KHR': '៛',
  'THB': '฿',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'CNY': '¥',
  'KRW': '₩',
  'VND': '₫',
  'LAK': '₭',
  'MMK': 'K',
  'MYR': 'RM',
  'SGD': r'S$',
  'AUD': r'A$',
  'CAD': r'C$',
};

/// Currencies with no minor unit worth displaying (e.g. the smallest riel
/// note is 100 KHR) — shown as whole numbers instead of `x.00`.
const Set<String> _zeroDecimalCurrencies = {'KHR', 'VND', 'JPY', 'KRW'};

/// Returns the currency symbol for the given currency code.
/// Defaults to `៛` (KHR, the store default) if the code is null/unknown.
String currencySymbol(String? currencyCode) {
  if (currencyCode == null || currencyCode.isEmpty) return '៛';
  final upper = currencyCode.toUpperCase();
  return _currencySymbols[upper] ?? '៛';
}

/// Formats an amount with the appropriate currency symbol and grouping.
/// Example: formatAmount(12.50, 'USD') → "$12.50"
/// Example: formatAmount(1000, 'KHR') → "៛1,000"
String formatAmount(double amount, String? currencyCode) {
  final upper = currencyCode?.toUpperCase();
  // Unknown/missing codes resolve to KHR for both symbol and decimals, so
  // the two stay in sync instead of pairing a KHR symbol with USD-style cents.
  final code = (upper != null && _currencySymbols.containsKey(upper)) ? upper : 'KHR';
  final symbol = currencySymbol(code);
  final decimalDigits = _zeroDecimalCurrencies.contains(code) ? 0 : 2;
  final formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: symbol,
    decimalDigits: decimalDigits,
  );
  return formatter.format(amount);
}

/// Convenience helper to watch the live currency code from settings.
String watchCurrency(WidgetRef ref) {
  final currency = ref.watch(currencyCodeProvider);
  return currency.when(
    data: (code) => code,
    loading: () => 'KHR',
    error: (_, __) => 'KHR',
  );
}

/// Convenience helper to read the live currency code once (not reactive).
String readCurrency(WidgetRef ref) {
  final currency = ref.read(currencyCodeProvider);
  return currency.when(
    data: (code) => code,
    loading: () => 'KHR',
    error: (_, __) => 'KHR',
  );
}
