package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.PurchasingWorkflowDtos;
import com.kaknnea.pos.service.PurchasingWorkflowService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/goods-receipts")
public class GoodsReceiptController {
    private final PurchasingWorkflowService purchasingWorkflowService;

    public GoodsReceiptController(PurchasingWorkflowService purchasingWorkflowService) {
        this.purchasingWorkflowService = purchasingWorkflowService;
    }

    @GetMapping
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_INVENTORY_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public List<PurchasingWorkflowDtos.GoodsReceiptResponse> list() {
        return purchasingWorkflowService.listGoodsReceipts();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_INVENTORY_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public PurchasingWorkflowDtos.GoodsReceiptResponse get(@PathVariable Long id) {
        return purchasingWorkflowService.getGoodsReceipt(id);
    }

    @PostMapping
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_INVENTORY_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.GoodsReceiptResponse create(
            @Valid @RequestBody PurchasingWorkflowDtos.GoodsReceiptRequest request) {
        return purchasingWorkflowService.createGoodsReceipt(request);
    }
}
