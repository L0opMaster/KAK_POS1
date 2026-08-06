package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.OtherIncomeDtos;
import com.kaknnea.pos.service.OtherIncomeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/other-income-categories")
@RequiredArgsConstructor
public class OtherIncomeCategoryController {
    private final OtherIncomeService service;

    private static final String READ_ACCESS =
            "hasRole('OWNER') or hasRole('ADMIN') or hasRole('ACCOUNTANT') or hasRole('MANAGER') " +
            "or hasAuthority('PERM_REPORTS_VIEW') or hasAuthority('PERM_EXPENSE_MANAGE') or hasAuthority('PERM_ADMIN')";
    private static final String WRITE_ACCESS =
            "hasRole('OWNER') or hasRole('ADMIN') or hasRole('MANAGER') or hasRole('ACCOUNTANT') " +
            "or hasAuthority('PERM_EXPENSE_MANAGE') or hasAuthority('PERM_ADMIN')";

    @GetMapping
    @PreAuthorize(READ_ACCESS)
    public List<OtherIncomeDtos.CategoryResponse> list() {
        return service.listCategories();
    }

    @PostMapping
    @PreAuthorize(WRITE_ACCESS)
    public OtherIncomeDtos.CategoryResponse create(@Valid @RequestBody OtherIncomeDtos.CategoryRequest request) {
        return service.createCategory(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize(WRITE_ACCESS)
    public OtherIncomeDtos.CategoryResponse update(@PathVariable Long id, @Valid @RequestBody OtherIncomeDtos.CategoryRequest request) {
        return service.updateCategory(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize(WRITE_ACCESS)
    public void delete(@PathVariable Long id) {
        service.deleteCategory(id);
    }
}
