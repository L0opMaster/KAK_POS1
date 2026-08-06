package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.SupplierCatalogDtos;
import com.kaknnea.pos.service.SupplierCatalogService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/supplier-catalog")
public class SupplierCatalogController {
    private final SupplierCatalogService supplierCatalogService;

    public SupplierCatalogController(SupplierCatalogService supplierCatalogService) {
        this.supplierCatalogService = supplierCatalogService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_SUPPLIER_MANAGE') or hasAuthority('PERM_PURCHASE_MANAGE') or hasAuthority('PERM_INVENTORY_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public List<SupplierCatalogDtos.SupplierCatalogItemResponse> list(@RequestParam Long supplierId) {
        return supplierCatalogService.list(supplierId);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_SUPPLIER_MANAGE') or hasAuthority('PERM_PURCHASE_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public SupplierCatalogDtos.SupplierCatalogItemResponse create(@Valid @RequestBody SupplierCatalogDtos.SupplierCatalogItemRequest request) {
        return supplierCatalogService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_SUPPLIER_MANAGE') or hasAuthority('PERM_PURCHASE_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public SupplierCatalogDtos.SupplierCatalogItemResponse update(@PathVariable Long id, @Valid @RequestBody SupplierCatalogDtos.SupplierCatalogItemRequest request) {
        return supplierCatalogService.update(id, request);
    }
}
