import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/widgets/mobile_status_action_sheet.dart';
import '../models/production_models.dart';
import '../providers/inventory_provider.dart';
import '../providers/production_provider.dart';
import '../services/inventory_service.dart' show defaultInventoryStoreId;
import 'mobile_create_recipe_screen.dart';

List<String> _orderActionsFor(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT':
      return ['start', 'cancel'];
    case 'IN_PROGRESS':
      return ['complete', 'cancel'];
    default:
      return [];
  }
}

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// productions_screen.dart` + `create_recipe.dart`'s recipe-list half —
/// COPY/ADAPT NEARLY EXACTLY for all business logic. Desktop's 2-tab
/// `TabBar` (Orders / Recipes) is kept as-is (MOBILE UI REIMPLEMENT of the
/// row/dialog widgets only). Notable behaviors preserved exactly:
///  - `_orderActionsFor`: DRAFT → [start, cancel], IN_PROGRESS →
///    [complete, cancel], terminal states → [] (verbatim switch).
///  - `checkAvailability` is a manual "Check Availability" button, never
///    auto-triggered and never blocking — Create is always enabled
///    regardless of the (advisory-only) result; changing recipe/quantity
///    clears the cached result, forcing a re-check.
///  - `start` fires immediately, no confirm dialog.
///  - `complete`'s producedQuantity defaults to `order.plannedQuantity`;
///    wasteQuantity defaults to `'0'`; validated `>= 0`.
///  - `cancel` has a confirm dialog with NO reason field at all (unlike
///    e.g. Purchase Orders, which also has none — consistent).
///  - Recipes: `deactivate` is the only lifecycle action exposed in the
///    UI (icon shown only when `recipe.active`, confirm dialog) — no
///    reactivate control, matching source.
/// Print/save-PDF (order + recipe detail) deferred to Day 18.
class MobileProductionsScreen extends ConsumerStatefulWidget {
  const MobileProductionsScreen({super.key});

  @override
  ConsumerState<MobileProductionsScreen> createState() =>
      _MobileProductionsScreenState();
}

