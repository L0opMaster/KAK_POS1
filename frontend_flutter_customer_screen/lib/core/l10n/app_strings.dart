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

  // ── Connect screen ──
  String get connectTitle => _t('Connect to Register', 'ភ្ជាប់ទៅកាន់ម៉ាស៊ីនគិតលុយ');
  String get connectSubtitle => _t(
        'Enter this store\'s server address and the pairing code '
            'shown on the register\'s Customer Display button.',
        'បញ្ចូលអាសយដ្ឋានម៉ាស៊ីនមេនៃហាងនេះ និងលេខកូដភ្ជាប់'
            'ដែលបង្ហាញនៅលើប៊ូតុងអេក្រង់អតិថិជននៃម៉ាស៊ីនគិតលុយ។',
      );
  String get scanQrCode => _t('Scan QR Code', 'ស្កេនកូដ QR');
  String get orDivider => _t('OR', 'ឬ');
  String get serverAddressLabel => _t('Server address', 'អាសយដ្ឋានម៉ាស៊ីនមេ');
  String get pairingCodeLabel => _t('Pairing code', 'លេខកូដភ្ជាប់');
  String get connect => _t('Connect', 'ភ្ជាប់');
  String get connecting => _t('Connecting...', 'កំពុងភ្ជាប់...');
  String get enterServerAddress =>
      _t('Enter the store server address', 'សូមបញ្ចូលអាសយដ្ឋានម៉ាស៊ីនមេរបស់ហាង');
  String get enterPairingCode => _t(
        'Enter the 8-character code shown on the register',
        'សូមបញ្ចូលលេខកូដ ៨ តួដែលបង្ហាញនៅលើម៉ាស៊ីនគិតលុយ',
      );
  String get connectFailed => _t(
        'Could not connect — check the address and code',
        'មិនអាចភ្ជាប់បានទេ — សូមពិនិត្យអាសយដ្ឋាន និងលេខកូដ',
      );

  // ── Display screen ──
  String get displayTitle => _t('Customer Display', 'អេក្រង់អតិថិជន');
  String get waitingForRegister =>
      _t('Waiting for the register to connect...', 'កំពុងរង់ចាំម៉ាស៊ីនគិតលុយភ្ជាប់...');
}
