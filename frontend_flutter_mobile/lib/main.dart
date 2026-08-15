import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/pos_theme.dart';
import 'core/models/auth_models.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/language_provider.dart';
import 'core/providers/main_color_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/api_service.dart';
import 'core/utils/khmer_text_scaler.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/shell/mobile_shell_screen.dart';
import 'l10n/generated/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: MobileApp()));
}

/// Root widget — mirrors `frontend-flutter-pos/lib/main.dart`'s `PosApp` for
/// the theme/locale wiring (Day 3) and now the auth gate (Day 4); see
/// `docs/DAY_03_THEME_LOCALIZATION_FOUNDATION.md` and `docs/DAY_04.md` for
/// the full OLD/SOURCE → NEW/MOBILE mapping.
///
/// MODIFIED Day 4: `home:` now branches on `authProvider` exactly like
/// `[OLD/SOURCE] PosApp.build()`'s `authState.maybeWhen(...)` — LoginScreen
/// when logged out, a post-login screen when logged in. No explicit
/// `routes['/']` entry is added — `home:` already registers the default
/// route (`'/'`), and adding both throws MaterialApp's `home`/`routes`
/// conflict assertion, exactly why `[OLD/SOURCE]`'s own `routes` table
/// never defines `'/'` either. `LoginScreen._login()`'s
/// `pushReplacementNamed('/')` resolves to this same `home:` route.
///
/// MODIFIED Day 5: the logged-in branch is now `MobileShellScreen` (the
/// real bottom-nav shell — see DAY_05.md) instead of Day 3/4's temporary
/// `ThemeDemoScreen` placeholder. `ThemeDemoScreen` still exists and is
/// still reachable (via the shell's "More" tab), it's just no longer the
/// top-level destination.
class MobileApp extends ConsumerWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    PosTheme.applyMainColor(ref.watch(mainColorProvider));
    final isKhmer = ref.watch(appLanguageProvider).isKhmer;
    final authState = ref.watch(authProvider);

    // Wires ApiService's 401 interceptor (see api_service.dart) to
    // authProvider's logout, exactly like [OLD/SOURCE] PosApp.build() —
    // any backend-rejected session (expired/invalidated token on a later
    // authenticated call) clears the cached session and this rebuild sends
    // the user back to LoginScreen via the `home:` gate below, instead of
    // holding a dead token forever.
    ApiService.onUnauthorized = () => ref.read(authProvider.notifier).logout();

    return MaterialApp(
      title: 'KAKNNEA',
      debugShowCheckedModeBanner: false,
      theme: PosTheme.lightTheme,
      darkTheme: PosTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider).value,
      locale: ref.watch(appLanguageProvider).toLocale(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler:
              khmerAwareTextScaler(MediaQuery.of(context).textScaler, isKhmer: isKhmer),
        ),
        child: child!,
      ),
      supportedLocales: const [Locale('en'), Locale('km')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: authState.maybeWhen(
        data: (User? user) =>
            user != null ? const MobileShellScreen() : const LoginScreen(),
        orElse: () => const LoginScreen(),
      ),
    );
  }
}
