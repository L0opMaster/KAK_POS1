import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { en, km }

const _languagePreferenceKey = 'app_language';

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>(
  (final Ref ref) => AppLanguageNotifier(),
);

extension AppLanguageX on AppLanguage {
  bool get isKhmer => this == AppLanguage.km;
}

/// Device-local UI language preference, stored in SharedPreferences —
/// mirrors `frontend-flutter-pos/lib/core/providers/language_provider.dart`.
/// This app has no ARB/flutter_localizations pipeline (see
/// `pairing_qr_scan_screen.dart`'s doc comment), so switching language here
/// just swaps which strings `AppStrings` returns rather than changing
/// `MaterialApp.locale`.
class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.en) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_languagePreferenceKey);
    state = saved == AppLanguage.km.name ? AppLanguage.km : AppLanguage.en;
  }

  Future<void> setLanguage(final AppLanguage language) async {
    state = language;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePreferenceKey, language.name);
  }
}
