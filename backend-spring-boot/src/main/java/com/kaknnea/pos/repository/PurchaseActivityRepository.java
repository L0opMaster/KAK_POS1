package com.kaknnea.pos.repository;

import com.kaknnea.pos.domain.PurchaseActivity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PurchaseActivityRepository extends JpaRepository<PurchaseActivity, Long> {
    List<PurchaseActivity> findAllByDocumentTypeAndDocumentIdOrderByCreatedAtDesc(String documentType, Long documentId);
}
