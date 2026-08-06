package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.TransferDtos;
import com.kaknnea.pos.service.StockTransferService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/inventory/transfers")
public class StockTransferController {
    private final StockTransferService stockTransferService;

    public StockTransferController(StockTransferService stockTransferService) {
        this.stockTransferService = stockTransferService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_TRANSFER_MANAGE')")
    public List<TransferDtos.TransferResponse> list() {
        return stockTransferService.list();
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_TRANSFER_MANAGE')")
    public TransferDtos.TransferResponse create(@Valid @RequestBody TransferDtos.TransferCreateRequest request) {
        return stockTransferService.create(request);
    }

    @PostMapping("/{id}/complete")
    @PreAuthorize("hasAuthority('PERM_TRANSFER_MANAGE')")
    public TransferDtos.TransferResponse complete(@PathVariable Long id) {
        return stockTransferService.complete(id);
    }

    @PostMapping("/{id}/cancel")
    @PreAuthorize("hasAuthority('PERM_TRANSFER_MANAGE')")
    public TransferDtos.TransferResponse cancel(@PathVariable Long id) {
        return stockTransferService.cancel(id);
    }
}
