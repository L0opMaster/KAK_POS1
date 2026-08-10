// Regression coverage for KhmerTextRasterizer — the shared helper that
// renders a single run of text via Flutter's TextPainter (real shaping)
// and returns either a plain `pw.Text` (English/numeric — fast, vector) or
// a `pw.Image` (Khmer/mixed — Flutter-shaped bitmap), for embedding inside
// package:pdf documents (A4 reports; see a4_report_pdf.dart).
//
// Unlike ReceiptBitmapRenderer, this needs no BuildContext/Overlay/frame
// pump — TextPainter lays out and paints directly onto a canvas — so these
// tests run as plain `test()`s (well, `testWidgets` only because font
// loading needs `WidgetsFlutterBinding`), no pump-loop tricks required.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/printing/khmer_text_rasterizer.dart';
import 'package:frontend_flutter_pos/core/utils/khmer_text.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(KhmerTextRasterizer.debugClearCache);

  group('containsKhmerText', () {
    test('English -> false', () {
      expect(containsKhmerText('Sales Summary Report'), isFalse);
      expect(containsKhmerText('26,650'), isFalse);
    });

    test('Khmer -> true', () {
      expect(containsKhmerText('របាយការណ៍សង្ខេបការលក់'), isTrue);
    });

    test('mixed -> true', () {
      expect(containsKhmerText('Total សរុប'), isTrue);
      expect(containsKhmerText('Product ទឹកក្រឡុក'), isTrue);
    });
  });

  group('KhmerTextRasterizer.textOrImage dispatch', () {
    testWidgets('English text -> plain pw.Text (fast, vector path)',
        (tester) async {
      final widget = await tester.runAsync(() =>
          KhmerTextRasterizer.textOrImage('Sales Summary Report',
              fontSize: 15, bold: true));
      expect(widget, isA<pw.Text>());
    });

    testWidgets('Khmer text -> pw.Image (Flutter-shaped bitmap)',
        (tester) async {
      final widget = await tester.runAsync(() =>
          KhmerTextRasterizer.textOrImage('របាយការណ៍សង្ខេបការលក់',
              fontSize: 15, bold: true));
      expect(widget, isA<pw.Image>());
    });

    testWidgets('mixed English/Khmer text -> pw.Image, rendered as one run',
        (tester) async {
      final widget = await tester.runAsync(() =>
          KhmerTextRasterizer.textOrImage('Total សរុប 26,650 ៛', fontSize: 11));
      expect(widget, isA<pw.Image>());
    });

    testWidgets('numeric-only text -> plain pw.Text', (tester) async {
      final widget = await tester.runAsync(
          () => KhmerTextRasterizer.textOrImage('92.00', fontSize: 9));
      expect(widget, isA<pw.Text>());
    });
  });

  group('KhmerTextRasterizer bold vs regular (Phase 9)', () {
    testWidgets(
        'regular and bold Khmer both rasterize to a valid image '
        'with positive dimensions', (tester) async {
      final regular = await tester.runAsync(() =>
              KhmerTextRasterizer.textOrImage('កាលបរិច្ឆេទ', fontSize: 12))
          as pw.Image;
      final bold = await tester.runAsync(() => KhmerTextRasterizer.textOrImage(
          'កាលបរិច្ឆេទ',
          fontSize: 12,
          bold: true)) as pw.Image;

      expect(regular.width, greaterThan(0));
      expect(regular.height, greaterThan(0));
      expect(bold.width, greaterThan(0));
      expect(bold.height, greaterThan(0));
    });
  });

  group('KhmerTextRasterizer caching (Phase 11)', () {
    testWidgets(
        'identical (text, fontSize, bold, color) reuses the same rasterized '
        'image — not re-rendered on every call', (tester) async {
      final first = await tester.runAsync(() =>
              KhmerTextRasterizer.textOrImage('សរុប', fontSize: 9, bold: true))
          as pw.Image;
      final second = await tester.runAsync(() =>
              KhmerTextRasterizer.textOrImage('សរុប', fontSize: 9, bold: true))
          as pw.Image;

      // Each call constructs a fresh pw.Image wrapper (package:pdf widgets
      // carry layout state and can't be reused verbatim across positions —
      // e.g. a header repeated on every page), but the expensive underlying
      // rasterized bytes must be the exact same cached object.
      expect(identical(first.image, second.image), isTrue);
    });

    testWidgets(
        'a different fontSize is NOT served from the same cache '
        'entry', (tester) async {
      final small = await tester.runAsync(
              () => KhmerTextRasterizer.textOrImage('សរុប', fontSize: 9))
          as pw.Image;
      final large = await tester.runAsync(
              () => KhmerTextRasterizer.textOrImage('សរុប', fontSize: 20))
          as pw.Image;

      expect(identical(small.image, large.image), isFalse);
      expect(large.width, greaterThan(small.width!));
    });
  });

  group('KhmerTextRenderException (Phase 14)', () {
    test('carries a clear, specific message', () {
      const e = KhmerTextRenderException('Unable to render Khmer text: x');
      expect(e.toString(), 'Unable to render Khmer text: x');
      expect(e, isA<Exception>());
    });
  });
}
