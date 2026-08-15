import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/currency_provider.dart';

/// Ported from `frontend-flutter-pos/lib/core/config/currency_utils.dart` —
/// COPY/ADAPT NEARLY EXACTLY.
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

/// Returns the currency symbol for the given currency code.
/// Defaults to `$` if the code is unknown.
String currencySymbol(String? currencyCode) {
  if (currencyCode == null || currencyCode.isEmpty) return r'$';
  final upper = currencyCode.toUpperCase();
  return _currencySymbols[upper] ?? r'$';
}

/// Formats an amount with the appropriate currency symbol.
/// Example: formatAmount(12.50, 'USD') -> "$12.50"
String formatAmount(double amount, String? currencyCode) {
  final symbol = currencySymbol(currencyCode);
  final formatted = amount.toStringAsFixed(2);
  return '$symbol$formatted';
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
