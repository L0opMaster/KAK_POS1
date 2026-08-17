import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/modifier_models.dart';
import '../../pos/providers/modifier_provider.dart';
import '../../pos/providers/product_provider.dart';
import 'mobile_create_modifier_screen.dart';
import 'mobile_modifier_product_assignment_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/screens/
/// modifier_management.dart` — the BUSINESS LOGIC (search-by-name/option,
/// multi-select + bulk delete, tap-row-to-edit, trailing "apply to
/// products" action, refresh-after-save) is COPY/ADAPT NEARLY EXACTLY.
/// Desktop's `DataTable`-with-pagination is MOBILE UI REIMPLEMENT: a
/// single scrolling checkbox list (matching
/// `mobile_suppliers_screen.dart`'s convention) instead of a fixed-size
/// paged table, since a phone screen has no room for page-size math or a
/// wide toolbar row.
class MobileModifierManagementScreen extends ConsumerStatefulWidget {
  const MobileModifierManagementScreen({super.key});

  @override
  ConsumerState<MobileModifierManagementScreen> createState() =>
      _MobileModifierManagementScreenState();
}

class _MobileModifierManagementScreenState
    extends ConsumerState<MobileModifierManagementScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(modifierProvider.notifier).loadGroups());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const MobileCreateModifierScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await ref.read(modifierProvider.notifier).loadGroups();
    }
  }

  Future<void> _openEdit(ModifierGroupResponse group) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MobileCreateModifierScreen(initialModifier: group),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await ref.read(modifierProvider.notifier).loadGroups();
    }
  }

  Future<void> _openAssignProducts(ModifierGroupResponse group) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MobileModifierProductAssignmentScreen(group: group),
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      await ref.read(modifierProvider.notifier).loadGroups();
      await ref.read(productsProvider.notifier).refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.modifierManagementProductsUpdated(
              group.localizedName(ref.read(appLanguageProvider)),
            ),
          ),
        ),
      );
    }
  }

  void _toggle(int groupId, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(groupId);
      } else {
        _selected.remove(groupId);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final l10n = context.l10n;
    final count = _selected.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.modifierManagementDeleteDialogTitle),
          content: Text(
            l10n.modifierManagementDeleteDialogMessage('$count'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: PosTheme.errorRed),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final ids = [..._selected];

    try {
      for (final id in ids) {
        await ref.read(modifierProvider.notifier).deleteModifier(id);
      }

      if (!mounted) return;

      setState(() => _selected.clear());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.modifierManagementDeleteSuccess('${ids.length}'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      final error = ref.read(modifierProvider).error ??
          l10n.modifierManagementDeleteFailedDefault;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(modifierProvider);
    final lang = ref.watch(appLanguageProvider);
    final query = _searchCtl.text.trim().toLowerCase();

    final visible = query.isEmpty
        ? state.groups
        : state.groups.where((group) {
            final nameMatches = group.nameEn.toLowerCase().contains(query) ||
                group.nameKm.toLowerCase().contains(query);

            final optionMatches = group.options.any(
              (option) =>
                  option.nameEn.toLowerCase().contains(query) ||
                  option.nameKm.toLowerCase().contains(query),
            );

            return nameMatches || optionMatches;
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selected.isEmpty
              ? l10n.modifierManagementTitle
              : l10n.modifierManagementSelectedCount('${_selected.length}'),
        ),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: l10n.modifierManagementDeleteSelectedTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: l10n.modifierManagementAddModifier,
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
                hintText: l10n.modifierManagementSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (state.isLoading && state.groups.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.error != null && state.groups.isEmpty) {
                  return _buildErrorState(state.error!);
                }

                if (state.groups.isEmpty) {
                  return _buildEmptyState();
                }

                if (visible.isEmpty) {
                  return Center(
                    child: Text(l10n.modifierManagementNoModifiersFound),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(modifierProvider.notifier).loadGroups(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PosTheme.spacingMd,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      return _buildModifierCard(visible[i], lang);
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

  Widget _buildModifierCard(ModifierGroupResponse group, AppLanguage lang) {
    final l10n = context.l10n;
    final selected = _selected.contains(group.id);

    final optionNames = group.options.isEmpty
        ? l10n.modifierManagementNoOptions
        : group.options.map((option) => option.localizedName(lang)).join(', ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(
          color: selected ? PosTheme.primaryGreen : PosTheme.borderColorOf(context),
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: selected,
          onChanged: (v) => _toggle(group.id, v ?? false),
        ),
        title: Text(
          group.localizedName(lang),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          optionNames,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: PosTheme.fontSizeXs,
            color: PosTheme.textSecondaryOf(context),
          ),
        ),
        trailing: IconButton(
          tooltip: l10n.modifierManagementApplyToProductsTooltip,
          icon: const Icon(Icons.inventory_2_outlined),
          onPressed: () => _openAssignProducts(group),
        ),
        onTap: () => _openEdit(group),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PosTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: PosTheme.dividerColorOf(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 44,
                color: PosTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: PosTheme.spacingLg),
            Text(
              l10n.modifierManagementEmptyTitle,
              style: const TextStyle(
                fontSize: PosTheme.fontSizeXl,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PosTheme.spacingSm),
            Text(
              l10n.modifierManagementEmptyDescription,
              textAlign: TextAlign.center,
              style: TextStyle(color: PosTheme.textSecondaryOf(context)),
            ),
            const SizedBox(height: PosTheme.spacingLg),
            FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.modifierManagementAddModifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PosTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: PosTheme.errorRed),
            const SizedBox(height: PosTheme.spacingMd),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: PosTheme.spacingLg),
            FilledButton(
              onPressed: () => ref.read(modifierProvider.notifier).loadGroups(),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
