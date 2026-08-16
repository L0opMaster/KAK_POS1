import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';
import 'mobile_create_supplier_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// suppliers_screen.dart` — logic COPY/ADAPT NEARLY EXACTLY: same
/// client-side name/contact search, same multi-select delete flow
/// (confirm dialog, then `deleteSupplier(id)` called sequentially per
/// selected id — not batched — matching source; any "can't delete a
/// supplier with open POs" rejection surfaces from the backend via the
/// catch block, there's no client-side check for it in either project).
/// Desktop's paged `DataTable` becomes a plain scrolling list (MOBILE UI
/// REIMPLEMENT). Tapping a row opens edit (source: row tap); the FAB opens
/// create.
class MobileSuppliersScreen extends ConsumerStatefulWidget {
  const MobileSuppliersScreen({super.key});

  @override
  ConsumerState<MobileSuppliersScreen> createState() =>
      _MobileSuppliersScreenState();
}

class _MobileSuppliersScreenState extends ConsumerState<MobileSuppliersScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(suppliersProvider.notifier).loadSuppliers());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MobileCreateSupplierScreen()),
    );
    if (created == true) {
      ref.read(suppliersProvider.notifier).loadSuppliers();
    }
  }

  Future<void> _openEdit(Supplier supplier) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MobileCreateSupplierScreen(initialSupplier: supplier),
      ),
    );
    if (updated == true) {
      ref.read(suppliersProvider.notifier).loadSuppliers();
    }
  }

  Future<void> _deleteSelected() async {
    final l10n = context.l10n;
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.suppliersDeleteTitle),
        content: Text(l10n.suppliersDeleteConfirm('$count')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PosTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ids = [..._selected];
    try {
      for (final id in ids) {
        await ref.read(suppliersProvider.notifier).deleteSupplier(id);
      }
      setState(() => _selected.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.suppliersDeleteSuccess('${ids.length}'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.suppliersDeleteFailed('$e')),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(suppliersProvider);
    final query = _searchCtl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selected.isEmpty
              ? l10n.suppliersTitle
              : l10n.suppliersSelectedCount('${_selected.length}'),
        ),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: l10n.suppliersDeleteSelectedTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: l10n.suppliersAddButton,
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
                hintText: l10n.suppliersSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (suppliers) {
                final visible = query.isEmpty
                    ? suppliers
                    : suppliers
                          .where(
                            (s) =>
                                s.name.toLowerCase().contains(query) ||
                                (s.contactPerson ?? '').toLowerCase().contains(
                                  query,
                                ),
                          )
                          .toList();
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      query.isEmpty
                          ? l10n.suppliersNoSuppliersFound
                          : l10n.suppliersNoMatchingSuppliersFound,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(suppliersProvider.notifier).loadSuppliers(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PosTheme.spacingMd,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final s = visible[i];
                      final selected = s.id != null && _selected.contains(s.id);
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(
                          bottom: PosTheme.spacingSm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PosTheme.radiusMedium,
                          ),
                          side: BorderSide(
                            color: selected
                                ? PosTheme.primaryGreen
                                : PosTheme.borderColorOf(context),
                          ),
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: selected,
                            onChanged: s.id == null
                                ? null
                                : (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(s.id!);
                                    } else {
                                      _selected.remove(s.id!);
                                    }
                                  }),
                          ),
                          title: Text(s.name),
                          subtitle: Text(
                            s.contactPerson?.isNotEmpty == true
                                ? s.contactPerson!
                                : l10n.suppliersNoContactSet,
                            style: TextStyle(
                              fontSize: PosTheme.fontSizeXs,
                              color: PosTheme.textSecondaryOf(context),
                            ),
                          ),
                          trailing: !s.active
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PosTheme.textHintOf(
                                      context,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                      PosTheme.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    l10n.commonInactive,
                                    style: const TextStyle(
                                      fontSize: PosTheme.fontSizeXs,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () => _openEdit(s),
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
