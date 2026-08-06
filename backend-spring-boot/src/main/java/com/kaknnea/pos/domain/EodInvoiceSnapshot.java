package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "eod_invoice_snapshots", indexes = {
        @Index(name = "idx_eod_invoice_snapshot", columnList = "eod_snapshot_id"),
        @Index(name = "idx_eod_invoice_sale", columnList = "sale_id")
})
@Getter
@Setter
public class EodInvoiceSnapshot {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "eod_snapshot_id", nullable = false)
    private EodSnapshot eodSnapshot;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sale_id", nullable = false)
    private Sale sale;

    @Column(name = "invoice_no", length = 50)
    private String invoiceNo;

    @Column(name = "invoice_date", nullable = false)
    private LocalDate invoiceDate;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id")
    private Customer customer;

    @Column(name = "customer_name", length = 150)
    private String customerName;

    @Column(name = "total_sale", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalSale = BigDecimal.ZERO;

    @Column(name = "paid_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal paidAmount = BigDecimal.ZERO;

    @Column(name = "balance", nullable = false, precision = 18, scale = 2)
    private BigDecimal balance = BigDecimal.ZERO;

    @Column(name = "days_outstanding", nullable = false)
    private Integer daysOutstanding = 0;

    @Column(name = "aging_bucket", length = 20)
    private String agingBucket; // 0-7, 8-15, 16-30, >30

    @Column(name = "payment_status", length = 20)
    private String paymentStatus; // PAID, PARTIAL, CREDIT
}