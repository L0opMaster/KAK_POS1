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

class CreditLedgerResponse {
  final double creditBalance;
  CreditLedgerResponse({
    required this.creditBalance,
  });
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
