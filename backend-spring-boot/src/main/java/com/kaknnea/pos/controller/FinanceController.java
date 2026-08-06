package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.FinanceDtos;
import com.kaknnea.pos.service.FinanceService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/finance")
public class FinanceController {
    private final FinanceService financeService;

    public FinanceController(FinanceService financeService) {
        this.financeService = financeService;
    }

    @GetMapping("/ap-summary")
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public FinanceDtos.PayablesSummaryResponse payablesSummary() {
        return financeService.payablesSummary();
    }

    @GetMapping("/ar-summary")
    @PreAuthorize("hasAnyAuthority('PERM_CUSTOMER_MANAGE', 'PERM_POS_SALE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public FinanceDtos.ReceivablesSummaryResponse receivablesSummary() {
        return financeService.receivablesSummary();
    }

    @GetMapping("/ap-ledger")
    @PreAuthorize("hasAnyAuthority('PERM_PURCHASE_MANAGE', 'PERM_SUPPLIER_MANAGE') or hasAnyRole('OWNER', 'MANAGER', 'ADMIN', 'ACCOUNTANT')")
    public List<FinanceDtos.ApLedgerEntry> apLedger(@RequestParam(defaultValue = "500") int limit) {
        return financeService.apLedger(limit);
    }
}
