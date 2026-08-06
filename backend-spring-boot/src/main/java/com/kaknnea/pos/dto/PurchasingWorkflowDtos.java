package com.kaknnea.pos.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public class PurchasingWorkflowDtos {
    @Data
    public static class PurchaseDocumentLineRequest {
        @NotNull
        private Long productId;
        private Long purchaseOrderLineId;
        @NotNull
        private BigDecimal quantity;
        @NotNull
        private BigDecimal unitCost;
        private String lineNote;
    }

    @Data
    public static class PurchaseRfqRequest {
        private Long supplierId;
        private Long storeId;
        private LocalDate targetDate;
        private String requestReference;
        private String notes;
        @Valid
        @NotNull
        private List<PurchaseRfqLineRequest> lines;
    }

    @Data
    public static class PurchaseRfqLineRequest {
        @NotNull
        private Long productId;
        @NotNull
        private BigDecimal quantity;
        private BigDecimal estimatedUnitCost = BigDecimal.ZERO;
        private String lineNote;
    }

    @Data
    public static class PurchaseRfqResponse {
        private Long id;
        private Long supplierId;
        private String supplierName;
        private Long storeId;
        private String storeName;
        private String status;
        private LocalDate targetDate;
        private String requestReference;
        private String notes;
        private BigDecimal subtotal;
        private BigDecimal taxAmount;
        private BigDecimal totalAmount;
        private long attachmentCount;
        private Instant approvedAt;
        private String approvedByEmail;
        private List<PurchaseRfqLineResponse> lines;
    }

    @Data
    public static class PurchaseRfqLineResponse {
        private Long id;
        private Long productId;
        private String productNameEn;
        private BigDecimal quantity;
        private BigDecimal estimatedUnitCost;
        private BigDecimal lineTotal;
        private BigDecimal lastPurchaseCost;
        private String lineNote;
    }

    @Data
    public static class PurchaseOrderRequest {
        @NotNull
        private Long supplierId;
        private Long storeId;
        private LocalDate orderDeadline;
        private LocalDate expectedArrival;
        private Long purchaseRepresentativeId;
        private BigDecimal taxRate = BigDecimal.ZERO;
        private String notes;
        @Valid
        @NotNull
        private List<PurchaseDocumentLineRequest> lines;
    }

    @Data
    public static class PurchaseOrderResponse {
        private Long id;
        private String referenceNumber;
        private Long supplierId;
        private String supplierName;
        private String supplierEmail;
        private Long storeId;
        private String storeName;
        private String status;
        private LocalDate orderDeadline;
        private LocalDate expectedArrival;
        private Long purchaseRepresentativeId;
        private String purchaseRepresentativeName;
        private BigDecimal taxRate;
        private BigDecimal subtotal;
        private BigDecimal taxAmount;
        private BigDecimal totalAmount;
        private long attachmentCount;
        private String notes;
        private Instant orderedAt;
        private Instant approvedAt;
        private Instant sentAt;
        private List<PurchaseDocumentLineResponse> lines;
    }

    @Data
    public static class PurchaseDocumentLineResponse {
        private Long id;
        private Long productId;
        private String productNameEn;
        private String productNameKm;
        private BigDecimal quantity;
        private BigDecimal receivedQuantity;
        private BigDecimal billedQuantity;
        private BigDecimal returnedQuantity;
        private BigDecimal unitCost;
        private BigDecimal lineTotal;
        private BigDecimal taxAmount;
        private String lineNote;
        private String matchStatus;
    }

    @Data
    public static class GoodsReceiptRequest {
        @NotNull
        private Long purchaseOrderId;
        private Long storeId;
        private String notes;
        @Valid
        @NotNull
        private List<PurchaseDocumentLineRequest> lines;
    }

    @Data
    public static class GoodsReceiptResponse {
        private Long id;
        private String referenceNumber;
        private Long purchaseOrderId;
        private String poReferenceNumber;
        private Long supplierId;
        private String supplierName;
        private Long storeId;
        private String storeName;
        private String status;
        private String notes;
        private BigDecimal totalAmount;
        private long attachmentCount;
        private Instant receivedAt;
        private List<PurchaseDocumentLineResponse> lines;
    }

    @Data
    public static class SupplierInvoiceRequest {
        @NotNull
        private Long supplierId;
        private Long purchaseOrderId;
        private Long goodsReceiptId;
        private Long storeId;
        @NotBlank
        private String invoiceNumber;
        @NotNull
        private LocalDate invoiceDate;
        private LocalDate dueDate;
        private BigDecimal taxAmount = BigDecimal.ZERO;
        private String notes;
        @Valid
        @NotNull
        private List<PurchaseDocumentLineRequest> lines;
    }

    @Data
    public static class SupplierInvoiceResponse {
        private Long id;
        private Long supplierId;
        private String supplierName;
        private Long purchaseOrderId;
        private String poReferenceNumber;
        private Long goodsReceiptId;
        private String grnReferenceNumber;
        private Long storeId;
        private String storeName;
        private String status;
        private String invoiceNumber;
        private LocalDate invoiceDate;
        private LocalDate dueDate;
        private BigDecimal subtotal;
        private BigDecimal taxAmount;
        private BigDecimal totalAmount;
        private BigDecimal paidAmount;
        private BigDecimal outstandingAmount;
        private boolean stockApplied;
        private long attachmentCount;
        private String notes;
        private List<PurchaseDocumentLineResponse> lines;
    }

    @Data
    public static class SupplierPaymentRequest {
        @NotNull
        private Long supplierInvoiceId;
        @NotNull
        private BigDecimal amount;
        private Instant paidAt;
        private String reference;
        private String paymentMethod;
        private String notes;
    }

    @Data
    public static class SupplierPaymentResponse {
        private Long id;
        private Long supplierInvoiceId;
        private String invoiceNumber;
        private String supplierName;
        private BigDecimal amount;
        private Instant paidAt;
        private String reference;
        private String paymentMethod;
        private String status;
        private long attachmentCount;
        private String notes;
    }

    @Data
    public static class PurchaseReturnRequest {
        @NotNull
        private Long supplierId;
        private Long goodsReceiptId;
        private Long supplierInvoiceId;
        private Long storeId;
        @NotNull
        private LocalDate returnDate;
        private String notes;
        @Valid
        @NotNull
        private List<PurchaseDocumentLineRequest> lines;
    }

    @Data
    public static class PurchaseReturnResponse {
        private Long id;
        private Long supplierId;
        private String supplierName;
        private Long goodsReceiptId;
        private String grnReferenceNumber;
        private Long supplierInvoiceId;
        private Long storeId;
        private String storeName;
        private String status;
        private LocalDate returnDate;
        private BigDecimal totalAmount;
        private long attachmentCount;
        private String notes;
        private List<PurchaseDocumentLineResponse> lines;
    }

    @Data
    public static class PurchaseAttachmentRequest {
        @NotBlank
        private String documentType;
        @NotNull
        private Long documentId;
        @NotBlank
        private String fileName;
        @NotBlank
        private String fileUrl;
        private String contentType;
    }

    @Data
    public static class PurchaseAttachmentResponse {
        private Long id;
        private String documentType;
        private Long documentId;
        private String fileName;
        private String fileUrl;
        private String contentType;
        private String createdByEmail;
        private Instant createdAt;
    }

    @Data
    public static class PurchaseMatchWarningResponse {
        private Long supplierInvoiceId;
        private List<String> warnings;
    }

    @Data
    public static class PurchaseDashboardResponse {
        private int openRfqs;
        private int pendingApprovals;
        private int pendingReceipts;
        private int unpaidVendorBills;
        private BigDecimal overdueAp;
        private List<LowStockItem> lowStockItems;
        private List<QueueItem> queues;
    }

    @Data
    public static class LowStockItem {
        private Long productId;
        private String productNameEn;
        private Long storeId;
        private String stockUnitCode;
        private BigDecimal quantity;
        private BigDecimal lowStockThreshold;
        private String storeName;
    }

    @Data
    public static class QueueItem {
        private String key;
        private String label;
        private int count;
        private String actionTab;
    }

    @Data
    public static class PurchaseActivityResponse {
        private Long id;
        private String documentType;
        private Long documentId;
        private String action;
        private String summary;
        private String actorEmail;
        private Instant createdAt;
    }
}
