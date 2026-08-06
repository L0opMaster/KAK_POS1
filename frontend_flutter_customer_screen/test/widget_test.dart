import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_customer_screen/main.dart';

void main() {
  testWidgets('App boots to the connect screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CustomerDisplayApp()),
    );
    await tester.pump();

    expect(find.text('Connect to Register'), findsOneWidget);
  });
}
