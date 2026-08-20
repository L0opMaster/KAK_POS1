import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/main_color_provider.dart';
import '../../../core/utils/pairing_qr_data.dart';
import '../../../core/widgets/app_bar_actions.dart';
import '../providers/display_provider.dart';
import '../services/customer_display_relay.dart';
import 'display_screen.dart';
import 'pairing_qr_scan_screen.dart';

/// Staff-facing pairing form, shown on first launch and whenever the
/// customer-screen device isn't connected to a POS session. Mirrors the
/// layout/validation of the POS app's phone-scanner pairing form
/// (`phone_screen_scan.dart`) so the two "enter a server URL + 8-char code"
/// flows feel identical.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _sessionController = TextEditingController();
  String? _statusMessage;
  bool _loadingSavedValues = true;

  @override
  void initState() {
    super.initState();
    _loadSavedValues();
  }

  Future<void> _loadSavedValues() async {
    final String? savedServerUrl = await AppConfig.loadServerUrl();
    final String? savedSessionCode = await AppConfig.loadSessionCode();
    if (!mounted) return;
    setState(() {
      if (savedServerUrl != null) {
        _serverController.text = savedServerUrl;
      }
      if (savedSessionCode != null) {
        _sessionController.text = savedSessionCode;
      }
      _loadingSavedValues = false;
    });
  }

  @override
  void dispose() {
    _serverController.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  Future<void> _scanQrToConnect() async {
    final PairingQrData? data = await Navigator.of(context).push<PairingQrData>(
      MaterialPageRoute<PairingQrData>(
        builder: (_) => const PairingQrScanScreen(
          expectedType: PairingQrType.customerDisplay,
        ),
      ),
    );
    if (data == null || !mounted) {
      return;
    }

    _serverController.text = data.server;
    _sessionController.text = data.sessionCode;
    await _connect();
  }

  Future<void> _connect() async {
    final AppStrings strings = AppStrings(ref.read(appLanguageProvider));
    final String serverUrl = _serverController.text.trim();
    final String sessionCode = _sessionController.text.trim().toUpperCase();

    if (serverUrl.isEmpty) {
      setState(() => _statusMessage = strings.enterServerAddress);
      return;
    }

    if (!RegExp(r'^[A-Z2-9]{8}$').hasMatch(sessionCode)) {
      setState(() => _statusMessage = strings.enterPairingCode);
      return;
    }

    setState(() => _statusMessage = null);

    try {
      final bool connected = await ref.read(displayProvider.notifier).connect(
            serverUrl: serverUrl,
            sessionCode: sessionCode,
          );
      if (!mounted) return;
      if (connected) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const DisplayScreen()),
        );
      } else {
        setState(() => _statusMessage = strings.connectFailed);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _statusMessage = strings.connectFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DisplayState displayState = ref.watch(displayProvider);
    final bool connecting =
        displayState.connectionState == CustomerDisplayConnectionState.connecting;
    final AppStrings strings = AppStrings(ref.watch(appLanguageProvider));

    if (_loadingSavedValues) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ref.watch(mainColorProvider),
        foregroundColor: Colors.white,
        title: Text(strings.connectTitle),
        actions: buildAppBarActions(context: context, ref: ref),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.tv, size: 72, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  strings.connectTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.connectSubtitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: connecting ? null : _scanQrToConnect,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(strings.scanQrCode),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        strings.orDivider,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _serverController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: strings.serverAddressLabel,
                    hintText: 'http://192.168.1.10:8081',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _sessionController,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  maxLength: 8,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z2-9]')),
                  ],
                  decoration: InputDecoration(
                    labelText: strings.pairingCodeLabel,
                    hintText: 'e.g. AB23CD45',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                if (displayState.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    displayState.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: connecting ? null : _connect,
                  icon: connecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(connecting ? strings.connecting : strings.connect),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
