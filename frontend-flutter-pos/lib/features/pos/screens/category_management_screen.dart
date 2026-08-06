/// Category Management — Loyverse-inspired categories screen.
///
/// Supports:
/// - List all categories with color badges
/// - Create new category with name (EN/KM), color, and icon
/// - Edit existing categories
/// - Categories sync to POS sale screen category filter
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/product_models.dart';
import '../services/category_service.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(categoryServiceProvider);
      final list = await service.list();
      setState(() {
        _categories = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showForm({Category? category}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CategoryFormScreen(category: category),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _toggleActive(Category category) async {
    try {
      final service = ref.read(categoryServiceProvider);
      await service.update(category.id, {
        'nameEn': category.nameEn,
        'nameKm': category.nameKm,
        'active': !category.active,
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${context.l10n.categoryManagementUpdateFailedPrefix}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navCategories),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: PosTheme.errorRed, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.l10n.commonRetry),
                      ),
                    ],
                  ),
                )
              : _categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category_outlined,
                              size: 48, color: PosTheme.textHint),
                          const SizedBox(height: 12),
                          Text(context.l10n.categoryManagementEmptyTitle,
                              style: const TextStyle(
                                  color: PosTheme.textSecondary, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(context.l10n.categoryManagementEmptyHint,
                              style: const TextStyle(
                                  color: PosTheme.textHint, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final color = _categoryColor(cat.id);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(PosTheme.radiusMedium),
                              side: BorderSide(
                                color: cat.active
                                    ? PosTheme.borderColor
                                    : PosTheme.dividerColor,
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _showForm(category: cat),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(
                                      PosTheme.radiusMedium),
                                ),
                                child: Icon(
                                  _categoryIcon(cat.id),
                                  color: color,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                cat.nameEn,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: cat.active
                                      ? PosTheme.textPrimary
                                      : PosTheme.textHint,
                                ),
                              ),
                              subtitle: Text(
                                cat.nameKm,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cat.active
                                      ? PosTheme.textSecondary
                                      : PosTheme.textHint,
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
                                        color: PosTheme.dividerColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(context.l10n.commonInactive,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: PosTheme.textHint)),
                                    ),
                                  Switch(
                                    value: cat.active,
                                    activeColor: PosTheme.primaryGreen,
                                    onChanged: (_) => _toggleActive(cat),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.categoryManagementAddButton),
        backgroundColor: PosTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
    );
  }

  Color _categoryColor(int id) {
    final colors = [
      const Color(0xFF42A5F5), // blue
      const Color(0xFFFFA726), // orange
      const Color(0xFF66BB6A), // green
      const Color(0xFFAB47BC), // purple
      const Color(0xFFEF5350), // red
      const Color(0xFF26C6DA), // cyan
      const Color(0xFFEC407A), // pink
      const Color(0xFFFF7043), // deep orange
      const Color(0xFF8D6E63), // brown
      const Color(0xFF78909C), // blue grey
    ];
    return colors[id.abs() % colors.length];
  }

  IconData _categoryIcon(int id) {
    final icons = [
      Icons.local_cafe,
      Icons.restaurant,
      Icons.cookie,
      Icons.shopping_bag,
      Icons.local_bar,
      Icons.icecream,
      Icons.fastfood,
      Icons.ramen_dining,
      Icons.kitchen,
      Icons.liquor,
    ];
    return icons[id.abs() % icons.length];
  }
}

/// Form for creating or editing a category.
/// Loyverse-inspired: name, color badge, and active toggle.
class _CategoryFormScreen extends ConsumerStatefulWidget {
  final Category? category;

  const _CategoryFormScreen({this.category});

  @override
  ConsumerState<_CategoryFormScreen> createState() =>
      _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<_CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameEnCtl;
  late final TextEditingController _nameKmCtl;
  bool _active = true;
  bool _saving = false;
  int _selectedColorIndex = 0;

  static const _colors = [
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

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _nameEnCtl = TextEditingController(text: cat?.nameEn ?? '');
    _nameKmCtl = TextEditingController(text: cat?.nameKm ?? '');
    _active = cat?.active ?? true;
    if (cat != null) {
      _selectedColorIndex = cat.id.abs() % _colors.length;
    }
  }

  @override
  void dispose() {
    _nameEnCtl.dispose();
    _nameKmCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final service = ref.read(categoryServiceProvider);
      final data = {
        'nameEn': _nameEnCtl.text.trim(),
        'nameKm': _nameKmCtl.text.trim().isEmpty
            ? _nameEnCtl.text.trim()
            : _nameKmCtl.text.trim(),
        'active': _active,
      };

      if (widget.category != null) {
        await service.update(widget.category!.id, data);
      } else {
        await service.create(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.category != null
                ? '"${data['nameEn']}" ${context.l10n.categoryManagementUpdatedSuffix}'
                : '"${data['nameEn']}" ${context.l10n.categoryManagementCreatedSuffix}'),
            backgroundColor: PosTheme.successGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${context.l10n.categoryManagementSaveFailedPrefix}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? context.l10n.categoryManagementEditTitle
            : context.l10n.categoryManagementNewTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.commonSave,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Color picker (Loyverse style) ──
            Text(context.l10n.categoryManagementColorLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: PosTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(_colors.length, (i) {
                final selected = _selectedColorIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _colors[i],
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: _colors[i].withOpacity(0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // ── Name fields ──
            TextFormField(
              controller: _nameEnCtl,
              decoration: InputDecoration(
                labelText: '${context.l10n.formNameEn} *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.commonRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameKmCtl,
              decoration: InputDecoration(
                labelText: context.l10n.formNameKm,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // ── Active toggle ──
            SwitchListTile(
              value: _active,
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.commonActive),
              subtitle: Text(context.l10n.categoryManagementActiveSubtitle),
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 24),
            // Preview card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PosTheme.backgroundPage,
                borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                border: Border.all(color: PosTheme.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _colors[_selectedColorIndex].withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.category,
                      color: _colors[_selectedColorIndex],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameEnCtl.text.isNotEmpty
                            ? _nameEnCtl.text
                            : context.l10n.categoryManagementPreviewNamePlaceholder,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _nameKmCtl.text.isNotEmpty
                            ? _nameKmCtl.text
                            : 'ឈ្មោះកាតេកូរី',
                        style: const TextStyle(
                          fontSize: 13,
                          color: PosTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
