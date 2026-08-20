import '../providers/language_provider.dart';

/// Hand-rolled English/Khmer string lookup for this app's handful of
/// user-facing strings. Deliberately not ARB/flutter_localizations-based —
/// see `pairing_qr_scan_screen.dart`'s doc comment on why this app skips
/// that infrastructure.
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  String _t(String en, String km) => language.isKhmer ? km : en;

  // ── App bar actions ──
  String get languageTooltip => _t('Language', 'ភាសា');
  String get colorTooltip => _t('Theme Color', 'ពណ៌រូបរាង');
  String get disconnectTooltip => _t('Disconnect', 'ផ្តាច់ការតភ្ជាប់');
  String get chooseColorTitle => _t('Choose a color', 'ជ្រើសរើសពណ៌');

  // ── Phone scanner screen ──
  String get scannerTitle => _t('Phone 1D Scanner', 'ម៉ាស៊ីនស្កេនកូដទូរស័ព្ទ');
  String get flashlightTooltip => _t('Flashlight', 'ពិល');
  String get connectPrompt => _t(
        'Connect this phone to the active POS',
        'ភ្ជាប់ទូរស័ព្ទនេះទៅកាន់ម៉ាស៊ីនគិតលុយដែលកំពុងដំណើរការ',
      );
  String get connectHint => _t(
        'The phone and POS must use the same Wi-Fi and backend server.',
        'ទូរស័ព្ទ និងម៉ាស៊ីនគិតលុយត្រូវប្រើវ៉ាយហ្វាយ និងម៉ាស៊ីនមេដូចគ្នា។',
      );
  String get scanQrCode => _t('Scan QR Code', 'ស្កេនកូដ QR');
  String get orDivider => _t('OR', 'ឬ');
  String get serverUrlLabel => _t('POS server URL', 'អាសយដ្ឋាន URL ម៉ាស៊ីនមេ');
  String get sessionCodeLabel => _t('POS session code', 'លេខកូដសម័យរបស់ម៉ាស៊ីនគិតលុយ');
  String get connect => _t('Connect', 'ភ្ជាប់');
  String get connectToPos => _t('Connect to POS', 'ភ្ជាប់ទៅកាន់ម៉ាស៊ីនគិតលុយ');
  String get connecting => _t('Connecting...', 'កំពុងភ្ជាប់...');
  String get enterSessionCode => _t(
        'Enter the 8-character code shown on the POS',
        'សូមបញ្ចូលលេខកូដ ៨ តួដែលបង្ហាញនៅលើម៉ាស៊ីនគិតលុយ',
      );
  String get connectFailed => _t(
        'Could not connect. Check the server URL, Wi-Fi and code.',
        'មិនអាចភ្ជាប់បានទេ។ សូមពិនិត្យអាសយដ្ឋានម៉ាស៊ីនមេ វ៉ាយហ្វាយ និងលេខកូដ។',
      );
  String get readyToScan => _t('Ready to scan', 'ត្រៀមខ្លួនស្រាប់ដើម្បីស្កេន');
  String get lastBarcodePrefix => _t('Last barcode: ', 'កូដចុងក្រោយ៖ ');
  String get disconnectedStatus => _t('Disconnected', 'បានផ្តាច់ការតភ្ជាប់');
  String get posEndedSession =>
      _t('The POS ended this scanner session', 'ម៉ាស៊ីនគិតលុយបានបញ្ចប់សម័យស្កេននេះ');
  String get scannerRelayError => _t('Scanner relay error', 'កំហុសក្នុងការភ្ជាប់ម៉ាស៊ីនស្កេន');
}
