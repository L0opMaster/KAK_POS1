package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.ModifierDtos;
import com.kaknnea.pos.service.ModifierService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/modifiers")
public class ModifierController {
    private final ModifierService modifierService;

    public ModifierController(ModifierService modifierService) {
        this.modifierService = modifierService;
    }

    @GetMapping("/groups")
    @PreAuthorize("hasAuthority('PERM_MODIFIER_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public List<ModifierDtos.ModifierGroupResponse> listGroups() {
        return modifierService.listGroups();
    }

    @PostMapping("/groups")
    @PreAuthorize("hasAuthority('PERM_MODIFIER_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public ModifierDtos.ModifierGroupResponse createGroup(
            @Valid @RequestBody ModifierDtos.ModifierGroupRequest request) {
        return modifierService.createGroup(request);
    }

    @PutMapping("/groups/{id}")
    @PreAuthorize("hasAuthority('PERM_MODIFIER_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public ModifierDtos.ModifierGroupResponse updateGroup(@PathVariable Long id,
            @Valid @RequestBody ModifierDtos.ModifierGroupRequest request) {
        return modifierService.updateGroup(id, request);
    }

    @DeleteMapping("/groups/{id}")
    @PreAuthorize("hasAuthority('PERM_MODIFIER_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public void deleteGroup(@PathVariable Long id) {
        modifierService.deleteGroup(id);
    }

    @PostMapping("/groups/{groupId}/options")
    @PreAuthorize("hasAuthority('PERM_MODIFIER_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public ModifierDtos.ModifierOptionResponse addOption(@PathVariable Long groupId,
            @Valid @RequestBody ModifierDtos.ModifierOptionRequest request) {
        return modifierService.addOption(groupId, request);
    }

    @PutMapping("/options/{id}")
    @PreAuthorize("hasAuthority('PERM_MODIFIER_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public ModifierDtos.ModifierOptionResponse updateOption(@PathVariable Long id,
            @Valid @RequestBody ModifierDtos.ModifierOptionRequest request) {
        return modifierService.updateOption(id, request);
    }

    @DeleteMapping("/options/{id}")
    @PreAuthorize("hasAuthority('PERM_MODIFIER_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public void deleteOption(@PathVariable Long id) {
        modifierService.deleteOption(id);
    }

    @GetMapping("/groups/{groupId}/products")
    @PreAuthorize("hasAuthority('PERM_MODIFIER_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public List<Long> getGroupProducts(@PathVariable Long groupId) {
        return modifierService.getGroupProductIds(groupId);
    }

    @PutMapping("/groups/{groupId}/products")
    @PreAuthorize("hasAuthority('PERM_MODIFIER_MANAGE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public void updateGroupProducts(@PathVariable Long groupId, @RequestBody List<Long> productIds) {
        modifierService.updateGroupProducts(groupId, productIds);
    }

    @GetMapping("/products/{productId}")
    @PreAuthorize("hasAuthority('PERM_MODIFIER_MANAGE') or hasAuthority('PERM_POS_SALE') or hasAuthority('PERM_PRODUCT_MANAGE')")
    public List<ModifierDtos.ProductModifiersResponse> getProductModifiers(@PathVariable Long productId) {
        return modifierService.getProductModifiers(productId);
    }
}
