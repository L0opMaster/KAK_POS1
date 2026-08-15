/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// customer_models.dart` — PARTIAL PORT. Only `Customer` (needed to
/// search/select a customer for a sale) is ported. `CreateCustomerRequest`
/// (admin CRUD, out of scope) and the credit-ledger/collection classes
/// (`CreditCollectionCommit`/`CreditCollectionAllocationInput`/
/// `CreditCollectionAllocationRow`/`CreditLedgerResponse`/
/// `CustomerSaleHistory`/`CreditCollectionPreview` — all back a
/// credit-payment feature that's Day 11+/Payment scope) are not ported.
class Customer {
  final int id;
  final double creditLimit;
  final double creditBalance;
  final String type;
  final String status;
  final String nameEn;
  final String displayName;
  final String? nameKm;
  final String? phone;
  final String? email;
  final String? address;
  final String? contactPerson;
  final String? notes;
  final int loyaltyPoints;
  final bool overdue;

  const Customer({
    required this.id,
    required this.creditLimit,
    required this.creditBalance,
    required this.type,
    required this.status,
    required this.nameEn,
    required this.displayName,
    this.nameKm,
    this.phone,
    this.email,
    this.address,
    this.contactPerson,
    this.notes,
    this.loyaltyPoints = 0,
    this.overdue = false,
  });

  String get resolvedDisplayName =>
      displayName.isNotEmpty ? displayName : nameKm?.trim().isNotEmpty == true
          ? nameKm!
          : nameEn;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: (json['id'] as num?)?.toInt() ?? 0,
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0,
      creditBalance: (json['creditBalance'] as num?)?.toDouble() ?? 0,
      type: (json['type'] as String?) ?? 'WALK_IN',
      status: (json['status'] as String?) ?? 'ACTIVE',
      nameEn: (json['nameEn'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      nameKm: json['nameKm'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      contactPerson: json['contactPerson'] as String?,
      notes: json['notes'] as String?,
      loyaltyPoints: (json['loyaltyPoints'] as num?)?.toInt() ?? 0,
      overdue: json['overdue'] as bool? ?? false,
    );
  }
}
