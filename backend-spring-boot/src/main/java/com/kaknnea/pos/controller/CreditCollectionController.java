package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.CreditCollectionDtos;
import com.kaknnea.pos.service.CreditCollectionService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;

@RestController
@RequestMapping("/api/customers/{customerId}/collections")
public class CreditCollectionController {

    private final CreditCollectionService creditCollectionService;

    public CreditCollectionController(CreditCollectionService creditCollectionService) {
        this.creditCollectionService = creditCollectionService;
    }

    @PostMapping("/preview")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
    public CreditCollectionDtos.PreviewResponse previewCollection(
            @PathVariable Long customerId,
            @RequestBody CreditCollectionDtos.PreviewRequest request) {
        return creditCollectionService.previewCollection(customerId, request.getAmount(), request.getStrategy());
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER')")
    public CreditCollectionDtos.CollectResponse collect(
            @PathVariable Long customerId,
            @Valid @RequestBody CreditCollectionDtos.CollectRequest request) {
        return creditCollectionService.collect(customerId, request);
    }
}
