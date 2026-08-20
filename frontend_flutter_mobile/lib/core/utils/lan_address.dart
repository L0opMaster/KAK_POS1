import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Best-effort LAN-reachable version of [currentBaseUrl] for display/QR
/// purposes only.
///
/// `AppConfig.baseUrl` resolves to `http://localhost:8081` on desktop and
/// iOS-simulator builds (see app_config.dart) — correct for this app's own
/// HTTP/WebSocket calls to its local backend, but useless to a phone or
/// customer-display device on the same network, which can't resolve
/// "localhost" to this machine. This walks the host's own network
/// interfaces for a private IPv4 address and substitutes it into
/// [currentBaseUrl]'s scheme/port, e.g. `http://192.168.1.23:8081`.
///
/// Returns `null` when no such address can be found (web build, no LAN
/// connection, sandboxed environment, ...) — callers should fall back to
/// asking the user to type the address in manually rather than embedding a
/// loopback address in a QR code no other device could use.
Future<String?> detectLanServerUrl(String currentBaseUrl) async {
  if (kIsWeb) return null;

  final Uri? base = Uri.tryParse(currentBaseUrl);
  if (base == null) return null;

  try {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );

    for (final NetworkInterface interface in interfaces) {
      for (final InternetAddress address in interface.addresses) {
        if (_isPrivateIPv4(address.address)) {
          return base.replace(host: address.address).toString();
        }
      }
    }
  } catch (_) {
    // Best-effort only — fall through to null below.
  }

  return null;
}

/// Staff-configured override for the LAN address shown/embedded in Phone
/// Scanner and Customer Display pairing (Settings → Printers, "Pairing"
/// section) — for stores where [detectLanServerUrl]'s auto-detection picks
/// the wrong network interface (e.g. a VM/Ethernet adapter instead of the
/// Wi-Fi one the store's phones/tablets actually reach) or finds none at
/// all. Device-local (SharedPreferences) — same as the direct
/// thermal-printer transport config already on that screen, not synced to
/// the backend, since this is a per-terminal network fact, not store data.
class PairingServerOverride {
  PairingServerOverride._();

  static const String _key = 'pairing_server_override';

  /// The saved override, or `null` if unset/blank.
  static Future<String?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? value = prefs.getString(_key)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Saves [value] as the override, or clears it when null/blank.
  static Future<void> save(String? value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, trimmed);
    }
  }
}

/// [detectLanServerUrl], but checks the staff-configured
/// [PairingServerOverride] first. Every pairing call site (Phone Scanner
/// and Customer Display receiver buttons) should call this rather than
/// [detectLanServerUrl] directly, so a manual override always wins over
/// auto-detection instead of each call site needing its own check.
Future<String?> resolvePairingServerUrl(String currentBaseUrl) async {
  final String? override = await PairingServerOverride.load();
  if (override != null) return override;
  return detectLanServerUrl(currentBaseUrl);
}

/// RFC 1918 private ranges — the only addresses a phone/tablet on the same
/// store Wi-Fi/LAN would plausibly see this machine as.
bool _isPrivateIPv4(String ip) {
  if (ip.startsWith('10.') || ip.startsWith('192.168.')) return true;
  final RegExpMatch? match = RegExp(r'^172\.(\d{1,3})\.').firstMatch(ip);
  if (match == null) return false;
  final int? secondOctet = int.tryParse(match.group(1)!);
  return secondOctet != null && secondOctet >= 16 && secondOctet <= 31;
}
