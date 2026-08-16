import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modifier_models.dart';
import '../providers/modifier_provider.dart';
import '../providers/product_provider.dart';
import 'create_modifier.dart';
import 'modifier_product_assignment_screen.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';

class ModifierManagement extends ConsumerStatefulWidget {
  const ModifierManagement({super.key});

  @override
  ConsumerState<ModifierManagement> createState() {
    return _ModifierManagementState();
  }
}

class _ModifierManagementState extends ConsumerState<ModifierManagement> {
  static const Color primaryGreen = Color(0xFF8BCB3F);

  // Show 10 modifier groups on each page.
  static const int _pageSize = 6;

  int _currentPage = 0;

  // Selected modifier IDs remain selected when changing pages.
  final Set<int> _selectedModifierIds = {};

  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(modifiersProvider.notifier).loadGroups();
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _currentPage = 0;
    });
  }

  Future<void> _openCreateModifier() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) {
          return const CreateModifier();
        },
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await ref.read(modifiersProvider.notifier).loadGroups();

      if (!mounted) return;

      // Return to first page after adding a modifier.
      setState(() {
        _currentPage = 0;
      });
    }
  }

  Future<void> _openEditModifier(
    ModifierGroupResponse modifier,
  ) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) {
          return CreateModifier(
            initialModifier: modifier,
          );
        },
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await ref.read(modifiersProvider.notifier).loadGroups();
    }
  }

  void _toggleModifier(
    int modifierId,
    bool selected,
  ) {
    setState(() {
      if (selected) {
        _selectedModifierIds.add(modifierId);
      } else {
        _selectedModifierIds.remove(modifierId);
      }
    });
  }

  /// Selects or deselects only the modifiers visible
  /// on the current page.
  void _toggleCurrentPage(
    List<ModifierGroupResponse> pageGroups,
  ) {
    final pageIds = pageGroups.map((modifier) => modifier.id).toSet();

    final allPageItemsSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedModifierIds.contains);

    setState(() {
      if (allPageItemsSelected) {
        _selectedModifierIds.removeAll(pageIds);
      } else {
        _selectedModifierIds.addAll(pageIds);
      }
    });
  }

  Future<void> _deleteSelectedModifiers() async {
    if (_selectedModifierIds.isEmpty) return;

    final numberSelected = _selectedModifierIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.l10n.modifierManagementDeleteDialogTitle),
          content: Text(
            dialogContext.l10n.modifierManagementDeleteDialogMessage(
              numberSelected.toString(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(dialogContext.l10n.commonCancel.toUpperCase()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                dialogContext.l10n.commonDelete.toUpperCase(),
                style: const TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final idsToDelete = _selectedModifierIds.toList();

    try {
      for (final modifierId in idsToDelete) {
        await ref.read(modifiersProvider.notifier).deleteModifier(modifierId);
      }

      if (!mounted) return;

      final remainingGroups = ref.read(modifiersProvider).groups;

      final totalPages = remainingGroups.isEmpty
          ? 1
          : (remainingGroups.length / _pageSize).ceil();

      setState(() {
        _selectedModifierIds.clear();

        // Move backward when the last page becomes empty.
        if (_currentPage >= totalPages) {
          _currentPage = totalPages - 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.modifierManagementDeleteSuccess(
              idsToDelete.length.toString(),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      final error = ref.read(modifiersProvider).error ??
          context.l10n.modifierManagementDeleteFailedDefault;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    }
  }

  Future<void> _refreshModifiers() async {
    await ref.read(modifiersProvider.notifier).loadGroups();

    if (!mounted) return;

    final groups = ref.read(modifiersProvider).groups;
    final totalPages = groups.isEmpty ? 1 : (groups.length / _pageSize).ceil();

    setState(() {
      _selectedModifierIds.removeWhere(
        (id) => !groups.any((group) => group.id == id),
      );

      if (_currentPage >= totalPages) {
        _currentPage = totalPages - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final modifierState = ref.watch(modifiersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(context.l10n.modifierManagementTitle),
        // backgroundColor: Colors.white,
        // foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (modifierState.isLoading && modifierState.groups.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (modifierState.error != null && modifierState.groups.isEmpty) {
              return _buildErrorState(
                modifierState.error!,
              );
            }

            if (modifierState.groups.isEmpty) {
              return _buildEmptyState();
            }

            final query = _searchCtl.text.trim().toLowerCase();

            final filteredGroups = query.isEmpty
                ? modifierState.groups
                : modifierState.groups.where((group) {
                    final nameMatches =
                        group.nameEn.toLowerCase().contains(query);

                    final optionMatches = group.options.any(
                      (option) => option.nameEn.toLowerCase().contains(query),
                    );

                    return nameMatches || optionMatches;
                  }).toList();

            return _buildModifierList(
              filteredGroups,
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 650,
          ),
          child: Card(
            color: Colors.white,
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 45,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 105,
                    height: 105,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 52,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.l10n.modifierManagementEmptyTitle,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.modifierManagementEmptyDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _openCreateModifier,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(165, 54),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(
                      context.l10n.modifierManagementAddModifier,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModifierList(
    List<ModifierGroupResponse> allGroups,
  ) {
    final totalItems = allGroups.length;
    final totalPages = math.max(
      1,
      (totalItems / _pageSize).ceil(),
    );

    // Protect against an invalid page after deleting data.
    final safeCurrentPage = math.min(
      _currentPage,
      totalPages - 1,
    );

    final startIndex = safeCurrentPage * _pageSize;

    final endIndex = math.min(
      startIndex + _pageSize,
      totalItems,
    );

    // Only these 10 records appear on the current page.
    final pageGroups = allGroups.sublist(
      startIndex,
      endIndex,
    );

    final pageIds = pageGroups.map((group) => group.id).toSet();

    final allPageItemsSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedModifierIds.contains);

    final somePageItemsSelected = pageIds.any(
      _selectedModifierIds.contains,
    );

    return RefreshIndicator(
      onRefresh: _refreshModifiers,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          Card(
            color: Colors.white,
            elevation: 3,
            child: Column(
              children: [
                // ───────────── Toolbar ─────────────

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    30,
                    28,
                    30,
                    22,
                  ),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openCreateModifier,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(160, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          context.l10n.modifierManagementAddModifier,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Delete icon near ADD MODIFIER.
                      IconButton(
                        tooltip: context
                            .l10n.modifierManagementDeleteSelectedTooltip,
                        onPressed: _selectedModifierIds.isEmpty
                            ? null
                            : _deleteSelectedModifiers,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          foregroundColor: Colors.red,
                          disabledForegroundColor: Colors.grey.shade400,
                          side: BorderSide(
                            color: _selectedModifierIds.isEmpty
                                ? Colors.grey.shade300
                                : Colors.red,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_outline,
                        ),
                      ),

                      const Spacer(),

                      if (_selectedModifierIds.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.modifierManagementSelectedCount(
                            _selectedModifierIds.length.toString(),
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Search box in the top-right corner of the card.
                      SizedBox(
                        width: 260,
                        height: 42,
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: _search,
                          decoration: InputDecoration(
                            hintText: context.l10n.modifierManagementSearchHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchCtl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchCtl.clear();
                                      _search('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF7F7F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 12,
                            ),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ───────────── Header ─────────────

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: Checkbox(
                          tristate: true,
                          value: allPageItemsSelected
                              ? true
                              : somePageItemsSelected
                                  ? null
                                  : false,
                          onChanged: (_) {
                            _toggleCurrentPage(pageGroups);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.modifierManagementSectionHeader,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Text(
                        context.l10n.modifierManagementShowingCount(
                          pageGroups.length.toString(),
                          totalItems.toString(),
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                if (pageGroups.isEmpty)
                  _buildNoResultsRow()
                else
                  // Maximum of 10 rows.
                  ...pageGroups.map(_buildModifierRow),

                // ───────────── Pagination ─────────────

                if (pageGroups.isNotEmpty)
                  _buildPaginationControls(
                    currentPage: safeCurrentPage,
                    totalPages: totalPages,
                    totalItems: totalItems,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              context.l10n.modifierManagementNoModifiersFound,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModifierRow(
    ModifierGroupResponse group,
  ) {
    final selected = _selectedModifierIds.contains(group.id);
    final lang = ref.watch(appLanguageProvider);

    final optionNames = group.options.isEmpty
        ? context.l10n.modifierManagementNoOptions
        : group.options.map((option) => option.localizedName(lang)).join(', ');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 18,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Checkbox(
                  value: selected,
                  onChanged: (value) {
                    _toggleModifier(
                      group.id,
                      value ?? false,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    _openEditModifier(group);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFF99D267),
                          child: Icon(
                            Icons.description_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.localizedName(lang),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                optionNames,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.modifierManagementApplyToProductsTooltip,
                onPressed: () => _openAssignProducts(group),
                icon: const Icon(Icons.inventory_2_outlined),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _openAssignProducts(ModifierGroupResponse group) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ModifierProductAssignmentScreen(group: group),
      ),
    );

    if (saved == true && mounted) {
      await ref.read(modifiersProvider.notifier).loadGroups();
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

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required int totalItems,
  }) {
    final firstItem = totalItems == 0 ? 0 : currentPage * _pageSize + 1;

    final lastItem = math.min(
      (currentPage + 1) * _pageSize,
      totalItems,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            context.l10n.modifierManagementRangeOfTotal(
              firstItem.toString(),
              lastItem.toString(),
              totalItems.toString(),
            ),
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(width: 20),

          // First page.
          IconButton(
            tooltip: context.l10n.modifierManagementFirstPage,
            onPressed: currentPage == 0
                ? null
                : () {
                    setState(() {
                      _currentPage = 0;
                    });
                  },
            icon: const Icon(
              Icons.first_page,
            ),
          ),

          // Previous page.
          IconButton(
            tooltip: context.l10n.modifierManagementPreviousPage,
            onPressed: currentPage == 0
                ? null
                : () {
                    setState(() {
                      _currentPage = currentPage - 1;
                    });
                  },
            icon: const Icon(
              Icons.chevron_left,
            ),
          ),

          Container(
            constraints: const BoxConstraints(
              minWidth: 100,
            ),
            alignment: Alignment.center,
            child: Text(
              context.l10n.modifierManagementPageOf(
                (currentPage + 1).toString(),
                totalPages.toString(),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Next page.
          IconButton(
            tooltip: context.l10n.modifierManagementNextPage,
            onPressed: currentPage >= totalPages - 1
                ? null
                : () {
                    setState(() {
                      _currentPage = currentPage + 1;
                    });
                  },
            icon: const Icon(
              Icons.chevron_right,
            ),
          ),

          // Last page.
          IconButton(
            tooltip: context.l10n.modifierManagementLastPage,
            onPressed: currentPage >= totalPages - 1
                ? null
                : () {
                    setState(() {
                      _currentPage = totalPages - 1;
                    });
                  },
            icon: const Icon(
              Icons.last_page,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshModifiers,
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
