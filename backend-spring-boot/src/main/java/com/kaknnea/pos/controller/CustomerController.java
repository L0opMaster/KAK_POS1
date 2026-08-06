package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.CreditCollectionDtos;
import com.kaknnea.pos.dto.CustomerDtos;
import com.kaknnea.pos.dto.PaymentDtos;
import com.kaknnea.pos.service.CreditCollectionService;
import com.kaknnea.pos.service.CustomerService;
import com.kaknnea.pos.service.PaymentService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/customers")
public class CustomerController {
    private final CustomerService customerService;
    private final PaymentService paymentService;
    private final CreditCollectionService creditCollectionService;

    public CustomerController(CustomerService customerService, PaymentService paymentService, CreditCollectionService creditCollectionService) {
        this.customerService = customerService;
        this.paymentService = paymentService;
        this.creditCollectionService = creditCollectionService;
    }

    @GetMapping
    @PreAuthorize("hasAnyAuthority('PERM_CUSTOMER_MANAGE', 'PERM_POS_SALE') or hasAnyRole('ACCOUNTANT', 'OWNER', 'MANAGER')")
    public List<CustomerDtos.CustomerResponse> list(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String status) {
        return customerService.list(q, type, status);
    }

    @GetMapping("/search")
    @PreAuthorize("hasAnyAuthority('PERM_CUSTOMER_MANAGE', 'PERM_POS_SALE') or hasAnyRole('ACCOUNTANT', 'OWNER', 'MANAGER')")
    public CustomerDtos.CustomerSearchResponse search(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        return CustomerDtos.CustomerSearchResponse.from(customerService.search(q, type, status, page, size));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyAuthority('PERM_CUSTOMER_MANAGE', 'PERM_POS_SALE') or hasAnyRole('ACCOUNTANT', 'OWNER', 'MANAGER')")
    public CustomerDtos.CustomerResponse getById(@PathVariable Long id) {
        return customerService.getById(id);
    }

    @PostMapping
    @PreAuthorize("hasAnyAuthority('PERM_CUSTOMER_MANAGE', 'PERM_POS_SALE') or hasAnyRole('OWNER', 'MANAGER')")
    public CustomerDtos.CustomerResponse create(@Valid @RequestBody CustomerDtos.CustomerRequest request) {
        return customerService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyAuthority('PERM_CUSTOMER_MANAGE', 'PERM_POS_SALE') or hasAnyRole('OWNER', 'MANAGER')")
    public CustomerDtos.CustomerResponse update(@PathVariable Long id,
            @Valid @RequestBody CustomerDtos.CustomerRequest request) {
        return customerService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_CUSTOMER_MANAGE')")
    public void delete(@PathVariable Long id) {
        customerService.delete(id);
    }

    @PostMapping("/{id}/repayments")
    @PreAuthorize("hasAnyRole('MANAGER', 'OWNER')")
    public PaymentDtos.PaymentResponse recordRepayment(@PathVariable Long id,
            @Valid @RequestBody CustomerDtos.CustomerRepaymentRequest request) {
        return paymentService.recordCustomerRepayment(id, request);
    }

    @GetMapping("/{id}/history")
    @PreAuthorize("hasAnyAuthority('PERM_CUSTOMER_MANAGE', 'PERM_POS_SALE') or hasAnyRole('ACCOUNTANT', 'OWNER', 'MANAGER')")
    public List<CustomerDtos.CustomerSaleResponse> history(@PathVariable Long id) {
        return customerService.history(id);
    }

    @GetMapping("/{id}/sales")
    @PreAuthorize("hasAnyAuthority('PERM_CUSTOMER_MANAGE', 'PERM_POS_SALE') or hasAnyRole('ACCOUNTANT', 'OWNER', 'MANAGER')")
    public List<CustomerDtos.CustomerSaleResponse> sales(@PathVariable Long id) {
        return customerService.history(id);
    }

    @GetMapping("/{id}/credit-ledger")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER', 'ACCOUNTANT')")
    public CreditCollectionDtos.LedgerResponse getLedger(@PathVariable Long id) {
        return creditCollectionService.getLedger(id);
    }

    @PostMapping("/{id}/opening-balance")
    @PreAuthorize("hasAnyRole('MANAGER', 'OWNER', 'ACCOUNTANT')")
    public CustomerDtos.OpeningBalanceResponse addOpeningBalance(
            @PathVariable Long id,
            @Valid @RequestBody CustomerDtos.OpeningBalanceRequest request) {
        return creditCollectionService.createOpeningBalance(id, request);
    }

    @PostMapping("/{id}/adjustments")
    @PreAuthorize("hasAnyRole('MANAGER', 'OWNER', 'ACCOUNTANT')")
    public CreditCollectionDtos.AdjustmentResponse createAdjustment(
            @PathVariable Long id,
            @Valid @RequestBody CreditCollectionDtos.AdjustmentRequest request) {
        return creditCollectionService.createAdjustment(id, request);
    }

    @GetMapping("/{id}/adjustments")
    @PreAuthorize("hasAnyRole('CASHIER', 'MANAGER', 'OWNER', 'ACCOUNTANT')")
    public java.util.List<CreditCollectionDtos.AdjustmentResponse> listAdjustments(@PathVariable Long id) {
        return creditCollectionService.listAdjustments(id);
    }
}
