import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/utils/bounded_concurrency.dart';

void main() {
  group('mapBounded', () {
    test('never runs more than `concurrency` calls at once', () async {
      var current = 0;
      var maxObserved = 0;

      Future<int> fn(int item) async {
        current++;
        maxObserved = current > maxObserved ? current : maxObserved;
        // Yield so other workers get a chance to start while this one is
        // "in flight" — without this, a single-threaded event loop could
        // never actually overlap two calls even if the cap were broken.
        await Future.delayed(const Duration(milliseconds: 10));
        current--;
        return item * 2;
      }

      final items = List.generate(20, (i) => i);
      await mapBounded<int, int>(items, fn, concurrency: 3);

      expect(maxObserved, lessThanOrEqualTo(3));
      expect(maxObserved, greaterThan(1)); // actually overlapped, not serial
    });

    test('preserves input order in results regardless of completion order', () async {
      // Item 0 finishes last, item 4 finishes first — completion order is
      // the reverse of input order, but results must still come back in
      // input order.
      Future<int> fn(int item) async {
        await Future.delayed(Duration(milliseconds: (5 - item) * 10));
        return item;
      }

      final items = [0, 1, 2, 3, 4];
      final results = await mapBounded<int, int>(items, fn, concurrency: 5);

      expect(results.map((r) => r.item).toList(), [0, 1, 2, 3, 4]);
      expect(results.map((r) => r.value).toList(), [0, 1, 2, 3, 4]);
    });

    test('one item throwing does not stop the others — mixed results carry '
        'both isOk and !isOk entries correlated to their item', () async {
      Future<int> fn(int item) async {
        if (item == 2) throw StateError('boom for $item');
        return item * 10;
      }

      final items = [0, 1, 2, 3];
      final results = await mapBounded<int, int>(items, fn, concurrency: 2);

      expect(results, hasLength(4));

      final failed = results.where((r) => !r.isOk).toList();
      expect(failed, hasLength(1));
      expect(failed.single.item, 2);
      expect(failed.single.value, isNull);
      expect(failed.single.error, isA<StateError>());

      final ok = results.where((r) => r.isOk).toList();
      expect(ok, hasLength(3));
      for (final r in ok) {
        expect(r.value, r.item * 10);
      }
    });

    test('empty input returns an empty list without calling fn', () async {
      var called = false;
      final results = await mapBounded<int, int>(
        [],
        (item) async {
          called = true;
          return item;
        },
      );
      expect(results, isEmpty);
      expect(called, isFalse);
    });
  });
}
