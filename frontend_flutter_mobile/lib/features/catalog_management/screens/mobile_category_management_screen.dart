import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/category_provider.dart';
import 'mobile_create_category_screen.dart';

/// Mobile-friendly Category Management screen.
///
/// Ported functionality from `frontend-flutter-pos/lib/features/pos/
/// screens/category_management_screen.dart` — same data flow (flat list,
/// no pagination/search — category counts are small), same inline
/// active/inactive `Switch` that fires a full PUT via
/// `CategoryNotifier.updateCategory`, same tap-row-to-edit / FAB-to-create
/// flow. There is no delete anywhere (source's `CategoryService` has no
/// delete method), so unlike `MobileSuppliersScreen` there's no selection
/// mode or bulk-delete UI here.
///
/// UI itself is a fresh mobile build (MOBILE UI REIMPLEMENT): a single
/// scrolling `ListView` of touch-sized rows instead of desktop's `Card`
/// grid, using `PosTheme`'s dark-mode-aware `*Of(context)` tokens.
class MobileCategoryManagementScreen extends ConsumerStatefulWidget {
  const MobileCategoryManagementScreen({super.key});

  @override
  ConsumerState<MobileCategoryManagementScreen> createState() =>
      _MobileCategoryManagementScreenState();
}

class _MobileCategoryManagementScreenState
    extends ConsumerState<MobileCategoryManagementScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(categoriesProvider.notifier).loadCategories(),
    );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MobileCreateCategoryScreen()),
    );
    if (created == true) {
      ref.read(categoriesProvider.notifier).loadCategories();
    }
  }

  Future<void> _openEdit(Category category) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            MobileCreateCategoryScreen(initialCategory: category),
      ),
    );
    if (updated == true) {
      ref.read(categoriesProvider.notifier).loadCategories();
    }
  }

  Future<void> _toggleActive(Category category) async {
    final l10n = context.l10n;
    try {
      await ref.read(categoriesProvider.notifier).updateCategory(
        category.id,
        {
          'nameEn': category.nameEn,
          'nameKm': category.nameKm,
          'active': !category.active,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.categoryManagementUpdateFailedPrefix}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  /// Deterministic client-side color per category — mirrors source's
  /// `id.abs() % 10` palette lookup exactly. Purely cosmetic: never part of
  /// the API payload, the backend has no color field for categories.
  Color _categoryColor(int id) {
    const colors = [
      Color(0xFF42A5F5),
      Color(0xFFFFA726),
      Color(0xFF66BB6A),
      Color(0xFFAB47BC),
      Color(0xFFEF5350),
      Color(0xFF26C6DA),
      Color(0xFFEC407A),
      Color(0xFFFF7043),
      Color(0xFF8D6E63),
      Color(0xFF78909C),
    ];
    return colors[id.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navCategories),
        actions: [
          IconButton(
            tooltip: l10n.commonRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(categoriesProvider.notifier).loadCategories(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: l10n.categoryManagementAddButton,
        child: const Icon(Icons.add),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(PosTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    color: PosTheme.errorRed, size: 40),
                const SizedBox(height: PosTheme.spacingMd),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: PosTheme.spacingMd),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(categoriesProvider.notifier).loadCategories(),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category_outlined,
                      size: 48, color: PosTheme.textHintOf(context)),
                  const SizedBox(height: PosTheme.spacingMd),
                  Text(
                    l10n.categoryManagementEmptyTitle,
                    style: TextStyle(
                      color: PosTheme.textSecondaryOf(context),
                      fontSize: PosTheme.fontSizeMd,
                    ),
                  ),
                  const SizedBox(height: PosTheme.spacingXs),
                  Text(
                    l10n.categoryManagementEmptyHint,
                    style: TextStyle(
                      color: PosTheme.textHintOf(context),
                      fontSize: PosTheme.fontSizeSm,
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(categoriesProvider.notifier).loadCategories(),
            child: ListView.builder(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final color = _categoryColor(cat.id);
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(PosTheme.radiusMedium),
                    side: BorderSide(
                      color: cat.active
                          ? PosTheme.borderColorOf(context)
                          : PosTheme.dividerColorOf(context),
                    ),
                  ),
                  child: ListTile(
                    onTap: () => _openEdit(cat),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusMedium),
                      ),
                      child: Icon(Icons.category, color: color, size: 22),
                    ),
                    title: Text(
                      cat.nameEn,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cat.active
                            ? PosTheme.textPrimaryOf(context)
                            : PosTheme.textHintOf(context),
                      ),
                    ),
                    subtitle: Text(
                      cat.nameKm,
                      style: TextStyle(
                        fontSize: PosTheme.fontSizeXs,
                        color: cat.active
                            ? PosTheme.textSecondaryOf(context)
                            : PosTheme.textHintOf(context),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!cat.active)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: PosTheme.dividerColorOf(context),
                              borderRadius:
                                  BorderRadius.circular(PosTheme.radiusPill),
                            ),
                            child: Text(
                              l10n.commonInactive,
                              style: const TextStyle(
                                  fontSize: PosTheme.fontSizeXs),
                            ),
                          ),
                        Switch(
                          value: cat.active,
                          activeThumbColor: PosTheme.primaryGreen,
                          onChanged: (_) => _toggleActive(cat),
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
    );
  }
}
