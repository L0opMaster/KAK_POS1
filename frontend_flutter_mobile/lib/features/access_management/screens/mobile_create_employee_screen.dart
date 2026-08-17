import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/employee_model.dart';
import '../../pos/models/user_account_model.dart';
import '../../pos/providers/employee_provider.dart';
import '../../pos/providers/role_provider.dart';
import '../../pos/providers/user_account_provider.dart';

const List<String> _kPayTypes = ['MONTHLY', 'HOURLY', 'DAILY'];
const List<String> _kStatuses = ['ACTIVE', 'INACTIVE'];

/// Create/edit an employee HR record (admin CRUD). Ported business logic
/// from `frontend-flutter-pos/lib/features/pos/screens/create_employee.dart`
/// — including its non-obvious "Has User Account" flow: an employee's
/// login account is resolved BEFORE the employee itself is
/// created/updated, via one of three paths:
///
/// 1. Already linked (`initialEmployee.linkedUserId != null`) — the account
///    itself can't be edited here (name/role/password changes happen on the
///    User Accounts screen); the switch here only controls whether to KEEP
///    the link (on) or clear it (off, sends `linkedUserId: null`).
/// 2. Not yet linked, switch turned on, "Create New" selected — creates a
///    brand-new login via `userAccountProvider.create(...)` first, then
///    uses the returned id as `linkedUserId`.
/// 3. Not yet linked, switch turned on, "Link Existing" selected — picks
///    from user accounts that aren't already linked to some OTHER employee
///    (diffed client-side against the currently-loaded employee list,
///    matching source exactly).
///
/// There is no server-side transaction tying employee-save to
/// account-creation — if step 2 succeeds but the employee save fails, an
/// orphan account can result, same risk as source.
///
/// Desktop's fixed multi-column form + AppBar-action Save button becomes a
/// single scrollable column with a bottom `FilledButton` here (mobile UI
/// reimplement), following this app's established
/// `mobile_create_supplier_screen.dart`/`mobile_create_table_screen.dart`
/// save/error-handling flow.
class MobileCreateEmployeeScreen extends ConsumerStatefulWidget {
  const MobileCreateEmployeeScreen({super.key, this.initialEmployee});

  final EmployeeResponse? initialEmployee;

  @override
  ConsumerState<MobileCreateEmployeeScreen> createState() =>
      _MobileCreateEmployeeScreenState();
}

