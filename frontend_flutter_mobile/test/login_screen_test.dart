import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/core/models/auth_models.dart';
import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/core/services/auth_service.dart';
import 'package:frontend_flutter_mobile/features/auth/screens/login_screen.dart';
import 'package:frontend_flutter_mobile/features/shell/mobile_shell_screen.dart';
import 'package:frontend_flutter_mobile/l10n/generated/app_localizations.dart';
import 'package:frontend_flutter_mobile/main.dart';

const _user = User(
  id: 1,
  email: 'owner@kaknnea.local',
  fullName: 'Owner',
  roles: ['OWNER'],
);

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ApiService());

  bool shouldFail = false;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<AuthResponse> login(String email, String password,
      {String? terminalId}) async {
    if (shouldFail) throw Exception('Invalid credentials');
    return const AuthResponse(token: 'fake.jwt.token', user: _user);
  }
}

/// Bare-`LoginScreen` wrapper for the two tests that never reach the
/// navigation line in `_login()` (validation fails, or the login call
/// throws) — no route table needed since `Navigator.pushReplacementNamed`
/// is never called on those paths.
Widget _wrapFormOnly(AuthService service) => ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('km')],
        home: const LoginScreen(),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows validation errors for empty email/password',
      (tester) async {
    final service = _FakeAuthService();
    await tester.pumpWidget(_wrapFormOnly(service));
    await tester.pumpAndSettle();

    // Clear the pre-filled demo credentials to exercise validation.
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets(
      'failed login: reproduces a real [OLD/SOURCE] defect — the error '
      'SnackBar never shows, because AuthNotifier.login() swallows the '
      'exception into AsyncValue.error instead of rethrowing, so '
      '_login()\'s catch block is unreachable dead code. See DAY_04.md '
      '"Problems Found" — NOT fixed here, faithfully reproduced from '
      'source per the source-of-truth rule.', (tester) async {
    final service = _FakeAuthService()..shouldFail = true;
    await tester.pumpWidget(_wrapFormOnly(service));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
    await tester.pumpAndSettle();

    // The SnackBar never appears — this IS the current, faithfully-ported
    // behavior, not a gap in the test.
    expect(find.textContaining('Login failed'), findsNothing);
  });

  testWidgets(
      'successful login swaps MobileApp.home from LoginScreen to the '
      'post-login screen', (tester) async {
    final service = _FakeAuthService();

    // Exercises the REAL production navigation path — MobileApp.home
    // re-evaluating `authProvider` — rather than a hand-rolled route table,
    // since `_login()`'s `pushReplacementNamed('/')` only does anything
    // useful when `home:` is the thing deciding what "/" builds (see
    // DAY_04.md "Problems Found" for why a bespoke `routes['/']` table
    // can't reproduce this).
    await tester.pumpWidget(ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(service)],
      child: const MobileApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'LOGIN'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(MobileShellScreen), findsOneWidget);
  });
}
