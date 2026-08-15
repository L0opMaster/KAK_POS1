import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/l10n/generated/app_localizations.dart';

void main() {
  group('AppLocalizations', () {
    test('English ARB resolves and matches expected strings', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.appName, 'KAKNNEA');
      expect(l10n.commonSave, 'Save');
      expect(l10n.settingsMainColor, 'Main Color');
      expect(l10n.settingsLanguage, 'App language');
    });

    test('Khmer ARB resolves and matches expected strings (no fallback to '
        'English)', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('km'));
      expect(l10n.appName, 'គណនា');
      expect(l10n.commonSave, 'រក្សាទុក');
      expect(l10n.settingsMainColor, 'ពណ៌សំខាន់');
    });

    test('both supported locales are resolvable via isSupported', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('km')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('fr')), isFalse);
    });
  });
}
