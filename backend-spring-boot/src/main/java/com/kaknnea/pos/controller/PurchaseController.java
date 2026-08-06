package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.PurchaseDtos;
import com.kaknnea.pos.service.PurchaseService;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/purchases")
public class PurchaseController {
    private final PurchaseService purchaseService;

    public PurchaseController(PurchaseService purchaseService) {
        this.purchaseService = purchaseService;
    }

    private HttpHeaders legacyHeaders() {
        HttpHeaders headers = new HttpHeaders();
        headers.add("Deprecation", "true");
        headers.add("Warning", "299 - Legacy purchase API; use /api/purchase-orders, /api/goods-receipts, /api/supplier-invoices, /api/supplier-payments, and /api/purchase-returns");
        headers.add("Link", "</api/purchase-orders>; rel=\"successor-version\"");
        return headers;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE')")
    public ResponseEntity<List<PurchaseDtos.PurchaseResponse>> list() {
        return ResponseEntity.ok().headers(legacyHeaders()).body(purchaseService.list());
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE')")
    public ResponseEntity<PurchaseDtos.PurchaseResponse> create(@Valid @RequestBody PurchaseDtos.PurchaseCreateRequest request) {
        return ResponseEntity.ok().headers(legacyHeaders()).body(purchaseService.create(request));
    }

    @PostMapping("/{id}/receive")
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE')")
    public ResponseEntity<PurchaseDtos.PurchaseResponse> receive(@PathVariable Long id) {
        return ResponseEntity.ok().headers(legacyHeaders()).body(purchaseService.receive(id));
    }

    @PostMapping("/{id}/pay")
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE')")
    public ResponseEntity<PurchaseDtos.PurchaseResponse> pay(@PathVariable Long id, @Valid @RequestBody PurchaseDtos.PurchasePayRequest request) {
        return ResponseEntity.ok().headers(legacyHeaders()).body(purchaseService.pay(id, request));
    }
}
