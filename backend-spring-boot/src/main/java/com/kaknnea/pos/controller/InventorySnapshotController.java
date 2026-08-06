package com.kaknnea.pos.controller;

import com.kaknnea.pos.service.InventorySnapshotService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/inventory/snapshots")
public class InventorySnapshotController {
    private final InventorySnapshotService inventorySnapshotService;

    public InventorySnapshotController(InventorySnapshotService inventorySnapshotService) {
        this.inventorySnapshotService = inventorySnapshotService;
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public void snapshot(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(defaultValue = "1") Long storeId
    ) {
        inventorySnapshotService.snapshot(date, storeId);
    }
}
