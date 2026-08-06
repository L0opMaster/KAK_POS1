package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.ProductionDtos;
import com.kaknnea.pos.service.ProductionService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/production")
public class ProductionController {
    private final ProductionService productionService;

    public ProductionController(ProductionService productionService) {
        this.productionService = productionService;
    }

    @GetMapping("/recipes")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public List<ProductionDtos.RecipeResponse> listRecipes() {
        return productionService.listRecipes();
    }

    @PostMapping("/recipes")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public ProductionDtos.RecipeResponse createRecipe(
            @Valid @RequestBody ProductionDtos.RecipeRequest request) {
        return productionService.createRecipe(request);
    }

    @PutMapping("/recipes/{id}")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public ProductionDtos.RecipeResponse updateRecipe(
            @PathVariable Long id,
            @Valid @RequestBody ProductionDtos.RecipeUpdateRequest request) {
        return productionService.updateRecipe(id, request);
    }

    @DeleteMapping("/recipes/{id}")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deactivateRecipe(@PathVariable Long id) {
        productionService.deactivateRecipe(id);
    }

    @GetMapping("/orders")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public List<ProductionDtos.ProductionOrderResponse> listOrders() {
        return productionService.listOrders();
    }

    @PostMapping("/orders")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public ProductionDtos.ProductionOrderResponse createOrder(
            @Valid @RequestBody ProductionDtos.ProductionOrderRequest request) {
        return productionService.createOrder(request);
    }

    @PostMapping("/orders/check-availability")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public ProductionDtos.AvailabilityCheckResponse checkAvailability(
            @Valid @RequestBody ProductionDtos.AvailabilityCheckRequest request) {
        return productionService.checkAvailability(request);
    }

    @PostMapping("/orders/{id}/start")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public ProductionDtos.ProductionOrderResponse startOrder(@PathVariable Long id) {
        return productionService.startOrder(id);
    }

    @PostMapping("/orders/{id}/complete")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public ProductionDtos.ProductionOrderResponse completeOrder(
            @PathVariable Long id,
            @Valid @RequestBody ProductionDtos.CompleteOrderRequest request) {
        return productionService.completeOrder(id, request);
    }

    @PostMapping("/orders/{id}/cancel")
    @PreAuthorize("hasAuthority('PERM_INVENTORY_MANAGE')")
    public ProductionDtos.ProductionOrderResponse cancelOrder(
            @PathVariable Long id,
            @RequestBody(required = false) ProductionDtos.CancelOrderRequest request) {
        return productionService.cancelOrder(id, request);
    }
}
