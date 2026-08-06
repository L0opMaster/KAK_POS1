// Mocks for missing types and stubs for test compilation
// Placeholders for test-only usage

class CreditCollectionCommit {
  final String? paymentId;
  final int? customerId;
  final String? referenceNumber;
  final double? amountCollected;
  final double? outstandingAfter;
  final List<CreditCollectionAllocationRow>? allocations;
  const CreditCollectionCommit({
    this.paymentId,
    this.customerId,
    this.referenceNumber,
    this.amountCollected,
    this.outstandingAfter,
    this.allocations,
  });
}

class CreditCollectionAllocationInput {
  final String? targetType;
  final int? openingBalanceId;
  final double? allocatedAmount;
  final double? outstandingBefore;
  final double? outstandingAfter;
  const CreditCollectionAllocationInput({
    this.targetType,
    this.openingBalanceId,
    this.allocatedAmount,
    this.outstandingBefore,
    this.outstandingAfter,
  });
}

class CreditLedgerEntry {
  const CreditLedgerEntry();
}

class CreditLedgerResponse {
  final int? customerId;
  final String? customerName;
  final double? creditBalance;
  final List<CreditLedgerEntry>? entries;
  const CreditLedgerResponse(
      {this.customerId, this.customerName, this.creditBalance, this.entries});
}

class CreditCollectionPreview {
  final int? customerId;
  final String? customerName;
  final double? amountRequested;
  final double? amountAllocatable;
  final double? amountUnallocated;
  final double? outstandingBefore;
  final double? outstandingAfter;
  final bool? valid;
  final String? message;
  final List<CreditCollectionAllocationRow>? allocations;
  const CreditCollectionPreview({
    this.customerId,
    this.customerName,
    this.amountRequested,
    this.amountAllocatable,
    this.amountUnallocated,
    this.outstandingBefore,
    this.outstandingAfter,
    this.valid,
    this.message,
    this.allocations,
  });
}

class CreditCollectionAllocationRow {
  final String? targetType;
  final int? openingBalanceId;
  final double? outstandingBefore;
  final double? allocatedAmount;
  final double? outstandingAfter;
  const CreditCollectionAllocationRow({
    this.targetType,
    this.openingBalanceId,
    this.outstandingBefore,
    this.allocatedAmount,
    this.outstandingAfter,
  });
}

class CustomerSaleHistory {
  final int? saleId;
  final String? status;
  final double? grandTotal;
  final double? paidAmount;
  final int? createdAt;
  const CustomerSaleHistory({
    this.saleId,
    this.status,
    this.grandTotal,
    this.paidAmount,
    this.createdAt,
  });
}

class TablePage {
  const TablePage();
}

class TableStats {
  const TableStats();
}
