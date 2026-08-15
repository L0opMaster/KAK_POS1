import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/core/config/pos_theme.dart';
import 'package:frontend_flutter_mobile/core/providers/main_color_provider.dart';

/// MainColorNotifier's constructor kicks off an async `_loadPreference()`
/// that awaits `SharedPreferences.getInstance()`. Pre-warming the instance
/// (as `main()` itself does before `runApp`, see Day 1's startup-flow notes)
/// and forcing the provider to build here — then draining the event queue —
/// ensures that initial load has finished before a test calls setMainColor.
///
/// This matters because of a real, source-inherited race: if setMainColor()
/// runs before the constructor's own _loadPreference() resolves, the two
/// writes to `state` can interleave and the load can clobber the just-set
/// color. See DAY_03_THEME_LOCALIZATION_FOUNDATION.md "Problems Found" —
/// harmless in the real app (a user can't tap a color swatch before the
/// first frame renders, which is always later than this microtask-fast
/// load), but real, and not silently patched here per task instructions.
Future<ProviderContainer> _readyContainer() async {
  await SharedPreferences.getInstance();
  final container = ProviderContainer();
  container.read(mainColorProvider); // force creation, kick off _loadPreference
  await pumpEventQueue();
  return container;
}

void main() {
  group('mainColorProvider', () {
    test('defaults to the first palette entry (green) with no saved pref',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = await _readyContainer();
      addTearDown(container.dispose);

      expect(container.read(mainColorProvider), kMainColorOptions.first);
    });

    test('setMainColor updates state and persists the ARGB value', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await _readyContainer();
      addTearDown(container.dispose);

      final blue = kMainColorOptions[1];
      await container.read(mainColorProvider.notifier).setMainColor(blue);

      expect(container.read(mainColorProvider), blue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('app_main_color'), blue.toARGB32());
    });

    test('restores a previously persisted color on next load (restart)',
        () async {
      final purple = kMainColorOptions[2];
      SharedPreferences.setMockInitialValues({
        'app_main_color': purple.toARGB32(),
      });

      final container = await _readyContainer();
      addTearDown(container.dispose);

      expect(container.read(mainColorProvider), purple);
    });

    test('falls back to default if the saved value matches no palette entry',
        () async {
      SharedPreferences.setMockInitialValues({
        'app_main_color': const Color(0xFF123456).toARGB32(),
      });

      final container = await _readyContainer();
      addTearDown(container.dispose);

      expect(container.read(mainColorProvider), kMainColorOptions.first);
    });
  });

  group('PosTheme.applyMainColor', () {
    test('updates primaryGreen synchronously — no restart needed', () {
      PosTheme.applyMainColor(const Color(0xFF2196F3));
      expect(PosTheme.primaryGreen, const Color(0xFF2196F3));

      PosTheme.applyMainColor(const Color(0xFF9C27B0));
      expect(PosTheme.primaryGreen, const Color(0xFF9C27B0));
    });

    test('lightTheme/darkTheme both reflect the applied main color', () {
      PosTheme.applyMainColor(const Color(0xFFFF9800));
      expect(PosTheme.lightTheme.colorScheme.primary, const Color(0xFFFF9800));
      expect(PosTheme.darkTheme.colorScheme.primary, const Color(0xFFFF9800));
    });

    test('semantic colors are constants, independent of main color', () {
      PosTheme.applyMainColor(const Color(0xFF2196F3));
      expect(PosTheme.errorRed, const Color(0xFFE53935));
      expect(PosTheme.warningAmber, const Color(0xFFFFA000));
      expect(PosTheme.successGreen, const Color(0xFF43A047));

      PosTheme.applyMainColor(const Color(0xFFE53935)); // "red" palette option
      // Even when the main color happens to equal errorRed's hex, the two
      // are still independent constants/getters — errorRed didn't change
      // *because* of applyMainColor, it just happens to share a value here.
      expect(PosTheme.errorRed, const Color(0xFFE53935));
    });
  });
}
