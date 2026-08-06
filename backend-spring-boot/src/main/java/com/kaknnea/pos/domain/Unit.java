package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import java.math.BigDecimal;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "units")
@Getter
@Setter
public class Unit {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 40)
    private String code;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(name = "name_en", nullable = false, length = 120)
    private String nameEn;

    @Column(name = "name_km", nullable = false, length = 120)
    private String nameKm;

    @Column(nullable = false, length = 20)
    private String symbol;

    @Column(name = "base_unit_group", nullable = false, length = 60)
    private String baseUnitGroup;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "base_unit_id")
    private Unit baseUnit;

    @Column(name = "is_base_unit", nullable = false)
    private boolean baseUnitFlag = true;

    @Column(name = "conversion_factor", nullable = false, precision = 18, scale = 6)
    private BigDecimal conversionFactor = BigDecimal.ONE;

    @Column(nullable = false)
    private boolean active = true;

    public boolean isBaseUnit() {
        return baseUnitFlag;
    }
}
