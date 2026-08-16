package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Entity
@Table(name = "sale_lines")
@Getter
@Setter
public class SaleLine {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sale_id", nullable = false)
    private Sale sale;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @Column(nullable = false, precision = 18, scale = 2)
    private BigDecimal quantity;

    @Column(name = "unit_price", nullable = false, precision = 18, scale = 2)
    private BigDecimal unitPrice;

    @Column(name = "line_discount", nullable = false, precision = 18, scale = 2)
    private BigDecimal lineDiscount;

    @Column(name = "line_total", nullable = false, precision = 18, scale = 2)
    private BigDecimal lineTotal;

    /**
     * The tax rate (fraction, e.g. 0.08) actually applied to this line at
     * sale time — captured from the product's own rate so a later edit to
     * that product's tax rate never retroactively changes an already-sold
     * line. {@code taxAmount} for a line is deliberately not persisted
     * separately; compute it on demand as {@code lineTotal * taxRate}.
     */
    @Column(name = "tax_rate", nullable = false)
    private double taxRate;

    @Column(name = "refunded_quantity", nullable = false, precision = 18, scale = 2)
    private BigDecimal refundedQuantity = BigDecimal.ZERO;

    @Column(name = "delivered_quantity", nullable = false, precision = 18, scale = 2)
    private BigDecimal deliveredQuantity = BigDecimal.ZERO;

    @Column(name = "stock_deducted_quantity", nullable = false, precision = 18, scale = 2)
    private BigDecimal stockDeductedQuantity = BigDecimal.ZERO;

    @Column(name = "line_note", length = 500)
    private String lineNote;

    @Column(name = "modifier_summary", length = 512)
    private String modifierSummary;

    @Lob
    @Column(name = "modifier_data", columnDefinition = "LONGTEXT")
    private String modifierData;
}
