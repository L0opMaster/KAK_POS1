package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "modifier_groups")
@Getter
@Setter
public class ModifierGroup extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "name_en", nullable = false, length = 120)
    private String nameEn;

    @Column(name = "name_km", nullable = false, length = 120)
    private String nameKm;

    @Column(nullable = false)
    private boolean required = false;

    @Column(name = "multi_select", nullable = false)
    private boolean multiSelect = false;

    @Column(nullable = false)
    private boolean active = true;

    @Column(name = "display_order", nullable = false)
    private int displayOrder = 0;

    @OneToMany(mappedBy = "group", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    private List<ModifierOption> options = new ArrayList<>();

    @ManyToMany(mappedBy = "modifierGroups")
    private List<Product> products = new ArrayList<>();
}
