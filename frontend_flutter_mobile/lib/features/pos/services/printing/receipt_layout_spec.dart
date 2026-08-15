import 'printer_profile.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// receipt_layout_spec.dart` — COPY/ADAPT NEARLY EXACTLY, full file. The
/// single source of truth for what a receipt is supposed to LOOK like,
/// shared by `receipt_paper_view.dart`'s on-screen `_Text` sizes (Day 12,
/// hand-matched) and `print_service.dart`'s PDF `pw.TextStyle` sizes (this
/// day), so the printed PDF can't silently drift into a different-looking
/// document. mm80 values ARE the on-screen sizes; mm58 is a deliberately
/// compact ~70% scale (never below 7pt), not a blind proportional shrink.
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

  final double businessTitle;
  final double businessInfo;
  final double metadataLabel;
  final double metadataValue;
  final double tableHeader;
  final double itemName;
  final double itemQty;
  final double itemPrice;
  final double itemNote;
  final double summaryLabel;
  final double summaryValue;
  final double totalLabel;
  final double totalValue;
  final double footer;
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
/// of paper width.
class ReceiptSpacing {
  ReceiptSpacing._();

  static const double sectionGap = 10;
  static const double smallGap = 4;
  static const double dividerGap = 8;
  static const double rowGap = 6;
  static const double footerGap = 12;
}

extension PrinterPaperSizeReceiptTypography on PrinterPaperSize {
  ReceiptTypography get receiptTypography => this == PrinterPaperSize.mm58
      ? ReceiptTypography.mm58
      : ReceiptTypography.mm80;
}
