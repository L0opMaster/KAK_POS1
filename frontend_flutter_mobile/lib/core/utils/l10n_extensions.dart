import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

/// Ergonomic shorthand for `AppLocalizations.of(context)!` — use as
/// `context.l10n.commonSave` from any widget build method.
///
/// Ported from `frontend-flutter-pos/lib/core/utils/l10n_extensions.dart`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
