import 'package:flutter/foundation.dart';

/// Lightweight, debug-only timing instrumentation for the Khmer-safe
/// printing pipeline (`[PrintPerf] stage=Nms` log lines) — added to find
/// and verify fixes for real bottlenecks instead of guessing at them.
/// Zero-cost in release builds (the stopwatch never starts); cheap enough
/// to leave in permanently for future profiling, matching this codebase's
/// existing `[ReportPrint]` kDebugMode-only log convention.
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
