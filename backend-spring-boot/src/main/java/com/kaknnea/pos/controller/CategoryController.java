package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.CategoryDtos;
import com.kaknnea.pos.service.CategoryService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/categories")
public class CategoryController {
    private final CategoryService categoryService;

    public CategoryController(CategoryService categoryService) {
        this.categoryService = categoryService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_CATEGORY_MANAGE') or hasAuthority('PERM_POS_SALE') or hasRole('ACCOUNTANT')")
    public List<CategoryDtos.CategoryResponse> list() {
        return categoryService.list();
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_CATEGORY_MANAGE')")
    public CategoryDtos.CategoryResponse create(@Valid @RequestBody CategoryDtos.CategoryRequest request) {
        return categoryService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_CATEGORY_MANAGE')")
    public CategoryDtos.CategoryResponse update(@PathVariable Long id, @Valid @RequestBody CategoryDtos.CategoryRequest request) {
        return categoryService.update(id, request);
    }
}
