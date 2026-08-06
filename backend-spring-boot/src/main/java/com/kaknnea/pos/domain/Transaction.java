package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "transactions", indexes = {
        @Index(name = "idx_transactions_payment", columnList = "payment_id"),
        @Index(name = "idx_transactions_type", columnList = "transaction_type"),
        @Index(name = "idx_transactions_status", columnList = "status"),
        @Index(name = "idx_transactions_gateway_id", columnList = "gateway_transaction_id"),
        @Index(name = "idx_transactions_created_at", columnList = "transaction_date")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Transaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "payment_id", nullable = false)
    private Payment payment;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TransactionType transactionType;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private LocalDateTime transactionDate;

    @Column(nullable = false, precision = 18, scale = 2)
    private BigDecimal amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private TransactionStatus status = TransactionStatus.PENDING;

    @Column(length = 255)
    private String gatewayTransactionId;

    @Column(length = 50)
    private String gatewayResponseCode;

    @Column(columnDefinition = "TEXT")
    private String gatewayResponseMessage;

    @Column(length = 100)
    private String processorName;

    @Column(length = 4)
    private String lastFourDigits;

    @Column(length = 50)
    private String cardBrand;

    @Column(length = 50)
    private String authCode;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(nullable = false, updatable = false)
    @Builder.Default
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(length = 100)
    private String createdBy;

    // Business methods
    public void markAsSuccess() {
        this.status = TransactionStatus.SUCCESS;
    }

    public void markAsFailed(String errorMessage) {
        this.status = TransactionStatus.FAILED;
        this.gatewayResponseMessage = errorMessage;
    }

    public void markAsDeclined(String errorMessage) {
        this.status = TransactionStatus.DECLINED;
        this.gatewayResponseMessage = errorMessage;
    }

    public void markAsExpired() {
        this.status = TransactionStatus.EXPIRED;
    }

    public boolean isSuccessful() {
        return status == TransactionStatus.SUCCESS;
    }

    public boolean isFailed() {
        return status == TransactionStatus.FAILED;
    }

    @Getter
    @RequiredArgsConstructor
    public enum TransactionType {
        AUTHORIZATION("Authorization"),
        CAPTURE("Capture"),
        REFUND("Refund"),
        VOID("Void"),
        SETTLEMENT("Settlement");

        private final String displayName;
    }

    @Getter
    @RequiredArgsConstructor
    public enum TransactionStatus {
        PENDING("Pending"),
        SUCCESS("Success"),
        FAILED("Failed"),
        DECLINED("Declined"),
        EXPIRED("Expired");

        private final String displayName;
    }
}
