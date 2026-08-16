import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modifier_models.dart';
import '../providers/modifier_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';

class CreateModifier extends ConsumerStatefulWidget {
  final ModifierGroupResponse? initialModifier;

  const CreateModifier({
    super.key,
    this.initialModifier,
  });

  bool get isEditing => initialModifier != null;

  @override
  ConsumerState<CreateModifier> createState() {
    return _CreateModifierState();
  }
}

class _CreateModifierState extends ConsumerState<CreateModifier> {
  final _formKey = GlobalKey<FormState>();
  final _modifierNameController = TextEditingController();

  final List<ModifierOptionControllers> _options = [];
  final List<int> _deletedOptionIds = [];

  static const Color primaryGreen = Color(0xFF8BCB3F);
  static const Color darkGreen = Color(0xFF73B52E);
  static const double fieldHeight = 84;

  late String _initialSnapshot;

  bool _allowPop = false;
  bool _isRequired = false;
  bool _multiSelect = false;

  @override
  void initState() {
    super.initState();

    final modifier = widget.initialModifier;

    if (modifier == null) {
      _options.add(
        ModifierOptionControllers(),
      );
    } else {
      _modifierNameController.text = modifier.nameEn;
      _isRequired = modifier.isRequired;
      _multiSelect = modifier.multiSelect;

      if (modifier.options.isEmpty) {
        _options.add(
          ModifierOptionControllers(),
        );
      } else {
        for (final option in modifier.options) {
          _options.add(
            ModifierOptionControllers(
              id: option.id,
              name: option.nameEn,
              price: _formatPrice(option.priceDelta),
            ),
          );
        }
      }
    }

    _initialSnapshot = _createSnapshot();
  }

  @override
  void dispose() {
    _modifierNameController.dispose();

    for (final option in _options) {
      option.dispose();
    }

    super.dispose();
  }

  String _formatPrice(double price) {
    if (price == price.truncateToDouble()) {
      return price.toInt().toString();
    }

    return price.toString();
  }

  String _createSnapshot() {
    return jsonEncode({
      'name': _modifierNameController.text,
      'required': _isRequired,
      'multiSelect': _multiSelect,
      'options': _options.map((option) {
        return {
          'id': option.id,
          'name': option.nameController.text,
          'price': option.priceController.text,
        };
      }).toList(),
      'deletedOptionIds': _deletedOptionIds,
    });
  }

  bool get _hasUnsavedChanges {
    return _createSnapshot() != _initialSnapshot;
  }

  void _addOption() {
    setState(() {
      _options.add(
        ModifierOptionControllers(),
      );
    });
  }

