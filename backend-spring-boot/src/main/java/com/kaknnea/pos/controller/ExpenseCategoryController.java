package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.ExpenseDtos;
import com.kaknnea.pos.service.ExpenseService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/expense-categories")
@RequiredArgsConstructor
public class ExpenseCategoryController {

    private final ExpenseService expenseService;

    private static final String READ_ACCESS =
        "hasRole('OWNER') or hasRole('ADMIN') or hasRole('ACCOUNTANT') or hasRole('MANAGER') " +
        "or hasAuthority('PERM_EXPENSE_MANAGE') or hasAuthority('PERM_ADMIN')";

    private static final String WRITE_ACCESS =
        "hasRole('OWNER') or hasRole('ADMIN') or hasRole('MANAGER') " +
        "or hasAuthority('PERM_EXPENSE_MANAGE') or hasAuthority('PERM_ADMIN')";

    @GetMapping
    @PreAuthorize(READ_ACCESS)
    public List<ExpenseDtos.ExpenseCategoryResponse> list() {
        return expenseService.listCategories();
    }

    @PostMapping
    @PreAuthorize(WRITE_ACCESS)
    public ExpenseDtos.ExpenseCategoryResponse create(@Valid @RequestBody ExpenseDtos.ExpenseCategoryRequest request) {
        return expenseService.createCategory(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize(WRITE_ACCESS)
    public ExpenseDtos.ExpenseCategoryResponse update(@PathVariable Long id,
                                                       @Valid @RequestBody ExpenseDtos.ExpenseCategoryRequest request) {
        return expenseService.updateCategory(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize(WRITE_ACCESS)
    public void delete(@PathVariable Long id) {
        expenseService.deleteCategory(id);
    }
}
