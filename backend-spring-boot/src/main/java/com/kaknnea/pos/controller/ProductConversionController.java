package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.ProductConversionDtos;
import com.kaknnea.pos.service.ProductConversionService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/product-conversions")
public class ProductConversionController {
    private final ProductConversionService productConversionService;

    public ProductConversionController(ProductConversionService productConversionService) {
        this.productConversionService = productConversionService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_INVENTORY_MANAGE')")
    public List<ProductConversionDtos.ConversionResponse> list(@RequestParam Long productId) {
        return productConversionService.listForProduct(productId);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_INVENTORY_MANAGE')")
    public ProductConversionDtos.ConversionResponse create(@Valid @RequestBody ProductConversionDtos.ConversionRequest request) {
        return productConversionService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_INVENTORY_MANAGE')")
    public ProductConversionDtos.ConversionResponse update(@PathVariable Long id,
                                                           @Valid @RequestBody ProductConversionDtos.ConversionRequest request) {
        return productConversionService.update(id, request);
    }

    @PostMapping("/execute")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public void execute(@Valid @RequestBody ProductConversionDtos.ConversionExecuteRequest request) {
        productConversionService.execute(request);
    }
}
