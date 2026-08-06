package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.InventoryDtos;
import com.kaknnea.pos.service.InventoryService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.time.LocalDate;

@RestController
@RequestMapping("/api/inventory")
public class InventoryController {
    private final InventoryService inventoryService;

    public InventoryController(InventoryService inventoryService) {
        this.inventoryService = inventoryService;
    }

    @GetMapping("/stocks")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE') or hasRole('ACCOUNTANT')")
    public List<InventoryDtos.StockResponse> list(@RequestParam(required = false) Long storeId) {
        return inventoryService.listStocks(storeId);
    }

    @PostMapping("/stocks/in")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public InventoryDtos.StockResponse stockIn(@Valid @RequestBody InventoryDtos.StockInRequest request) {
        return inventoryService.stockIn(request);
    }

    @PostMapping("/stock-in")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public InventoryDtos.StockResponse stockInAlias(@Valid @RequestBody InventoryDtos.StockInRequest request) {
        return inventoryService.stockIn(request);
    }

    @PostMapping("/stocks/adjust")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public InventoryDtos.StockResponse adjust(@Valid @RequestBody InventoryDtos.StockAdjustRequest request) {
        return inventoryService.adjust(request);
    }

    @PostMapping("/adjust")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public InventoryDtos.StockResponse adjustAlias(@Valid @RequestBody InventoryDtos.StockAdjustRequest request) {
        return inventoryService.adjust(request);
    }

    @GetMapping("/valuation")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE') or hasRole('ACCOUNTANT')")
    public InventoryDtos.StockValuationResponse valuation(@RequestParam(required = false) Long storeId) {
        return inventoryService.valuation(storeId);
    }

    @GetMapping("/movements")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE') or hasRole('ACCOUNTANT')")
    public java.util.List<InventoryDtos.StockMovementResponse> movements(@RequestParam(required = false) Long storeId) {
        return inventoryService.movements(storeId);
    }

    @GetMapping("/counts")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE') or hasRole('ACCOUNTANT')")
    public List<InventoryDtos.InventoryCountEntryResponse> counts(@RequestParam LocalDate date,
            @RequestParam(defaultValue = "1") Long storeId) {
        return inventoryService.listCountEntries(date, storeId);
    }

    @PostMapping("/counts/entry")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public InventoryDtos.InventoryCountEntryResponse recordCount(
            @Valid @RequestBody InventoryDtos.InventoryCountEntryRequest request) {
        return inventoryService.recordCount(request);
    }

    @PostMapping("/counts/post")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public InventoryDtos.InventoryCountPostResponse postCount(
            @Valid @RequestBody InventoryDtos.InventoryCountPostRequest request) {
        return inventoryService.postCount(request);
    }
}
