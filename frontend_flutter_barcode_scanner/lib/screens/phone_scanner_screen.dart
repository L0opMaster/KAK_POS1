import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/l10n/app_strings.dart';
import '../core/providers/language_provider.dart';
import '../core/providers/main_color_provider.dart';
import '../core/widgets/app_bar_actions.dart';
import '../models/pairing_qr_data.dart';
import '../services/scanner_relay_role.dart';
import 'pairing_qr_scan_screen.dart';

class PhoneScannerScreen extends ConsumerStatefulWidget {
  const PhoneScannerScreen({super.key});

  @override
  ConsumerState<PhoneScannerScreen> createState() => _PhoneScannerScreenState();
}

class _PhoneScannerScreenState extends ConsumerState<PhoneScannerScreen> {
  final TextEditingController _serverController = TextEditingController(
    text: 'http://192.168.1.101:8081',
  );
  final TextEditingController _sessionController = TextEditingController();
  final ScannerRelayClient _relay = ScannerRelayClient();

  late final MobileScannerController _cameraController;
  StreamSubscription<ScannerRelayMessage>? _messageSubscription;
  StreamSubscription<ScannerRelayConnectionState>? _stateSubscription;

  ScannerRelayConnectionState _connectionState =
      ScannerRelayConnectionState.disconnected;
  String? _statusMessage;
  String? _lastBarcode;
  String? _lastDetectedValue;
  DateTime? _lastDetectedAt;

  @override
  void initState() {
    super.initState();

    _cameraController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 700,
      autoZoom: true,
      formats: const <BarcodeFormat>[
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.itf,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );

    _messageSubscription = _relay.messages.listen(_handleRelayMessage);
    _stateSubscription = _relay.connectionStates.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });
  }

  @override
  void dispose() {
    _serverController.dispose();
    _sessionController.dispose();
    unawaited(_messageSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    unawaited(_cameraController.dispose());
    unawaited(_relay.dispose());
    super.dispose();
  }

  Future<void> _connect() async {
    final AppStrings strings = AppStrings(ref.read(appLanguageProvider));
    final String serverUrl = _serverController.text.trim();
    final String sessionCode = _sessionController.text.trim().toUpperCase();

    if (!RegExp(r'^[A-Z2-9]{8}$').hasMatch(sessionCode)) {
      setState(() {
        _statusMessage = strings.enterSessionCode;
      });
      return;
    }

    setState(() {
      _statusMessage = null;
    });

    try {
      await _relay.connect(
        serverBaseUrl: serverUrl,
        sessionCode: sessionCode,
        role: ScannerRelayRole.scanner,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = strings.connectFailed;
        });
      }
    }
  }

  Future<void> _scanQrToConnect() async {
    final PairingQrData? data = await Navigator.of(context).push<PairingQrData>(
      MaterialPageRoute<PairingQrData>(
        builder: (_) =>
            const PairingQrScanScreen(expectedType: PairingQrType.phoneScanner),
      ),
    );
    if (data == null || !mounted) {
      return;
    }

    _serverController.text = data.server;
    _sessionController.text = data.sessionCode;
    await _connect();
  }

  Future<void> _disconnect() async {
    final AppStrings strings = AppStrings(ref.read(appLanguageProvider));
    await _relay.disconnect();
    if (mounted) {
      setState(() {
        _statusMessage = strings.disconnectedStatus;
      });
    }
  }

  void _handleRelayMessage(ScannerRelayMessage message) {
    if (!mounted) {
      return;
    }

    final AppStrings strings = AppStrings(ref.read(appLanguageProvider));
    setState(() {
      switch (message.type) {
        case 'ready':
          _statusMessage = strings.readyToScan;
          break;
        case 'barcode_ack':
          _lastBarcode = message.value;
          _statusMessage = '${strings.lastBarcodePrefix}${message.value ?? ''}';
          break;
        case 'pos_disconnected':
          _statusMessage = strings.posEndedSession;
          break;
        case 'error':
          _statusMessage = message.message ?? strings.scannerRelayError;
          break;
      }
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_connectionState != ScannerRelayConnectionState.connected) {
      return;
    }

    String? value;
    for (final Barcode barcode in capture.barcodes) {
      final String candidate = barcode.rawValue?.trim() ?? '';
      if (candidate.isNotEmpty) {
        value = candidate;
        break;
      }
    }

    if (value == null) {
      return;
    }

    final DateTime now = DateTime.now();
    if (_lastDetectedValue == value &&
        _lastDetectedAt != null &&
        now.difference(_lastDetectedAt!) < const Duration(milliseconds: 1200)) {
      return;
    }

    _lastDetectedValue = value;
    _lastDetectedAt = now;

    _relay.sendBarcode(value);
    HapticFeedback.mediumImpact();

    setState(() {
      _lastBarcode = value;
      _statusMessage = '$value detected — sending to POS';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool connected =
        _connectionState == ScannerRelayConnectionState.connected;
    final AppStrings strings = AppStrings(ref.watch(appLanguageProvider));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ref.watch(mainColorProvider),
        foregroundColor: Colors.white,
        title: Text(strings.scannerTitle),
        actions: [
          if (connected)
            IconButton(
              tooltip: strings.flashlightTooltip,
              icon: const Icon(Icons.flashlight_on_outlined),
              onPressed: _cameraController.toggleTorch,
            ),
          ...buildAppBarActions(
            context: context,
            ref: ref,
            onDisconnect: connected ? _disconnect : null,
          ),
        ],
      ),
      body: connected ? _buildScanner(strings) : _buildConnectionForm(strings),
    );
  }

  Widget _buildConnectionForm(AppStrings strings) {
    final bool connecting =
        _connectionState == ScannerRelayConnectionState.connecting;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.phone_android,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            strings.connectPrompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.connectHint,
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
              labelText: strings.serverUrlLabel,
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
              FilteringTextInputFormatter.allow(
                RegExp(r'[A-Za-z2-9]'),
              ),
            ],
            decoration: InputDecoration(
              labelText: strings.sessionCodeLabel,
              hintText: 'Example: 7KMX4P2R',
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
            label: Text(connecting ? strings.connecting : strings.connectToPos),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner(AppStrings strings) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _cameraController,
          onDetect: _onDetect,
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: MediaQuery.sizeOf(context).width * 0.82,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Card(
            color: Colors.black87,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusMessage ?? strings.readyToScan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (_lastBarcode != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${strings.lastBarcodePrefix}$_lastBarcode',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
