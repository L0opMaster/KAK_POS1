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
@Table(name = "purchase_orders")
@Getter
@Setter
public class PurchaseOrder extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "supplier_id", nullable = false)
    private Supplier supplier;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "store_id", nullable = false)
    private Store store;

    @Column(nullable = false, length = 40)
    private String status;

    @Column(name = "tax_rate", nullable = false, precision = 18, scale = 4)
    private BigDecimal taxRate;

    @Column(nullable = false, precision = 18, scale = 2)
    private BigDecimal subtotal;

    @Column(name = "tax_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal taxAmount;

    @Column(name = "total_amount", nullable = false, precision = 18, scale = 2)
    private BigDecimal totalAmount;

    @Column(length = 255)
    private String notes;

    @Column(name = "ordered_at")
    private Instant orderedAt;

    @Column(name = "approved_at")
    private Instant approvedAt;

    @Column(name = "order_deadline")
    private LocalDate orderDeadline;

    @Column(name = "expected_arrival")
    private LocalDate expectedArrival;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "purchase_representative_id")
    private User purchaseRepresentative;

    @Column(name = "sent_at")
    private Instant sentAt;

    @Column(name = "reference_number", length = 30, unique = true)
    private String referenceNumber;

    @OneToMany(mappedBy = "purchaseOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<PurchaseOrderLine> lines = new ArrayList<>();
}
