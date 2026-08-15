import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/widgets/category_tabs.dart';

import 'test_l10n_helper.dart';

void main() {
  testWidgets('shows "All" plus every category and reports taps',
      (tester) async {
    final categories = [
      Category(id: 1, nameEn: 'Beverages', nameKm: 'ភេសជ្ជៈ', active: true),
      Category(id: 2, nameEn: 'Food', nameKm: 'អាហារ', active: true),
    ];
    int? tapped;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: CategoryTabs(
            categories: categories,
            selectedId: null,
            onSelected: (id) => tapped = id,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Beverages'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.pump();
    expect(tapped, 2);

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(tapped, isNull);
  });
}
