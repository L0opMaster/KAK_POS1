package com.kaknnea.pos.dto;

import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public class PaymentDtos {

    // Request DTOs
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class CreatePaymentRequest {
        private Long cartId;
        private String paymentMethod;
        private String notes;

        public void validate() {
            if (cartId == null || cartId <= 0) {
                throw new IllegalArgumentException("Cart ID is required and must be positive");
            }
            if (paymentMethod == null || paymentMethod.trim().isEmpty()) {
                throw new IllegalArgumentException("Payment method is required");
            }
        }
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class ProcessPaymentRequest {
        private Long paymentId;
        private String cardToken;
        private String gatewayId;
        private String billingZipCode;
        private String notes;

        public void validate() {
            if (paymentId == null || paymentId <= 0) {
                throw new IllegalArgumentException("Payment ID is required and must be positive");
            }
        }
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class RefundPaymentRequest {
        private Long paymentId;
        private BigDecimal refundAmount;
        private String reason;

        public void validate() {
            if (paymentId == null || paymentId <= 0) {
                throw new IllegalArgumentException("Payment ID is required and must be positive");
            }
            if (refundAmount == null || refundAmount.compareTo(BigDecimal.ZERO) <= 0) {
                throw new IllegalArgumentException("Refund amount must be greater than zero");
            }
            if (reason == null || reason.trim().isEmpty()) {
                throw new IllegalArgumentException("Refund reason is required");
            }
        }
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class UpdatePaymentRequest {
        private BigDecimal amount;
        private String paymentMethod;
        private String notes;
        private String reason;

        public void validate() {
            if (amount == null || amount.compareTo(BigDecimal.ZERO) < 0) {
                throw new IllegalArgumentException("Payment amount must be zero or greater");
            }
            if (paymentMethod == null || paymentMethod.trim().isEmpty()) {
                throw new IllegalArgumentException("Payment method is required");
            }
        }
    }

    // Response DTOs
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class PaymentResponse {
        private Long id;
        private Long cartId;
        private Long saleId;
        private String saleDocumentNumber;
        private Long customerId;
        private Long storeId;
        private BigDecimal amount;
        private String currency;
        private String status;
        private String paymentMethod;
        private String transactionId;
        private String referenceNumber;
        private String errorMessage;
        private String failureReason;
        private String notes;
        private LocalDateTime createdAt;
        private LocalDateTime updatedAt;
        private String createdBy;
        private List<TransactionResponse> transactions;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class TransactionResponse {
        private Long id;
        private Long paymentId;
        private String transactionType;
        private BigDecimal amount;
        private String status;
        private String gatewayTransactionId;
        private String gatewayResponseCode;
        private String gatewayResponseMessage;
        private String processorName;
        private String lastFourDigits;
        private String cardBrand;
        private String authCode;
        private String notes;
        private LocalDateTime transactionDate;
        private LocalDateTime createdAt;
        private String createdBy;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class PaymentSummary {
        private Long paymentId;
        private BigDecimal amount;
        private String status;
        private String paymentMethod;
        private LocalDateTime processedAt;
        private String transactionId;
        private String referenceNumber;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class PaymentStatusResponse {
        private Long paymentId;
        private String status;
        private String statusDisplay;
        private Boolean isCompleted;
        private Boolean isFailed;
        private String errorMessage;
        private String failureReason;
        private List<TransactionResponse> transactions;
        private LocalDateTime updatedAt;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class PaymentConfirmation {
        private Long paymentId;
        private Long cartId;
        private Long orderId;
        private BigDecimal totalAmount;
        private String currency;
        private String paymentMethod;
        private String transactionId;
        private String referenceNumber;
        private LocalDateTime confirmedAt;
        private String receiptUrl;
        private String status;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class PaymentListResponse {
        private List<PaymentResponse> payments;
        private long totalCount;
        private int pageNumber;
        private int pageSize;
    }
}
