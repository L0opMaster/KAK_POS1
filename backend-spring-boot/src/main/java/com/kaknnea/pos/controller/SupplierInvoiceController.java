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
@RequestMapping("/api/supplier-invoices")
public class SupplierInvoiceController {
    private final PurchasingWorkflowService purchasingWorkflowService;

    public SupplierInvoiceController(PurchasingWorkflowService purchasingWorkflowService) {
        this.purchasingWorkflowService = purchasingWorkflowService;
    }

    @GetMapping
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public Object list(
            @RequestParam(required = false) Integer page,
            @RequestParam(defaultValue = "25") int size,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Long supplierId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        if (page != null) {
            Pageable pageable = PageRequest.of(Math.max(0, page), Math.min(Math.max(1, size), 200),
                    Sort.by(Sort.Direction.DESC, "invoiceDate", "id"));
            return purchasingWorkflowService.listSupplierInvoicesPage(q, status, supplierId, from, to, pageable);
        }
        return purchasingWorkflowService.listSupplierInvoices();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public PurchasingWorkflowDtos.SupplierInvoiceResponse get(@PathVariable Long id) {
        return purchasingWorkflowService.getSupplierInvoice(id);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasRole('ACCOUNTANT') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.SupplierInvoiceResponse create(
            @Valid @RequestBody PurchasingWorkflowDtos.SupplierInvoiceRequest request) {
        return purchasingWorkflowService.createSupplierInvoice(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasRole('ACCOUNTANT') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.SupplierInvoiceResponse update(
            @PathVariable Long id,
            @Valid @RequestBody PurchasingWorkflowDtos.SupplierInvoiceRequest request) {
        return purchasingWorkflowService.updateSupplierInvoice(id, request);
    }

    @PostMapping("/{id}/void")
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasRole('ACCOUNTANT') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public PurchasingWorkflowDtos.SupplierInvoiceResponse voidInvoice(@PathVariable Long id) {
        return purchasingWorkflowService.voidSupplierInvoice(id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAuthority('PERM_PURCHASE_MANAGE') or hasRole('ACCOUNTANT') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public void delete(@PathVariable Long id) {
        purchasingWorkflowService.deleteSupplierInvoice(id);
    }

    @PostMapping("/{id}/match-check")
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public PurchasingWorkflowDtos.PurchaseMatchWarningResponse matchCheck(@PathVariable Long id) {
        return purchasingWorkflowService.invoiceMatchWarnings(id);
    }
}
