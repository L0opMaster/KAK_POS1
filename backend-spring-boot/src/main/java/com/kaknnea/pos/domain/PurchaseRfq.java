package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "purchase_rfqs")
@Getter
@Setter
public class PurchaseRfq extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "supplier_id")
    private Supplier supplier;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_id")
    private Store store;

    @Column(nullable = false, length = 40)
    private String status;

    @Column(name = "target_date")
    private LocalDate targetDate;

    @Column(name = "request_reference", length = 120)
    private String requestReference;

    @Column(length = 500)
    private String notes;

    @Column(nullable = false, precision = 18, scale = 2)
    private BigDecimal subtotal = BigDecimal.ZERO;

    @Column(name = "tax_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal taxAmount = BigDecimal.ZERO;

    @Column(name = "total_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "approved_by_email", length = 150)
    private String approvedByEmail;

    @OneToMany(mappedBy = "purchaseRfq", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<PurchaseRfqLine> lines = new ArrayList<>();
}
