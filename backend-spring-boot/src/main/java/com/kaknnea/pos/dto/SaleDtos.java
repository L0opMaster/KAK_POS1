package com.kaknnea.pos.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

public class SaleDtos {
    @Data
    public static class SaleLineRequest {
        @NotNull
        private Long productId;
        @NotNull
        private BigDecimal quantity;
        private BigDecimal unitPrice; // nullable — server resolves from price list when omitted
        private BigDecimal lineDiscount = BigDecimal.ZERO;
        private String note;
        private String modifierSummary;
        private String modifierData;
    }

    @Data
    public static class SaleCreateRequest {
        private Long customerId;
        private Long tableId;
        private Long heldTicketId;
        private String terminalId;
        private String idempotencyKey;
        private String displayName;
        private String note;
        private String orderDate;
        private String deliveryDate;
        private String paymentTerms;
        private BigDecimal deliveryCharge = BigDecimal.ZERO;
        private BigDecimal otherCharge = BigDecimal.ZERO;
        private BigDecimal depositAmount = BigDecimal.ZERO;
        private BigDecimal invoiceDiscount = BigDecimal.ZERO;
        private double taxRate = 0.0;
        private String clientRef;
        private String orderMode;
        private String deliveryRecipientName;
        private String deliveryPhone;
        private String deliveryAddress;
        private String deliveryLandmark;
        private String deliveryNote;
        private String estimateExpiryDate; // for estimate/quotation creation
        @Valid
        @NotNull
        private List<SaleLineRequest> lines;
    }

    @Data
    public static class SaleResponse {
        private Long id;
        private String invoiceNumber;
        private String status;
        private String currency;
        private String displayName;
        private BigDecimal subtotal;
        private BigDecimal discountAmount;
        private double taxRate;
        private BigDecimal taxAmount;
        private BigDecimal grandTotal;
        private BigDecimal paidAmount;
        private BigDecimal deliveryCharge;
        private BigDecimal otherCharge;
        private BigDecimal depositAmount;
        private String note;
        private String orderDate;
        private String deliveryDate;
        private String paymentTerms;
        private String creditDueAt;
        private String creditExpiresAt;
        private String creditStatus;
        private Long customerId;
        private String customerName;
        private Long tableId;
        private String tableNumber;
        private String cashierName;
        private Long shiftId;
        private String createdAt;
        private String endDate;
        private String orderMode;
        private String deliveryRecipientName;
        private String deliveryPhone;
        private String deliveryAddress;
        private String deliveryLandmark;
        private String deliveryNote;
        private List<SaleLineResponse> lines;
        private List<PaymentSummary> payments;
        // ── Estimate/Quotation fields ──
        private String estimateExpiryDate;
        private String estimateSentAt;
        private String estimateAcceptedAt;
        private String estimateDeclinedAt;
        private String estimateDeclineReason;
        private Long convertedFromEstimateId;
        private Boolean isEstimate;
    }

    @Data
    public static class SaleLineResponse {
        private Long id;
        private Long productId;
        private String productNameEn;
        private String productNameKm;
        private BigDecimal quantity;
        private BigDecimal unitPrice;
        private BigDecimal lineDiscount;
        private BigDecimal lineTotal;
        /** Fraction (e.g. 0.08) — this line's product's own tax rate at sale time. */
        private double taxRate;
        private String note;
        private String modifierSummary;
        private String modifierData;
    }

    @Data
    public static class PaymentRequest {
        @NotNull
        private String method;
        @NotNull
        private BigDecimal amount;
    }

    @Data
    public static class PayRequest {
        @Valid
        @NotNull
        private List<PaymentRequest> payments;
    }

    @Data
    public static class RefundLineRequest {
        @NotNull
        private Long saleLineId;
        @NotNull
        private BigDecimal quantity;
    }

    @Data
    public static class RefundRequest {
        private BigDecimal amount;
        @NotNull
        private String method;
        private String reason;
        private String managerEmail;
        private String managerPassword;
        private String approvalReason;
        private Boolean forceApproval = Boolean.FALSE;
        @Valid
        private List<RefundLineRequest> lines;
    }

    @Data
    public static class PaymentSummary {
        private Long id;
        private String method;
        private BigDecimal amount;
        private String status;
    }

    @Data
    public static class CreditRepaymentRequest {
        @NotNull
        private BigDecimal amount;
        @NotNull
        private String method;
        private String notes;
    }

    /**
     * Optional body for POST /{id}/credit. All fields optional so a no-body
     * call keeps the legacy behavior (due date derived from
     * {@code paymentTerms}) — see SaleService.credit().
     */
    @Data
    public static class CreditRequest {
        private String dueDate; // ISO-8601 LocalDate, e.g. "2026-09-16"
        private String expiresAt; // ISO-8601 LocalDate, optional
        private String notes;
    }

    @Data
    public static class DeclineEstimateRequest {
        @NotNull
        private String reason;
    }
}
