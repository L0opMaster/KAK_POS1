package com.kaknnea.pos.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "currencies")
@Getter
@Setter
public class CurrencySetting extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 12)
    private String code;

    @Column(nullable = false, length = 60)
    private String name;

    @Column(nullable = false, length = 12)
    private String symbol;

    @Column(name = "exchange_rate", nullable = false, precision = 18, scale = 6)
    private java.math.BigDecimal exchangeRate = java.math.BigDecimal.ONE;

    @Column(name = "display_order", nullable = false)
    private int displayOrder = 0;

    @Column(name = "is_default", nullable = false)
    private boolean defaultCurrency = false;

    @Column(nullable = false)
    private boolean active = true;
}
