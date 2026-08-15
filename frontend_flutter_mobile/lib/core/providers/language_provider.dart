import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ported from `frontend-flutter-pos/lib/core/providers/language_provider.dart`.
enum AppLanguage {
  en,
  km,
}

const _languagePreferenceKey = 'app_language';

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>(
  (final Ref ref) => AppLanguageNotifier(),
);

extension AppLanguageX on AppLanguage {
  bool get isKhmer => this == AppLanguage.km;

  /// The `Locale` this language maps to, for `MaterialApp.locale`.
  Locale toLocale() => Locale(name);
}

// ══ OFFLINE (this whole file) ═════════════════════════════════════════
// Not part of the app's online/offline data switching (there is no backend
// "language" endpoint) — this is simply a device-local UI preference stored
// in SharedPreferences under `_languagePreferenceKey`.
class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  AppLanguageNotifier() : super(AppLanguage.en) {
    _loadPreference();
  }

  /// Reads the saved language on app startup.
  Future<void> _loadPreference() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_languagePreferenceKey);
    if (saved == AppLanguage.km.name) {
      state = AppLanguage.km;
      return;
    }
    state = AppLanguage.en;
  }

  /// Persists the chosen language so it survives restarts.
  Future<void> setLanguage(final AppLanguage language) async {
    state = language;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePreferenceKey, language.name);
  }
}
