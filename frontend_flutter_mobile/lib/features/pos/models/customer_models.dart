/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// customer_models.dart`. `Customer` was originally a partial port (only
/// what the sale-time picker needed); this now also carries
/// `CreateCustomerRequest` (admin CRUD), `CreditLedgerEntry`/
/// `CreditLedgerResponse` (the customer credit ledger — a customer's credit
/// sales plus the individual payments collected against them, one entry
/// per row, exactly mirroring backend's `CreditCollectionDtos.LedgerEntry`/
/// `LedgerResponse`), and `CustomerSaleHistoryEntry` (the
/// `/api/customers/{id}/history` purchase-history endpoint — given a proper
/// typed model here rather than source's ad hoc `Map<String,dynamic>`
/// reads, since this is a fresh mobile screen, not a byte-for-byte port).
class Customer {
  final int id;
  final double creditLimit;
  final double creditBalance;
  final bool creditHold;
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
    this.creditHold = false,
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
      creditHold: json['creditHold'] as bool? ?? false,
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

/// Create/update payload — same class serves both (matches source).
/// Optional fields are omitted from `toJson()` entirely when null (not sent
/// as a `null` literal), except `creditLimit`/`type`/`status`/`nameEn`
/// which default to `0`/`'WALK_IN'`/`'ACTIVE'`/`''` respectively, matching
/// source's `CreateCustomerRequest.toJson()` exactly.
class CreateCustomerRequest {
  final double? creditLimit;
  final String? type;
  final String? status;
  final String? nameEn;
  final String? nameKm;
  final String? displayName;
  final String? phone;
  final String? email;
  final String? address;
  final String? contactPerson;
  final String? notes;
  final int? loyaltyPoints;

  const CreateCustomerRequest({
    this.creditLimit,
    this.type,
    this.status,
    this.nameEn,
    this.nameKm,
    this.displayName,
    this.phone,
    this.email,
    this.address,
    this.contactPerson,
    this.notes,
    this.loyaltyPoints,
  });

  Map<String, dynamic> toJson() => {
        'creditLimit': creditLimit ?? 0,
        'type': type ?? 'WALK_IN',
        'status': status ?? 'ACTIVE',
        'nameEn': nameEn ?? '',
        if (nameKm != null) 'nameKm': nameKm,
        if (displayName != null) 'displayName': displayName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (contactPerson != null) 'contactPerson': contactPerson,
        if (notes != null) 'notes': notes,
        if (loyaltyPoints != null) 'loyaltyPoints': loyaltyPoints,
      };
}

/// One row of a customer's credit ledger. `entryType` is one of
/// `OPENING_BALANCE`/`CREDIT_SALE`/`COLLECTION`/`SALE_RETURN`/
/// `CREDIT_NOTE`/`DEBIT_NOTE`. `remainingAmount` is only meaningful on
/// `CREDIT_SALE` rows (what's still owed on that specific sale);
/// `COLLECTION` rows carry `saleId` to link a payment back to the sale it
/// paid down. Backend returns entries pre-sorted newest-first.
class CreditLedgerEntry {
  final String entryType;
  final String? targetType;
  final int? saleId;
  final String? invoiceNumber;
  final int? openingBalanceId;
  final int? paymentId;
  final double amount;
  final double? remainingAmount;
  final String? note;
  final String createdAt;
  final int? agingDays;

  const CreditLedgerEntry({
    required this.entryType,
    this.targetType,
    this.saleId,
    this.invoiceNumber,
    this.openingBalanceId,
    this.paymentId,
    required this.amount,
    this.remainingAmount,
    this.note,
    required this.createdAt,
    this.agingDays,
  });

  factory CreditLedgerEntry.fromJson(Map<String, dynamic> json) {
    return CreditLedgerEntry(
      entryType: json['entryType'] as String? ?? '',
      targetType: json['targetType'] as String?,
      saleId: (json['saleId'] as num?)?.toInt(),
      invoiceNumber: json['invoiceNumber'] as String?,
      openingBalanceId: (json['openingBalanceId'] as num?)?.toInt(),
      paymentId: (json['paymentId'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble(),
      note: json['note'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      agingDays: (json['agingDays'] as num?)?.toInt(),
    );
  }
}

/// `GET /api/customers/{id}/credit-ledger` response — a customer's credit
/// balance/limit/hold status plus their full ledger entry list.
class CreditLedgerResponse {
  final int customerId;
  final String customerName;
  final double creditBalance;
  final double creditLimit;
  final bool creditHold;
  final List<CreditLedgerEntry> entries;

  const CreditLedgerResponse({
    required this.customerId,
    required this.customerName,
    required this.creditBalance,
    required this.creditLimit,
    required this.creditHold,
    this.entries = const [],
  });

  factory CreditLedgerResponse.fromJson(Map<String, dynamic> json) {
    return CreditLedgerResponse(
      customerId: (json['customerId'] as num?)?.toInt() ?? 0,
      customerName: json['customerName'] as String? ?? '',
      creditBalance: (json['creditBalance'] as num?)?.toDouble() ?? 0,
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0,
      creditHold: json['creditHold'] as bool? ?? false,
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => CreditLedgerEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// One row of `GET /api/customers/{id}/history` — a past sale for this
/// customer. Typed here (unlike source's ad hoc `Map` reads) since this is
/// a fresh mobile screen.
class CustomerSaleHistoryEntry {
  final int id;
  final double grandTotal;
  final String status;
  final String? createdAt;

  const CustomerSaleHistoryEntry({
    required this.id,
    required this.grandTotal,
    required this.status,
    this.createdAt,
  });

  factory CustomerSaleHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CustomerSaleHistoryEntry(
      id: (json['saleId'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String?,
    );
  }
}