  void _removeOption(int index) {
    if (_options.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.createModifierMinOneOptionError,
          ),
        ),
      );

      return;
    }

    final removedOption = _options.removeAt(index);

    if (removedOption.id != null) {
      _deletedOptionIds.add(removedOption.id!);
    }

    removedOption.dispose();

    setState(() {});
  }

  Future<void> _requestClose() async {
    if (!_hasUnsavedChanges) {
      _closePage();
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            context.l10n.dialogUnsavedChangesTitle,
          ),
          content: Text(
            context.l10n.createModifierDiscardChangesMessage,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                context.l10n.createModifierContinueEditingButton,
                style: const TextStyle(
                  color: Colors.black87,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                context.l10n.createModifierDiscardChangesButton,
                style: const TextStyle(
                  color: darkGreen,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (discard == true) {
      _closePage();
    }
  }

  void _closePage([bool? result]) {
    if (!mounted) {
      return;
    }

    setState(() {
      _allowPop = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  Future<void> _saveModifier() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    if (_options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'At least one option is required.',
          ),
        ),
      );

      return;
    }

    final modifierName = _modifierNameController.text.trim();

    final groupRequest = ModifierGroupRequest(
      nameEn: modifierName,

      // Backend requires nameKm to be nonblank.
      // Replace this with a Khmer controller when needed.
      nameKm: modifierName,

      isRequired: _isRequired,
      multiSelect: _multiSelect,
      active: true,
      displayOrder: widget.initialModifier?.displayOrder ?? 0,
    );

    try {
      if (widget.isEditing) {
        final upserts = List.generate(
          _options.length,
          (index) {
            final option = _options[index];
            final optionName = option.nameController.text.trim();

            return ModifierOptionUpsert(
              id: option.id,
              request: ModifierOptionRequest(
                nameEn: optionName,

                // Backend requires nameKm.
                nameKm: optionName,

                priceDelta: double.tryParse(
                      option.priceController.text.trim(),
                    ) ??
                    0,
                active: true,
                displayOrder: index,
              ),
            );
          },
        );

        await ref.read(modifiersProvider.notifier).updateModifier(
              groupId: widget.initialModifier!.id,
              groupRequest: groupRequest,
              optionUpserts: upserts,
              deletedOptionIds: _deletedOptionIds,
            );
      } else {
        final requests = List.generate(
          _options.length,
          (index) {
            final option = _options[index];
            final optionName = option.nameController.text.trim();

            return ModifierOptionRequest(
              nameEn: optionName,
              nameKm: optionName,
              priceDelta: double.tryParse(
                    option.priceController.text.trim(),
                  ) ??
                  0,
              active: true,
              displayOrder: index,
            );
          },
        );

        await ref.read(modifiersProvider.notifier).createModifier(
              groupRequest: groupRequest,
              optionRequests: requests,
            );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? context.l10n.createModifierUpdatedMessage
                : context.l10n.createModifierCreatedMessage,
          ),
        ),
      );

      _closePage(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      final error = ref.read(modifiersProvider).error ??
          context.l10n.createModifierSaveFailedFallback;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    }
  }

  Future<void> _deleteModifier() async {
    final modifier = widget.initialModifier;

    if (modifier == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.createModifierDeleteTitle),
          content: Text(
            '${context.l10n.createModifierDeleteConfirmPrefix} '
            '"${modifier.localizedName(ref.read(appLanguageProvider))}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(context.l10n.commonCancel.toUpperCase()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                context.l10n.commonDelete.toUpperCase(),
                style: const TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(modifiersProvider.notifier).deleteModifier(modifier.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.createModifierDeletedMessage,
          ),
        ),
      );

      _closePage(true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      final error = ref.read(modifiersProvider).error ??
          context.l10n.createModifierDeleteFailedFallback;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modifiersProvider);

    return PopScope<bool>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _requestClose();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: Text(
            widget.isEditing
                ? context.l10n.createModifierEditTitle
                : context.l10n.createModifierCreateTitle,
          ),
          // backgroundColor: Colors.white,
          // foregroundColor: Colors.black87,
          elevation: 1,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Align(
              alignment: Alignment.topLeft,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 650,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          color: Colors.white,
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              30,
                              36,
                              30,
                              28,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Center(
                                  child: CircleAvatar(
                                    radius: 55,
                                    backgroundColor: primaryGreen,
                                    child: Icon(
                                      Icons.description_outlined,
                                      size: 58,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 65),
                                _buildModifierNameField(),
                                const SizedBox(height: 42),
                                ...List.generate(
                                  _options.length,
                                  (index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 18,
                                      ),
                                      child: _buildOptionRow(index),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: state.isSaving ? null : _addOption,
                                  style: TextButton.styleFrom(
                                    foregroundColor: darkGreen,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 14,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 28,
                                  ),
                                  label: Text(
                                    context.l10n.createModifierAddOptionButton,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    context.l10n.commonRequired,
                                  ),
                                  subtitle: Text(
                                    context.l10n.createModifierRequiredSubtitle,
                                  ),
                                  value: _isRequired,
                                  activeThumbColor: primaryGreen,
                                  onChanged: state.isSaving
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _isRequired = value;
                                          });
                                        },
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    context.l10n.createModifierMultiSelectTitle,
                                  ),
                                  subtitle: Text(
                                    context
                                        .l10n.createModifierMultiSelectSubtitle,
                                  ),
                                  value: _multiSelect,
                                  activeThumbColor: primaryGreen,
                                  onChanged: state.isSaving
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _multiSelect = value;
                                          });
                                        },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (widget.isEditing)
                              ElevatedButton(
                                onPressed: state.isDeleting || state.isSaving
                                    ? null
                                    : _deleteModifier,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  elevation: 3,
                                  minimumSize: const Size(95, 52),
                                ),
                                child: state.isDeleting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        context.l10n.commonDelete.toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: state.isSaving ? null : _requestClose,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                elevation: 3,
                                minimumSize: const Size(95, 52),
                              ),
                              child: Text(
                                context.l10n.commonCancel.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: state.isSaving ? null : _saveModifier,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                minimumSize: const Size(85, 52),
                              ),
                              child: state.isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      context.l10n.commonSave.toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModifierNameField() {
    return SizedBox(
      height: fieldHeight,
      child: TextFormField(
        controller: _modifierNameController,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
        decoration: _inputDecoration(
          labelText: context.l10n.createModifierNameLabel,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return context.l10n.createModifierNameRequiredError;
          }

          return null;
        },
      ),
    );
  }

  Widget _buildOptionRow(int index) {
    final option = _options[index];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;

        if (compact) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 17),
                    child: Icon(
                      Icons.drag_handle,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _optionNameField(option),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: IconButton(
                      onPressed: () {
                        _removeOption(index);
                      },
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 36,
                  right: 48,
                ),
                child: _priceField(option),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 17),
              child: Icon(
                Icons.drag_handle,
                size: 28,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: _optionNameField(option),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _priceField(option),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: IconButton(
                tooltip: context.l10n.createModifierDeleteOptionTooltip,
                onPressed: () {
                  _removeOption(index);
                },
                icon: const Icon(
                  Icons.delete,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _optionNameField(
    ModifierOptionControllers option,
  ) {
    return SizedBox(
      height: fieldHeight,
      child: TextFormField(
        controller: option.nameController,
        decoration: _inputDecoration(
          labelText: option.nameController.text.isEmpty
              ? null
              : context.l10n.createModifierOptionNameLabel,
          hintText: context.l10n.createModifierOptionNameLabel,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return context.l10n.createModifierOptionNameRequiredError;
          }

          return null;
        },
      ),
    );
  }

  Widget _priceField(
    ModifierOptionControllers option,
  ) {
    return SizedBox(
      height: fieldHeight,
      child: TextFormField(
        controller: option.priceController,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(r'^\d*\.?\d{0,2}'),
          ),
        ],
        decoration: _inputDecoration(
          labelText: context.l10n.formPrice,
          prefixText: 'KHR ',
          hintText: '0',
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return context.l10n.createModifierPriceRequiredError;
          }

          final price = double.tryParse(value.trim());

          if (price == null) {
            return context.l10n.createModifierInvalidPriceError;
          }

          if (price < 0) {
            return context.l10n.createModifierNegativePriceError;
          }

          return null;
        },
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? labelText,
    String? hintText,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixText: prefixText,

      // Keeps the total field height unchanged.
      helperText: ' ',
      helperStyle: const TextStyle(
        fontSize: 12,
        height: 1,
      ),
      errorStyle: const TextStyle(
        fontSize: 12,
        height: 1,
      ),
      errorMaxLines: 1,

      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),

      labelStyle: const TextStyle(
        color: Colors.grey,
      ),
      hintStyle: const TextStyle(
        color: Colors.grey,
      ),

      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(
          color: Color(0xFFD6D6D6),
        ),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(
          color: primaryGreen,
          width: 2,
        ),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
    );
  }
}

class ModifierOptionControllers {
  final int? id;
  final TextEditingController nameController;
  final TextEditingController priceController;

  ModifierOptionControllers({
    this.id,
    String name = '',
    String price = '0',
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}
