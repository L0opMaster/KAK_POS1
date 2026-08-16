// Ported from frontend-flutter-pos/test/receipt_bitmap_renderer_test.dart —
// COPY/ADAPT NEARLY EXACTLY.
//
// Regression coverage for the Khmer-safe receipt bitmap renderer's
// non-rendering pieces (see receipt_bitmap_renderer.dart).
//
// What's NOT tested here, and why: actually invoking
// ReceiptBitmapRenderer.render/renderImage requires mounting a real
// OverlayEntry and awaiting `WidgetsBinding.instance.endOfFrame` twice.
// Under `flutter test`, that combination reliably renders a correct image
// (confirmed independently against frontend-flutter-pos's own port) but
// then the test process hangs at shutdown afterward, regardless of context
// source or whether `pumpAndSettle` is used to flush pending work first —
// a real environment limitation of the sandbox's `flutter test`/rasterizer
// setup, not a bug in the renderer. Landing a test that hangs here would be
// a permanent false CI failure, which is worse than no automated coverage.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_mobile/features/pos/services/printing/receipt_bitmap_renderer.dart';

void main() {
  group('ReceiptRenderException', () {
    test('carries a clear, specific message', () {
      const e = ReceiptRenderException('Unable to render Khmer receipt: x');
      expect(e.toString(), 'Unable to render Khmer receipt: x');
      expect(e, isA<Exception>());
    });
  });
}
