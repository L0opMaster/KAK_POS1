package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.PurchasingWorkflowDtos;
import com.kaknnea.pos.service.PurchasingWorkflowService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/purchasing")
public class PurchasingInsightsController {
    private final PurchasingWorkflowService purchasingWorkflowService;

    public PurchasingInsightsController(PurchasingWorkflowService purchasingWorkflowService) {
        this.purchasingWorkflowService = purchasingWorkflowService;
    }

    @GetMapping("/dashboard")
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE', 'PERM_INVENTORY_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public PurchasingWorkflowDtos.PurchaseDashboardResponse dashboard() {
        return purchasingWorkflowService.purchasingDashboard();
    }

    @GetMapping("/activities/{documentType}/{documentId}")
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE', 'PERM_INVENTORY_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public List<PurchasingWorkflowDtos.PurchaseActivityResponse> activities(@PathVariable String documentType, @PathVariable Long documentId) {
        return purchasingWorkflowService.listActivities(documentType.toUpperCase(), documentId);
    }
}
