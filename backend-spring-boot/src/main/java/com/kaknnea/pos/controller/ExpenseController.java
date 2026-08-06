package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.ExpenseDtos;
import com.kaknnea.pos.service.ExpenseService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/expenses")
@RequiredArgsConstructor
public class ExpenseController {

    private final ExpenseService expenseService;

    private static final String READ_ACCESS =
        "hasRole('OWNER') or hasRole('ADMIN') or hasRole('ACCOUNTANT') or hasRole('MANAGER') or hasRole('CASHIER') " +
        "or hasAuthority('PERM_EXPENSE_MANAGE') or hasAuthority('PERM_EXPENSE_VIEW') or hasAuthority('PERM_ADMIN')";

    private static final String WRITE_ACCESS =
        "hasRole('OWNER') or hasRole('ADMIN') or hasRole('MANAGER') " +
        "or hasAuthority('PERM_EXPENSE_MANAGE') or hasAuthority('PERM_ADMIN')";

    private static final String APPROVE_ACCESS =
        "hasRole('OWNER') or hasRole('ADMIN') or hasRole('ACCOUNTANT') " +
        "or hasAuthority('PERM_ADMIN')";

    @GetMapping
    @PreAuthorize(READ_ACCESS)
    public List<ExpenseDtos.ExpenseResponse> list(
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) String status) {
        return expenseService.list(from, to, categoryId, status);
    }

    @GetMapping("/summary")
    @PreAuthorize(READ_ACCESS)
    public ExpenseDtos.ExpenseSummary summary() {
        return expenseService.summary();
    }

    @PostMapping
    @PreAuthorize(WRITE_ACCESS)
    public ExpenseDtos.ExpenseResponse create(@Valid @RequestBody ExpenseDtos.ExpenseRequest request) {
        return expenseService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize(WRITE_ACCESS)
    public ExpenseDtos.ExpenseResponse update(@PathVariable Long id,
                                               @Valid @RequestBody ExpenseDtos.ExpenseRequest request) {
        return expenseService.update(id, request);
    }

    @PostMapping("/{id}/approve")
    @PreAuthorize(APPROVE_ACCESS)
    public ExpenseDtos.ExpenseResponse approve(@PathVariable Long id) {
        return expenseService.approve(id);
    }

    @PostMapping("/{id}/revert")
    @PreAuthorize(APPROVE_ACCESS)
    public ExpenseDtos.ExpenseResponse revert(@PathVariable Long id) {
        return expenseService.revertToDraft(id);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize(WRITE_ACCESS)
    public void delete(@PathVariable Long id) {
        expenseService.delete(id);
    }
}
