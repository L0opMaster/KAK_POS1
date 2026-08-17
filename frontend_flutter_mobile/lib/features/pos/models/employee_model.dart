/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// employee_model.dart` — COPY/ADAPT NEARLY EXACTLY. `EmployeeRequest` is
/// the create/update payload (optional fields omitted from `toJson()` when
/// null); `EmployeeResponse` is the read model, with `linkedUserName` and
/// two read-only payroll-aggregate fields (`openAdvanceBalance`/
/// `unpaidExpenseTotal`) that only ever come from the server, never sent
/// back up.
class EmployeeRequest {
  final String? employeeCode;
  final String fullName;
  final String? phone;
  final String? email;
  final String? position;
  final String? department;
  final String? hireDate;
  final double baseSalary;
  final String payType;
  final String status;
  final int? linkedUserId;
  final String? notes;

  const EmployeeRequest({
    this.employeeCode,
    required this.fullName,
    this.phone,
    this.email,
    this.position,
    this.department,
    this.hireDate,
    required this.baseSalary,
    required this.payType,
    required this.status,
    this.linkedUserId,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      if (employeeCode != null && employeeCode!.isNotEmpty)
        'employeeCode': employeeCode,
      'fullName': fullName,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (position != null && position!.isNotEmpty) 'position': position,
      if (department != null && department!.isNotEmpty) 'department': department,
      if (hireDate != null) 'hireDate': hireDate,
      'baseSalary': baseSalary,
      'payType': payType,
      'status': status,
      'linkedUserId': linkedUserId,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}

class EmployeeResponse {
  final int id;
  final String? employeeCode;
  final String fullName;
  final String? phone;
  final String? email;
  final String? position;
  final String? department;
  final String? hireDate;
  final double baseSalary;
  final String payType;
  final String status;
  final int? linkedUserId;
  final String? linkedUserName;
  final String? notes;
  final double? openAdvanceBalance;
  final double? unpaidExpenseTotal;

  const EmployeeResponse({
    required this.id,
    this.employeeCode,
    required this.fullName,
    this.phone,
    this.email,
    this.position,
    this.department,
    this.hireDate,
    required this.baseSalary,
    required this.payType,
    required this.status,
    this.linkedUserId,
    this.linkedUserName,
    this.notes,
    this.openAdvanceBalance,
    this.unpaidExpenseTotal,
  });

  factory EmployeeResponse.fromJson(Map<String, dynamic> json) {
    return EmployeeResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeCode: json['employeeCode'] as String?,
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      position: json['position'] as String?,
      department: json['department'] as String?,
      hireDate: json['hireDate'] as String?,
      baseSalary: (json['baseSalary'] as num?)?.toDouble() ?? 0,
      payType: json['payType'] as String? ?? 'MONTHLY',
      status: json['status'] as String? ?? 'ACTIVE',
      linkedUserId: (json['linkedUserId'] as num?)?.toInt(),
      linkedUserName: json['linkedUserName'] as String?,
      notes: json['notes'] as String?,
      openAdvanceBalance: (json['openAdvanceBalance'] as num?)?.toDouble(),
      unpaidExpenseTotal: (json['unpaidExpenseTotal'] as num?)?.toDouble(),
    );
  }
}
