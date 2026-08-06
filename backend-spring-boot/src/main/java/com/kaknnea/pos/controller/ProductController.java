package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.ProductDtos;
import com.kaknnea.pos.dto.ProductConversionDtos;
import com.kaknnea.pos.service.ProductService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/products")
public class ProductController {
    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_POS_SALE') or hasRole('ACCOUNTANT')")
    public Page<ProductDtos.ProductResponse> search(@RequestParam(defaultValue = "") String q,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) Boolean active,
            @RequestParam(required = false) Boolean sellable,
            @RequestParam(required = false) Boolean stockTracked,
            @RequestParam(required = false) Boolean purchasable,
            @RequestParam(required = false) Long storeId,
            @RequestParam(required = false) String productType,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return productService.search(q, categoryId, active, sellable, stockTracked, purchasable, storeId, productType,
                PageRequest.of(page, size));
    }

    @GetMapping("/pos-catalog")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_POS_SALE') or hasRole('ACCOUNTANT')")
    public java.util.List<ProductDtos.ProductResponse> posCatalog(@RequestParam(required = false) Long storeId) {
        return productService.posCatalog(storeId);
    }

    @GetMapping("/inventory-catalog")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_INVENTORY_MANAGE') or hasRole('ACCOUNTANT')")
    public java.util.List<ProductDtos.ProductResponse> inventoryCatalog(@RequestParam(required = false) Long storeId) {
        return productService.inventoryCatalog(storeId);
    }

    @GetMapping("/purchasable-catalog")
    @PreAuthorize(
            "hasAnyAuthority('PERM_PRODUCT_MANAGE', 'PERM_PURCHASE_MANAGE', 'PERM_INVENTORY_MANAGE') " +
            "or hasAnyRole('OWNER', 'MANAGER', 'ACCOUNTANT', 'ADMIN')"
    )
    public java.util.List<ProductDtos.ProductResponse> purchasableCatalog(@RequestParam(required = false) Long storeId) {
        return productService.purchasableCatalog(storeId);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public ProductDtos.ProductResponse create(@Valid @RequestBody ProductDtos.ProductRequest request) {
        return productService.create(request);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_POS_SALE') or hasRole('ACCOUNTANT')")
    public ProductDtos.ProductResponse getById(@PathVariable Long id) {
        return productService.getById(id);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public ProductDtos.ProductResponse update(@PathVariable Long id,
            @Valid @RequestBody ProductDtos.ProductRequest request) {
        return productService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public void delete(@PathVariable Long id) {
        productService.delete(id);
    }

    @PostMapping("/{id}/archive")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public ProductDtos.ProductResponse archive(@PathVariable Long id) {
        return productService.archive(id);
    }

    @GetMapping("/{id}/history")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE') or hasAuthority('PERM_INVENTORY_MANAGE') or hasAuthority('PERM_PURCHASE_MANAGE') or hasAuthority('PERM_TRANSFER_MANAGE')")
    public ProductConversionDtos.ProductHistoryResponse history(@PathVariable Long id) {
        return productService.history(id);
    }

    @PostMapping("/seed-samples")
    @PreAuthorize("hasAuthority('PERM_PRODUCT_MANAGE')")
    public ProductDtos.SampleSeedResponse seedSamples(@RequestBody ProductDtos.SampleSeedRequest request) {
        return productService.seedSampleProducts(request);
    }
}
