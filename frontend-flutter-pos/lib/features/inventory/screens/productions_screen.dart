import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';
import '../models/production_models.dart';
import '../providers/production_provider.dart';
import '../services/inventory_service.dart' show defaultInventoryStoreId;
import 'create_recipe.dart';

/// Production order flow (ProductionService): DRAFT --start--> IN_PROGRESS
/// --complete--> COMPLETED. DRAFT or IN_PROGRESS --cancel--> CANCELLED.
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

class ProductionsScreen extends ConsumerStatefulWidget {
  const ProductionsScreen({super.key});

  @override
  ConsumerState<ProductionsScreen> createState() => _ProductionsScreenState();
}

class _ProductionsScreenState extends ConsumerState<ProductionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() async {
      await ref.read(recipesProvider.notifier).load();
      await ref.read(productionOrdersProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.productionsTitle),
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          // This TabBar sits inside the AppBar, which is always brand
          // green — labelColor/indicatorColor must be white (not
          // primaryGreen) or they vanish against their own background.
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: context.l10n.productionsOrdersTab),
            Tab(text: context.l10n.productionsRecipesTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OrdersTab(),
          _RecipesTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Orders tab
// ─────────────────────────────────────────────────────────────
class _OrdersTab extends ConsumerStatefulWidget {
  const _OrdersTab();

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  bool _generatingPdf = false;

  Future<void> _openCreateOrderDialog() async {
    final recipes = ref.read(recipesProvider).valueOrNull?.where((r) => r.active).toList() ?? const <Recipe>[];
    Recipe? selectedRecipe;
    final qtyCtl = TextEditingController(text: '1');
    final notesCtl = TextEditingController();
    AvailabilityCheckResult? availability;
    bool saving = false;
    bool checking = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> checkAvailability() async {
              final qty = double.tryParse(qtyCtl.text.trim());
              if (selectedRecipe == null || qty == null || qty <= 0) {
                setDialogState(() =>
                    error = context.l10n.productionsPickRecipeQtyError);
                return;
              }
              setDialogState(() {
                checking = true;
                error = null;
              });
              try {
                final result = await ref.read(productionOrdersProvider.notifier).checkAvailability(
                      recipeId: selectedRecipe!.id!,
                      storeId: defaultInventoryStoreId,
                      producedQuantity: qty,
                    );
                setDialogState(() {
                  availability = result;
                  checking = false;
                });
              } catch (e) {
                setDialogState(() {
                  checking = false;
                  error = context.l10n.productionsCheckAvailabilityFailed('$e');
                });
              }
            }

            Future<void> save() async {
              final qty = double.tryParse(qtyCtl.text.trim());
              if (selectedRecipe == null || qty == null || qty <= 0) {
                setDialogState(() =>
                    error = context.l10n.productionsPickRecipeQtyError);
                return;
              }
              setDialogState(() {
                saving = true;
                error = null;
              });
              try {
                await ref.read(productionOrdersProvider.notifier).create(
                      ProductionOrder(
                        recipeId: selectedRecipe!.id!,
                        storeId: defaultInventoryStoreId,
                        plannedQuantity: qty,
                        notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
                      ),
                    );
                if (context.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() {
                  saving = false;
                  error = context.l10n.inventoryFailedToSave('$e');
                });
              }
            }

            return AlertDialog(
              title: Text(context.l10n.productionsNewOrderTitle),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<Recipe>(
                        initialValue: selectedRecipe,
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText: context.l10n.productionsRecipeLabel,
                            border: const OutlineInputBorder()),
                        items: recipes
                            .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                            .toList(),
                        onChanged: (value) => setDialogState(() {
                          selectedRecipe = value;
                          availability = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qtyCtl,
                        decoration: InputDecoration(
                            labelText: context.l10n.productionsPlannedQuantityLabel,
                            border: const OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setDialogState(() => availability = null),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtl,
                        decoration: InputDecoration(
                            labelText: context.l10n.productionsNotesLabel,
                            border: const OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: checking ? null : checkAvailability,
                          icon: checking
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.fact_check_outlined, size: 18),
                          label: Text(context.l10n.productionsCheckAvailabilityButton),
                        ),
                      ),
                      if (availability != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (availability!.available ? PosTheme.successGreen : PosTheme.errorRed)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                availability!.available
                                    ? context.l10n.productionsAllComponentsAvailable
                                    : context.l10n.productionsInsufficientStock,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: availability!.available ? PosTheme.successGreen : PosTheme.errorRed,
                                ),
                              ),
                              ...availability!.components.map((c) => Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${c.productName ?? context.l10n.productionsProductFallback('${c.productId}')}: '
                                      '${context.l10n.productionsComponentNeedHave('${c.required}', '${c.onHand}')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: c.sufficient ? Colors.black54 : PosTheme.errorRed,
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: PosTheme.errorRed)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonCancel.toUpperCase()),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(backgroundColor: PosTheme.primaryGreen, foregroundColor: Colors.white),
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(context.l10n.productionsCreateButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _completeOrder(ProductionOrder order) async {
    final producedCtl = TextEditingController(text: order.plannedQuantity.toString());
    final wasteCtl = TextEditingController(text: '0');
    final notesCtl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final produced = double.tryParse(producedCtl.text.trim());
              final waste = double.tryParse(wasteCtl.text.trim()) ?? 0;
              if (produced == null || produced < 0) {
                setDialogState(() =>
                    error = context.l10n.productionsInvalidProducedQtyError);
                return;
              }
              setDialogState(() {
                saving = true;
                error = null;
              });
              try {
                await ref.read(productionOrdersProvider.notifier).complete(
                      order.id!,
                      producedQuantity: produced,
                      wasteQuantity: waste,
                      notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
                    );
                if (context.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() {
                  saving = false;
                  error = context.l10n.inventoryActionFailed('$e');
                });
              }
            }

            return AlertDialog(
              title: Text(context.l10n.productionsCompleteOrderTitle),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: producedCtl,
                      decoration: InputDecoration(
                          labelText: context.l10n.productionsProducedQuantityLabel,
                          border: const OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: wasteCtl,
                      decoration: InputDecoration(
                          labelText: context.l10n.productionsWasteQuantityLabel,
                          border: const OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtl,
                      decoration: InputDecoration(
                          labelText: context.l10n.productionsNotesLabel,
                          border: const OutlineInputBorder()),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: PosTheme.errorRed)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonCancel.toUpperCase()),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(backgroundColor: PosTheme.primaryGreen, foregroundColor: Colors.white),
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(context.l10n.productionsCompleteButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// `order.lines` is already fully populated in the list response — no
  /// separate order-detail endpoint exists.
  Future<Uint8List> _buildOrderPdf(ProductionOrder order) async {
    final l10n = context.l10n;
    final company = await ref.read(settingsServiceProvider).getCompanyProfile();

    final details = <MapEntry<String, String>>[
      MapEntry(l10n.productionOrderPdfNumberLabel,
          order.orderNumber ?? l10n.productionsOrderFallback('${order.id}')),
      MapEntry(l10n.formRecipe,
          order.recipeName ?? l10n.productionsRecipeFallback('${order.recipeId}')),
      if (order.storeName != null) MapEntry(l10n.formStore, order.storeName!),
      MapEntry(l10n.commonStatus, order.status),
      MapEntry(l10n.productionsPlannedLabel, '${order.plannedQuantity}'),
      if (order.producedQuantity != null)
        MapEntry(l10n.productionsProducedLabel, '${order.producedQuantity}'),
      if (order.wasteQuantity != null && order.wasteQuantity != 0)
        MapEntry(l10n.productionOrderPdfWasteLabel, '${order.wasteQuantity}'),
      if (order.yieldPercent != null)
        MapEntry(l10n.productionOrderPdfYieldLabel, '${order.yieldPercent}'),
      if (order.startedAt != null)
        MapEntry(l10n.productionOrderPdfStartedLabel, order.startedAt!),
      if (order.completedAt != null)
        MapEntry(l10n.productionOrderPdfCompletedLabel, order.completedAt!),
      if (order.createdBy != null) MapEntry(l10n.commonUser, order.createdBy!),
      if (order.notes != null && order.notes!.isNotEmpty)
        MapEntry(l10n.inventoryNotesLabel, order.notes!),
    ];

    final rows = order.lines
        .map((line) => [
              line.componentProductNameEn ??
                  l10n.productionsProductFallback('${line.componentProductId}'),
              line.plannedQuantity.toStringAsFixed(
                  line.plannedQuantity.truncateToDouble() == line.plannedQuantity ? 0 : 2),
              line.consumedQuantity != null
                  ? line.consumedQuantity!.toStringAsFixed(
                      line.consumedQuantity!.truncateToDouble() == line.consumedQuantity ? 0 : 2)
                  : '',
            ])
        .toList();

    return A4ReportPdf.build(
      title: l10n.productionOrderPdfTitle,
      businessName: '${company['businessName'] ?? ''}',
      businessAddress: '${company['address'] ?? ''}',
      businessPhone: '${company['phone'] ?? ''}',
      details: details,
      columns: [
        l10n.productionOrderPdfComponentLabel,
        l10n.productionOrderPdfRequiredLabel,
        l10n.productionOrderPdfConsumedLabel,
      ],
      rows: rows,
      columnAlignments: const {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
      generatedAt: DateTime.now(),
      generatedLabel: l10n.reportPdfGeneratedLabel,
      pageLabel: l10n.reportPdfPageLabel,
    );
  }

  Future<void> _printOrder(ProductionOrder order) async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildOrderPdf(order);
      await Printing.layoutPdf(
          onLayout: (_) => bytes, name: order.orderNumber ?? 'production_order');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.l10n.printerPrintFailed}: $e')));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _saveOrderPdf(ProductionOrder order) async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await _buildOrderPdf(order);
      await Printing.sharePdf(
          bytes: bytes, filename: '${order.orderNumber ?? 'production_order'}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.l10n.printerPrintFailed}: $e')));
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _runAction(ProductionOrder order, String action) async {
    if (action == 'start') {
      try {
        await ref.read(productionOrdersProvider.notifier).start(order.id!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.l10n.inventoryActionFailed('$e')),
              backgroundColor: PosTheme.errorRed));
        }
      }
      return;
    }
    if (action == 'complete') {
      await _completeOrder(order);
      return;
    }
    if (action == 'cancel') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.productionsCancelOrderTitle),
          content: Text(context.l10n
              .productionsCancelOrderConfirm(order.orderNumber ?? '#${order.id}')),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.l10n.inventoryKeepButton)),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.inventoryCancelOrderButton,
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await ref.read(productionOrdersProvider.notifier).cancel(order.id!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context.l10n.inventoryActionFailed('$e')),
              backgroundColor: PosTheme.errorRed));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productionOrdersProvider);
    return state.when(
      data: (orders) => _buildList(orders),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Widget _buildList(List<ProductionOrder> orders) {
    return RefreshIndicator(
      onRefresh: () => ref.read(productionOrdersProvider.notifier).load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          Card(
            color: Colors.white,
            elevation: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 22),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openCreateOrderDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(180, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.productionsNewOrderButton,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(context.l10n.inventoryOrderCount('${orders.length}'),
                          style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (orders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.precision_manufacturing_outlined, size: 44, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(context.l10n.productionsNoOrdersFound,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
                        ],
                      ),
                    ),
                  )
                else
                  ...orders.map(_buildRow),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(ProductionOrder order) {
    final status = order.status.toUpperCase();
    final actions = order.id == null ? const <String>[] : _orderActionsFor(status);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF99D267),
                child: Icon(Icons.precision_manufacturing, color: Colors.white),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        order.orderNumber ??
                            context.l10n.productionsOrderFallback('${order.id}'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${order.recipeName ?? context.l10n.productionsRecipeFallback('${order.recipeId}')} '
                      '• ${context.l10n.productionsPlannedLabel} ${order.plannedQuantity}'
                      '${order.producedQuantity != null ? ' • ${context.l10n.productionsProducedLabel} ${order.producedQuantity}' : ''}',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status))),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: context.l10n.inventoryDocumentActionsTooltip,
                enabled: !_generatingPdf,
                onSelected: (action) => action == 'print'
                    ? _printOrder(order)
                    : _saveOrderPdf(order),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'print', child: Text(context.l10n.commonPrint)),
                  PopupMenuItem(value: 'save', child: Text(context.l10n.commonSavePdf)),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (action) => _runAction(order, action),
                  itemBuilder: (context) => actions
                      .map((a) => PopupMenuItem(
                          value: a, child: Text(_actionLabel(context, a))))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return PosTheme.successGreen;
      case 'CANCELLED':
        return PosTheme.errorRed;
      case 'IN_PROGRESS':
        return PosTheme.warningAmber;
      default:
        return Colors.grey;
    }
  }

  String _actionLabel(BuildContext context, String action) {
    switch (action) {
      case 'start':
        return context.l10n.productionsActionStart;
      case 'complete':
        return context.l10n.productionsActionComplete;
      case 'cancel':
        return context.l10n.commonCancel;
      default:
        return action;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Recipes tab
// ─────────────────────────────────────────────────────────────
class _RecipesTab extends ConsumerStatefulWidget {
  const _RecipesTab();

  @override
  ConsumerState<_RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends ConsumerState<_RecipesTab> {
  Future<void> _openCreate() async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CreateRecipe()));
  }

  Future<void> _openEdit(Recipe recipe) async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => CreateRecipe(initialRecipe: recipe)));
  }

  Future<void> _deactivate(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.productionsDeactivateRecipeTitle),
        content: Text(context.l10n.productionsDeactivateRecipeConfirm(recipe.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.inventoryKeepButton)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.productionsDeactivateButton,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || recipe.id == null) return;
    try {
      await ref.read(recipesProvider.notifier).deactivate(recipe.id!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.inventoryActionFailed('$e')),
            backgroundColor: PosTheme.errorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipesProvider);
    return state.when(
      data: (recipes) => _buildList(recipes),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Widget _buildList(List<Recipe> recipes) {
    return RefreshIndicator(
      onRefresh: () => ref.read(recipesProvider.notifier).load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          Card(
            color: Colors.white,
            elevation: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 22),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openCreate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(180, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.productionsNewRecipeButton,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(context.l10n.productionsRecipeCount('${recipes.length}'),
                          style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (recipes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 44, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(context.l10n.productionsNoRecipesFound,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
                        ],
                      ),
                    ),
                  )
                else
                  ...recipes.map(_buildRow),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Recipe recipe) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
          leading: const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF99D267),
            child: Icon(Icons.receipt_long, color: Colors.white),
          ),
          title: Text(recipe.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${context.l10n.productionsMakesLabel} ${recipe.outputQuantity} × '
            '${recipe.outputProductNameEn ?? context.l10n.productionsProductFallback('${recipe.outputProductId}')} • '
            '${context.l10n.productionsComponentCount('${recipe.lines.length}')}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          onTap: () => _openEdit(recipe),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (recipe.active ? PosTheme.successGreen : PosTheme.errorRed).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  recipe.active
                      ? context.l10n.commonActive.toUpperCase()
                      : context.l10n.commonInactive.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: recipe.active ? PosTheme.successGreen : PosTheme.errorRed),
                ),
              ),
              if (recipe.active)
                IconButton(
                  icon: const Icon(Icons.block, size: 20, color: PosTheme.errorRed),
                  tooltip: context.l10n.productionsDeactivateTooltip,
                  onPressed: () => _deactivate(recipe),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
