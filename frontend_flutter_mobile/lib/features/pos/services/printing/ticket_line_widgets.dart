import 'package:flutter/widgets.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// ticket_line_widgets.dart` — COPY/ADAPT NEARLY EXACTLY, full file.
///
/// Small, self-contained widgets for rasterizing a single Khmer-containing
/// line/row on a lightweight, non-[ReceiptViewModel] ticket (queue-number
/// ticket — see `print_service.dart`'s `_buildWaitingNumberEscPos`). Native
/// ESC/POS text can't render Khmer glyphs at all, so a field containing
/// Khmer gets rendered through `ReceiptBitmapRenderer.renderWidget` one
/// line at a time instead of being silently dropped — everything else on
/// the ticket stays native text (faster, crisper), only the Khmer field(s)
/// pay the bitmap cost. Deliberately plain: no `Theme`/`Material` of their
/// own, since they always render inside `ReceiptBitmapRenderer`'s
/// off-screen `Material` ancestor, which already carries the app's Khmer
/// font fallback.
///
/// [TicketLabelValueRow] has no caller yet on mobile — `printCreditPaymentReceipt`
/// (the credit-repayment print stub this would serve, see desktop's
/// `print_service.dart`) hasn't been ported here. Kept anyway, ported
/// verbatim alongside [TicketCenteredText], so that port isn't blocked on
/// rebuilding this piece from scratch later.
///
/// [WaitingNumberTicketContent] IS used — `_buildWaitingNumberEscPos`
/// rasterizes the whole ticket as one bitmap when it contains Khmer,
/// mirroring desktop's identical redesign of the same method.

/// A single centered line of text — the waiting-number ticket's
/// business name/heading/instruction.
class TicketCenteredText extends StatelessWidget {
  const TicketCenteredText(
    this.text, {
    super.key,
    this.bold = false,
    this.fontSize = 13,
  });

  final String text;
  final bool bold;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      );
}

/// The full queue-number ticket — used by `_buildWaitingNumberEscPos` to
/// rasterize the *entire* ticket as one bitmap whenever any of
/// [businessName]/[heading]/[instruction] is Khmer, rather than one line at
/// a time. The number itself sits inside a bordered box — a small "ticket
/// stub" touch a bare centered number lacked — sized to always fit
/// [numberText] via `FittedBox`, so a wider stub (`#1234` on future days
/// with 4+ digit queues) never overflows a fixed-width box on paper.
/// Mirrors `_buildWaitingNumberPdf`'s layout so the printed thermal ticket
/// and PDF/driver ticket read the same regardless of which pipeline
/// produced them.
class WaitingNumberTicketContent extends StatelessWidget {
  const WaitingNumberTicketContent({
    super.key,
    this.businessName,
    this.heading,
    required this.numberText,
    this.instruction,
  });

  final String? businessName;
  final String? heading;
  final String numberText;
  final String? instruction;

  @override
  Widget build(BuildContext context) {
    final hasBusinessName = businessName != null && businessName!.isNotEmpty;
    final hasHeading = heading != null && heading!.isNotEmpty;
    final hasInstruction = instruction != null && instruction!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasBusinessName) ...[
          Text(
            businessName!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
        ],
        if (hasHeading) ...[
          Text(
            heading!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 10),
        ],
        // Stretched to the parent Column's full width (not wrapped in
        // `Center`, which would give this box loose/shrink-wrap
        // constraints) so `FittedBox` has a genuinely bounded width to
        // shrink into — a long `numberText` at a fixed font size could
        // otherwise silently clip instead of scaling down.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF222222), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              numberText,
              style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (hasInstruction) ...[
          const SizedBox(height: 10),
          Text(
            instruction!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
          ),
        ],
      ],
    );
  }
}

/// A label-left/value-right row — mirrors the credit payment stub's
/// `row()` ESC/POS helper (and its PDF equivalent) for the one row whose
/// value contains Khmer (e.g. `customerName`).
class TicketLabelValueRow extends StatelessWidget {
  const TicketLabelValueRow(
    this.label,
    this.value, {
    super.key,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        const SizedBox(width: 8),
        Flexible(
          child: Text(value, textAlign: TextAlign.right, style: style),
        ),
      ],
    );
  }
}
