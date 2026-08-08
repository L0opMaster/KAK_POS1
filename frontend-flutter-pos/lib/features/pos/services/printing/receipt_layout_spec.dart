// Shared receipt design values — the single source of truth for what a
// receipt is supposed to LOOK like, independent of which renderer draws it.
//
// receipt_preview_screen.dart (on-screen Flutter widgets) and
// print_service.dart (pw widgets, PDF/driver transport) cannot literally
// share UI widgets — Flutter's widget system and package:pdf's are
// unrelated tree types — so instead they share this: the same named
// typography scale and the same spacing constants, both measured directly
// from the on-screen design (receipt_preview_screen.dart's `_Text`/
// `_Spacer` call sites), so the printed PDF can't silently drift back into
// a different-looking document again. mm80 values ARE the on-screen sizes;
// mm58 is a deliberately-chosen compact scale (~70%, never below 7pt —
// Khmer's stacked marks need more room than Latin at the same size, see
// khmer_pdf_font.dart), not a blind proportional shrink of the whole page.
import 'printer_profile.dart';

class ReceiptTypography {
  const ReceiptTypography({
    required this.businessTitle,
    required this.businessInfo,
    required this.metadataLabel,
    required this.metadataValue,
    required this.tableHeader,
    required this.itemName,
    required this.itemQty,
    required this.itemPrice,
    required this.itemNote,
    required this.summaryLabel,
    required this.summaryValue,
    required this.totalLabel,
    required this.totalValue,
    required this.footer,
    required this.footerSmall,
  });

  /// Business name — the largest, boldest text on the receipt.
  final double businessTitle;

  /// Address / phone lines under the business name.
  final double businessInfo;

  /// Left-column labels in the invoice-metadata block (Invoice No., Date,
  /// Time, Cashier).
  final double metadataLabel;

  /// Right-column values in the invoice-metadata block.
  final double metadataValue;

  /// The "Item / Qty / Total" column-header row above the line items.
  final double tableHeader;

  /// Line item product name.
  final double itemName;

  /// Line item quantity column.
  final double itemQty;

  /// Line item price/line-total column.
  final double itemPrice;

  /// Modifier summary / note line under an item (smallest item-level text).
  final double itemNote;

  /// Plain summary rows (Subtotal, Paid, Change) — label side.
  final double summaryLabel;

  /// Plain summary rows — value side (one step larger than [summaryLabel],
  /// matching the on-screen design's emphasis even on non-bold rows).
  final double summaryValue;

  /// The grand-Total row's label (bold).
  final double totalLabel;

  /// The grand-Total row's value — the single largest number on the
  /// receipt after the business title.
  final double totalValue;

  /// The "Thank you" footer line (bold).
  final double footer;

  /// Website / "Powered by" footer lines (smallest text on the receipt).
  final double footerSmall;

  static const mm80 = ReceiptTypography(
    businessTitle: 22,
    businessInfo: 8,
    metadataLabel: 8,
    metadataValue: 8,
    tableHeader: 8,
    itemName: 9,
    itemQty: 9,
    itemPrice: 9,
    itemNote: 7,
    summaryLabel: 9,
    summaryValue: 10,
    totalLabel: 10,
    totalValue: 16,
    footer: 12,
    footerSmall: 8,
  );

  static const mm58 = ReceiptTypography(
    businessTitle: 16,
    businessInfo: 7,
    metadataLabel: 7,
    metadataValue: 7,
    tableHeader: 7,
    itemName: 8,
    itemQty: 8,
    itemPrice: 8,
    itemNote: 7,
    summaryLabel: 8,
    summaryValue: 9,
    totalLabel: 9,
    totalValue: 13,
    footer: 10,
    footerSmall: 7,
  );
}

/// Vertical spacing constants, shared by every receipt section regardless
/// of paper width (spacing reads consistently across widths; only text
/// itself needs the 58/80mm split above).
class ReceiptSpacing {
  ReceiptSpacing._();

  /// Around a major section divider (header→metadata, metadata→items,
  /// items→totals, totals→payment).
  static const double sectionGap = 10;

  /// Small internal gaps within a section (title→address, subtotal→total).
  static const double smallGap = 4;

  /// Around the solid divider directly above/below the line-item table.
  static const double dividerGap = 8;

  /// Between individual line-item rows.
  static const double rowGap = 6;

  /// Before the footer block.
  static const double footerGap = 12;
}

extension PrinterPaperSizeReceiptTypography on PrinterPaperSize {
  ReceiptTypography get receiptTypography =>
      this == PrinterPaperSize.mm58 ? ReceiptTypography.mm58 : ReceiptTypography.mm80;
}
