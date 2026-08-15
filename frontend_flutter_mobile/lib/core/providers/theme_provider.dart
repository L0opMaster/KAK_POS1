import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple notifier for toggling between light and dark theme.
///
/// Ported from `frontend-flutter-pos/lib/core/providers/theme_provider.dart`.
class ThemeModeNotifier extends ValueNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light);

  void toggle() {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  void setLight() => value = ThemeMode.light;
  void setDark() => value = ThemeMode.dark;
}

/// Provider for the current theme mode.
final themeModeProvider =
    ChangeNotifierProvider<ThemeModeNotifier>((ref) => ThemeModeNotifier());
