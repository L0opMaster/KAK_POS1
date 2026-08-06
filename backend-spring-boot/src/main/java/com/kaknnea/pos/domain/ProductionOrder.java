package com.kaknnea.pos.domain;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "production_orders")
@Getter
@Setter
public class ProductionOrder extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "recipe_id", nullable = false)
    private ProductionRecipe recipe;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Column(nullable = false, length = 40)
    private String status;

    @Column(name = "planned_quantity", nullable = false, precision = 18, scale = 2)
    private BigDecimal plannedQuantity;

    @Column(name = "produced_quantity", nullable = false, precision = 18, scale = 2)
    private BigDecimal producedQuantity;

    @Column(name = "waste_quantity", nullable = false, precision = 18, scale = 2)
    private BigDecimal wasteQuantity = BigDecimal.ZERO;

    @Column(name = "posted_at")
    private Instant postedAt;

    @Column(name = "started_at")
    private Instant startedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;

    @Column(name = "cancel_reason", length = 255)
    private String cancelReason;

    @Column(length = 255)
    private String notes;

    @Column(name = "order_number", length = 30, unique = true)
    private String orderNumber;

    @Column(name = "created_by", length = 100)
    private String createdBy;

    @OneToMany(mappedBy = "productionOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<ProductionOrderLine> lines = new ArrayList<>();
}
