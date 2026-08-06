package com.kaknnea.pos.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;
import lombok.Data;

public class CreditCollectionDtos {
    @Data
    public static class PreviewRequest {
        @NotNull
        private BigDecimal amount;

        @NotBlank
        private String strategy = "FIFO";
    }

    @Data
    public static class CollectRequest {
        @NotNull
        private BigDecimal amount;

        @NotBlank
        private String paymentMethod;

        private String notes;

        @NotBlank
        private String strategy = "FIFO";

        private String idempotencyKey;
        private List<AllocationInput> allocations;
    }

    @Data
    public static class AllocationInput {
        @NotBlank
        private String targetType; // SALE|OPENING_BALANCE
        private Long saleId;
        private Long openingBalanceId;

        @NotNull
        private BigDecimal allocatedAmount;
    }

    @Data
    public static class AllocationRow {
        private String targetType; // SALE|OPENING_BALANCE
        private Long saleId;
        private String invoiceNumber;
        private Long openingBalanceId;
        private String dueAt;
        private Integer ageDays;
        private BigDecimal outstandingBefore;
        private BigDecimal allocatedAmount;
        private BigDecimal outstandingAfter;
    }

    @Data
    public static class PreviewResponse {
        private Long customerId;
        private String customerName;
        private BigDecimal amountRequested;
        private BigDecimal amountAllocatable;
        private BigDecimal amountUnallocated;
        private BigDecimal outstandingBefore;
        private BigDecimal outstandingAfter;
        private boolean valid;
        private String message;
        private List<AllocationRow> allocations;
    }

    @Data
    public static class CollectResponse {
        private Long customerId;
        private Long paymentId;
        private String referenceNumber;
        private BigDecimal amountCollected;
        private BigDecimal outstandingAfter;
        private List<AllocationRow> allocations;
    }

    @Data
    public static class LedgerEntry {
        private String entryType; // OPENING_BALANCE|CREDIT_SALE|COLLECTION
        private String targetType; // SALE|OPENING_BALANCE|CUSTOMER
        private Long saleId;
        private String invoiceNumber;
        private Long openingBalanceId;
        private Long paymentId;
        private BigDecimal amount;
        private BigDecimal remainingAmount;
        private String note;
        private String createdAt;
        private Integer agingDays; // days since credit due date; null for non-CREDIT_SALE entries
    }

    @Data
    public static class AdjustmentRequest {
        private String type; // CREDIT_NOTE or DEBIT_NOTE
        private java.math.BigDecimal amount;
        private String reason;
        private String note;
    }

    @Data
    public static class AdjustmentResponse {
        private Long id;
        private String type;
        private String referenceNumber;
        private java.math.BigDecimal amount;
        private String reason;
        private String note;
        private String createdBy;
        private String createdAt;
    }

    @Data
    public static class LedgerResponse {
        private Long customerId;
        private String customerName;
        private BigDecimal creditBalance;
        private BigDecimal creditLimit;
        private boolean creditHold;
        private List<LedgerEntry> entries;
    }
}
