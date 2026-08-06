package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "suppliers")
@Getter
@Setter
public class Supplier extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String name;

    @Column(length = 50)
    private String phone;

    @Column(length = 150)
    private String email;

    @Column(length = 255)
    private String address;

    @Column(name = "contact_person", length = 120)
    private String contactPerson;

    @Column(name = "payment_terms", length = 120)
    private String paymentTerms;

    @Column(name = "lead_time_days")
    private Integer leadTimeDays;

    @Column(name = "tax_id", length = 80)
    private String taxId;

    @Column(name = "default_currency", nullable = false, length = 12)
    private String defaultCurrency = "KHR";

    @Column(nullable = false)
    private boolean active = true;

    @Column(length = 255)
    private String notes;
}
