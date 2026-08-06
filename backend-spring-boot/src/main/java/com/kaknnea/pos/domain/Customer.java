package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Entity
@Table(name = "customers")
@Getter
@Setter
public class Customer extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 20, columnDefinition = "VARCHAR(20) DEFAULT 'RETAIL'")
    private String type = "RETAIL";

    @Column(name = "customer_code", nullable = false, unique = true, length = 32)
    private String customerCode;

    @Column(name = "status", nullable = false, length = 20, columnDefinition = "VARCHAR(20) DEFAULT 'ACTIVE'")
    private String status = "ACTIVE";

    @Column(name = "name_en", length = 150)
    private String nameEn;

    @Column(name = "name_km", length = 150)
    private String nameKm;

    @Column(length = 50)
    private String phone;

    @Column(length = 150)
    private String email;

    @Column(length = 255)
    private String address;

    @Column(name = "contact_person", length = 150)
    private String contactPerson;

    @Column(name = "payment_terms", length = 80)
    private String paymentTerms;

    @Column(name = "tax_number", length = 80)
    private String taxNumber;

    @Column(name = "display_name", length = 180)
    private String displayName;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "credit_balance", nullable = false, precision = 18, scale = 2)
    private BigDecimal creditBalance = BigDecimal.ZERO;

    @Column(name = "credit_limit", nullable = false, precision = 18, scale = 2)
    private BigDecimal creditLimit = BigDecimal.ZERO;

    @Column(name = "credit_hold", nullable = false, columnDefinition = "TINYINT(1) DEFAULT 0")
    private boolean creditHold = false;

    @OneToOne(mappedBy = "customer", cascade = CascadeType.ALL, orphanRemoval = true)
    private CustomerCreditAccount creditAccount;

    @Transient
    private String code;

    @Transient
    private BigDecimal totalSales = BigDecimal.ZERO;
}
