import 'package:flutter/material.dart';

/// Loyverse-inspired design tokens for the POS system.
///
/// Based on the clean, minimalist aesthetic of [loyverse.com]:
/// - Primary green (#4CAF50) as the brand color
/// - Clean white backgrounds with subtle grey dividers
/// - Card-based UI with soft shadows
/// - Clean sans-serif typography
class PosTheme {
  PosTheme._();

  // ── Brand Colors (Loyverse-inspired) ────────────────────────────
  // `primaryGreen`/`primaryGreenDark`/`primaryGreenLight` are the ONE
  // configurable "main app color" (Settings > Main Color). They're
  // getters (not `const`) specifically so every existing call site
  // across the app — ~150 of them, buttons/tabs/chips/AppBar/etc. —
  // picks up a newly-selected color automatically with zero per-call-site
  // changes, the moment applyMainColor() runs. The actual state owner
  // (persistence + the Riverpod provider UI reads/writes) is
  // core/providers/main_color_provider.dart; this class only holds the
  // current *resolved* Color for widgets to read synchronously. Defaults
  // to the original brand green so nothing shifts for existing users
  // before their saved preference loads.
  static Color _mainColor = const Color(0xFF4CAF50);

  static Color get primaryGreen => _mainColor;
  static Color get primaryGreenDark => _shade(_mainColor, -0.11);
  static Color get primaryGreenLight => _shade(_mainColor, 0.35);

  /// Called from main.dart on every build with the current
  /// mainColorProvider value, right before MaterialApp's theme is built —
  /// see that provider for where the value actually comes from/persists.
  static void applyMainColor(Color color) {
    _mainColor = color;
  }

  /// Lightens ([amount] > 0) or darkens ([amount] < 0) [color] by shifting
  /// HSL lightness — derives a dark/light variant of whichever main color
  /// is currently selected, instead of needing a hand-picked shade
  /// constant per color option.
  static Color _shade(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  static const Color accentBlue = Color(0xFF2196F3);
  static const Color accentBlueLight = Color(0xFFE3F2FD);

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  static const Color backgroundPage = Color(0xFFF5F5F5);
  static const Color backgroundCard = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0xFFE0E0E0);
  static const Color borderColor = Color(0xFFEEEEEE);

  static const Color errorRed = Color(0xFFE53935);
  static const Color warningAmber = Color(0xFFFFA000);
  static const Color successGreen = Color(0xFF43A047);

  // ── Theme-aware colors ──────────────────────────────────────────
  // The constants above are fixed to the light palette — every widget
  // that reads them directly ignores dark mode entirely. These `xOf`
  // variants pick the right shade for the current Theme.of(context)
  // brightness, reusing the same dark palette as [darkTheme] below so
  // the two stay visually consistent. New/updated screens should use
  // these; the old constants remain for screens not yet migrated.
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color backgroundPageOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF121212) : backgroundPage;

  static Color backgroundCardOf(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E1E1E) : backgroundCard;

  static Color textPrimaryOf(BuildContext context) =>
      _isDark(context) ? Colors.white : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade300 : textSecondary;

  static Color textHintOf(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade500 : textHint;

  static Color dividerColorOf(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade800 : dividerColor;

  static Color borderColorOf(BuildContext context) =>
      _isDark(context) ? Colors.grey.shade700 : borderColor;

  // ── Shadows ──────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // ── Border Radius ────────────────────────────────────────────────
  static const double radiusSmall = 6.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusPill = 24.0;

  // ── Spacing ──────────────────────────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // ── Font Sizes ───────────────────────────────────────────────────
  static const double fontSizeXs = 11.0;
  static const double fontSizeSm = 13.0;
  static const double fontSizeMd = 15.0;
  static const double fontSizeLg = 18.0;
  static const double fontSizeXl = 22.0;
  static const double fontSizeXxl = 28.0;

  // ── Theme Data ───────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: accentBlue,
      surface: backgroundCard,
      error: errorRed,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundPage,

      // Khmer script falls back to this bundled font wherever the default
      // font lacks the glyphs (see requirements: no tofu boxes, no restart
      // needed) — Latin text keeps its existing look untouched.
      fontFamilyFallback: const ['NotoSansKhmer'],

      // AppBar — branded green header, consistent in light and dark mode
      // (see darkTheme below) rather than switching to a neutral surface
      // color, so the app keeps one clear brand identity either way.
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: borderColor, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: fontSizeMd,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textSecondary,
          side: const BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentBlue,
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundPage,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: primaryGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingMd,
        ),
        hintStyle: const TextStyle(color: textHint, fontSize: fontSizeSm),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 0.5,
        space: 0,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: backgroundPage,
        selectedColor: primaryGreenLight,
        labelStyle: const TextStyle(fontSize: fontSizeSm),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingSm,
          vertical: spacingXs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
    );
  }

  // ── Dark Theme ───────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: accentBlue,
      brightness: Brightness.dark,
      error: errorRed,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      fontFamilyFallback: const ['NotoSansKhmer'],
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: Colors.grey.shade800, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: fontSizeMd,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade300,
          side: BorderSide(color: Colors.grey.shade700),
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLg,
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentBlueLight,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: primaryGreen, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingMd,
        ),
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: fontSizeSm),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 0.5,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2C2C2C),
        selectedColor: primaryGreenDark,
        labelStyle:
            TextStyle(color: Colors.grey.shade300, fontSize: fontSizeSm),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingSm,
          vertical: spacingXs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
    );
  }
}
