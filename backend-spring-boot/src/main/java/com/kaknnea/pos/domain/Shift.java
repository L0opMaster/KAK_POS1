package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "shifts")
@Getter
@Setter
public class Shift {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "opened_by", nullable = false)
    private User openedBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "closed_by")
    private User closedBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "approved_by_id")
    private User approvedBy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_id")
    private Store store;

    @Column(name = "approval_note")
    private String approvalNote;

    @Column(name = "opened_at", nullable = false)
    private Instant openedAt = Instant.now();

    @Column(name = "closed_at")
    private Instant closedAt;

    @Column(name = "opening_cash", nullable = false, precision = 18, scale = 2)
    private BigDecimal openingCash;

    @Column(name = "closing_cash", precision = 18, scale = 2)
    private BigDecimal closingCash;

    @Column(name = "expected_cash", precision = 18, scale = 2)
    private BigDecimal expectedCash;

    @Column(name = "variance", precision = 18, scale = 2)
    private BigDecimal variance;

    @Column(name = "status", nullable = false, length = 20)
    private String status;
}
