package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.PurchasingWorkflowDtos;
import com.kaknnea.pos.service.PurchasingWorkflowService;
import jakarta.validation.Valid;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/supplier-payments")
public class SupplierPaymentController {
    private final PurchasingWorkflowService purchasingWorkflowService;

    public SupplierPaymentController(PurchasingWorkflowService purchasingWorkflowService) {
        this.purchasingWorkflowService = purchasingWorkflowService;
    }

    @GetMapping
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public Object list(
            @RequestParam(required = false) Integer page,
            @RequestParam(defaultValue = "25") int size,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) Long supplierId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        if (page != null) {
            Pageable pageable = PageRequest.of(Math.max(0, page), Math.min(Math.max(1, size), 200),
                    Sort.by(Sort.Direction.DESC, "paidAt", "id"));
            return purchasingWorkflowService.listSupplierPaymentsPage(q, supplierId, from, to, pageable);
        }
        return purchasingWorkflowService.listSupplierPayments();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public PurchasingWorkflowDtos.SupplierPaymentResponse get(@PathVariable Long id) {
        return purchasingWorkflowService.getSupplierPayment(id);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasRole('ACCOUNTANT') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.SupplierPaymentResponse create(
            @Valid @RequestBody PurchasingWorkflowDtos.SupplierPaymentRequest request) {
        return purchasingWorkflowService.createSupplierPayment(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasRole('ACCOUNTANT') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.SupplierPaymentResponse update(
            @PathVariable Long id,
            @Valid @RequestBody PurchasingWorkflowDtos.SupplierPaymentRequest request) {
        return purchasingWorkflowService.updateSupplierPayment(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasRole('ACCOUNTANT') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public void delete(@PathVariable Long id) {
        purchasingWorkflowService.deleteSupplierPayment(id);
    }
}
