package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.UpdateTimestamp;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "stock_items", uniqueConstraints = @UniqueConstraint(columnNames = {"store_id", "product_id"}))
@Getter
@Setter
public class StockItem {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id", nullable = false)
    private Product product;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Column(name = "quantity", nullable = false, precision = 18, scale = 2)
    private BigDecimal quantity;

    @Column(name = "low_stock_threshold", nullable = false, precision = 18, scale = 2)
    private BigDecimal lowStockThreshold;

    @Version
    private Long version;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
