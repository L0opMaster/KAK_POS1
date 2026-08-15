import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter_pos/core/providers/main_color_provider.dart';

Future<void> _pumpUntilLoaded(
    ProviderContainer container, Color expected) async {
  for (var i = 0; i < 50; i++) {
    if (container.read(mainColorProvider) == expected) break;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  // The constructor's `_loadPreference()` is fire-and-forget, so state can
  // already equal `expected` (e.g. it's the same as the initial default)
  // *before* that in-flight future actually settles. A couple more ticks
  // guarantee it has resolved before the test issues its next write —
  // otherwise the late `_loadPreference` write can race and clobber it.
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to the original brand green when nothing is saved',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _pumpUntilLoaded(container, kMainColorOptions.first);

    expect(container.read(mainColorProvider), kMainColorOptions.first);
  });

  test('setMainColor updates provider state immediately', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpUntilLoaded(container, kMainColorOptions.first);

    final blue = kMainColorOptions[1];
    await container.read(mainColorProvider.notifier).setMainColor(blue);

    expect(container.read(mainColorProvider), blue);
  });

  test('setMainColor persists across a fresh provider container', () async {
    final container1 = ProviderContainer();
    addTearDown(container1.dispose);
    await _pumpUntilLoaded(container1, kMainColorOptions.first);

    final purple = kMainColorOptions[2];
    await container1.read(mainColorProvider.notifier).setMainColor(purple);

    // Simulate an app restart: a brand-new container re-reads SharedPreferences.
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    await _pumpUntilLoaded(container2, purple);

    expect(container2.read(mainColorProvider), purple);
  });

  test('falls back to default if a stale/unknown color value was saved',
      () async {
    SharedPreferences.setMockInitialValues({
      'app_main_color': const Color(0xFF123456).value,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await _pumpUntilLoaded(container, kMainColorOptions.first);

    expect(container.read(mainColorProvider), kMainColorOptions.first);
  });

  test('kMainColorOptions offers more than one color and green is first', () {
    expect(kMainColorOptions.length, greaterThanOrEqualTo(6));
    expect(kMainColorOptions.first, const Color(0xFF4CAF50));
    expect(kMainColorOptions.toSet().length, kMainColorOptions.length,
        reason: 'palette entries should be distinct colors');
  });
}
