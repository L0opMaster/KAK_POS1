// Smoke test for the app shell. Originally (Day 3) `MobileApp` always
// showed the theme demo screen; Day 4 added the auth gate (see
// docs/DAY_04.md), so the default — logged out, no cached session — is now
// LoginScreen. MODIFIED to match.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/features/auth/screens/login_screen.dart';
import 'package:frontend_flutter_mobile/main.dart';

void main() {
  testWidgets('MobileApp boots logged-out and shows LoginScreen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: MobileApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
