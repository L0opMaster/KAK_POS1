import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pos/services/settings_service.dart';

/// Ported from `frontend-flutter-pos/lib/core/providers/company_provider
/// .dart` — COPY/ADAPT NEARLY EXACTLY, full file.
///
/// The store's company profile (business name, address, phone, receipt
/// footer) from `/api/settings/company-profile` — fetched once per app
/// session and cached, mirroring `currencyCodeProvider`'s pattern
/// (core/providers/currency_provider.dart), so every consumer (POS
/// AppBar, POS drawer, Settings screen) reads the same value instead of
/// each independently re-fetching and drifting apart.
///
/// After a successful save, `mobile_settings_screen.dart`'s
/// `_saveCompany()` calls `ref.invalidate(companyProfileProvider)` — the
/// same invalidate-after-save pattern `_saveGeneral()` already uses for
/// `currencyCodeProvider` — so every watcher picks up the new value
/// immediately, with no full page/browser reload. If the save fails,
/// invalidate is never reached, so this provider (and therefore every
/// screen watching it) keeps showing the last-known-good profile.
final companyProfileProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  return ref.read(settingsServiceProvider).getCompanyProfile();
});

/// Convenience helper for read-only display widgets (POS AppBar, POS
/// drawer header): the live business name, or [fallback] while the first
/// load is in flight, on error with no prior successful value, or if the
/// business name hasn't been set yet. Uses `valueOrNull` (not `.when()`)
/// so that invalidating the provider after a save briefly re-enters a
/// loading state without visibly flashing back to [fallback] — the last
/// successfully-fetched name stays on screen until the new one arrives.
String watchCompanyName(WidgetRef ref, {required String fallback}) {
  final company = ref.watch(companyProfileProvider).valueOrNull;
  final name = (company?['businessName'] as String?)?.trim();
  return (name == null || name.isEmpty) ? fallback : name;
}
