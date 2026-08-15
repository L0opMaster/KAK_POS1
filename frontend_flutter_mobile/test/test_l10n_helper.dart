import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend_flutter_mobile/l10n/generated/app_localizations.dart';

/// Ported from `frontend-flutter-pos/test/test_l10n_helper.dart` — shared
/// localization config for widget tests. Any test that pumps a
/// screen/widget using `context.l10n` needs its `MaterialApp` to declare
/// these, or `AppLocalizations.of(context)` throws — there's no
/// `Localizations` ancestor otherwise.
const testLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const testSupportedLocales = <Locale>[Locale('en'), Locale('km')];
