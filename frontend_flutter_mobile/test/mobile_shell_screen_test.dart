import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/core/models/auth_models.dart';
import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/core/services/auth_service.dart';
import 'package:frontend_flutter_mobile/features/auth/screens/login_screen.dart';
import 'package:frontend_flutter_mobile/features/pos/screens/customer_picker_screen.dart';
import 'package:frontend_flutter_mobile/features/pos/screens/pos_register_screen.dart';
import 'package:frontend_flutter_mobile/features/pos/screens/receipts_screen.dart';
import 'package:frontend_flutter_mobile/features/pos/screens/table_picker_screen.dart';
import 'package:frontend_flutter_mobile/features/pos/widgets/cart_fab.dart';
import 'package:frontend_flutter_mobile/features/shell/mobile_shell_screen.dart';
import 'package:frontend_flutter_mobile/l10n/generated/app_localizations.dart';
import 'package:frontend_flutter_mobile/main.dart';

const _user = User(
  id: 7,
  email: 'cashier@kaknnea.local',
  fullName: 'Cashier Person',
  roles: ['CASHIER'],
);

/// A well-formed, unexpired fake JWT — same shape as
/// `test/auth_provider_test.dart`'s `_makeToken` helper.
/// `AuthNotifier._initializeAuth()` decodes the `exp` claim via
/// `isJwtExpired()`, so a garbage string would fail that check and the
/// startup guard would log the fake session straight back out.
String _validToken() {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');
  final header = segment(<String, String>{'alg': 'HS256', 'typ': 'JWT'});
  final body = segment(<String, dynamic>{
    'sub': _user.email,
    'exp':
        DateTime.now()
            .toUtc()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch ~/
        1000,
  });
  return '$header.$body.signature';
}

class _LoggedInAuthService extends AuthService {
  _LoggedInAuthService() : super(ApiService());

  @override
  Future<String?> getToken() async => _validToken();

  @override
  Future<User?> getCurrentUser() async => _user;

  bool loggedOut = false;

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}

Widget _wrapShell() => ProviderScope(
  overrides: [authServiceProvider.overrideWithValue(_LoggedInAuthService())],
  child: MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('km')],
    home: const MobileShellScreen(),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows all 4 bottom nav destinations, Register selected first', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapShell());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Register'), findsWidgets); // AppBar title + nav label
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Held Tickets'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    // Register tab shows the real Day 6 product screen now (no longer the
    // Day 5 _ComingSoon placeholder) — see mobile_shell_screen_test.dart's
    // Day 5 version of this test for what it used to assert.
    expect(find.byType(PosRegisterScreen), findsOneWidget);
  });

  testWidgets('switching tabs swaps the AppBar title and selected index', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapShell());
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await tester.tap(find.text('Tables'));
    await tester.pumpAndSettle();

    // Real content since Day 9, replacing the old Day 5 _ComingSoon
    // placeholder — `AppConfig.useApiTableService` defaults to
    // `kDebugMode` (true under `flutter test`), so this actually exercises
    // ApiTableService against the test sandbox's always-400 HTTP, landing
    // in the picker's error state rather than empty/data — either way,
    // the real screen is what's mounted.
    expect(find.byType(TablePickerScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    // The AppBar title tracks the selected tab. (Material 3's
    // NavigationBar internally renders more than one "Tables" Text node
    // for its selection-indicator animation, so this only checks presence,
    // not an exact count.)
    expect(find.text('Tables'), findsWidgets);
  });

  testWidgets(
    'Tables tab -> No Table returns to the Register tab without tearing '
    'the shell down (regression: this used to call Navigator.pop(), which '
    'has nothing to pop since MobileShellScreen is the root route, and '
    'blanked the whole app)',
    (tester) async {
      await tester.pumpWidget(_wrapShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tables'));
      await tester.pumpAndSettle();
      expect(find.byType(TablePickerScreen), findsOneWidget);

      await tester.tap(find.text('No Table'));
      await tester.pumpAndSettle();

      // The shell is still there (nothing was popped off the root route)...
      expect(find.byType(MobileShellScreen), findsOneWidget);
      // ...and it switched back to the Register tab, same as this screen's
      // "done, show me the result" contract used to promise via pop().
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.byType(PosRegisterScreen), findsOneWidget);
    },
  );

  testWidgets(
    'the cart FAB only shows on the Register tab',
    (tester) async {
      await tester.pumpWidget(_wrapShell());
      await tester.pumpAndSettle();

      // Empty cart -> CartFab renders but stays invisible either way, so
      // just confirm it's mounted on Register (index 0)...
      expect(find.byType(CartFab), findsOneWidget);

      await tester.tap(find.text('Tables'));
      await tester.pumpAndSettle();
      // ...and gone once a non-Register tab is selected.
      expect(find.byType(CartFab), findsNothing);

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.byType(CartFab), findsOneWidget);
    },
  );

  testWidgets('More tab lists Customers/Shifts/Settings placeholders and '
      'a working Logout', (tester) async {
    await tester.pumpWidget(_wrapShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Shifts'), findsOneWidget);
    expect(find.text('Cashier Person'), findsOneWidget); // currentUserProvider

    // 'Settings' and 'Logout' are further down the More tab's list than
    // the initial viewport reaches now that Inventory (Day 17) and
    // Reports (Day 18) added two more entries above them — scroll to
    // bring each into the widget tree before asserting on it.
    await tester.scrollUntilVisible(
      find.text('Settings'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Settings'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Logout'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('More tab -> Customers opens the real customer picker', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Customers'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerPickerScreen), findsOneWidget);
    expect(find.text('Select customer'), findsOneWidget);
  });

  testWidgets('More tab -> Receipts opens the real receipts screen', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Receipts'));
    await tester.pumpAndSettle();

    expect(find.byType(ReceiptsScreen), findsOneWidget);
  });

  testWidgets('More tab -> Logout calls AuthService.logout()', (tester) async {
    final service = _LoggedInAuthService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('km')],
          home: const MobileShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Logout'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Logout'));
    await tester.pumpAndSettle();

    expect(service.loggedOut, isTrue);
  });

  testWidgets(
    'end-to-end: logging out from the shell returns MobileApp to LoginScreen',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_LoggedInAuthService()),
          ],
          child: const MobileApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MobileShellScreen), findsOneWidget);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, 'Logout'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Logout'));
      await tester.pumpAndSettle();

      expect(find.byType(MobileShellScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );
}
