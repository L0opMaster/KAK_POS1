import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/table_models.dart';
import '../../../core/config/app_config.dart';

// ══ OFFLINE (this whole file) ═════════════════════════════════════════
/// StateNotifier that keeps track of the currently selected table and
/// persists it to SharedPreferences so selection survives restarts.
///
/// Both `_load()` and `select()` below are OFFLINE-only: they read/write
/// the table name string under `AppConfig.selectedTableKey` and never call
/// the network. Note this only stores the table *name* — full table data
/// (see table_service.dart, which IS a SWITCH POINT between online/offline)
/// is fetched separately and not cached here.
class TableSelectionNotifier extends StateNotifier<RestaurantTable?> {
  /// Default constructor used in production; it will load the previously
  /// selected table from shared preferences.
  TableSelectionNotifier() : super(null) {
    _load();
  }

  /// Constructor intended for tests.  It does **not** perform any async
  /// loading, allowing unit tests to take control of the initial state.
  @visibleForTesting
  TableSelectionNotifier.withValue(RestaurantTable? initial) : super(initial);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(AppConfig.selectedTableKey);
    if (name != null) {
      // we don't have full table data, so just stash name
      state = RestaurantTable.sample().copyWith(
        tableNumber: name,
        displayName: 'Table $name',
      );
    }
  }

  Future<void> select(RestaurantTable? table) async {
    state = table;
    final prefs = await SharedPreferences.getInstance();
    if (table == null) {
      await prefs.remove(AppConfig.selectedTableKey);
    } else {
      await prefs.setString(AppConfig.selectedTableKey, table.tableNumber);
    }
  }
}

/// Provider for table selection.
final tableSelectionProvider =
    StateNotifierProvider<TableSelectionNotifier, RestaurantTable?>((ref) {
  return TableSelectionNotifier();
});
