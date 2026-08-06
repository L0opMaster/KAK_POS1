package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.PurchasingWorkflowDtos;
import com.kaknnea.pos.service.PurchaseAttachmentService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/purchase-attachments")
public class PurchaseAttachmentController {
    private final PurchaseAttachmentService purchaseAttachmentService;

    public PurchaseAttachmentController(PurchaseAttachmentService purchaseAttachmentService) {
        this.purchaseAttachmentService = purchaseAttachmentService;
    }

    @GetMapping
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE', 'PERM_INVENTORY_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public List<PurchasingWorkflowDtos.PurchaseAttachmentResponse> list(
            @RequestParam String documentType,
            @RequestParam Long documentId) {
        return purchaseAttachmentService.list(documentType, documentId);
    }

    @PostMapping
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public PurchasingWorkflowDtos.PurchaseAttachmentResponse create(
            @Valid @RequestBody PurchasingWorkflowDtos.PurchaseAttachmentRequest request) {
        return purchaseAttachmentService.create(request);
    }
}
