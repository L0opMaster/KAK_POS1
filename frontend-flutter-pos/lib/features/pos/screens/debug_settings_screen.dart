import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/l10n_extensions.dart';

/// Lightweight debug/settings page that lets developers toggle feature flags.
/// Only visible in debug mode (`kDebugMode`).
class DebugSettingsScreen extends StatefulWidget {
  const DebugSettingsScreen({super.key});

  @override
  State<DebugSettingsScreen> createState() => _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends State<DebugSettingsScreen> {
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
        body: Center(child: Text(context.l10n.debugSettingsUnavailableMessage)),
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
