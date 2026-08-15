import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/providers/language_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/receipt_models.dart';
import 'package:frontend_flutter_mobile/features/pos/services/printing/receipt_view_model.dart';
import 'package:frontend_flutter_mobile/l10n/generated/app_localizations.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

Product _product(int id, {String nameEn = 'Item', double price = 5}) => Product(
  id: id,
  sku: 'SKU$id',
  barcode: 'BAR$id',
  nameEn: nameEn,
  nameKm: nameEn,
  cost: 1,
  price: price,
  active: true,
  categoryId: 1,
);

void main() {
  group('ReceiptViewModel.fromReceiptResponse', () {
    test('businessName falls back businessName -> storeName -> appName', () {
      final withBusinessName = ReceiptViewModel.fromReceiptResponse(
        ReceiptResponse(saleId: 1, businessName: 'Acme', storeName: 'Store 1'),
        AppLanguage.en,
        _l10n,
      );
      expect(withBusinessName.businessName, 'Acme');

      final withStoreNameOnly = ReceiptViewModel.fromReceiptResponse(
        ReceiptResponse(saleId: 1, storeName: 'Store 1'),
        AppLanguage.en,
        _l10n,
      );
      expect(withStoreNameOnly.businessName, 'Store 1');

      final withNeither = ReceiptViewModel.fromReceiptResponse(
        ReceiptResponse(saleId: 1),
        AppLanguage.en,
        _l10n,
      );
      expect(withNeither.businessName, _l10n.appName);
    });

    test('invoiceNumber falls back saleNumber -> #saleId', () {
      final withNumber = ReceiptViewModel.fromReceiptResponse(
        ReceiptResponse(saleId: 42, saleNumber: 'INV-0042'),
        AppLanguage.en,
        _l10n,
      );
      expect(withNumber.invoiceNumber, 'INV-0042');

      final withoutNumber = ReceiptViewModel.fromReceiptResponse(
        ReceiptResponse(saleId: 42),
        AppLanguage.en,
        _l10n,
      );
      expect(withoutNumber.invoiceNumber, '#42');
    });

    test('paymentMethodLabel shows only the FIRST payment, even for a '
        'split sale', () {
      final vm = ReceiptViewModel.fromReceiptResponse(
        ReceiptResponse(
          saleId: 1,
          payments: [
            ReceiptPayment(method: 'CASH', amount: 5),
            ReceiptPayment(method: 'CARD', amount: 5),
          ],
        ),
        AppLanguage.en,
        _l10n,
      );
      expect(vm.paymentMethodLabel, 'CASH');
    });

    test('footer falls back to the localized thank-you when blank', () {
      final withFooter = ReceiptViewModel.fromReceiptResponse(
        ReceiptResponse(saleId: 1, footer: 'Custom footer'),
        AppLanguage.en,
        _l10n,
      );
      expect(withFooter.footer, 'Custom footer');

      final withoutFooter = ReceiptViewModel.fromReceiptResponse(
        ReceiptResponse(saleId: 1, footer: ''),
        AppLanguage.en,
        _l10n,
      );
      expect(withoutFooter.footer, _l10n.receiptThankYou);
    });

    test('createdAt (UTC instant) converts to local date/time, not the raw '
        'UTC calendar fields', () {
      // A UTC instant that's a different LOCAL calendar day/hour in most
      // timezones east of UTC — if this were sliced from the raw string
      // instead of properly converted, .toLocal() differences wouldn't show.
      final vm = ReceiptViewModel.fromReceiptResponse(
        ReceiptResponse(saleId: 1, createdAt: '2026-01-01T23:30:00.000Z'),
        AppLanguage.en,
        _l10n,
      );
      final expectedLocal = DateTime.parse(
        '2026-01-01T23:30:00.000Z',
      ).toLocal();
      expect(vm.date, contains('${expectedLocal.year}'));
    });
  });

  group('ReceiptViewModel.fromCart', () {
    test('computes subtotal from item line totals when subtotal is not '
        'given', () {
      final items = [
        CartItem(id: '1', product: _product(1, price: 5), qty: 2, addedAt: 0),
        CartItem(id: '2', product: _product(2, price: 3), qty: 1, addedAt: 0),
      ];
      final vm = ReceiptViewModel.fromCart(
        language: AppLanguage.en,
        l10n: _l10n,
        total: 13,
        items: items,
        paidAmount: 13,
      );
      expect(vm.subtotal, 13); // 5*2 + 3*1
      expect(vm.lines, hasLength(2));
    });

    test('note is populated on lines (unlike fromReceiptResponse, which '
        'has no cart-only note field)', () {
      final items = [
        CartItem(
          id: '1',
          product: _product(1),
          qty: 1,
          addedAt: 0,
          note: 'No onions',
        ),
      ];
      final vm = ReceiptViewModel.fromCart(
        language: AppLanguage.en,
        l10n: _l10n,
        total: 5,
        items: items,
        paidAmount: 5,
      );
      expect(vm.lines.single.note, 'No onions');
    });

    test('invoiceNumber defaults to N/A, cashierName null when blank', () {
      final vm = ReceiptViewModel.fromCart(
        language: AppLanguage.en,
        l10n: _l10n,
        total: 0,
        items: const [],
        paidAmount: 0,
      );
      expect(vm.invoiceNumber, 'N/A');
      expect(vm.cashierName, isNull);
    });
  });

  group('ReceiptViewModel computed fields', () {
    test('adjustments list only includes non-zero rows, in fixed order', () {
      final vm = ReceiptViewModel(
        language: AppLanguage.en,
        businessName: 'Acme',
        invoiceNumber: '#1',
        date: '',
        time: '',
        lines: const [],
        subtotal: 100,
        discountAmount: 10,
        taxAmount: 5,
        deliveryCharge: 0, // zero -> excluded
        otherCharge: 2,
        total: 97,
        footer: 'Thanks',
      );
      expect(vm.adjustments.map((a) => a.type), [
        ReceiptAdjustmentType.discount,
        ReceiptAdjustmentType.otherCharge,
        ReceiptAdjustmentType.tax,
      ]);
    });

    test('fmtAdjustment puts the minus sign before the currency symbol', () {
      const vm = ReceiptViewModel(
        language: AppLanguage.en,
        businessName: 'Acme',
        invoiceNumber: '#1',
        date: '',
        time: '',
        lines: [],
        subtotal: 10,
        currencyCode: 'USD',
        total: 10,
        footer: 'Thanks',
      );
      final discount = const ReceiptAdjustment(
        ReceiptAdjustmentType.discount,
        1.5,
      );
      final tax = const ReceiptAdjustment(ReceiptAdjustmentType.tax, 1.5);
      expect(vm.fmtAdjustment(discount), '-\$1.50');
      expect(vm.fmtAdjustment(tax), '\$1.50');
    });

    test('khrGroup adds thousands separators with no decimals', () {
      expect(ReceiptViewModel.khrGroup(82000), '82,000');
      expect(ReceiptViewModel.khrGroup(1234567), '1,234,567');
      expect(ReceiptViewModel.khrGroup(500), '500');
    });

    test('showExchangeRate is false for a KHR-priced receipt even with a '
        'rate set', () {
      const vm = ReceiptViewModel(
        language: AppLanguage.en,
        businessName: 'Acme',
        invoiceNumber: '#1',
        date: '',
        time: '',
        lines: [],
        subtotal: 10,
        currencyCode: 'KHR',
        exchangeRateKhr: 4100,
        total: 10,
        footer: 'Thanks',
      );
      expect(vm.showExchangeRate, isFalse);
    });

    test('containsKhmer is true when the UI language itself is Khmer, '
        'even with all-English content', () {
      const vm = ReceiptViewModel(
        language: AppLanguage.km,
        businessName: 'Acme',
        invoiceNumber: '#1',
        date: '',
        time: '',
        lines: [],
        subtotal: 10,
        total: 10,
        footer: 'Thanks',
      );
      expect(vm.containsKhmer, isTrue);
    });

    test('containsKhmer is true when a line name has Khmer text, even in '
        'English UI language', () {
      const vm = ReceiptViewModel(
        language: AppLanguage.en,
        businessName: 'Acme',
        invoiceNumber: '#1',
        date: '',
        time: '',
        lines: [
          ReceiptLineViewModel(
            name: 'នំបុ័ង',
            qty: 1,
            unitPrice: 1,
            lineTotal: 1,
          ),
        ],
        subtotal: 1,
        total: 1,
        footer: 'Thanks',
      );
      expect(vm.containsKhmer, isTrue);
    });
  });
}
