import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_barcode_scanner/main.dart';

void main() {
  testWidgets('shows the connect-to-POS form on launch',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Connect this phone to the active POS'), findsOneWidget);
    expect(find.text('Connect to POS'), findsOneWidget);
  });
}
