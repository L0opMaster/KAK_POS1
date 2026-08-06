package com.kaknnea.pos.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "purchase_attachments")
@Getter
@Setter
public class PurchaseAttachment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 32)
    private String documentType;

    @Column(nullable = false)
    private Long documentId;

    @Column(nullable = false)
    private String fileName;

    @Column(nullable = false, length = 1024)
    private String fileUrl;

    @Column(length = 128)
    private String contentType;

    private String createdByEmail;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
