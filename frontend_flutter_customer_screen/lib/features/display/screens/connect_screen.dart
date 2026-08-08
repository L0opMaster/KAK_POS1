import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../providers/display_provider.dart';
import '../services/customer_display_relay.dart';
import 'display_screen.dart';

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

  Future<void> _connect() async {
    final String serverUrl = _serverController.text.trim();
    final String sessionCode = _sessionController.text.trim().toUpperCase();

    if (serverUrl.isEmpty) {
      setState(() => _statusMessage = 'Enter the store server address');
      return;
    }

    if (!RegExp(r'^[A-Z2-9]{8}$').hasMatch(sessionCode)) {
      setState(() => _statusMessage = 'Enter the 8-character code shown on the register');
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
        setState(() => _statusMessage = 'Could not connect — check the address and code');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _statusMessage = 'Could not connect — check the address and code');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DisplayState displayState = ref.watch(displayProvider);
    final bool connecting =
        displayState.connectionState == CustomerDisplayConnectionState.connecting;

    if (_loadingSavedValues) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
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
                const Text(
                  'Connect to Register',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter this store\'s server address and the pairing code '
                  'shown on the register\'s Customer Display button.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _serverController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Server address',
                    hintText: 'http://192.168.1.10:8081',
                    border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: 'Pairing code',
                    hintText: 'e.g. AB23CD45',
                    border: OutlineInputBorder(),
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
                  label: Text(connecting ? 'Connecting...' : 'Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
