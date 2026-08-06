package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Entity
@Table(name = "supplier_catalog_items")
@Getter
@Setter
public class SupplierCatalogItem extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "supplier_id", nullable = false)
    private Supplier supplier;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @Column(name = "supplier_sku", length = 80)
    private String supplierSku;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "purchase_unit_id")
    private Unit purchaseUnit;

    @Column(name = "last_cost", precision = 18, scale = 2)
    private BigDecimal lastCost;

    @Column(name = "lead_time_days")
    private Integer leadTimeDays;

    @Column(name = "minimum_order_quantity", precision = 18, scale = 2)
    private BigDecimal minimumOrderQuantity;

    @Column(name = "pack_size", precision = 18, scale = 2)
    private BigDecimal packSize;

    @Column(nullable = false)
    private boolean active = true;
}
