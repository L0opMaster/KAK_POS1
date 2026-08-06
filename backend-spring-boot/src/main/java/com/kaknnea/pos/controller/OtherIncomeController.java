package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.OtherIncomeDtos;
import com.kaknnea.pos.service.OtherIncomeService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/other-incomes")
@RequiredArgsConstructor
public class OtherIncomeController {
    private final OtherIncomeService service;

    private static final String READ_ACCESS =
            "hasRole('OWNER') or hasRole('ADMIN') or hasRole('ACCOUNTANT') or hasRole('MANAGER') or hasRole('CASHIER') " +
            "or hasAuthority('PERM_REPORTS_VIEW') or hasAuthority('PERM_EXPENSE_MANAGE') or hasAuthority('PERM_ADMIN')";
    private static final String WRITE_ACCESS =
            "hasRole('OWNER') or hasRole('ADMIN') or hasRole('MANAGER') or hasRole('ACCOUNTANT') " +
            "or hasAuthority('PERM_EXPENSE_MANAGE') or hasAuthority('PERM_ADMIN')";
    private static final String APPROVE_ACCESS =
            "hasRole('OWNER') or hasRole('ADMIN') or hasRole('ACCOUNTANT') or hasAuthority('PERM_ADMIN')";

    @GetMapping
    @PreAuthorize(READ_ACCESS)
    public List<OtherIncomeDtos.IncomeResponse> list(
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) String status) {
        return service.list(from, to, categoryId, status);
    }

    @GetMapping("/summary")
    @PreAuthorize(READ_ACCESS)
    public OtherIncomeDtos.Summary summary() {
        return service.summary();
    }

    @PostMapping
    @PreAuthorize(WRITE_ACCESS)
    public OtherIncomeDtos.IncomeResponse create(@Valid @RequestBody OtherIncomeDtos.IncomeRequest request) {
        return service.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize(WRITE_ACCESS)
    public OtherIncomeDtos.IncomeResponse update(@PathVariable Long id, @Valid @RequestBody OtherIncomeDtos.IncomeRequest request) {
        return service.update(id, request);
    }

    @PostMapping("/{id}/approve")
    @PreAuthorize(APPROVE_ACCESS)
    public OtherIncomeDtos.IncomeResponse approve(@PathVariable Long id) {
        return service.approve(id);
    }

    @PostMapping("/{id}/revert")
    @PreAuthorize(APPROVE_ACCESS)
    public OtherIncomeDtos.IncomeResponse revert(@PathVariable Long id) {
        return service.revertToDraft(id);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize(WRITE_ACCESS)
    public void delete(@PathVariable Long id) {
        service.delete(id);
    }
}
