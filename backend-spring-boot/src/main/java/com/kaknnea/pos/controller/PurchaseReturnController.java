package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.PurchasingWorkflowDtos;
import com.kaknnea.pos.service.PurchasingWorkflowService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/purchase-returns")
public class PurchaseReturnController {
    private final PurchasingWorkflowService purchasingWorkflowService;

    public PurchaseReturnController(PurchasingWorkflowService purchasingWorkflowService) {
        this.purchasingWorkflowService = purchasingWorkflowService;
    }

    @GetMapping
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_INVENTORY_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public List<PurchasingWorkflowDtos.PurchaseReturnResponse> list() {
        return purchasingWorkflowService.listPurchaseReturns();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_INVENTORY_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public PurchasingWorkflowDtos.PurchaseReturnResponse get(@PathVariable Long id) {
        return purchasingWorkflowService.getPurchaseReturn(id);
    }

    @PostMapping
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_INVENTORY_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.PurchaseReturnResponse create(
            @Valid @RequestBody PurchasingWorkflowDtos.PurchaseReturnRequest request) {
        return purchasingWorkflowService.createPurchaseReturn(request);
    }
}
