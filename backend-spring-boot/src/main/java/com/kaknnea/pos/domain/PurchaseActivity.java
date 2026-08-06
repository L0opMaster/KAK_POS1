package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "purchase_activities")
@Getter
@Setter
public class PurchaseActivity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "document_type", nullable = false, length = 40)
    private String documentType;

    @Column(name = "document_id", nullable = false)
    private Long documentId;

    @Column(nullable = false, length = 60)
    private String action;

    @Column(nullable = false, length = 255)
    private String summary;

    @Column(name = "actor_email", length = 150)
    private String actorEmail;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();
}
