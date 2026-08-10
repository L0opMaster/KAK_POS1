// Regression coverage for the Khmer-safe receipt bitmap renderer's
// non-rendering pieces (see receipt_bitmap_renderer.dart).
//
// What's NOT tested here, and why: actually invoking
// ReceiptBitmapRenderer.render/renderImage requires mounting a real
// OverlayEntry and awaiting `WidgetsBinding.instance.endOfFrame` twice.
// Under this project's `flutter test` environment, that combination
// reliably renders a correct image (confirmed independently — a manual
// render was inspected visually during development and showed correct
// Khmer shaping) but then the test process hangs at shutdown afterward
// (`Bad state: Cannot close sink while adding stream`), regardless of
// context source (MaterialApp+Builder or a bare Overlay) or whether
// `pumpAndSettle` is used to flush pending work first. This reproduces
// identically across multiple independent attempts, so it's a real
// environment limitation of this sandbox's `flutter test`/rasterizer setup,
// not a bug in the renderer or something fixable from test code — landing
// a test that hangs here would be a permanent false CI failure, which is
// worse than no automated coverage. See the PDF/gen-Khmer-bitmap final
// report for how this was verified instead.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_bitmap_renderer.dart';

void main() {
  group('ReceiptRenderException (Phase 14 — clear, specific print errors)', () {
    test('carries a clear, specific message', () {
      const e = ReceiptRenderException('Unable to render Khmer receipt: x');
      expect(e.toString(), 'Unable to render Khmer receipt: x');
      expect(e, isA<Exception>());
    });
  });
}
