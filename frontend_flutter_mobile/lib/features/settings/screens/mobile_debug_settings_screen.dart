import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/l10n_extensions.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/screens/
/// debug_settings_screen.dart` — COPY/ADAPT NEARLY EXACTLY, full file:
/// same 2-flag in-memory mechanism (no persistence across app restarts,
/// matching source), same `kDebugMode`-only visibility gate.
class MobileDebugSettingsScreen extends StatefulWidget {
  const MobileDebugSettingsScreen({super.key});

  @override
  State<MobileDebugSettingsScreen> createState() =>
      _MobileDebugSettingsScreenState();
}

class _MobileDebugSettingsScreenState
    extends State<MobileDebugSettingsScreen> {
  late bool _useApiCart;
  late bool _syncHeldTickets;

  @override
  void initState() {
    super.initState();
    _useApiCart = AppConfig.useApiCartService;
    _syncHeldTickets = AppConfig.enableHeldTicketSync;
  }

  void _save() {
    setState(() {
      AppConfig.useApiCartService = _useApiCart;
      AppConfig.enableHeldTicketSync = _syncHeldTickets;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.debugSettingsUpdatedMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return Scaffold(
        body: Center(
          child: Text(context.l10n.debugSettingsUnavailableMessage),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.debugSettingsTitle)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(context.l10n.debugSettingsUseApiCartLabel),
            value: _useApiCart,
            onChanged: (v) => setState(() => _useApiCart = v),
          ),
          SwitchListTile(
            title: Text(context.l10n.debugSettingsHeldTicketSyncLabel),
            value: _syncHeldTickets,
            onChanged: (v) => setState(() => _syncHeldTickets = v),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _save,
              child: Text(context.l10n.commonApply),
            ),
          ),
        ],
      ),
    );
  }
}
