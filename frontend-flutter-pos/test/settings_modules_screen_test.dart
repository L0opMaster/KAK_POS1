import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/screens/settings_modules_screen.dart';
import 'package:frontend_flutter_pos/features/pos/services/settings_service.dart';

import 'test_l10n_helper.dart';

class FakeApiService extends ApiService {
  final Map<String, dynamic> getResponses = {};
  final List<String> calls = [];
  bool failNextPut = false;

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('GET $path');
    return (getResponses[path] ?? <String, dynamic>{}) as T;
  }

  @override
  Future<T> put<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('PUT $path $data');
    if (failNextPut) {
      throw ApiException('Business name is required', statusCode: 400);
    }
    return (data as Map).cast<String, dynamic>() as T;
  }

  @override
  Future<T> patch<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('PATCH $path $data');
    return <String, dynamic>{} as T;
  }
}

void main() {
  late FakeApiService fakeApi;

  setUp(() {
    fakeApi = FakeApiService();
    fakeApi.getResponses['/api/settings/general'] = {
      'defaultLanguage': 'en',
      'currency': 'USD',
      'receiptFooter': 'General footer',
      'showKhqr': false,
      'requireShiftForSales': false,
    };
    fakeApi.getResponses['/api/settings/company-profile'] = {
      'businessName': 'Kaknnea Cafe',
      'address': 'Phnom Penh',
      'phone': '012345678',
    };
    fakeApi.getResponses['/api/settings/tax'] = {
      'taxRate': 0.1,
      'showTax': true,
    };
    fakeApi.getResponses['/api/settings/printers'] = {
      'printerName': 'Front desk',
      'printerType': 'thermal',
      'printerAddress': '192.168.1.50',
      'invoiceFooter': 'Printer-only footer',
    };
    fakeApi.getResponses['/api/settings/payment-methods'] = {
      'content': [
        {'id': 1, 'code': 'CASH', 'name': 'Cash', 'active': true},
      ],
    };
    fakeApi.getResponses['/api/settings/currencies'] = {
      'content': [
        {
          'id': 2,
          'code': 'USD',
          'symbol': r'$',
          'name': 'US Dollar',
          'active': true,
          'defaultCurrency': true,
        },
      ],
    };
  });

  Widget buildScreen() {
    return ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWithValue(SettingsService(fakeApi)),
      ],
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: SettingsModulesScreen(),
      ),
    );
  }

  // The settings ListView is taller than every section combined; the default
  // 800x600 test surface clips most of it. Grow the surface so every save
  // button and toggle is on-screen without needing scroll gestures.
  Future<void> pumpScreen(WidgetTester tester, [Widget? widget]) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget ?? buildScreen());
    await tester.pumpAndSettle();
  }

  testWidgets('shows tax rate as a percentage, not the raw fraction',
      (tester) async {
    await pumpScreen(tester);

    expect(find.widgetWithText(TextField, 'Tax rate'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Tax rate'),
    );
    expect(field.controller!.text, '10');
  });

  testWidgets(
      'printer invoice footer loads its own value, distinct from the general receipt footer',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('General footer'), findsOneWidget);
    expect(find.text('Printer-only footer'), findsOneWidget);
  });

  testWidgets('rejects an out-of-range tax rate without calling the API',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Tax rate'),
      '150',
    );
    await tester.tap(find.text('Save Tax'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a tax rate between 0 and 100'), findsOneWidget);
    expect(
      fakeApi.calls.any((c) => c.startsWith('PUT /api/settings/tax')),
      isFalse,
    );
  });

  testWidgets('shows the backend error message when a save fails',
      (tester) async {
    fakeApi.failNextPut = true;
    await pumpScreen(tester);

    await tester.tap(find.text('Save Company'));
    await tester.pumpAndSettle();

    expect(find.text('Business name is required'), findsOneWidget);
  });

  testWidgets('toggling a payment method calls the status PATCH endpoint',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Cash'));
    await tester.pumpAndSettle();

    expect(
      fakeApi.calls,
      contains('PATCH /api/settings/payment-methods/1/status {active: false}'),
    );
  });

  testWidgets('shows a retry button when the initial load fails',
      (tester) async {
    final erroringApi = _ThrowingApiService();
    await pumpScreen(
      tester,
      ProviderScope(
        overrides: [
          settingsServiceProvider
              .overrideWithValue(SettingsService(erroringApi)),
        ],
        child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: SettingsModulesScreen(),
      ),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Connection lost'), findsOneWidget);
  });
}

class _ThrowingApiService extends ApiService {
  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    throw ApiException('Connection lost');
  }
}
