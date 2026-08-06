package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Entity
@Table(name = "purchase_rfq_lines")
@Getter
@Setter
public class PurchaseRfqLine extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "purchase_rfq_id", nullable = false)
    private PurchaseRfq purchaseRfq;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @Column(name = "requested_quantity", nullable = false, precision = 18, scale = 2)
    private BigDecimal requestedQuantity;

    @Column(name = "estimated_unit_cost", nullable = false, precision = 18, scale = 2)
    private BigDecimal estimatedUnitCost = BigDecimal.ZERO;

    @Column(name = "line_total", nullable = false, precision = 18, scale = 2)
    private BigDecimal lineTotal = BigDecimal.ZERO;

    @Column(name = "last_purchase_cost", precision = 18, scale = 2)
    private BigDecimal lastPurchaseCost;

    @Column(name = "line_note", length = 255)
    private String lineNote;
}
