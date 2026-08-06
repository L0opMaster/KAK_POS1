package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.RecurringInvoiceDtos;
import com.kaknnea.pos.service.RecurringInvoiceService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/recurring-invoices")
public class RecurringInvoiceController {

    private final RecurringInvoiceService recurringInvoiceService;

    public RecurringInvoiceController(RecurringInvoiceService recurringInvoiceService) {
        this.recurringInvoiceService = recurringInvoiceService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_POS_SALE') or hasRole('OWNER') or hasRole('ADMIN')")
    public List<RecurringInvoiceDtos.TemplateResponse> list() {
        return recurringInvoiceService.listAll();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_POS_SALE') or hasRole('OWNER') or hasRole('ADMIN')")
    public RecurringInvoiceDtos.TemplateResponse getById(@PathVariable Long id) {
        return recurringInvoiceService.getById(id);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_POS_SALE') or hasRole('OWNER') or hasRole('ADMIN')")
    public RecurringInvoiceDtos.TemplateResponse create(@Valid @RequestBody RecurringInvoiceDtos.CreateRequest request) {
        return recurringInvoiceService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_POS_SALE') or hasRole('OWNER') or hasRole('ADMIN')")
    public RecurringInvoiceDtos.TemplateResponse update(@PathVariable Long id,
                                                         @Valid @RequestBody RecurringInvoiceDtos.UpdateRequest request) {
        return recurringInvoiceService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_POS_SALE') or hasRole('OWNER') or hasRole('ADMIN')")
    public Map<String, Object> delete(@PathVariable Long id) {
        recurringInvoiceService.delete(id);
        return Map.of("success", true);
    }

    @PostMapping("/generate-now")
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public Map<String, Object> generateNow() {
        int count = recurringInvoiceService.generateDueInvoices();
        return Map.of("success", true, "generated", count);
    }
}
