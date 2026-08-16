import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';

/// Ported from the Payment Methods card in `frontend-flutter-pos/lib/
/// features/pos/screens/settings_modules_screen.dart` — COPY/ADAPT NEARLY
/// EXACTLY: no separate save button, each row's `Switch` is optimistic —
/// flips local state immediately, calls `updatePaymentMethodStatus`, and
/// reverts + shows an error if the call fails. Per-code icon/color
/// dropped (MOBILE UI REIMPLEMENT) — a plain list with a leading
/// monogram is enough at phone width; the name/code/active data is
/// unchanged.
class MobilePaymentMethodsScreen extends ConsumerStatefulWidget {
  const MobilePaymentMethodsScreen({super.key});

  @override
  ConsumerState<MobilePaymentMethodsScreen> createState() =>
      _MobilePaymentMethodsScreenState();
}

class _MobilePaymentMethodsScreenState
    extends ConsumerState<MobilePaymentMethodsScreen> {
  List<Map<String, dynamic>> _methods = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final methods = await ref
          .read(settingsServiceProvider)
          .getPaymentMethods();
      if (mounted) setState(() => _methods = methods);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(int index, bool active) async {
    final l10n = context.l10n;
    final previous = List<Map<String, dynamic>>.from(_methods);
    setState(() => _methods[index] = {..._methods[index], 'active': active});
    try {
      await ref
          .read(settingsServiceProvider)
          .updatePaymentMethodStatus(_methods[index]['id'], active);
    } catch (e) {
      if (mounted) {
        setState(() => _methods = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorGeneric}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsPaymentMethods),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_error'),
                  const SizedBox(height: PosTheme.spacingSm),
                  OutlinedButton(
                    onPressed: _load,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              itemCount: _methods.length,
              itemBuilder: (context, i) {
                final m = _methods[i];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      PosTheme.radiusMedium,
                    ),
                    side: BorderSide(color: PosTheme.borderColorOf(context)),
                  ),
                  child: SwitchListTile(
                    title: Text('${m['name'] ?? ''}'),
                    subtitle: Text('${m['code'] ?? ''}'),
                    value: m['active'] as bool? ?? false,
                    onChanged: (v) => _toggle(i, v),
                  ),
                );
              },
            ),
    );
  }
}
