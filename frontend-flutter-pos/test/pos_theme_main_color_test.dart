import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/config/pos_theme.dart';

void main() {
  // PosTheme.applyMainColor mutates process-global state; reset to the
  // default brand green after every test so other test files (and other
  // tests in this file) aren't affected by ordering.
  tearDown(() {
    PosTheme.applyMainColor(const Color(0xFF4CAF50));
  });

  test('primaryGreen defaults to the original brand green', () {
    expect(PosTheme.primaryGreen, const Color(0xFF4CAF50));
  });

  test('applyMainColor updates primaryGreen for every subsequent read', () {
    const blue = Color(0xFF2196F3);
    PosTheme.applyMainColor(blue);

    expect(PosTheme.primaryGreen, blue);
  });

  test('applyMainColor derives distinct dark/light shades from the new color',
      () {
    const purple = Color(0xFF9C27B0);
    PosTheme.applyMainColor(purple);

    expect(PosTheme.primaryGreenDark, isNot(purple));
    expect(PosTheme.primaryGreenLight, isNot(purple));
    expect(PosTheme.primaryGreenDark, isNot(PosTheme.primaryGreenLight));

    final baseLightness = HSLColor.fromColor(purple).lightness;
    final darkLightness =
        HSLColor.fromColor(PosTheme.primaryGreenDark).lightness;
    final lightLightness =
        HSLColor.fromColor(PosTheme.primaryGreenLight).lightness;
    expect(darkLightness, lessThan(baseLightness));
    expect(lightLightness, greaterThan(baseLightness));
  });

  test('semantic colors stay fixed regardless of the selected main color',
      () {
    const originalError = PosTheme.errorRed;
    const originalWarning = PosTheme.warningAmber;
    const originalSuccess = PosTheme.successGreen;

    PosTheme.applyMainColor(const Color(0xFFE53935)); // pick red main color
    PosTheme.applyMainColor(const Color(0xFF9C27B0));

    expect(PosTheme.errorRed, originalError);
    expect(PosTheme.warningAmber, originalWarning);
    expect(PosTheme.successGreen, originalSuccess);
  });

  test('lightTheme.colorScheme.primary reflects the applied main color', () {
    const orange = Color(0xFFFF9800);
    PosTheme.applyMainColor(orange);

    expect(PosTheme.lightTheme.colorScheme.primary, orange);
  });

  test('darkTheme still builds and stays legible after a main color change',
      () {
    const teal = Color(0xFF009688);
    PosTheme.applyMainColor(teal);

    final darkTheme = PosTheme.darkTheme;
    expect(darkTheme.brightness, Brightness.dark);
    // The dark theme should still expose a usable primary/onPrimary pair.
    expect(darkTheme.colorScheme.primary, isNotNull);
    expect(
      darkTheme.colorScheme.onPrimary,
      isNotNull,
    );
  });
}
