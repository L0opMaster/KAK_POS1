import 'package:flutter/foundation.dart';

/// Ported from `frontend-flutter-pos/lib/core/config/app_config.dart` —
/// COPY/ADAPT NEARLY EXACTLY. Only the branding-color constants and UI-only
/// fields were dropped (mobile owns its brand color via `PosTheme`/
/// `main_color_provider.dart`, see Day 3); every networking/storage-key
/// constant below is byte-identical to the source so the mobile app talks to
/// the exact same backend contract. See DAY_04.md for the full mapping.
// ignore: avoid_classes_with_only_static_members
class AppConfig {
  /// Same three-platform switch as `[OLD/SOURCE]` — the Android branch uses
  /// a real LAN IP (not the `10.0.2.2` emulator alias) because that's what
  /// the source project already relies on for its dev backend. Kept
  /// identical here rather than "fixed", per the source-of-truth rule — see
  /// DAY_04.md "Problems Found" for why this may need to be a per-developer
  /// override in a real multi-machine mobile dev setup.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8081';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.13:8081';
    }
    return 'http://localhost:8081';
  }

  static String get apiBaseUrl => baseUrl;

  // Storage keys — identical to [OLD/SOURCE] so a token cached by one app
  // is shaped the same way as the other (not shared storage, just the same
  // key-naming convention).
  static const String authTokenKey = 'auth_token';
  static const String userKey = 'user_data';

  static const String appName = 'KAKNNEA';

  /// SWITCH POINT for the shopping cart backend, added Day 7.
  /// true  -> ApiCartService  (ONLINE, backend `/api/carts`)
  /// false -> LocalCartService (OFFLINE, SharedPreferences key 'cart_items')
  /// Matches `[OLD/SOURCE]`'s CURRENT default (`true`) exactly — safe
  /// either way because `CartNotifier._syncService` swallows every remote
  /// failure and the OFFLINE `persistCart()` snapshot is always the
  /// source of truth `restoreCart()` reads back, regardless of this flag.
  /// Read by: features/pos/services/cart_service.dart (cartServiceProvider).
  static bool useApiCartService = true;

  /// SWITCH POINT for table search, added Day 9. Matches `[OLD/SOURCE]`'s
  /// current default (`kDebugMode`) exactly.
  /// Read by: features/pos/services/table_service.dart (tableServiceProvider).
  static bool useApiTableService = kDebugMode;

  /// SWITCH POINT for held tickets, added Day 9. Matches `[OLD/SOURCE]`'s
  /// current default (`kDebugMode`) exactly.
  /// Read by: features/pos/services/held_ticket_service.dart
  /// (heldTicketServiceProvider).
  static bool enableHeldTicketSync = kDebugMode;

  /// Key for storing the selected table number in preferences. Added
  /// Day 9. Byte-identical to `[OLD/SOURCE]`.
  static const String selectedTableKey = 'selected_table';
}
