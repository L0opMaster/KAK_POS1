import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ignore: avoid_classes_with_only_static_members
class AppConfig {
  // ── Dev flags ────────────────────────────────────────────────────────────
  // In debug builds all API-backed services are enabled automatically so you
  // can develop against a running backend without manually flipping flags.
  // In release builds everything defaults to false for safety.
  //
  // ══ SWITCH POINTS ══════════════════════════════════════════════════════
  // These three booleans are the actual "online vs offline" switches used by
  // this app. There is no live network/connectivity check anywhere in the
  // codebase (see core/providers/connectivity_provider.dart, which exists but
  // is not read by any of these flags) — instead each flag is read once when
  // its Provider is created, and it decides whether that feature's Provider
  // builds the ONLINE (Api***Service, talks to the backend over HTTP) or the
  // OFFLINE (Local***Service, reads/writes SharedPreferences on-device)
  // implementation. Flip a flag → the app switches which implementation the
  // rest of the code talks to.
  // They can also be toggled at runtime from the developer menu, see
  // features/pos/screens/debug_settings_screen.dart (_useApiCart,
  // _syncHeldTickets).

  /// SWITCH POINT for held tickets.
  /// true  -> ApiHeldTicketService  (ONLINE, backend `/api/pos/open-tickets`)
  /// false -> LocalHeldTicketService (OFFLINE, SharedPreferences key
  ///          'held_tickets_local')
  /// Read by: features/pos/services/held_ticket_service.dart
  /// (heldTicketServiceProvider).
  static bool enableHeldTicketSync = kDebugMode;

  /// SWITCH POINT for the shopping cart backend.
  /// true  -> ApiCartService  (ONLINE, backend `/api/carts`)
  /// false -> LocalCartService (OFFLINE, SharedPreferences key 'cart_items')
  /// NOTE: ONLINE is now the default (backend `/api/carts` is ready). The
  /// OFFLINE implementation is still fully intact in cart_service.dart and
  /// can be restored either by setting this back to `false` or by flipping
  /// the "Use API cart" toggle in the developer menu
  /// (debug_settings_screen.dart) at runtime.
  /// Read by: features/pos/services/cart_service.dart (cartServiceProvider).
  static bool useApiCartService = true;

  /// SWITCH POINT for table search/stats.
  /// true  -> ApiTableService  (ONLINE, backend `/api/tables`)
  /// false -> LocalTableService (OFFLINE, static in-memory sample data)
  /// Read by: features/pos/services/table_service.dart (tableServiceProvider).
  static bool useApiTableService = kDebugMode;

  // Queue key for offline held order operations
  // ignore: public_member_api_docs
  static const String heldOrderOpsQueueKey = 'held_order_ops_queue';

  // Device ID (for offline queue tracking)
  // ignore: public_member_api_docs
  static const String defaultDeviceId = 'DEVICE-1';
  // App Info
  // ignore: public_member_api_docs
  static const String appName = 'KAKNNEA';

  /// Key for storing held orders in SharedPreferences
  static const String heldOrdersKey = 'held_orders';
  // API Configuration
  // Note: Repositories typically append '/api/...', so we use the root here to avoid '/api/api/...'
  // ignore: public_member_api_docs
  static String get baseUrl {
    // ignore: always_put_control_body_on_new_line
    if (kIsWeb) return 'http://localhost:8081';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8081'; // Android Emulator host access
    }
    return 'http://localhost:8081'; // iOS Simulator / Desktop
  }

  // ignore: public_member_api_docs
  static String get apiBaseUrl => baseUrl; // Alias used by ApiService

  // Storage Keys
  // ignore: public_member_api_docs
  static const String authTokenKey = 'auth_token';
  // ignore: public_member_api_docs
  static const String userKey = 'user_data';
  // ignore: public_member_api_docs
  static const String cartKey = 'cart_items';

  // UI Constants
  static const double defaultPadding = 16;
  static const double defaultBorderRadius = 8;

  // Branding Colors (Loyverse-inspired)
  static const Color primaryColor = Color(0xFF4CAF50); // Loyverse Green
  static const Color secondaryColor = Color(0xFF2196F3); // Blue accent
  static const Color errorColor = Color(0xFFE53935); // Red-600
  static const Color successColor = Color(0xFF43A047); // Green-600
  static const Color warningColor = Color(0xFFFFA000); // Amber

  // Default IDs
  static const int defaultStoreId = 1;
  static const String defaultTerminalId = 'T1';

  /// Key for storing selected table number in preferences
  static const String selectedTableKey = 'selected_table';

  // Initialization
  static Future<void> initialize() async {}
}
