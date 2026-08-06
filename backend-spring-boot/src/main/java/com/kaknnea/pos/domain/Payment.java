package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.List;

@Entity
@Table(name = "payments", indexes = {
        @Index(name = "idx_payments_cart", columnList = "cart_id"),
        @Index(name = "idx_payments_sale", columnList = "sale_id"),
        @Index(name = "idx_payments_status", columnList = "status"),
        @Index(name = "idx_payments_created_at", columnList = "created_at")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Payment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Legacy Sale-based payment
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sale_id")
    private Sale sale;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shift_id")
    private Shift shift;

    @Column(name = "method", length = 30)
    private String method;

    @Transient
    @Builder.Default
    private Instant createdAtLegacy = Instant.now();

    // New Cart-based payment
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cart_id")
    private Cart cart;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id")
    private Customer customer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_id")
    private Store store;

    @Column(precision = 18, scale = 2)
    private BigDecimal amount;

    @Column(length = 3)
    @Builder.Default
    private String currency = "USD";

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private PaymentStatus status = PaymentStatus.PENDING;

    @Enumerated(EnumType.STRING)
    private PaymentMethod paymentMethod;

    @Column(length = 255)
    private String transactionId;

    @Column(length = 255, unique = true)
    private String referenceNumber;

    @Column(columnDefinition = "TEXT")
    private String errorMessage;

    @Column(name = "failure_reason", columnDefinition = "TEXT")
    private String failureReason;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @OneToMany(mappedBy = "payment", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private List<Transaction> transactions;

    @CreationTimestamp
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    @Column(length = 100)
    private String createdBy;

    @Column(length = 100)
    private String updatedBy;

    // Business methods for legacy Payment
    public void setSale(Sale sale) {
        this.sale = sale;
    }

    public void setMethod(String method) {
        this.method = method == null ? null : method.trim().toUpperCase(Locale.ROOT);
        if (paymentMethod == null && this.method != null && !this.method.isBlank()) {
            this.paymentMethod = fromLegacyMethod(this.method);
        }
    }

    public void setPaymentMethod(PaymentMethod paymentMethod) {
        this.paymentMethod = paymentMethod;
        if ((method == null || method.isBlank()) && paymentMethod != null) {
            this.method = toLegacyMethod(paymentMethod);
        }
    }

    @PrePersist
    @PreUpdate
    void syncPaymentMethodFields() {
        if ((method == null || method.isBlank()) && paymentMethod != null) {
            method = toLegacyMethod(paymentMethod);
        }
        if (paymentMethod == null && method != null && !method.isBlank()) {
            paymentMethod = fromLegacyMethod(method);
        }
    }

    private static String toLegacyMethod(PaymentMethod paymentMethod) {
        return switch (paymentMethod) {
            case CASH -> "CASH";
            case KHQR -> "KHQR";
            case ABA -> "ABA";
            case WING -> "WING";
            case CARD, CREDIT_CARD, DEBIT_CARD -> "CARD";
            case BANK_TRANSFER -> "BANK_TRANSFER";
            case MOBILE_WALLET -> "KHQR";
        };
    }

    private static PaymentMethod fromLegacyMethod(String rawMethod) {
        return switch (rawMethod.trim().toUpperCase(Locale.ROOT)) {
            case "CASH" -> PaymentMethod.CASH;
            case "KHQR", "QR" -> PaymentMethod.KHQR;
            case "ABA" -> PaymentMethod.ABA;
            case "WING" -> PaymentMethod.WING;
            case "CARD", "CREDIT_CARD" -> PaymentMethod.CREDIT_CARD;
            case "DEBIT_CARD" -> PaymentMethod.DEBIT_CARD;
            case "MOBILE_WALLET" -> PaymentMethod.MOBILE_WALLET;
            case "BANK_TRANSFER", "TRANSFER" -> PaymentMethod.BANK_TRANSFER;
            default -> PaymentMethod.CASH;
        };
    }

    // Business methods for new Payment
    public void markAsPending() {
        this.status = PaymentStatus.PENDING;
    }

    public void markAsProcessing() {
        this.status = PaymentStatus.PROCESSING;
    }

    public void markAsCompleted(String transactionId) {
        this.status = PaymentStatus.COMPLETED;
        this.transactionId = transactionId;
    }

    public void markAsRefunded() {
        this.status = PaymentStatus.REFUNDED;
    }

    public void markAsFailed(String failureReason) {
        this.status = PaymentStatus.FAILED;
        this.failureReason = failureReason;
    }

    public boolean isPending() {
        return status == PaymentStatus.PENDING;
    }

    public boolean isCompleted() {
        return status == PaymentStatus.COMPLETED;
    }

    public boolean isFailed() {
        return status == PaymentStatus.FAILED;
    }

    public boolean isRefundable() {
        return status == PaymentStatus.COMPLETED;
    }

    @Getter
    @RequiredArgsConstructor
    public enum PaymentStatus {
        PENDING("Pending"),
        PROCESSING("Processing"),
        COMPLETED("Completed"),
        FAILED("Failed"),
        VOID("Void"),
        REFUNDED("Refunded");

        private final String displayName;
    }

    @Getter
    @RequiredArgsConstructor
    public enum PaymentMethod {
        CASH("Cash"),
        KHQR("KHQR"),
        ABA("ABA"),
        WING("Wing"),
        CARD("Card"),
        CREDIT_CARD("Credit Card"),
        DEBIT_CARD("Debit Card"),
        MOBILE_WALLET("Mobile Wallet"),
        BANK_TRANSFER("Bank Transfer");

        private final String displayName;
    }
}
