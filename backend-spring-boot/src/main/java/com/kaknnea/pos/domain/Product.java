package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Entity
@Table(name = "products")
@Getter
@Setter
public class Product extends BaseEntity {
            @Column(name = "parent_product_id", insertable = false, updatable = false)
            private Long parentProductId;

            @Transient
            private String parentProductNameEn;

            @Transient
            private BigDecimal resolvedPrice;

            @Transient
            private Long componentProductId;

            @Transient
            private String componentProductNameEn;

            @Transient
            private String componentProductNameKm;

            @Transient
            private String name;

            @Column(name = "description", length = 255)
            private String description;

            @ManyToMany
            @JoinTable(name = "product_modifier_groups", joinColumns = @JoinColumn(name = "product_id"), inverseJoinColumns = @JoinColumn(name = "group_id"))
            private java.util.List<ModifierGroup> modifierGroups = new java.util.ArrayList<>();
        @ManyToOne(fetch = FetchType.LAZY)
        @JoinColumn(name = "category_id")
        private Category category;

        @ManyToOne(fetch = FetchType.LAZY)
        @JoinColumn(name = "sale_unit_id")
        private Unit saleUnit;

        @ManyToOne(fetch = FetchType.LAZY)
        @JoinColumn(name = "purchase_unit_id")
        private Unit purchaseUnit;

        @ManyToOne(fetch = FetchType.LAZY)
        @JoinColumn(name = "stock_unit_id")
        private Unit stockUnit;

        @Column(name = "variant_label", length = 120)
        private String variantLabel;

        @Column(name = "bundle_mode", length = 40)
        private String bundleMode;

        @Column(name = "low_stock_threshold", nullable = false, precision = 18, scale = 2)
        private BigDecimal lowStockThreshold = new BigDecimal("5.00");

        @ManyToOne(fetch = FetchType.LAZY)
        @JoinColumn(name = "parent_product_id", insertable = false, updatable = false)
        private Product parentProduct;

        @OneToMany(mappedBy = "bundleProduct", cascade = CascadeType.ALL, orphanRemoval = true)
        private java.util.List<ProductBundleComponent> bundleComponents = new java.util.ArrayList<>();

        @OneToMany(mappedBy = "product", cascade = CascadeType.ALL, orphanRemoval = true)
        private java.util.List<ProductImage> images = new java.util.ArrayList<>();
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 80)
    private String sku;

    @Column(nullable = false, unique = true, length = 80)
    private String barcode;

    @Column(name = "name_en", nullable = false, length = 150)
    private String nameEn;

    @Column(name = "name_km", nullable = false, length = 150)
    private String nameKm;

    @Column(name = "image_url", length = 255)
    private String imageUrl;

    @Column(nullable = false, precision = 18, scale = 2)
    private BigDecimal cost;

    @Column(nullable = false, precision = 18, scale = 2)
    private BigDecimal price;

    /**
     * This product's own tax rate, as a fraction (0.08 = 8%) — matches
     * {@code BusinessSettings.taxRate}/{@code Sale.taxRate}'s existing
     * convention. Every product carries its own rate; there is no more
     * store-wide fallback (see V116 migration for how existing rows are
     * backfilled from the old global rate).
     */
    @Column(name = "tax_rate", nullable = false)
    private double taxRate;

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false)
    private boolean sellable = true;

    @Column(nullable = false)
    private boolean purchasable = false;

    @Column(name = "track_inventory", nullable = false)
    private boolean trackInventory = false;

    @Column(name = "product_type", nullable = false, length = 40)
    private String productType = "SALE_ITEM";

    // ...existing code...
}
