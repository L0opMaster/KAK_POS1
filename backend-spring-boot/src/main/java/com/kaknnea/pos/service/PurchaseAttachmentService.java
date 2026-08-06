package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.PurchaseAttachment;
import com.kaknnea.pos.dto.PurchasingWorkflowDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.PurchaseAttachmentRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Set;

@Service
public class PurchaseAttachmentService {
    private static final Set<String> SUPPORTED_DOCUMENT_TYPES = Set.of("RFQ", "PO", "GRN", "BILL", "PAYMENT", "RETURN");

    private final PurchaseAttachmentRepository purchaseAttachmentRepository;
    private final PurchaseActivityService purchaseActivityService;

    public PurchaseAttachmentService(PurchaseAttachmentRepository purchaseAttachmentRepository,
            PurchaseActivityService purchaseActivityService) {
        this.purchaseAttachmentRepository = purchaseAttachmentRepository;
        this.purchaseActivityService = purchaseActivityService;
    }

    public List<PurchasingWorkflowDtos.PurchaseAttachmentResponse> list(String documentType, Long documentId) {
        String normalizedType = normalizeDocumentType(documentType);
        return purchaseAttachmentRepository
                .findAllByDocumentTypeAndDocumentIdOrderByCreatedAtDesc(normalizedType, documentId)
                .stream()
                .map(this::toResponse)
                .toList();
    }

    public PurchasingWorkflowDtos.PurchaseAttachmentResponse create(PurchasingWorkflowDtos.PurchaseAttachmentRequest request) {
        String normalizedType = normalizeDocumentType(request.getDocumentType());
        if (request.getDocumentId() == null) {
            throw new ApiException("Document is required");
        }
        if (request.getFileUrl() == null || request.getFileUrl().isBlank()) {
            throw new ApiException("Attachment URL is required");
        }
        if (request.getFileName() == null || request.getFileName().isBlank()) {
            throw new ApiException("Attachment file name is required");
        }
        PurchaseAttachment attachment = new PurchaseAttachment();
        attachment.setDocumentType(normalizedType);
        attachment.setDocumentId(request.getDocumentId());
        attachment.setFileName(request.getFileName().trim());
        attachment.setFileUrl(request.getFileUrl().trim());
        attachment.setContentType(request.getContentType());
        attachment.setCreatedByEmail(currentActorEmail());
        PurchaseAttachment saved = purchaseAttachmentRepository.save(attachment);
        purchaseActivityService.log(normalizedType, saved.getDocumentId(), "ATTACH",
                "Attachment added: " + saved.getFileName());
        return toResponse(saved);
    }

    public long count(String documentType, Long documentId) {
        return purchaseAttachmentRepository.countByDocumentTypeAndDocumentId(normalizeDocumentType(documentType), documentId);
    }

    private String normalizeDocumentType(String documentType) {
        String normalized = documentType == null ? "" : documentType.trim().toUpperCase();
        if (!SUPPORTED_DOCUMENT_TYPES.contains(normalized)) {
            throw new ApiException("Unsupported purchase attachment document type");
        }
        return normalized;
    }

    private String currentActorEmail() {
        var authentication = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        return authentication != null ? authentication.getName() : null;
    }

    private PurchasingWorkflowDtos.PurchaseAttachmentResponse toResponse(PurchaseAttachment attachment) {
        PurchasingWorkflowDtos.PurchaseAttachmentResponse response = new PurchasingWorkflowDtos.PurchaseAttachmentResponse();
        response.setId(attachment.getId());
        response.setDocumentType(attachment.getDocumentType());
        response.setDocumentId(attachment.getDocumentId());
        response.setFileName(attachment.getFileName());
        response.setFileUrl(attachment.getFileUrl());
        response.setContentType(attachment.getContentType());
        response.setCreatedByEmail(attachment.getCreatedByEmail());
        response.setCreatedAt(attachment.getCreatedAt());
        return response;
    }
}
