import 'package:flutter/foundation.dart';

/// Ported from `frontend-flutter-pos/lib/core/utils/print_perf.dart` —
/// COPY/ADAPT NEARLY EXACTLY. Lightweight, debug-only timing
/// instrumentation for the printing pipeline (`[PrintPerf] stage=Nms` log
/// lines). Zero-cost in release builds (the stopwatch never starts).
Future<T> timePrintStage<T>(String stage, Future<T> Function() action) async {
  if (!kDebugMode) return action();
  final sw = Stopwatch()..start();
  try {
    return await action();
  } finally {
    debugPrint('[PrintPerf] $stage=${sw.elapsedMilliseconds}ms');
  }
}

T timePrintStageSync<T>(String stage, T Function() action) {
  if (!kDebugMode) return action();
  final sw = Stopwatch()..start();
  try {
    return action();
  } finally {
    debugPrint('[PrintPerf] $stage=${sw.elapsedMilliseconds}ms');
  }
}
