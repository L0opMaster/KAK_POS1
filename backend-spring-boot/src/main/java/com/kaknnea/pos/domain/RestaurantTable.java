package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@Entity
@Table(name = "tables", indexes = {
    @Index(name = "idx_tables_table_number", columnList = "table_number", unique = true),
    @Index(name = "idx_tables_status", columnList = "status")
})
public class RestaurantTable extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "table_number", nullable = false, length = 20, unique = true)
    private String tableNumber;

    @Column(name = "display_name", length = 100)
    private String displayName;

    @Column(name = "status", nullable = false, length = 20)
    private String status = "AVAILABLE"; // AVAILABLE, OCCUPIED, RESERVED, OUT_OF_ORDER

    @Column(name = "capacity", nullable = false)
    private Integer capacity = 4;

    @Column(name = "section", length = 50)
    private String section; // e.g., "INDOOR", "OUTDOOR", "VIP"

    @Column(name = "notes", length = 255)
    private String notes;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;
}