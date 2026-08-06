package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Entity
@Table(name = "product_unit_conversions")
@Getter
@Setter
public class ProductUnitConversion {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "source_product_id", nullable = false)
    private Product sourceProduct;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "target_product_id", nullable = false)
    private Product targetProduct;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "source_unit_id", nullable = false)
    private Unit sourceUnit;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "target_unit_id", nullable = false)
    private Unit targetUnit;

    @Column(nullable = false, precision = 18, scale = 4)
    private BigDecimal ratio;

    @Column(name = "conversion_type", nullable = false, length = 40)
    private String conversionType;

    @Column(nullable = false)
    private boolean active = true;
}
