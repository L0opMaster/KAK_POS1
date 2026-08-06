package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "predefined_tickets")
@Getter
@Setter
public class PredefinedTicket extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "store_id", nullable = false, length = 80)
    private String storeId;

    @Column(name = "terminal_id", length = 80)
    private String terminalId;

    @Column(name = "name", nullable = false, length = 120)
    private String name;

    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder = 0;

    @Column(name = "active", nullable = false)
    private boolean active = true;
}
