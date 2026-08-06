package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "eod_snapshots", indexes = {
        @Index(name = "idx_eod_date", columnList = "eod_date"),
        @Index(name = "idx_eod_status", columnList = "status")
})
@Getter
@Setter
public class EodSnapshot extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "eod_date", nullable = false)
    private LocalDate eodDate;

    @Column(name = "status", nullable = false, length = 20)
    private String status; // LOCKED, PROCESSING, COMPLETED

    @Column(name = "net_sales_today", nullable = false, precision = 18, scale = 2)
    private BigDecimal netSalesToday = BigDecimal.ZERO;

    @Column(name = "cash_collected_today", nullable = false, precision = 18, scale = 2)
    private BigDecimal cashCollectedToday = BigDecimal.ZERO;

    @Column(name = "new_credit_today", nullable = false, precision = 18, scale = 2)
    private BigDecimal newCreditToday = BigDecimal.ZERO;

    @Column(name = "total_ar_balance", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalArBalance = BigDecimal.ZERO;

    @Column(name = "overdue_gt_30_days", nullable = false, precision = 18, scale = 2)
    private BigDecimal overdueGt30Days = BigDecimal.ZERO;

    @Column(name = "total_sales_count", nullable = false)
    private Integer totalSalesCount = 0;

    @Column(name = "total_payments_count", nullable = false)
    private Integer totalPaymentsCount = 0;

    @CreationTimestamp
    @Column(name = "processed_at", updatable = false)
    private LocalDateTime processedAt;

    @Column(name = "processed_by", length = 100)
    private String processedBy;

    @OneToMany(mappedBy = "eodSnapshot", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<EodInvoiceSnapshot> invoiceSnapshots = new ArrayList<>();

    @OneToMany(mappedBy = "eodSnapshot", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<EodCollectionSummary> collectionSummaries = new ArrayList<>();

    @OneToMany(mappedBy = "eodSnapshot", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<EodAgingSummary> agingSummaries = new ArrayList<>();

    @OneToMany(mappedBy = "eodSnapshot", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<EodCustomerCredit> customerCredits = new ArrayList<>();
}