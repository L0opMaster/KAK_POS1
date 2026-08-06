import 'package:flutter/material.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/report_models.dart';

/// Prev/next pagination control driven by a [PageMeta], shown under a
/// paginated report table. Disabled appropriately at the ends.
class ReportPaginationBar extends StatelessWidget {
  const ReportPaginationBar({
    super.key,
    required this.meta,
    required this.onPageChange,
  });

  final PageMeta meta;
  final ValueChanged<int> onPageChange;

  @override
  Widget build(BuildContext context) {
    final bool hasPrev = meta.page > 0;
    final bool hasNext = meta.page + 1 < meta.totalPages;
    final int shownTotalPages = meta.totalPages == 0 ? 1 : meta.totalPages;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: hasPrev ? PosTheme.textPrimary : PosTheme.textHint,
            onPressed: hasPrev ? () => onPageChange(meta.page - 1) : null,
            tooltip: context.l10n.reportPaginationPreviousPage,
          ),
          Text(
            context.l10n.reportPaginationPageInfo(
                meta.page + 1, shownTotalPages, meta.totalElements),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PosTheme.textSecondary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: hasNext ? PosTheme.textPrimary : PosTheme.textHint,
            onPressed: hasNext ? () => onPageChange(meta.page + 1) : null,
            tooltip: context.l10n.reportPaginationNextPage,
          ),
        ],
      ),
    );
  }
}
