import 'dart:convert';

/// What a [PairingQrData] payload is for. Encoded on the wire as a short
/// string (`wireValue`) rather than the Dart enum name, so the QR content
/// stays plain portable JSON — readable by any scanner, not just this app.
enum PairingQrType {
  phoneScanner('phone_scanner'),
  customerDisplay('customer_display');

  const PairingQrType(this.wireValue);

  final String wireValue;

  static PairingQrType? fromWireValue(String? value) {
    for (final PairingQrType type in PairingQrType.values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}

/// Pairing payload embedded in the QR code shown by the POS's Phone
/// Scanner dialog (`frontend-flutter-pos`/`frontend_flutter_mobile`'s
/// `PhoneScannerReceiverButton`) and read back here after a scan.
///
/// Mirrors `frontend-flutter-pos/lib/core/utils/pairing_qr_data.dart` —
/// same shape, kept in sync by hand since this project has no shared
/// package with the POS apps. Deliberately carries nothing beyond what the
/// existing manual-entry fields above already ask for (server address +
/// session code) — no tokens, no credentials.
class PairingQrData {
  const PairingQrData({
    required this.type,
    required this.server,
    required this.sessionCode,
  });

  final PairingQrType type;
  final String server;
  final String sessionCode;

  static final RegExp _sessionCodePattern = RegExp(r'^[A-Za-z2-9]{8}$');

  /// Encodes this payload as plain JSON text — normal portable data, not a
  /// Flutter-specific serialization, so any QR-capable device can read it.
  String encode() => jsonEncode(<String, String>{
        'type': type.wireValue,
        'server': server,
        'code': sessionCode,
      });

  /// Parses raw QR text into a [PairingQrData]. Returns `null` for anything
  /// that isn't well-formed JSON, is missing a required field, has an
  /// unrecognized `type`, or fails [validate].
  static PairingQrData? decode(String raw) {
    try {
      final Object? json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;

      final PairingQrType? type =
          PairingQrType.fromWireValue(json['type'] as String?);
      final String? server = json['server'] as String?;
      final String? code = json['code'] as String?;
      if (type == null || server == null || code == null) return null;

      final PairingQrData data =
          PairingQrData(type: type, server: server, sessionCode: code);
      return data.validate() ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// True when [server] parses as a URL with a host and [sessionCode]
  /// matches the same 8-character alphabet the POS's session generator and
  /// this screen's manual entry field already enforce.
  bool validate() {
    if (!_sessionCodePattern.hasMatch(sessionCode.trim())) return false;
    final Uri? uri = Uri.tryParse(server.trim());
    return uri != null && uri.host.isNotEmpty;
  }
}
