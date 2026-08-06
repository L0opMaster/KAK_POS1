package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.PurchasingWorkflowDtos;
import com.kaknnea.pos.service.PurchasingWorkflowService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/purchase-rfqs")
public class PurchaseRfqController {
    private final PurchasingWorkflowService purchasingWorkflowService;

    public PurchaseRfqController(PurchasingWorkflowService purchasingWorkflowService) {
        this.purchasingWorkflowService = purchasingWorkflowService;
    }

    @GetMapping
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public List<PurchasingWorkflowDtos.PurchaseRfqResponse> list() {
        return purchasingWorkflowService.listPurchaseRfqs();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public PurchasingWorkflowDtos.PurchaseRfqResponse get(@PathVariable Long id) {
        return purchasingWorkflowService.getPurchaseRfq(id);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.PurchaseRfqResponse create(@Valid @RequestBody PurchasingWorkflowDtos.PurchaseRfqRequest request) {
        return purchasingWorkflowService.createPurchaseRfq(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.PurchaseRfqResponse update(@PathVariable Long id, @Valid @RequestBody PurchasingWorkflowDtos.PurchaseRfqRequest request) {
        return purchasingWorkflowService.updatePurchaseRfq(id, request);
    }

    @PostMapping("/{id}/{action}")
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.PurchaseRfqResponse transition(@PathVariable Long id, @PathVariable String action) {
        return purchasingWorkflowService.transitionPurchaseRfq(id, action);
    }

    @PostMapping("/{id}/convert-to-po")
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.PurchaseOrderResponse convertToPurchaseOrder(@PathVariable Long id) {
        return purchasingWorkflowService.convertRfqToPurchaseOrder(id);
    }
}
