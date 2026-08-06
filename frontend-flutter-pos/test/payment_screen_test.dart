import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/screens/payment_screen.dart';

void main() {
  testWidgets('payment screen entry and review flow', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PaymentScreen(total: 50.0)));
    await tester.pumpAndSettle();

    expect(find.text('Total due: \$50.00'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '60');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next: Review'));
    await tester.pumpAndSettle();

    expect(find.text('Paid: \$60.00'), findsOneWidget);
    expect(find.text('Change: \$10.00'), findsOneWidget);

    // finish returns to previous
    await tester.tap(find.widgetWithText(ElevatedButton, 'Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Total due:'), findsNothing);
  });
}
