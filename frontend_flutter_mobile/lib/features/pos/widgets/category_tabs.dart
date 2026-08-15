import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/product_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/widgets/
/// category_tabs.dart` — COPY/ADAPT NEARLY EXACTLY, and used directly
/// (unlike `[OLD/SOURCE]`'s `pos_screen.dart`, which has its own separate,
/// nearly-duplicate `_CategoryFilterBar` with desktop-only mouse-wheel
/// scroll handling bolted on — this reusable, already-generic,
/// touch-appropriate widget is the better fit for the mobile port; see
/// DAY_06.md section 10). `vertical` mode (unused by this day's Register
/// screen, which only needs the horizontal pill row) is kept since it adds
/// no real cost and matches source's public API exactly.
class CategoryTabs extends ConsumerWidget {
  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
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
          children: items.map((cat) => _buildPill(context, cat, lang)).toList(),
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
