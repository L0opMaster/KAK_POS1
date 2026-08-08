/// The outcome of running [fn] on one item in [mapBounded] — either [value]
/// is set (success) or [error] is set (the call threw), never both.
class BoundedResult<T, R> {
  const BoundedResult.ok(this.item, this.value) : error = null;
  const BoundedResult.failed(this.item, this.error) : value = null;

  final T item;
  final R? value;
  final Object? error;

  bool get isOk => error == null;
}

/// Runs [fn] once per item in [items], with at most [concurrency] calls in
/// flight at any time, returning one [BoundedResult] per item in the same
/// order as [items] (unless [isCancelled] stops the run early, in which
/// case only the items already started are present).
///
/// Used for "fetch full detail for every filtered receipt before printing"
/// (see [ReceiptsScreen._printAllReceipts]) — a plain `Future.wait` over
/// every item at once would fire an unbounded burst of requests for a
/// large batch (e.g. 64+ receipts); this caps how many are in flight.
Future<List<BoundedResult<T, R>>> mapBounded<T, R>(
  List<T> items,
  Future<R> Function(T item) fn, {
  int concurrency = 5,
  bool Function()? isCancelled,
  void Function(int done, int total)? onProgress,
}) async {
  if (items.isEmpty) return const [];
  final results = List<BoundedResult<T, R>?>.filled(items.length, null);
  var nextIndex = 0;
  var done = 0;

  Future<void> worker() async {
    while (isCancelled?.call() != true) {
      final i = nextIndex;
      if (i >= items.length) return;
      nextIndex++;
      try {
        final value = await fn(items[i]);
        results[i] = BoundedResult.ok(items[i], value);
      } catch (e) {
        results[i] = BoundedResult.failed(items[i], e);
      }
      done++;
      onProgress?.call(done, items.length);
    }
  }

  final workerCount = concurrency.clamp(1, items.length);
  await Future.wait(List.generate(workerCount, (_) => worker()));
  return results.whereType<BoundedResult<T, R>>().toList();
}
