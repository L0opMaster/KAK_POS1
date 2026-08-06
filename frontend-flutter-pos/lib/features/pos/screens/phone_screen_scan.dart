import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/scanner_relay_role.dart';
import '../../../core/utils/l10n_extensions.dart';

class PhoneScannerScreen extends StatefulWidget {
  const PhoneScannerScreen({super.key});

  @override
  State<PhoneScannerScreen> createState() => _PhoneScannerScreenState();
}

class _PhoneScannerScreenState extends State<PhoneScannerScreen> {
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
    final String serverUrl = _serverController.text.trim();
    final String sessionCode = _sessionController.text.trim().toUpperCase();

    if (!RegExp(r'^[A-Z2-9]{8}$').hasMatch(sessionCode)) {
      setState(() {
        _statusMessage = context.l10n.phoneScanScreenEnterCode;
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
          _statusMessage = context.l10n.phoneScanScreenConnectFailed;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    await _relay.disconnect();
    if (mounted) {
      setState(() {
        _statusMessage = context.l10n.phoneScanScreenDisconnected;
      });
    }
  }

  void _handleRelayMessage(ScannerRelayMessage message) {
    if (!mounted) {
      return;
    }

    setState(() {
      switch (message.type) {
        case 'ready':
          _statusMessage = context.l10n.phoneScanScreenConnectedReady;
          break;
        case 'barcode_ack':
          _lastBarcode = message.value;
          _statusMessage =
              context.l10n.phoneScanScreenBarcodeSent(message.value ?? '');
          break;
        case 'pos_disconnected':
          _statusMessage = context.l10n.phoneScanScreenPosEndedSession;
          break;
        case 'error':
          _statusMessage =
              message.message ?? context.l10n.phoneScanScreenRelayError;
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
      _statusMessage = context.l10n.phoneScanScreenDetectedSending(value!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool connected =
        _connectionState == ScannerRelayConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.phoneScanScreenTitle),
        actions: [
          if (connected)
            IconButton(
              tooltip: context.l10n.phoneScanScreenFlashlight,
              icon: const Icon(Icons.flashlight_on_outlined),
              onPressed: _cameraController.toggleTorch,
            ),
          if (connected)
            IconButton(
              tooltip: context.l10n.phoneScanScreenDisconnectTooltip,
              icon: const Icon(Icons.link_off),
              onPressed: _disconnect,
            ),
        ],
      ),
      body: connected ? _buildScanner() : _buildConnectionForm(),
    );
  }

  Widget _buildConnectionForm() {
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
            context.l10n.phoneScanScreenConnectHeadline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.phoneScanScreenConnectSubtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _serverController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.l10n.phoneScanScreenServerUrlLabel,
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
              labelText: context.l10n.phoneScanScreenSessionCodeLabel,
              hintText: context.l10n.phoneScanScreenSessionCodeHint,
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
            label: Text(
              connecting
                  ? context.l10n.phoneScanScreenConnecting
                  : context.l10n.phoneScanScreenConnectButton,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
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
                    _statusMessage ?? context.l10n.phoneScanScreenReadyToScan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (_lastBarcode != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.l10n
                          .phoneScanScreenLastBarcode(_lastBarcode!),
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
