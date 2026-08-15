import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mainColorPreferenceKey = 'app_main_color';

/// The selectable "main app color" palette (Settings > Main Color) — the
/// first entry is the app's original brand green and is the default for
/// anyone who hasn't picked a color yet.
///
/// Ported from `frontend-flutter-pos/lib/core/providers/main_color_provider.dart`.
const List<Color> kMainColorOptions = [
  Color(0xFF4CAF50), // green (default)
  Color(0xFF2196F3), // blue
  Color(0xFF9C27B0), // purple
  Color(0xFFFF9800), // orange
  Color(0xFFE53935), // red
  Color(0xFF009688), // teal
];

final mainColorProvider = StateNotifierProvider<MainColorNotifier, Color>(
  (final Ref ref) => MainColorNotifier(),
);

// ══ OFFLINE (this whole file) ═════════════════════════════════════════
// Same pattern as language_provider.dart's AppLanguageNotifier: a
// device-local UI preference in SharedPreferences, not backend-persisted.
class MainColorNotifier extends StateNotifier<Color> {
  MainColorNotifier() : super(kMainColorOptions.first) {
    _loadPreference();
  }

  /// Reads the saved main color on app startup. Falls back to the default
  /// (index 0) if nothing was saved yet, or if the saved value somehow
  /// doesn't match a current palette entry.
  Future<void> _loadPreference() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? saved = prefs.getInt(_mainColorPreferenceKey);
    if (saved != null) {
      for (final color in kMainColorOptions) {
        if (color.toARGB32() == saved) {
          state = color;
          return;
        }
      }
    }
    state = kMainColorOptions.first;
  }

  /// Persists the chosen main color so it survives restarts. The actual
  /// live theme update happens in main.dart, which watches this provider
  /// and calls `PosTheme.applyMainColor` on every build — this notifier
  /// only owns the color value and its persistence, nothing about theming.
  Future<void> setMainColor(final Color color) async {
    state = color;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_mainColorPreferenceKey, color.toARGB32());
  }
}
