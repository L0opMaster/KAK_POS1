package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.StoreDtos;
import com.kaknnea.pos.service.StoreService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/stores")
public class StoreController {
    private final StoreService storeService;

    public StoreController(StoreService storeService) {
        this.storeService = storeService;
    }

    @GetMapping
    @PreAuthorize(
            "hasAnyAuthority('PERM_STORE_MANAGE', 'PERM_POS_SALE', 'PERM_SHIFT_MANAGE', 'PERM_INVENTORY_MANAGE', 'PERM_PURCHASE_MANAGE', 'PERM_TRANSFER_MANAGE') " +
            "or hasAnyRole('OWNER', 'MANAGER', 'ACCOUNTANT', 'ADMIN')"
    )
    public List<StoreDtos.StoreResponse> list() {
        return storeService.list();
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_STORE_MANAGE')")
    public StoreDtos.StoreResponse create(@Valid @RequestBody StoreDtos.StoreRequest request) {
        return storeService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_STORE_MANAGE')")
    public StoreDtos.StoreResponse update(@PathVariable Long id, @Valid @RequestBody StoreDtos.StoreRequest request) {
        return storeService.update(id, request);
    }
}
