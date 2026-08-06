package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "expense_categories")
@Getter
@Setter
public class ExpenseCategory extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "name_en", nullable = false, length = 120)
    private String nameEn;

    @Column(name = "name_km", nullable = false, length = 120)
    private String nameKm;

    @Column(name = "color", length = 20)
    private String color = "#6366f1";

    @Column(name = "active", nullable = false)
    private boolean active = true;
}
