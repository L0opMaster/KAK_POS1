import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic Flutter test', (final WidgetTester tester) async {
    // Build a simple widget to test basic Flutter functionality
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('KAKNNEA POS'),
          ),
        ),
      ),
    );

    // Verify that the text is shown
    expect(find.text('KAKNNEA POS'), findsOneWidget);
  });
}
