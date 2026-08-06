package com.kaknnea.pos.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import lombok.Data;

public class FinanceDtos {
    @Data
    public static class AgingBucket {
        private String bucket;
        private BigDecimal amount;
        private int count;
    }

    @Data
    public static class PayableRow {
        private Long supplierInvoiceId;
        private String invoiceNumber;
        private String supplierName;
        private String invoiceDate;
        private String status;
        private BigDecimal totalAmount;
        private BigDecimal paidAmount;
        private BigDecimal outstandingAmount;
        private int ageDays;
    }

    @Data
    public static class ReceivableRow {
        private Long saleId;
        private String invoiceNumber;
        private Long customerId;
        private String customerName;
        private String createdAt;
        private String dueAt;
        private String status;
        private BigDecimal grandTotal;
        private BigDecimal paidAmount;
        private BigDecimal outstandingAmount;
        private int ageDays;
    }

    @Data
    public static class PayablesSummaryResponse {
        private BigDecimal totalOutstanding;
        private BigDecimal totalOpenInvoices;
        private int invoiceCount;
        private List<AgingBucket> aging;
        private List<PayableRow> invoices;
    }

    @Data
    public static class ReceivablesSummaryResponse {
        private BigDecimal totalOutstanding;
        private BigDecimal totalCreditLimit;
        private int invoiceCount;
        private List<AgingBucket> aging;
        private List<ReceivableRow> invoices;
    }

    @Data
    public static class ApLedgerEntry {
        private String entryType;
        private Long supplierId;
        private String supplierName;
        private Long documentId;
        private String documentNumber;
        private Instant occurredAt;
        private BigDecimal debit = BigDecimal.ZERO;
        private BigDecimal credit = BigDecimal.ZERO;
        private BigDecimal balanceImpact = BigDecimal.ZERO;
        private String note;
    }
}
