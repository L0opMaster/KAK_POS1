package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.PurchaseActivity;
import com.kaknnea.pos.dto.PurchasingWorkflowDtos;
import com.kaknnea.pos.repository.PurchaseActivityRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

@Service
public class PurchaseActivityService {
    private final PurchaseActivityRepository purchaseActivityRepository;

    public PurchaseActivityService(PurchaseActivityRepository purchaseActivityRepository) {
        this.purchaseActivityRepository = purchaseActivityRepository;
    }

    public void log(String documentType, Long documentId, String action, String summary) {
        PurchaseActivity activity = new PurchaseActivity();
        activity.setDocumentType(documentType);
        activity.setDocumentId(documentId);
        activity.setAction(action);
        activity.setSummary(summary);
        activity.setActorEmail(currentActorEmail());
        activity.setCreatedAt(Instant.now());
        purchaseActivityRepository.save(activity);
    }

    public List<PurchasingWorkflowDtos.PurchaseActivityResponse> list(String documentType, Long documentId) {
        return purchaseActivityRepository.findAllByDocumentTypeAndDocumentIdOrderByCreatedAtDesc(documentType, documentId)
                .stream()
                .map(this::toResponse)
                .toList();
    }

    private PurchasingWorkflowDtos.PurchaseActivityResponse toResponse(PurchaseActivity activity) {
        PurchasingWorkflowDtos.PurchaseActivityResponse response = new PurchasingWorkflowDtos.PurchaseActivityResponse();
        response.setId(activity.getId());
        response.setDocumentType(activity.getDocumentType());
        response.setDocumentId(activity.getDocumentId());
        response.setAction(activity.getAction());
        response.setSummary(activity.getSummary());
        response.setActorEmail(activity.getActorEmail());
        response.setCreatedAt(activity.getCreatedAt());
        return response;
    }

    private String currentActorEmail() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        return authentication != null ? authentication.getName() : null;
    }
}
