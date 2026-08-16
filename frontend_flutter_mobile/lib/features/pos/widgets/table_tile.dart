import 'package:flutter/material.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/table_models.dart';

/// Genuinely new shared widget — extracted so the redesigned
/// `table_picker_screen.dart` (the Tables tab) and the new
/// `table_picker_sheet.dart` (picked from the cart header) render an
/// identical table card instead of two hand-drifted copies. Neither
/// `[OLD/SOURCE]`'s `table_selector.dart` nor this port's original
/// plain-`ListTile` version grouped by section or showed capacity, even
/// though `RestaurantTable.section`/`.capacity` have been sitting unused
/// in the model since Day 9 — this tile is a deliberate visual upgrade
/// (not a source port), using data the model already carries.
class TableTile extends StatelessWidget {
  const TableTile({
    super.key,
    required this.table,
    required this.onTap,
    this.dense = false,
  });

  final RestaurantTable table;
  final VoidCallback? onTap;

  /// Tighter padding/sizing for the bottom-sheet picker, where vertical
  /// space is scarcer than on the dedicated Tables tab.
  final bool dense;

  bool get _isAvailable => table.status.toUpperCase() == 'AVAILABLE';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = _isAvailable ? PosTheme.primaryGreen : PosTheme.errorRed;

    return Material(
      color: PosTheme.backgroundCardOf(context),
      borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
        onTap: _isAvailable
            ? onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.tableSelectorInUse(table.displayText)),
                  backgroundColor: PosTheme.errorRed,
                ),
              ),
        child: Container(
          padding: EdgeInsets.all(dense ? PosTheme.spacingSm : PosTheme.spacingMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            color: color.withValues(alpha: 0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.table_restaurant_rounded,
                    color: color,
                    size: dense ? 20 : 26,
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ],
              ),
              SizedBox(height: dense ? 6 : PosTheme.spacingSm),
              Text(
                table.displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: dense ? 13 : 15,
                  color: PosTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 12,
                    color: PosTheme.textHintOf(context),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${table.capacity}',
                    style: TextStyle(
                      fontSize: 11,
                      color: PosTheme.textHintOf(context),
                    ),
                  ),
                  if (!_isAvailable) ...[
                    const Spacer(),
                    Text(
                      l10n.tableSelectorInUseBadge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
