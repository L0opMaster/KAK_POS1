import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter_pos/core/config/app_config.dart';
import 'package:frontend_flutter_pos/features/pos/providers/table_selection_provider.dart';
import 'package:frontend_flutter_pos/features/pos/models/table_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('TableSelectionNotifier persists selection across instances', () async {
    final notifier = TableSelectionNotifier.withValue(null);
    expect(notifier.state, isNull);

    final table = RestaurantTable.sample();
    await notifier.select(table);
    expect(notifier.state, same(table));

    // create a new notifier which should load from prefs
    final notifier2 = TableSelectionNotifier();
    // allow async load to complete
    await Future.delayed(const Duration(milliseconds: 20));
    expect(notifier2.state, isNotNull);
    expect(notifier2.state!.tableNumber, table.tableNumber);
  });

  test('clear selection removes preference', () async {
    final notifier = TableSelectionNotifier.withValue(null);
    final table = RestaurantTable.sample();
    await notifier.select(table);
    expect(notifier.state, isNotNull);

    await notifier.select(null);
    expect(notifier.state, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConfig.selectedTableKey), isNull);
  });
}
