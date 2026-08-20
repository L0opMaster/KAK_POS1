// Coverage for the "🟡 BILL PRINTED" badge tracking on held_tickets_dialog
// .dart's ticket cards. Purely a local UI hint (see the provider's doc
// comment) persisted to SharedPreferences, not the backend — these tests
// lock in mark/clear/persist behavior and, importantly, that marking a
// ticket printed never implies it's paid (that's a separate axis entirely,
// covered by receipt_bill_status_test.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/providers/bill_print_status_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a fresh ticket id is not marked printed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(billPrintStatusProvider.notifier).isPrinted(1024),
        isFalse);
  });

  test('markPrinted adds the ticket id to state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(billPrintStatusProvider.notifier).markPrinted(1024);
    expect(container.read(billPrintStatusProvider), contains(1024));
    expect(
        container.read(billPrintStatusProvider.notifier).isPrinted(1024), isTrue);
  });

  test('clear removes the ticket id — e.g. once paid or cancelled', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(billPrintStatusProvider.notifier).markPrinted(1024);
    await container.read(billPrintStatusProvider.notifier).clear(1024);
    expect(container.read(billPrintStatusProvider), isNot(contains(1024)));
  });

  test('marked ids persist across a fresh provider instance (SharedPreferences)',
      () async {
    final container1 = ProviderContainer();
    await container1.read(billPrintStatusProvider.notifier).markPrinted(1024);
    container1.dispose();

    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    // The notifier loads its persisted state asynchronously in its
    // constructor — read once to trigger creation, then let that load
    // complete.
    container2.read(billPrintStatusProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container2.read(billPrintStatusProvider), contains(1024));
  });

  test('marking one ticket does not affect another', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(billPrintStatusProvider.notifier).markPrinted(1024);
    expect(container.read(billPrintStatusProvider.notifier).isPrinted(2048),
        isFalse);
  });
}
