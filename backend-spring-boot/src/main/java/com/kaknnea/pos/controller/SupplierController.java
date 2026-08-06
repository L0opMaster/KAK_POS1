package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.SupplierDtos;
import com.kaknnea.pos.service.SupplierService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/suppliers")
public class SupplierController {
    private final SupplierService supplierService;

    public SupplierController(SupplierService supplierService) {
        this.supplierService = supplierService;
    }

    @GetMapping
    @PreAuthorize(
            "hasAnyAuthority('PERM_SUPPLIER_MANAGE', 'PERM_PURCHASE_MANAGE', 'PERM_INVENTORY_MANAGE') " +
            "or hasAnyRole('OWNER', 'MANAGER', 'ACCOUNTANT', 'ADMIN')"
    )
    public List<SupplierDtos.SupplierResponse> list() {
        return supplierService.list();
    }

    @GetMapping("/{id}")
    @PreAuthorize(
            "hasAnyAuthority('PERM_SUPPLIER_MANAGE', 'PERM_PURCHASE_MANAGE', 'PERM_INVENTORY_MANAGE') " +
            "or hasAnyRole('OWNER', 'MANAGER', 'ACCOUNTANT', 'ADMIN')"
    )
    public SupplierDtos.SupplierResponse get(@PathVariable Long id) {
        return supplierService.get(id);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_SUPPLIER_MANAGE') or hasAuthority('PERM_PURCHASE_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public SupplierDtos.SupplierResponse create(@Valid @RequestBody SupplierDtos.SupplierRequest request) {
        return supplierService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_SUPPLIER_MANAGE') or hasAuthority('PERM_PURCHASE_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public SupplierDtos.SupplierResponse update(@PathVariable Long id, @Valid @RequestBody SupplierDtos.SupplierRequest request) {
        return supplierService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_SUPPLIER_MANAGE') or hasAuthority('PERM_PURCHASE_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN')")
    public void delete(@PathVariable Long id) {
        supplierService.delete(id);
    }
}
