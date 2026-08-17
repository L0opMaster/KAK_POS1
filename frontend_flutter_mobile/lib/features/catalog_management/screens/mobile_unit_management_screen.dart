import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/unit_models.dart';
import '../../pos/providers/unit_provider.dart';
import 'mobile_create_unit_screen.dart';

/// Unit Management — list/add/edit units of measure (kg, g, box, pcs, ...).
///
/// Ported from `frontend-flutter-pos/lib/features/pos/screens/
/// unit_management_screen.dart` — same business logic/API calls (list,
/// create, update, and a dedicated active-status toggle — units have no
/// delete). The desktop screen's `Card`+`ListTile` list, search box, and
/// FAB are functionally mirrored here but the layout follows this mobile
/// app's established list+form convention (see `mobile_suppliers_screen.
/// dart`) rather than the desktop widget tree: client-side live search
/// against the already-fetched list, `AsyncValue.when`, `RefreshIndicator`,
/// and a plain (non-extended) FAB.
class MobileUnitManagementScreen extends ConsumerStatefulWidget {
  const MobileUnitManagementScreen({super.key});

  @override
  ConsumerState<MobileUnitManagementScreen> createState() =>
      _MobileUnitManagementScreenState();
}

class _MobileUnitManagementScreenState
    extends ConsumerState<MobileUnitManagementScreen> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(unitProvider.notifier).loadUnits());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MobileCreateUnitScreen()),
    );
    if (created == true) {
      ref.read(unitProvider.notifier).loadUnits();
    }
  }

  Future<void> _openEdit(Unit unit, List<Unit> allUnits) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MobileCreateUnitScreen(
          initialUnit: unit,
          allUnits: allUnits,
        ),
      ),
    );
    if (updated == true) {
      ref.read(unitProvider.notifier).loadUnits();
    }
  }

  Future<void> _toggleActive(Unit unit) async {
    try {
      await ref.read(unitProvider.notifier).toggleActive(unit.id, !unit.active);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${context.l10n.unitManagementUpdateFailedPrefix}: ${e is ApiException ? e.message : e}'),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(unitProvider);
    final query = _searchCtl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.posDrawerUnits)),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: l10n.unitManagementAddButton,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PosTheme.spacingMd),
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.commonSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
                suffixIcon: _searchCtl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtl.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: PosTheme.errorRed, size: 40),
                    const SizedBox(height: PosTheme.spacingMd),
                    Text('$e'),
                    const SizedBox(height: PosTheme.spacingMd),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(unitProvider.notifier).loadUnits(),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
              data: (units) {
                final visible = query.isEmpty
                    ? units
                    : units
                        .where((u) =>
                            u.nameEn.toLowerCase().contains(query) ||
                            u.nameKm.toLowerCase().contains(query) ||
                            u.code.toLowerCase().contains(query) ||
                            u.symbol.toLowerCase().contains(query))
                        .toList();

                if (visible.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.straighten_rounded,
                            size: 48, color: PosTheme.textHintOf(context)),
                        const SizedBox(height: PosTheme.spacingMd),
                        Text(
                          l10n.unitManagementEmptyTitle,
                          style: const TextStyle(
                              color: PosTheme.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: PosTheme.spacingXs),
                        Text(
                          l10n.unitManagementEmptyHint,
                          style: TextStyle(
                              color: PosTheme.textHintOf(context),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(unitProvider.notifier).loadUnits(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PosTheme.spacingMd,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final unit = visible[index];
                      return Card(
                        elevation: 0,
                        margin:
                            const EdgeInsets.only(bottom: PosTheme.spacingSm),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(PosTheme.radiusMedium),
                          side: BorderSide(
                            color: unit.active
                                ? PosTheme.borderColorOf(context)
                                : PosTheme.dividerColorOf(context),
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _openEdit(unit, units),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color:
                                  PosTheme.primaryGreen.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(PosTheme.radiusMedium),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unit.symbol.isEmpty ? '?' : unit.symbol,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: PosTheme.primaryGreen,
                              ),
                            ),
                          ),
                          title: Text(
                            '${unit.nameEn} (${unit.code})',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: unit.active
                                  ? PosTheme.textPrimaryOf(context)
                                  : PosTheme.textHintOf(context),
                            ),
                          ),
                          subtitle: Text(
                            unit.baseUnit
                                ? l10n.unitManagementBaseUnitLabel
                                : '1 ${unit.symbol} = ${unit.conversionFactor} ${unit.baseUnitCode ?? unit.baseUnitGroup}',
                            style: TextStyle(
                              fontSize: PosTheme.fontSizeXs,
                              color: unit.active
                                  ? PosTheme.textSecondaryOf(context)
                                  : PosTheme.textHintOf(context),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!unit.active)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PosTheme.textHintOf(context)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                        PosTheme.radiusPill),
                                  ),
                                  child: Text(
                                    l10n.commonInactive,
                                    style: const TextStyle(
                                        fontSize: PosTheme.fontSizeXs),
                                  ),
                                ),
                              Switch(
                                value: unit.active,
                                activeThumbColor: PosTheme.primaryGreen,
                                onChanged: (_) => _toggleActive(unit),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
