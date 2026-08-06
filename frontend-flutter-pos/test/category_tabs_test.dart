import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/category_tabs.dart';

import 'test_l10n_helper.dart';

void main() {
  testWidgets('CategoryTabs shows all categories and handles taps',
      (tester) async {
    final categories = [
      Category(id: 1, nameEn: 'Coffee', nameKm: 'កាហ្វេ', active: true),
      Category(id: 2, nameEn: 'Tea', nameKm: 'តែ', active: true),
    ];
    int? selected;

    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(
        body: CategoryTabs(
          categories: categories,
          selectedId: null,
          onSelected: (id) => selected = id,
        ),
      ),
    )));
    await tester.pumpAndSettle();

    // should render "All" plus each category name and icon
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Tea'), findsOneWidget);

    // icons should also be present (coffee/tea emoji)
    expect(find.text('☕'), findsOneWidget);
    expect(find.text('🍵'), findsOneWidget);

    // tap the Tea tab
    await tester.tap(find.text('Tea'));
    await tester.pumpAndSettle();
    expect(selected, equals(2));

    // tap All
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('CategoryTabs can be vertical', (tester) async {
    final categories = [
      Category(id: 1, nameEn: 'Foo', nameKm: 'ហ្វូ', active: true),
      Category(id: 2, nameEn: 'Bar', nameKm: 'បារ', active: true),
    ];
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: CategoryTabs(
            categories: categories,
            selectedId: 2,
            onSelected: (_) {},
            vertical: true,
          ),
        ),
      ),
    )));
    await tester.pumpAndSettle();

    // verify that the tabs scroll vertically by checking the
    // SingleChildScrollView direction.
    final scroll = find.byWidgetPredicate((widget) {
      return widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.vertical;
    });
    expect(scroll, findsOneWidget);
  });
}
