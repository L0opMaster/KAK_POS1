// Lightweight customer and credit models used by the Flutter POS app.

class CreditCollectionCommit {
  final double amountCollected;
  final String referenceNumber;
  CreditCollectionCommit({
    required this.amountCollected,
    required this.referenceNumber,
  });
}

class CreditCollectionAllocationInput {
  final String targetType;
  final int openingBalanceId;
  final double outstandingBefore;
  final double allocatedAmount;
  final double outstandingAfter;
  CreditCollectionAllocationInput({
    required this.targetType,
    required this.openingBalanceId,
    required this.outstandingBefore,
    required this.allocatedAmount,
    required this.outstandingAfter,
  });
}

class CreditCollectionAllocationRow {
  final String targetType;
  final int openingBalanceId;
  final double outstandingBefore;
  final double allocatedAmount;
  final double outstandingAfter;
  CreditCollectionAllocationRow({
    required this.targetType,
    required this.openingBalanceId,
    required this.outstandingBefore,
    required this.allocatedAmount,
    required this.outstandingAfter,
  });
}

/// One row in a customer's credit ledger — mirrors the backend's
/// `CreditCollectionDtos.LedgerEntry` (`GET /api/customers/{id}/credit-ledger`).
/// `entryType` is one of OPENING_BALANCE|CREDIT_SALE|COLLECTION|SALE_RETURN|
/// CREDIT_NOTE|DEBIT_NOTE. For a CREDIT_SALE row, `saleId`/`invoiceNumber`
/// identify the sale and `remainingAmount` is what's still owed on it; for a
/// COLLECTION row, `saleId` (when present) links the payment back to the
/// sale it was applied against.
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
      entryType: (json['entryType'] as String?) ?? '',
      targetType: json['targetType'] as String?,
      saleId: (json['saleId'] as num?)?.toInt(),
      invoiceNumber: json['invoiceNumber'] as String?,
      openingBalanceId: (json['openingBalanceId'] as num?)?.toInt(),
      paymentId: (json['paymentId'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble(),
      note: json['note'] as String?,
      createdAt: (json['createdAt'] as String?) ?? '',
      agingDays: (json['agingDays'] as num?)?.toInt(),
    );
  }
}

/// A customer's full credit ledger — mirrors the backend's
/// `CreditCollectionDtos.LedgerResponse`. `entries` is already sorted
/// newest-first by the backend.
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
    required this.entries,
  });

  factory CreditLedgerResponse.fromJson(Map<String, dynamic> json) {
    return CreditLedgerResponse(
      customerId: (json['customerId'] as num?)?.toInt() ?? 0,
      customerName: (json['customerName'] as String?) ?? '',
      creditBalance: (json['creditBalance'] as num?)?.toDouble() ?? 0,
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0,
      creditHold: json['creditHold'] as bool? ?? false,
      entries: (json['entries'] as List<dynamic>? ?? const [])
          .map((e) => CreditLedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomerSaleHistory {
  final int saleId;
  CustomerSaleHistory({required this.saleId});
}

class CreditCollectionPreview {
  final List<CreditCollectionAllocationRow> allocations;
  final double amountAllocatable;
  final bool valid;
  final String message;
  CreditCollectionPreview({
    required this.allocations,
    required this.amountAllocatable,
    required this.valid,
    required this.message,
  });
}

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

  CreateCustomerRequest({
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

  factory CreateCustomerRequest.fromCustomer(Customer customer) {
    return CreateCustomerRequest(
      creditLimit: customer.creditLimit,
      type: customer.type,
      status: customer.status,
      nameEn: customer.nameEn,
      nameKm: customer.nameKm,
      displayName: customer.displayName,
      phone: customer.phone,
      email: customer.email,
      address: customer.address,
      contactPerson: customer.contactPerson,
      notes: customer.notes,
      loyaltyPoints: customer.loyaltyPoints,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
}
