import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/modifier_models.dart';
import '../models/product_models.dart';
import '../services/demo_product_service.dart';
import '../services/modifier_service.dart';

/// Lets the user pick which products a modifier group applies to.
/// Loads the group's current assignment via `ModifierService.getGroupProducts`
/// and saves the new selection via `ModifierService.updateGroupProducts` —
/// both already existed on the service but weren't wired to any screen.
class ModifierProductAssignmentScreen extends ConsumerStatefulWidget {
  final ModifierGroupResponse group;

  const ModifierProductAssignmentScreen({super.key, required this.group});

  @override
  ConsumerState<ModifierProductAssignmentScreen> createState() =>
      _ModifierProductAssignmentScreenState();
}

class _ModifierProductAssignmentScreenState
    extends ConsumerState<ModifierProductAssignmentScreen> {
  static const Color primaryGreen = Color(0xFF8BCB3F);
  static const int _searchSize = 200;

  final TextEditingController _searchCtl = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Product> _products = const [];
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final assignedIds =
          await ref.read(modifierServiceProvider).getGroupProducts(widget.group.id);
      final products =
          await ref.read(productServiceProvider).getProducts(size: _searchSize);
      if (!mounted) return;
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(assignedIds);
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _search(value);
    });
  }

  Future<void> _search(String query) async {
    try {
      final products = await ref.read(productServiceProvider).getProducts(
            query: query.trim().isEmpty ? null : query.trim(),
            size: _searchSize,
          );
      if (!mounted) return;
      setState(() => _products = products);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.modifierProductAssignmentSearchFailed(e.toString()),
          ),
        ),
      );
    }
  }

  void _toggle(int productId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(productId);
      } else {
        _selectedIds.remove(productId);
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(modifierServiceProvider).updateGroupProducts(
            groupId: widget.group.id,
            productIds: _selectedIds.toList(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupName =
        widget.group.localizedName(ref.watch(appLanguageProvider));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          context.l10n.modifierProductAssignmentTitle(groupName),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    context.l10n.commonSave.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null && _products.isEmpty) {
              return _buildErrorState();
            }
            return _buildContent();
          },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadInitial,
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.modifierProductAssignmentDescription,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: context.l10n.posSearchProducts,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n
                    .modifierProductAssignmentSelectedCount(_selectedIds.length),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        Expanded(
          child: _products.isEmpty
              ? Center(
                  child: Text(context.l10n.modifierProductAssignmentNoProducts),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _products.length,
                  itemBuilder: (context, i) => _buildProductTile(_products[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildProductTile(Product product) {
    final selected = _selectedIds.contains(product.id);
    final lang = ref.watch(appLanguageProvider);
    final name = product.localizedName(lang);
    final categoryName = product.localizedCategoryName(lang);
    return CheckboxListTile(
      value: selected,
      onChanged: (value) => _toggle(product.id, value ?? false),
      activeColor: primaryGreen,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(name),
      subtitle: Text(
        '\$${product.price.toStringAsFixed(2)}'
        '${categoryName != null ? ' · $categoryName' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
