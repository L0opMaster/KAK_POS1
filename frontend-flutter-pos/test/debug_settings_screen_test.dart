import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/core/config/app_config.dart';
import 'package:frontend_flutter_pos/features/pos/screens/debug_settings_screen.dart';
import 'package:frontend_flutter_pos/features/pos/screens/pos_screen.dart';

import 'test_l10n_helper.dart';

void main() {
  setUp(() {
    // ensure flags have known defaults
    AppConfig.useApiCartService = false;
    AppConfig.enableHeldTicketSync = false;
  });

  testWidgets('DebugSettingsScreen shows switches and updates flags',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: DebugSettingsScreen(),
    ));

    expect(find.text('Use API cart service'), findsOneWidget);
    expect(find.text('Enable held-ticket sync'), findsOneWidget);

    // toggle both switches
    await tester.tap(find.byType(SwitchListTile).at(0));
    await tester.tap(find.byType(SwitchListTile).at(1));
    await tester.pumpAndSettle();
    // press apply
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(AppConfig.useApiCartService, isTrue);
    expect(AppConfig.enableHeldTicketSync, isTrue);
    expect(find.text('Settings updated'), findsOneWidget);
  });

  testWidgets('Settings icon appears in PosScreen app bar when debug mode',
      (tester) async {
    // kDebugMode is true in tests by default
    await tester.pumpWidget(ProviderScope(
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: PosScreen(),
      ),
    ));
    expect(find.byIcon(Icons.settings), findsOneWidget);

    // tap to navigate
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Debug Settings'), findsOneWidget);
  });
}
