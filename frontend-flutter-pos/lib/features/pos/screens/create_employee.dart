import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/core/config/pos_theme.dart';
import 'package:frontend_flutter_pos/features/pos/models/employee_model.dart';
import 'package:frontend_flutter_pos/features/pos/models/user_account_model.dart';
import 'package:frontend_flutter_pos/features/pos/providers/employee_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/role_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/user_account_provider.dart';
import '../../../core/utils/l10n_extensions.dart';

const List<String> _payTypes = ['MONTHLY', 'HOURLY', 'DAILY'];
const List<String> _statuses = ['ACTIVE', 'INACTIVE'];

// 'new' creates a fresh login for this employee; 'existing' links an
// already-created (and not-yet-linked) user account instead.
const List<String> _accountModes = ['new', 'existing'];

class CreateEmployee extends ConsumerStatefulWidget {
  final EmployeeResponse? initialEmployee;

  const CreateEmployee({super.key, this.initialEmployee});

  @override
  ConsumerState<CreateEmployee> createState() => _CreateEmployeeState();
}

class _CreateEmployeeState extends ConsumerState<CreateEmployee> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtl = TextEditingController();
  final _employeeCodeCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _positionCtl = TextEditingController();
  final _departmentCtl = TextEditingController();
  final _baseSalaryCtl = TextEditingController(text: '0');
  final _notesCtl = TextEditingController();

  final _accountEmailCtl = TextEditingController();
  final _accountPasswordCtl = TextEditingController();

  DateTime? _hireDate;
  String _payType = _payTypes.first;
  String _status = _statuses.first;
  bool _saving = false;

  // --- Has User Account ---
  bool _hasUserAccount = false;
  String _accountMode = _accountModes.first;
  String? _selectedRoleName;
  int? _selectedExistingUserId;

  bool get _isEditing => widget.initialEmployee != null;

  // The employee already had a linked user before this screen opened —
  // toggling the switch off here just unlinks it, it never re-creates it.
  bool get _alreadyLinked => widget.initialEmployee?.linkedUserId != null;

  @override
  void initState() {
    super.initState();

    final employee = widget.initialEmployee;

    if (employee != null) {
      _fullNameCtl.text = employee.fullName;
      _employeeCodeCtl.text = employee.employeeCode ?? '';
      _phoneCtl.text = employee.phone ?? '';
      _emailCtl.text = employee.email ?? '';
      _positionCtl.text = employee.position ?? '';
      _departmentCtl.text = employee.department ?? '';
      _baseSalaryCtl.text = employee.baseSalary.toString();
      _notesCtl.text = employee.notes ?? '';
      _hireDate = employee.hireDate == null || employee.hireDate!.isEmpty
          ? null
          : DateTime.tryParse(employee.hireDate!);
      _payType =
          _payTypes.contains(employee.payType) ? employee.payType : _payType;
      _status = _statuses.contains(employee.status) ? employee.status : _status;
      _hasUserAccount = employee.linkedUserId != null;
    }

    Future.microtask(() async {
      await ref.read(roleProvider.notifier).load();
      await ref.read(userAccountProvider.notifier).load();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _employeeCodeCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _positionCtl.dispose();
    _departmentCtl.dispose();
    _baseSalaryCtl.dispose();
    _notesCtl.dispose();
    _accountEmailCtl.dispose();
    _accountPasswordCtl.dispose();
    super.dispose();
  }

  Future<void> _pickHireDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      setState(() => _hireDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Resolves the linkedUserId to send with the employee, creating or
  /// linking a user account first if the "Has User Account" section
  /// requires it. Returns null when no account should be linked.
  Future<int?> _resolveLinkedUserId() async {
    if (!_hasUserAccount) {
      return null;
    }

    // Already linked before this screen opened — leave it untouched.
    if (_alreadyLinked) {
      return widget.initialEmployee!.linkedUserId;
    }

    if (_accountMode == 'existing') {
      if (_selectedExistingUserId == null) {
        throw Exception(context.l10n.createEmployeeSelectExistingAccountError);
      }
      return _selectedExistingUserId;
    }

    // Create a brand-new login for this employee.
    if (_accountEmailCtl.text.trim().isEmpty ||
        _accountPasswordCtl.text.trim().isEmpty ||
        _selectedRoleName == null) {
      throw Exception(context.l10n.createEmployeeAccountFieldsRequiredError);
    }

    final created = await ref.read(userAccountProvider.notifier).create(
          UserAccountCreateRequest(
            email: _accountEmailCtl.text.trim(),
            fullName: _fullNameCtl.text.trim(),
            password: _accountPasswordCtl.text.trim(),
            roles: [_selectedRoleName!],
          ),
        );
    return created.id;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final linkedUserId = await _resolveLinkedUserId();

      final request = EmployeeRequest(
        employeeCode: _employeeCodeCtl.text.trim().isEmpty
            ? null
            : _employeeCodeCtl.text.trim(),
        fullName: _fullNameCtl.text.trim(),
        phone: _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
        email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
        position:
            _positionCtl.text.trim().isEmpty ? null : _positionCtl.text.trim(),
        department: _departmentCtl.text.trim().isEmpty
            ? null
            : _departmentCtl.text.trim(),
        hireDate: _hireDate == null ? null : _formatDate(_hireDate!),
        baseSalary: double.tryParse(_baseSalaryCtl.text.trim()) ?? 0,
        payType: _payType,
        status: _status,
        linkedUserId: linkedUserId,
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      );

      if (_isEditing) {
        await ref
            .read(employeeProvider.notifier)
            .update(widget.initialEmployee!.id, request);
      } else {
        await ref.read(employeeProvider.notifier).create(request);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? context.l10n.createEmployeeUpdatedMessage
              : context.l10n.createEmployeeCreatedMessage),
          backgroundColor: PosTheme.successGreen,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.createEmployeeSaveFailedPrefix}: $e'),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildUserAccountSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.createEmployeeHasUserAccountTitle),
            subtitle: Text(
              context.l10n.createEmployeeHasUserAccountSubtitle,
            ),
            value: _hasUserAccount,
            activeThumbColor: PosTheme.primaryGreen,
            onChanged: (value) => setState(() => _hasUserAccount = value),
          ),
          if (_hasUserAccount) ...[
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (_alreadyLinked)
              _buildAlreadyLinkedInfo()
            else
              _buildAccountCreationFields(),
          ],
        ],
      ),
    );
  }

  Widget _buildAlreadyLinkedInfo() {
    final employee = widget.initialEmployee!;
    return Row(
      children: [
        Icon(Icons.verified_user, color: PosTheme.primaryGreen, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${context.l10n.createEmployeeLinkedAccountPrefix} '
            '${employee.linkedUserName ?? '#${employee.linkedUserId}'}.\n'
            '${context.l10n.createEmployeeLinkedAccountManageHint}',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCreationFields() {
    final roles = ref.watch(roleProvider).roles;
    final allUsers = ref.watch(userAccountProvider).users;
    final linkedUserIds = ref
        .watch(employeeProvider)
        .employees
        .map((e) => e.linkedUserId)
        .whereType<int>()
        .toSet();
    final availableUsers =
        allUsers.where((u) => !linkedUserIds.contains(u.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
                value: 'new',
                label: Text(context.l10n.createEmployeeCreateNewOption)),
            ButtonSegment(
                value: 'existing',
                label: Text(context.l10n.createEmployeeLinkExistingOption)),
          ],
          selected: {_accountMode},
          onSelectionChanged: (selection) {
            setState(() => _accountMode = selection.first);
          },
        ),
        const SizedBox(height: 12),
        if (_accountMode == 'new') ...[
          TextFormField(
            controller: _accountEmailCtl,
            decoration: InputDecoration(
              labelText: context.l10n.createEmployeeLoginEmailLabel,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _accountPasswordCtl,
            decoration: InputDecoration(
              labelText: context.l10n.createEmployeeAccountPasswordLabel,
              border: const OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedRoleName,
            decoration: InputDecoration(
              labelText: context.l10n.createEmployeeRoleLabel,
              border: const OutlineInputBorder(),
            ),
            hint: Text(context.l10n.createEmployeeSelectRoleHint),
            items: roles
                .map(
                    (r) => DropdownMenuItem(value: r.name, child: Text(r.name)))
                .toList(),
            onChanged: (value) => setState(() => _selectedRoleName = value),
          ),
        ] else ...[
          DropdownButtonFormField<int>(
            initialValue: _selectedExistingUserId,
            decoration: InputDecoration(
              labelText: context.l10n.createEmployeeExistingUserAccountLabel,
              border: const OutlineInputBorder(),
            ),
            hint: Text(context.l10n.createEmployeeSelectUserHint),
            items: availableUsers
                .map((u) => DropdownMenuItem(
                      value: u.id,
                      child: Text('${u.fullName} (${u.email})'),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _selectedExistingUserId = value),
          ),
          if (availableUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.createEmployeeNoUnlinkedAccountsMessage,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? context.l10n.createEmployeeEditTitle
            : context.l10n.createEmployeeNewTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    context.l10n.commonSave,
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _fullNameCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createEmployeeFullNameLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.commonRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _employeeCodeCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createEmployeeCodeLabel,
                hintText: context.l10n.createEmployeeCodeHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtl,
              decoration: InputDecoration(
                labelText: context.l10n.formPhone,
                hintText: '+855 12 345 678',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtl,
              decoration: InputDecoration(
                labelText: context.l10n.formEmail,
                hintText: 'employee@example.com',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _positionCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createEmployeePositionLabel,
                hintText: context.l10n.createEmployeePositionHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _departmentCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createEmployeeDepartmentLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickHireDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.l10n.createEmployeeHireDateLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(
                  _hireDate == null
                      ? context.l10n.createEmployeeNotSetLabel
                      : _formatDate(_hireDate!),
                  style: _hireDate == null
                      ? const TextStyle(color: PosTheme.textHint)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _baseSalaryCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createEmployeeBaseSalaryLabel,
                border: const OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final value = double.tryParse((v ?? '').trim());

                if (value == null) {
                  return context.l10n.createEmployeeInvalidAmountError;
                }

                if (value < 0) {
                  return context.l10n.createEmployeeNegativeAmountError;
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _payType,
                    decoration: InputDecoration(
                      labelText: context.l10n.createEmployeePayTypeLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: _payTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              '${type[0]}${type.substring(1).toLowerCase()}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _payType = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(
                      labelText: context.l10n.createEmployeeStatusLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: _statuses
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(
                              '${status[0]}${status.substring(1).toLowerCase()}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildUserAccountSection(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createEmployeeNotesLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving
                    ? context.l10n.createEmployeeSavingLabel
                    : (_isEditing
                        ? context.l10n.createEmployeeSaveChangesLabel
                        : context.l10n.createEmployeeCreateButtonLabel)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
