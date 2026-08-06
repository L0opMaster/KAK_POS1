package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.UnitDtos;
import com.kaknnea.pos.service.UnitService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/units")
public class UnitController {
    private final UnitService unitService;

    public UnitController(UnitService unitService) {
        this.unitService = unitService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_INVENTORY_MANAGE') or hasAuthority('PERM_PURCHASE_MANAGE') or hasAuthority('PERM_TRANSFER_MANAGE') or hasAuthority('PERM_POS_SALE')")
    public Page<UnitDtos.UnitResponse> list(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(required = false) Boolean active,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return unitService.list(q, active, PageRequest.of(page, size));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public UnitDtos.UnitResponse get(@PathVariable Long id) {
        return unitService.get(id);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public UnitDtos.UnitResponse create(@Valid @RequestBody UnitDtos.UnitRequest request) {
        return unitService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public UnitDtos.UnitResponse update(@PathVariable Long id, @Valid @RequestBody UnitDtos.UnitRequest request) {
        return unitService.update(id, request);
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAuthority('PERM_SETTINGS_MANAGE')")
    public UnitDtos.UnitResponse updateStatus(@PathVariable Long id, @RequestBody UnitDtos.UnitStatusRequest request) {
        return unitService.updateStatus(id, request.isActive());
    }
}