class _MobileProductionsScreenState extends ConsumerState<MobileProductionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(productionOrdersProvider.notifier).load();
      ref.read(recipesProvider.notifier).load();
      ref.read(locationsProvider.notifier).loadLocations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.productionsTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.productionsOrdersTab),
            Tab(text: l10n.productionsRecipesTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_OrdersTab(), _RecipesTab()],
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  String _actionLabel(BuildContext context, String action) {
    final l10n = context.l10n;
    switch (action) {
      case 'start':
        return l10n.productionsActionStart;
      case 'complete':
        return l10n.productionsActionComplete;
      case 'cancel':
        return l10n.commonCancel;
      default:
        return action;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'start':
        return Icons.play_arrow_outlined;
      case 'complete':
        return Icons.task_alt_outlined;
      case 'cancel':
        return Icons.cancel_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  Future<void> _openCreateOrderDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = context.l10n;
    final recipes = ref
        .read(recipesProvider)
        .valueOrNull
        ?.where((r) => r.active)
        .toList() ?? const [];
    Recipe? recipe;
    final qtyCtl = TextEditingController(text: '1');
    final notesCtl = TextEditingController();
    AvailabilityCheckResult? availability;
    bool checking = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> checkAvailability() async {
            final qty = double.tryParse(qtyCtl.text);
            if (recipe == null || qty == null || qty <= 0) {
              setState(() => error = l10n.productionsPickRecipeQtyError);
              return;
            }
            setState(() {
              checking = true;
              error = null;
            });
            try {
              final result = await ref
                  .read(productionOrdersProvider.notifier)
                  .checkAvailability(
                    recipeId: recipe!.id!,
                    storeId: defaultInventoryStoreId,
                    producedQuantity: qty,
                  );
              setState(() {
                availability = result;
                checking = false;
              });
            } catch (e) {
              setState(() {
                checking = false;
                error = l10n.productionsCheckAvailabilityFailed('$e');
              });
            }
          }

          Future<void> create() async {
            final qty = double.tryParse(qtyCtl.text);
            if (recipe == null || qty == null || qty <= 0) {
              setState(() => error = l10n.productionsPickRecipeQtyError);
              return;
            }
            try {
              await ref
                  .read(productionOrdersProvider.notifier)
                  .create(
                    ProductionOrder(
                      recipeId: recipe!.id!,
                      storeId: defaultInventoryStoreId,
                      plannedQuantity: qty,
                      notes: notesCtl.text.trim().isEmpty
                          ? null
                          : notesCtl.text.trim(),
                    ),
                  );
              if (context.mounted) Navigator.of(dialogContext).pop();
            } catch (e) {
              setState(() => error = l10n.inventoryFailedToSave('$e'));
            }
          }

          return AlertDialog(
            title: Text(l10n.productionsNewOrderTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Recipe>(
                    initialValue: recipe,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.productionsRecipeLabel,
                    ),
                    items: [
                      for (final r in recipes)
                        DropdownMenuItem(
                          value: r,
                          child: Text(r.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      recipe = v;
                      availability = null;
                    }),
                  ),
                  const SizedBox(height: PosTheme.spacingMd),
                  TextField(
                    controller: qtyCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() => availability = null),
                    decoration: InputDecoration(
                      labelText: l10n.productionsPlannedQuantityLabel,
                    ),
                  ),
                  const SizedBox(height: PosTheme.spacingMd),
                  TextField(
                    controller: notesCtl,
                    decoration: InputDecoration(
                      labelText: l10n.productionsNotesLabel,
                    ),
                  ),
                  const SizedBox(height: PosTheme.spacingMd),
                  OutlinedButton(
                    onPressed: checking ? null : checkAvailability,
                    child: Text(l10n.productionsCheckAvailabilityButton),
                  ),
                  if (availability != null) ...[
                    const SizedBox(height: PosTheme.spacingSm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(PosTheme.spacingSm),
                      decoration: BoxDecoration(
                        color:
                            (availability!.available
                                    ? PosTheme.successGreen
                                    : PosTheme.errorRed)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          PosTheme.radiusMedium,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            availability!.available
                                ? l10n.productionsAllComponentsAvailable
                                : l10n.productionsInsufficientStock,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: availability!.available
                                  ? PosTheme.successGreen
                                  : PosTheme.errorRed,
                            ),
                          ),
                          for (final c in availability!.components)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${c.productName ?? l10n.productionsProductFallback('${c.productId}')}: '
                                '${l10n.productionsComponentNeedHave(c.required.toStringAsFixed(0), c.onHand.toStringAsFixed(0))}',
                                style: TextStyle(
                                  fontSize: PosTheme.fontSizeXs,
                                  color: c.sufficient
                                      ? PosTheme.successGreen
                                      : PosTheme.errorRed,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: PosTheme.spacingSm),
                    Text(error!, style: TextStyle(color: PosTheme.errorRed)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: create,
                child: Text(l10n.productionsCreateButton),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCompleteDialog(
    BuildContext context,
    WidgetRef ref,
    ProductionOrder order,
  ) async {
    final l10n = context.l10n;
    final producedCtl = TextEditingController(
      text: order.plannedQuantity.toStringAsFixed(0),
    );
    final wasteCtl = TextEditingController(text: '0');
    final notesCtl = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> complete() async {
            final produced = double.tryParse(producedCtl.text);
            if (produced == null || produced < 0) {
              setState(
                () => error = l10n.productionsInvalidProducedQtyError,
              );
              return;
            }
            final waste = double.tryParse(wasteCtl.text) ?? 0;
            try {
              await ref
                  .read(productionOrdersProvider.notifier)
                  .complete(
                    order.id!,
                    producedQuantity: produced,
                    wasteQuantity: waste,
                    notes: notesCtl.text.trim().isEmpty
                        ? null
                        : notesCtl.text.trim(),
                  );
              if (context.mounted) Navigator.of(dialogContext).pop();
            } catch (e) {
              setState(() => error = l10n.inventoryActionFailed('$e'));
            }
          }

          return AlertDialog(
            title: Text(l10n.productionsCompleteOrderTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: producedCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.productionsProducedQuantityLabel,
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextField(
                  controller: wasteCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.productionsWasteQuantityLabel,
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextField(
                  controller: notesCtl,
                  decoration: InputDecoration(
                    labelText: l10n.productionsNotesLabel,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: PosTheme.spacingSm),
                  Text(error!, style: TextStyle(color: PosTheme.errorRed)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: complete,
                child: Text(l10n.productionsCompleteButton),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cancelOrder(
    BuildContext context,
    WidgetRef ref,
    ProductionOrder order,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.productionsCancelOrderTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.inventoryKeepButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PosTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.inventoryCancelOrderButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(productionOrdersProvider.notifier).cancel(order.id!);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.inventoryActionFailed('$e')),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(productionOrdersProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.productionsNewOrderButton,
        onPressed: () => _openCreateOrderDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(child: Text(l10n.productionsNoOrdersFound));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(productionOrdersProvider.notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              itemCount: orders.length,
              itemBuilder: (context, i) {
                final order = orders[i];
                final actions = _orderActionsFor(order.status);
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      PosTheme.radiusMedium,
                    ),
                    side: BorderSide(color: PosTheme.borderColorOf(context)),
                  ),
                  child: ListTile(
                    title: Text(
                      order.orderNumber ??
                          l10n.productionsOrderFallback('${order.id}'),
                    ),
                    subtitle: Text(
                      '${order.recipeName ?? l10n.productionsRecipeFallback('${order.recipeId}')} • '
                      '${l10n.productionsPlannedLabel} '
                      '${order.plannedQuantity.toStringAsFixed(0)} • ${order.status}',
                      style: TextStyle(
                        fontSize: PosTheme.fontSizeXs,
                        color: PosTheme.textSecondaryOf(context),
                      ),
                    ),
                    trailing: order.id == null || actions.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () async {
                              final action = await showStatusActionSheet(
                                context,
                                title:
                                    order.orderNumber ??
                                    l10n.productionsOrderFallback(
                                      '${order.id}',
                                    ),
                                actions: actions,
                                labelFor: (a) => _actionLabel(context, a),
                                iconFor: _actionIcon,
                                destructiveActions: const {'cancel'},
                              );
                              if (action == 'start') {
                                try {
                                  await ref
                                      .read(productionOrdersProvider.notifier)
                                      .start(order.id!);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.inventoryActionFailed('$e'),
                                        ),
                                        backgroundColor: PosTheme.errorRed,
                                      ),
                                    );
                                  }
                                }
                              } else if (action == 'complete') {
                                if (context.mounted) {
                                  _openCompleteDialog(context, ref, order);
                                }
                              } else if (action == 'cancel') {
                                if (context.mounted) {
                                  _cancelOrder(context, ref, order);
                                }
                              }
                            },
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

class _RecipesTab extends ConsumerWidget {
  const _RecipesTab();

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    Recipe recipe,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.productionsDeactivateRecipeTitle),
        content: Text(l10n.productionsDeactivateRecipeConfirm(recipe.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.inventoryKeepButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PosTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.productionsDeactivateButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(recipesProvider.notifier).deactivate(recipe.id!);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.inventoryActionFailed('$e')),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(recipesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.productionsNewRecipeButton,
        onPressed: () async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const MobileCreateRecipeScreen()),
          );
          if (saved == true) {
            ref.read(recipesProvider.notifier).load();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (recipes) {
          if (recipes.isEmpty) {
            return Center(child: Text(l10n.productionsNoRecipesFound));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(recipesProvider.notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              itemCount: recipes.length,
              itemBuilder: (context, i) {
                final recipe = recipes[i];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      PosTheme.radiusMedium,
                    ),
                    side: BorderSide(color: PosTheme.borderColorOf(context)),
                  ),
                  child: ListTile(
                    title: Text(recipe.name),
                    subtitle: Text(
                      '${l10n.productionsMakesLabel} '
                      '${recipe.outputProductNameEn ?? l10n.productionsProductFallback('${recipe.outputProductId}')} • '
                      '${l10n.productionsComponentCount('${recipe.lines.length}')}',
                      style: TextStyle(
                        fontSize: PosTheme.fontSizeXs,
                        color: PosTheme.textSecondaryOf(context),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (recipe.active
                                        ? PosTheme.successGreen
                                        : PosTheme.textHintOf(context))
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              PosTheme.radiusPill,
                            ),
                          ),
                          child: Text(
                            recipe.active
                                ? l10n.commonActive
                                : l10n.commonInactive,
                            style: const TextStyle(
                              fontSize: PosTheme.fontSizeXs,
                            ),
                          ),
                        ),
                        if (recipe.active)
                          IconButton(
                            tooltip: l10n.productionsDeactivateTooltip,
                            icon: const Icon(Icons.block_outlined),
                            onPressed: () => _deactivate(context, ref, recipe),
                          ),
                      ],
                    ),
                    onTap: () async {
                      final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              MobileCreateRecipeScreen(initialRecipe: recipe),
                        ),
                      );
                      if (saved == true) {
                        ref.read(recipesProvider.notifier).load();
                      }
                    },
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
