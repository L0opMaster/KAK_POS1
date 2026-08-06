package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.PriceListDtos;
import com.kaknnea.pos.service.PriceListService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/price-lists")
public class PriceListController {
    private final PriceListService priceListService;

    public PriceListController(PriceListService priceListService) {
        this.priceListService = priceListService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public List<PriceListDtos.PriceListResponse> list() {
        return priceListService.list();
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public PriceListDtos.PriceListResponse create(@Valid @RequestBody PriceListDtos.PriceListRequest request) {
        return priceListService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public PriceListDtos.PriceListResponse update(@PathVariable Long id, @Valid @RequestBody PriceListDtos.PriceListRequest request) {
        return priceListService.update(id, request);
    }
}
