import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mainColorPreferenceKey = 'app_main_color';

/// Selectable app accent color palette — same palette as
/// `frontend-flutter-pos/lib/core/providers/main_color_provider.dart` so a
/// venue's chosen brand color stays consistent across the register, the
/// customer display, and the phone scanner. First entry is this app's
/// original green and the default for anyone who hasn't picked one yet.
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

class MainColorNotifier extends StateNotifier<Color> {
  MainColorNotifier() : super(kMainColorOptions.first) {
    _loadPreference();
  }

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

  Future<void> setMainColor(final Color color) async {
    state = color;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_mainColorPreferenceKey, color.toARGB32());
  }
}
