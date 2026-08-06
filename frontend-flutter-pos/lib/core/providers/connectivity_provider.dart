import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// ONLINE: live device network-status stream (wifi/mobile/none), sourced
/// from the `connectivity_plus` plugin.
///
/// NOTE: this is currently not consumed anywhere in the app — no widget or
/// service `ref.watch`/`ref.read`s it. The actual online/offline SWITCH
/// POINTS used today are the static config flags in
/// core/config/app_config.dart (enableHeldTicketSync, useApiCartService,
/// useApiTableService), which pick between an Api***Service (online) and a
/// Local***Service (offline, SharedPreferences) at Provider-creation time
/// rather than reacting to this stream. Wire this provider in if/when the
/// app needs to react to real connectivity changes (e.g. auto-fall back to
/// offline mode when the network drops).
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged;
});
