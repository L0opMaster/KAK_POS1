import 'package:flutter/material.dart';

import '../../../core/config/pos_theme.dart';

/// Genuinely new in this port — `[OLD/SOURCE]`'s desktop screens show
/// status-transition actions via a `PopupMenuButton` anchored to each list
/// row (Purchase Orders, Transfer Orders, Production Orders all do this,
/// each with its own copy of the same "row of ListTiles" logic). A phone
/// list row is too narrow/tap-target-cramped for that same popup, so this
/// is one shared bottom sheet all three inventory order screens use
/// instead — same set of actions per entity, same
/// `_actionsFor(status)`-style business rule feeding it, just a different
/// (mobile-appropriate) presentation.
///
/// [destructiveActions] renders those entries in [PosTheme.errorRed] (e.g.
/// `cancel`) — everything else uses the default list-tile color. Returns
/// the tapped action string, or `null` if the sheet was dismissed without
/// a selection.
Future<String?> showStatusActionSheet(
  BuildContext context, {
  required String title,
  required List<String> actions,
  required String Function(String action) labelFor,
  required IconData Function(String action) iconFor,
  Set<String> destructiveActions = const {},
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PosTheme.spacingLg,
              PosTheme.spacingLg,
              PosTheme.spacingLg,
              PosTheme.spacingSm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          for (final action in actions)
            ListTile(
              leading: Icon(
                iconFor(action),
                color: destructiveActions.contains(action)
                    ? PosTheme.errorRed
                    : null,
              ),
              title: Text(
                labelFor(action),
                style: TextStyle(
                  color: destructiveActions.contains(action)
                      ? PosTheme.errorRed
                      : null,
                ),
              ),
              onTap: () => Navigator.of(ctx).pop(action),
            ),
          const SizedBox(height: PosTheme.spacingSm),
        ],
      ),
    ),
  );
}
