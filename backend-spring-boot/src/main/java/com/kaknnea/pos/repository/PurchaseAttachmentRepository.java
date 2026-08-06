package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PurchaseAttachment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PurchaseAttachmentRepository extends JpaRepository<PurchaseAttachment, Long> {
    List<PurchaseAttachment> findAllByDocumentTypeAndDocumentIdOrderByCreatedAtDesc(String documentType, Long documentId);

    long countByDocumentTypeAndDocumentId(String documentType, Long documentId);
}
