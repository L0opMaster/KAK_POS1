import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/table_models.dart';
import '../../../core/config/app_config.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// table_selection_provider.dart` — COPY/ADAPT NEARLY EXACTLY. OFFLINE:
/// keeps track of the currently selected table and persists it to
/// SharedPreferences (device-local, table NAME only — not full table
/// data) so selection survives restarts.
class TableSelectionNotifier extends StateNotifier<RestaurantTable?> {
  TableSelectionNotifier() : super(null) {
    _load();
  }

  @visibleForTesting
  TableSelectionNotifier.withValue(RestaurantTable? initial) : super(initial);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(AppConfig.selectedTableKey);
    if (name != null) {
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

final tableSelectionProvider =
    StateNotifierProvider<TableSelectionNotifier, RestaurantTable?>((ref) {
  return TableSelectionNotifier();
});
