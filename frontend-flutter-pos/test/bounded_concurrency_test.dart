// Regression coverage for "Print All" data selection: [mapBounded] is the
// primitive ReceiptsScreen._printAllReceipts uses to fetch full receipt
// detail for every filtered sale before printing, capped to a small number
// of simultaneous requests (Step 14 — never fire 64+ unrestricted requests
// at once). These tests exercise it directly: every item must be
// processed exactly once, in order, with the concurrency cap actually
// enforced, and per-item failures must not drop or duplicate other items.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/utils/bounded_concurrency.dart';

void main() {
  group('mapBounded — every item processed exactly once, in order', () {
    for (final total in [0, 1, 5, 64]) {
      test('$total items -> $total results, values 0..${total - 1}', () async {
        final results = await mapBounded<int, int>(
          List.generate(total, (i) => i),
          (i) async => i * 10,
          concurrency: 5,
        );

        expect(results.length, total);
        expect(results.every((r) => r.isOk), isTrue);
        expect(
            results.map((r) => r.item).toList(), List.generate(total, (i) => i),
            reason: 'must preserve input order');
        expect(results.map((r) => r.value).toList(),
            List.generate(total, (i) => i * 10));
      });
    }

    test(
        '64 receipt ids (e.g. sale ids 1..64) are all present in the '
        'output — the exact reported "Print All" scenario', () async {
      final ids = List.generate(64, (i) => i + 1); // 1..64
      final results = await mapBounded<int, String>(
        ids,
        (id) async => 'INV-${id.toString().padLeft(3, '0')}',
      );

      expect(results.length, 64);
      final labels = results.map((r) => r.value).toSet();
      expect(labels.contains('INV-001'), isTrue);
      expect(labels.contains('INV-064'), isTrue);
      expect(labels.length, 64, reason: 'no duplicates');
    });
  });

  group('mapBounded — concurrency cap is actually enforced', () {
    test('never more than [concurrency] calls in flight at once', () async {
      var inFlight = 0;
      var maxInFlight = 0;

      await mapBounded<int, void>(
        List.generate(20, (i) => i),
        (i) async {
          inFlight++;
          maxInFlight = maxInFlight < inFlight ? inFlight : maxInFlight;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          inFlight--;
        },
        concurrency: 4,
      );

      expect(maxInFlight, lessThanOrEqualTo(4));
      expect(maxInFlight, greaterThan(1),
          reason: 'sanity check that work actually overlapped at all');
    });

    test('concurrency higher than item count is clamped, not wasted', () async {
      final results = await mapBounded<int, int>(
        [1, 2, 3],
        (i) async => i,
        concurrency: 100,
      );
      expect(results.length, 3);
    });
  });

  group('mapBounded — per-item failures are isolated', () {
    test(
        'a failing item is captured as BoundedResult.failed without '
        'aborting or dropping the others', () async {
      final results = await mapBounded<int, int>(
        [1, 2, 3, 4, 5],
        (i) async {
          if (i == 3) throw Exception('boom for $i');
          return i * 100;
        },
      );

      expect(results.length, 5);
      final ok = results.where((r) => r.isOk).toList();
      final failed = results.where((r) => !r.isOk).toList();
      expect(ok.length, 4);
      expect(failed.length, 1);
      expect(failed.single.item, 3);
      expect(failed.single.error, isNotNull);
      expect(ok.map((r) => r.item).toSet(), {1, 2, 4, 5});
    });
  });

  group('mapBounded — cancellation stops picking up new work', () {
    test('isCancelled true from the start processes nothing new', () async {
      final results = await mapBounded<int, int>(
        List.generate(10, (i) => i),
        (i) async => i,
        isCancelled: () => true,
      );
      expect(results, isEmpty);
    });
  });
}