class _MobileCreateEmployeeScreenState
    extends ConsumerState<MobileCreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameCtl;
  late final TextEditingController _codeCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _positionCtl;
  late final TextEditingController _departmentCtl;
  late final TextEditingController _baseSalaryCtl;
  late final TextEditingController _notesCtl;
  final TextEditingController _loginEmailCtl = TextEditingController();
  final TextEditingController _accountPasswordCtl = TextEditingController();

  DateTime? _hireDate;
  String _payType = _kPayTypes.first;
  String _status = _kStatuses.first;
  bool _obscurePassword = true;

  late bool _alreadyLinked;
  late bool _hasUserAccount;
  String _accountMode = 'new';
  String? _selectedRoleName;
  int? _selectedExistingUserId;

  bool _saving = false;

  bool get _isEditing => widget.initialEmployee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEmployee;
    _fullNameCtl = TextEditingController(text: e?.fullName ?? '');
    _codeCtl = TextEditingController(text: e?.employeeCode ?? '');
    _phoneCtl = TextEditingController(text: e?.phone ?? '');
    _emailCtl = TextEditingController(text: e?.email ?? '');
    _positionCtl = TextEditingController(text: e?.position ?? '');
    _departmentCtl = TextEditingController(text: e?.department ?? '');
    _baseSalaryCtl = TextEditingController(text: e == null ? '0' : '${e.baseSalary}');
    _notesCtl = TextEditingController(text: e?.notes ?? '');
    _hireDate = e?.hireDate != null ? DateTime.tryParse(e!.hireDate!) : null;
    _payType = (e != null && _kPayTypes.contains(e.payType)) ? e.payType : _kPayTypes.first;
    _status = (e != null && _kStatuses.contains(e.status)) ? e.status : _kStatuses.first;
    _alreadyLinked = e?.linkedUserId != null;
    _hasUserAccount = _alreadyLinked;

    Future.microtask(() {
      ref.read(roleProvider.notifier).load();
      ref.read(userAccountProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _codeCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _positionCtl.dispose();
    _departmentCtl.dispose();
    _baseSalaryCtl.dispose();
    _notesCtl.dispose();
    _loginEmailCtl.dispose();
    _accountPasswordCtl.dispose();
    super.dispose();
  }

  Future<void> _pickHireDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _hireDate = picked);
  }

  /// Resolves what `linkedUserId` to send with the employee request —
  /// possibly creating a brand-new user account first. Throws (caught by
  /// `_save()`) if required sub-fields are missing.
  Future<int?> _resolveLinkedUserId() async {
    final l10n = context.l10n;
    if (!_hasUserAccount) return null;
    if (_alreadyLinked) return widget.initialEmployee!.linkedUserId;

    if (_accountMode == 'new') {
      if (_loginEmailCtl.text.trim().isEmpty ||
          _accountPasswordCtl.text.isEmpty ||
          _selectedRoleName == null) {
        throw Exception(l10n.createEmployeeAccountFieldsRequiredError);
      }
      final created = await ref.read(userAccountProvider.notifier).create(
            UserAccountCreateRequest(
              email: _loginEmailCtl.text.trim(),
              fullName: _fullNameCtl.text.trim(),
              password: _accountPasswordCtl.text,
              roles: [_selectedRoleName!],
            ),
          );
      return created.id;
    }

    if (_selectedExistingUserId == null) {
      throw Exception(l10n.createEmployeeSelectExistingAccountError);
    }
    return _selectedExistingUserId;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _saving = true);

    try {
      final linkedUserId = await _resolveLinkedUserId();
      final request = EmployeeRequest(
        employeeCode: _codeCtl.text.trim().isEmpty ? null : _codeCtl.text.trim(),
        fullName: _fullNameCtl.text.trim(),
        phone: _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
        email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
        position: _positionCtl.text.trim().isEmpty ? null : _positionCtl.text.trim(),
        department:
            _departmentCtl.text.trim().isEmpty ? null : _departmentCtl.text.trim(),
        hireDate: _hireDate == null ? null : DateFormat('yyyy-MM-dd').format(_hireDate!),
        baseSalary: double.parse(_baseSalaryCtl.text.trim()),
        payType: _payType,
        status: _status,
        linkedUserId: linkedUserId,
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      );

      if (_isEditing) {
        await ref.read(employeeProvider.notifier).update(widget.initialEmployee!.id, request);
      } else {
        await ref.read(employeeProvider.notifier).create(request);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _isEditing ? l10n.createEmployeeUpdatedMessage : l10n.createEmployeeCreatedMessage,
        ),
        backgroundColor: PosTheme.successGreen,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${l10n.createEmployeeSaveFailedPrefix}: $e'),
        backgroundColor: PosTheme.errorRed,
      ));
    }
  }

  String _payTypeLabel(String value) =>
      '${value[0]}${value.substring(1).toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final roles = ref.watch(roleProvider).roles;
    final allUsers = ref.watch(userAccountProvider).users;
    final linkedIdsElsewhere = ref
        .watch(employeeProvider)
        .employees
        .where((e) => e.id != widget.initialEmployee?.id)
        .map((e) => e.linkedUserId)
        .whereType<int>()
        .toSet();
    final unlinkedUsers =
        allUsers.where((u) => !linkedIdsElsewhere.contains(u.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.createEmployeeEditTitle : l10n.createEmployeeNewTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PosTheme.spacingMd),
          children: [
            TextFormField(
              controller: _fullNameCtl,
              decoration: InputDecoration(
                labelText: l10n.createEmployeeFullNameLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _codeCtl,
              decoration: InputDecoration(
                labelText: l10n.createEmployeeCodeLabel,
                hintText: l10n.createEmployeeCodeHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.formPhone,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: PosTheme.spacingMd),
                Expanded(
                  child: TextFormField(
                    controller: _emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.formEmail,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _positionCtl,
              decoration: InputDecoration(
                labelText: l10n.createEmployeePositionLabel,
                hintText: l10n.createEmployeePositionHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _departmentCtl,
              decoration: InputDecoration(
                labelText: l10n.createEmployeeDepartmentLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            InkWell(
              onTap: _pickHireDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.createEmployeeHireDateLabel,
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  _hireDate == null
                      ? l10n.createEmployeeNotSetLabel
                      : DateFormat('yyyy-MM-dd').format(_hireDate!),
                ),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _baseSalaryCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.createEmployeeBaseSalaryLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').trim());
                if (parsed == null) return l10n.createEmployeeInvalidAmountError;
                if (parsed < 0) return l10n.createEmployeeNegativeAmountError;
                return null;
              },
            ),
            const SizedBox(height: PosTheme.spacingMd),
            DropdownButtonFormField<String>(
              initialValue: _payType,
              decoration: InputDecoration(
                labelText: l10n.createEmployeePayTypeLabel,
                border: const OutlineInputBorder(),
              ),
              items: _kPayTypes
                  .map((p) => DropdownMenuItem(value: p, child: Text(_payTypeLabel(p))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _payType = v);
              },
            ),
            const SizedBox(height: PosTheme.spacingMd),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: InputDecoration(
                labelText: l10n.createEmployeeStatusLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'ACTIVE', child: Text(l10n.commonActive)),
                DropdownMenuItem(value: 'INACTIVE', child: Text(l10n.commonInactive)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _notesCtl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.createEmployeeNotesLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingLg),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasUserAccount,
              title: Text(l10n.createEmployeeHasUserAccountTitle),
              subtitle: Text(l10n.createEmployeeHasUserAccountSubtitle),
              onChanged: (v) => setState(() => _hasUserAccount = v),
            ),
            if (_hasUserAccount && _alreadyLinked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(PosTheme.spacingMd),
                decoration: BoxDecoration(
                  color: PosTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.createEmployeeLinkedAccountPrefix} '
                      '${widget.initialEmployee?.linkedUserName ?? '#${widget.initialEmployee?.linkedUserId}'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: PosTheme.spacingXs),
                    Text(
                      l10n.createEmployeeLinkedAccountManageHint,
                      style: TextStyle(
                        fontSize: PosTheme.fontSizeXs,
                        color: PosTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              )
            else if (_hasUserAccount && !_alreadyLinked) ...[
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'new',
                    label: Text(l10n.createEmployeeCreateNewOption),
                  ),
                  ButtonSegment(
                    value: 'existing',
                    label: Text(l10n.createEmployeeLinkExistingOption),
                  ),
                ],
                selected: {_accountMode},
                onSelectionChanged: (v) => setState(() => _accountMode = v.first),
              ),
              const SizedBox(height: PosTheme.spacingMd),
              if (_accountMode == 'new') ...[
                TextFormField(
                  controller: _loginEmailCtl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.createEmployeeLoginEmailLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextFormField(
                  controller: _accountPasswordCtl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.createEmployeeAccountPasswordLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRoleName,
                  decoration: InputDecoration(
                    labelText: l10n.createEmployeeRoleLabel,
                    hintText: l10n.createEmployeeSelectRoleHint,
                    border: const OutlineInputBorder(),
                  ),
                  items: roles
                      .map((r) => DropdownMenuItem(value: r.name, child: Text(r.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedRoleName = v),
                ),
              ] else ...[
                if (unlinkedUsers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: PosTheme.spacingSm),
                    child: Text(
                      l10n.createEmployeeNoUnlinkedAccountsMessage,
                      style: TextStyle(color: PosTheme.textSecondaryOf(context)),
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _selectedExistingUserId,
                    decoration: InputDecoration(
                      labelText: l10n.createEmployeeExistingUserAccountLabel,
                      hintText: l10n.createEmployeeSelectUserHint,
                      border: const OutlineInputBorder(),
                    ),
                    items: unlinkedUsers
                        .map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.fullName} (${u.email})'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedExistingUserId = v),
                  ),
              ],
            ],
            const SizedBox(height: PosTheme.spacingLg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? l10n.createEmployeeSavingLabel
                    : (_isEditing
                        ? l10n.createEmployeeSaveChangesLabel
                        : l10n.createEmployeeCreateButtonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
