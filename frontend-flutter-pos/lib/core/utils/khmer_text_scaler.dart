import 'package:flutter/widgets.dart';

/// Khmer script tends to read visually smaller than Latin text at the same
/// nominal font size, so Khmer-locale UI text is bumped up by a small flat
/// amount — NOT a multiplicative scale (`TextScaler.linear(1.x)` would
/// over-inflate large headings and under-inflate small labels relative to
/// each other). This only ever wraps app UI (see main.dart, where it's
/// applied via `MaterialApp.builder`) — it has no connection to and cannot
/// affect receipt/PDF/thermal print typography, which renders through an
/// entirely separate `package:pdf` widget system with its own literal font
/// sizes (see receipt_layout_spec.dart, a4_report_pdf.dart).
class KhmerTextScaler extends TextScaler {
  const KhmerTextScaler(this._base);

  /// The scaler already in effect before this wrapper — normally
  /// `MediaQuery.of(context).textScaler`, i.e. the platform/OS accessibility
  /// text-size preference. Applying the Khmer offset on top of (not instead
  /// of) that means a user's system text-size setting is still respected.
  final TextScaler _base;

  @override
  double scale(double fontSize) {
    final scaled = _base.scale(fontSize);
    // Leave very large display/heading text alone by default (e.g. cart
    // totals, hero numbers) — bumping those risks layout overflow for
    // comparatively little readability benefit, and the product
    // requirement explicitly calls for inspecting before changing them.
    if (scaled >= 28) return scaled;
    if (scaled >= 20) return scaled + 3;
    return scaled + 2;
  }

  @override
  double get textScaleFactor => _base.textScaleFactor;

  @override
  bool operator ==(Object other) =>
      other is KhmerTextScaler && other._base == _base;

  @override
  int get hashCode => Object.hash(KhmerTextScaler, _base);
}

/// Wraps [base] with the Khmer offset when [isKhmer] is true, otherwise
/// returns [base] unchanged (English typography stays exactly as-is).
TextScaler khmerAwareTextScaler(TextScaler base, {required bool isKhmer}) =>
    isKhmer ? KhmerTextScaler(base) : base;
