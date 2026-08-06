package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Entity
@Table(name = "eod_aging_summaries")
@Getter
@Setter
public class EodAgingSummary {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "eod_snapshot_id", nullable = false)
    private EodSnapshot eodSnapshot;

    @Column(name = "aging_bucket", length = 20, nullable = false)
    private String agingBucket; // 0-7, 8-15, 16-30, >30

    @Column(name = "total_balance", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalBalance = BigDecimal.ZERO;

    @Column(name = "invoice_count", nullable = false)
    private Integer invoiceCount = 0;
}