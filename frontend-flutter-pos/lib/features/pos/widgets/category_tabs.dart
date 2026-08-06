import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/product_models.dart';

/// Loyverse-inspired horizontal scrollable category pills.
///
/// Clean pill-shaped buttons with green fill for the active category.
class CategoryTabs extends ConsumerWidget {
  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  /// If true, render tabs in a vertical column suitable for a side panel.
  final bool vertical;

  const CategoryTabs({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <Category?>[null]..addAll(categories);
    final lang = ref.watch(appLanguageProvider);

    if (vertical) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          children:
              items.map((cat) => _buildPill(context, cat, lang)).toList(),
        ),
      );
    }

    return Container(
      height: 52,
      color: PosTheme.backgroundCardOf(context),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _buildPill(context, items[index], lang),
        ),
      ),
    );
  }

  Widget _buildPill(BuildContext context, Category? cat, AppLanguage lang) {
    final id = cat?.id;
    final name = cat?.localizedName(lang) ?? context.l10n.commonAll;
    final isSelected = id == selectedId;

    return GestureDetector(
      onTap: () => onSelected(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? PosTheme.primaryGreen : PosTheme.backgroundPage,
          borderRadius: BorderRadius.circular(PosTheme.radiusPill),
          border: Border.all(
            color: isSelected ? PosTheme.primaryGreen : PosTheme.borderColor,
          ),
        ),
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              color: isSelected ? Colors.white : PosTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
