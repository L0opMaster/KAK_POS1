import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend_flutter_pos/l10n/generated/app_localizations.dart';

/// Shared localization config for widget tests. Any test that pumps a
/// screen/widget using `context.l10n` (see `core/utils/l10n_extensions.dart`)
/// needs its `MaterialApp` to declare these, or `AppLocalizations.of(context)`
/// null-checks and throws — there's no `Localizations` ancestor otherwise.
const testLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const testSupportedLocales = <Locale>[Locale('en'), Locale('km')];
