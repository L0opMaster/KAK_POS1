import 'package:flutter/widgets.dart';

/// Small, self-contained widgets for rasterizing a single Khmer-containing
/// line/row on a lightweight, non-[ReceiptViewModel] ticket (queue-number
/// ticket, credit payment stub — see `print_service.dart`'s
/// `_buildWaitingNumberEscPos`/`_buildCreditPaymentEscPos`). Native ESC/POS
/// text can't render Khmer glyphs at all, so a field containing Khmer gets
/// rendered through [ReceiptBitmapRenderer.renderWidget] one line at a time
/// instead of being silently dropped — everything else on the ticket stays
/// native text (faster, crisper), only the Khmer field(s) pay the bitmap
/// cost. Deliberately plain: no `Theme`/`Material` of their own, since they
/// always render inside [ReceiptBitmapRenderer]'s off-screen `Material`
/// ancestor, which already carries the app's Khmer font fallback.

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

/// The full queue-number ticket — used by `_buildWaitingNumberEscPos` to
/// rasterize the *entire* ticket as one bitmap whenever any of
/// [businessName]/[heading]/[instruction] is Khmer, rather than one line at
/// a time (same reasoning as [CreditPaymentReceiptContent]'s doc comment).
/// The number itself sits inside a bordered box — a small "ticket stub"
/// touch a bare centered number lacked — sized to always fit [numberText]
/// via `FittedBox`, so a wider stub (`#1234` on future days with 4+ digit
/// queues) never overflows a fixed-width box on paper. Mirrors
/// `_buildWaitingNumberPdf`'s layout so the printed thermal ticket and
/// PDF/driver ticket read the same regardless of which pipeline produced
/// them.
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

/// The full credit-payment stub, composed from [TicketLabelValueRow]s — used
/// by `_buildCreditPaymentEscPos` to rasterize the *entire* ticket as one
/// bitmap whenever any of its content is Khmer, rather than one row at a
/// time. Once the receipt's own labels are localized (see
/// `print_service.dart`'s `_CreditPaymentLabels`), a Khmer-language cashier
/// sees Khmer labels on nearly every row, not just occasional Khmer values
/// — rasterizing row-by-row in that case would mean a bitmap render for
/// almost the whole ticket anyway, so one combined render is both simpler
/// and faster than many small ones. Mirrors `_buildCreditPaymentPdf`'s
/// layout so the printed thermal ticket and PDF/driver ticket read the same
/// regardless of which pipeline produced them.
class CreditPaymentReceiptContent extends StatelessWidget {
  const CreditPaymentReceiptContent({
    super.key,
    required this.title,
    required this.creditSaleLabel,
    required this.creditSaleNumber,
    required this.customerLabel,
    required this.customerName,
    this.cashierLabel,
    this.cashierName,
    required this.previousBalanceLabel,
    required this.previousBalanceValue,
    required this.paymentLabel,
    required this.paymentValue,
    required this.remainingLabel,
    required this.remainingValue,
    this.dueDateLabel,
    this.dueDateValue,
    required this.methodFieldLabel,
    required this.methodValue,
  });

  final String title;
  final String creditSaleLabel;
  final String creditSaleNumber;
  final String customerLabel;
  final String customerName;
  final String? cashierLabel;
  final String? cashierName;
  final String previousBalanceLabel;
  final String previousBalanceValue;
  final String paymentLabel;
  final String paymentValue;
  final String remainingLabel;
  final String remainingValue;
  final String? dueDateLabel;
  final String? dueDateValue;
  final String methodFieldLabel;
  final String methodValue;

  @override
  Widget build(BuildContext context) {
    final hasCashier = cashierName != null && cashierName!.isNotEmpty;
    final hasDueDate = dueDateValue != null && dueDateValue!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TicketLabelValueRow(creditSaleLabel, creditSaleNumber),
        TicketLabelValueRow(customerLabel, customerName),
        if (hasCashier) TicketLabelValueRow(cashierLabel!, cashierName!),
        const SizedBox(height: 4),
        // Plain `Container`, not a Material `Divider` — this file only
        // imports `flutter/widgets.dart` (see doc comment: no Theme/Material
        // dependency, since it always renders inside
        // [ReceiptBitmapRenderer]'s own off-screen `Material` ancestor).
        Container(height: 0.75, color: const Color(0xFFE0E0E0)),
        const SizedBox(height: 4),
        TicketLabelValueRow(previousBalanceLabel, previousBalanceValue),
        TicketLabelValueRow(paymentLabel, paymentValue, bold: true),
        TicketLabelValueRow(remainingLabel, remainingValue, bold: true),
        if (hasDueDate) TicketLabelValueRow(dueDateLabel!, dueDateValue!),
        TicketLabelValueRow(methodFieldLabel, methodValue),
      ],
    );
  }
}
