package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.SaleDtos;
import com.kaknnea.pos.service.EmailService;
import com.kaknnea.pos.service.SaleService;
import com.kaknnea.pos.service.ShiftService;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/pos/sales")
public class SaleController {
    private final SaleService saleService;
    private final ShiftService shiftService;
    private final EmailService emailService;

    public SaleController(SaleService saleService, ShiftService shiftService,
                          EmailService emailService) {
        this.saleService = saleService;
        this.shiftService = shiftService;
        this.emailService = emailService;
    }

    @PostMapping
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse create(@Valid @RequestBody SaleDtos.SaleCreateRequest request) {
        return saleService.create(request);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse update(@PathVariable Long id, @Valid @RequestBody SaleDtos.SaleCreateRequest request) {
        return saleService.update(id, request);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse getById(@PathVariable Long id) {
        return saleService.getById(id);
    }

    @PostMapping("/{id}/hold")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse hold(@PathVariable Long id) {
        return saleService.hold(id);
    }

    @PutMapping("/{id}/hold")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse holdPut(@PathVariable Long id) {
        return saleService.hold(id);
    }

    @PutMapping("/{id}/resume")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse resume(@PathVariable Long id) {
        return saleService.resume(id);
    }

    @PutMapping("/{id}/void")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse voidSale(@PathVariable Long id,
            @RequestBody(required = false) java.util.Map<String, String> body) {
        String reason = body != null ? body.get("reason") : null;
        return saleService.voidSale(id, reason);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse deleteSale(@PathVariable Long id,
            @RequestParam(required = false) String reason,
            @RequestBody(required = false) java.util.Map<String, String> body) {
        String resolvedReason = reason != null ? reason : (body != null ? body.get("reason") : "Deleted by user");
        return saleService.deleteSale(id, resolvedReason);
    }

    @PostMapping("/{id}/pay")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse pay(@PathVariable Long id, @Valid @RequestBody SaleDtos.PayRequest request) {
        return saleService.pay(id, request);
    }

    @PostMapping("/{id}/credit")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse credit(@PathVariable Long id) {
        return saleService.credit(id);
    }

    @PostMapping("/{id}/confirm")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse confirm(@PathVariable Long id) {
        return saleService.confirmInvoice(id);
    }

    @PostMapping("/{id}/refund")
    @PreAuthorize("hasAuthority('PERM_POS_REFUND')")
    public SaleDtos.SaleResponse refund(@PathVariable Long id, @Valid @RequestBody SaleDtos.RefundRequest request) {
        return saleService.refund(id, request);
    }

    @PostMapping("/{id}/repayments")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public SaleDtos.SaleResponse repay(@PathVariable Long id,
            @Valid @RequestBody SaleDtos.CreditRepaymentRequest request) {
        return saleService.repayCreditSale(id, request);
    }

    @GetMapping("/{id}/receipt")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public com.kaknnea.pos.dto.ReceiptDtos.ReceiptResponse receipt(@PathVariable Long id) {
        return saleService.receipt(id);
    }

    @GetMapping(value = "/{id}/invoice.pdf", produces = "application/pdf")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public byte[] invoicePdf(@PathVariable Long id,
            @RequestParam(required = false, defaultValue = "false") Boolean thermal) {
        return saleService.invoicePdf(id, thermal);
    }

    @PostMapping("/{id}/email")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public Map<String, Object> emailInvoice(@PathVariable Long id,
            @RequestBody Map<String, String> body) {
        String recipientEmail = body.get("email");
        if (recipientEmail == null || recipientEmail.isBlank()) {
            throw new IllegalArgumentException("Email is required");
        }
        var receipt = saleService.receipt(id);
        String customerName = receipt.getCustomerName();
        byte[] pdf = saleService.invoicePdf(id, false);
        emailService.sendReceipt(recipientEmail, customerName, receipt, pdf);
        return Map.of("success", true, "message", "Invoice emailed to " + recipientEmail);
    }

    @GetMapping("/active-shift")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public java.util.List<SaleDtos.SaleResponse> listByActiveShift(
            @RequestParam(required = false, defaultValue = "PAID") String status) {
        var currentShift = shiftService.getCurrentShift();
        if (currentShift == null) {
            return java.util.List.of();
        }
        return saleService.listByShift(currentShift.getId(), status);
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_POS_SALE') or hasRole('OWNER') or hasRole('ADMIN') or hasRole('MANAGER') or hasRole('ACCOUNTANT')")
    public java.util.List<SaleDtos.SaleResponse> listSales(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Long shiftId,
            @RequestParam(required = false) Instant dateFrom,
            @RequestParam(required = false) Instant dateTo,
            @RequestParam(required = false) String query) {
        return saleService.listFiltered(shiftId, status, dateFrom, dateTo, query);
    }

    @PostMapping("/maintenance/migrate-legacy-confirmed-holds")
    @PreAuthorize("hasRole('OWNER') or hasRole('ADMIN')")
    public java.util.Map<String, Object> migrateLegacyConfirmedHolds() {
        int migrated = saleService.migrateLegacyConfirmedHolds();
        return java.util.Map.of("migratedCount", migrated);
    }

    // ── Deprecated: estimate endpoints moved to EstimateController ─────────
    // Keep backward-compatible aliases during migration.
    @PostMapping("/estimates")
    @Deprecated
    public SaleDtos.SaleResponse createEstimate(@Valid @RequestBody SaleDtos.SaleCreateRequest request) {
        return saleService.createEstimate(request);
    }

    @GetMapping("/estimates")
    @Deprecated
    public List<SaleDtos.SaleResponse> listEstimates(
            @RequestParam(required = false) String status) {
        return saleService.listEstimates(status);
    }

    @PostMapping("/{id}/send-estimate")
    @Deprecated
    public SaleDtos.SaleResponse sendEstimate(@PathVariable Long id) {
        return saleService.sendEstimate(id);
    }

    @PostMapping("/{id}/accept-estimate")
    @Deprecated
    public SaleDtos.SaleResponse acceptEstimate(@PathVariable Long id) {
        return saleService.acceptEstimate(id);
    }

    @PostMapping("/{id}/decline-estimate")
    @Deprecated
    public SaleDtos.SaleResponse declineEstimate(@PathVariable Long id,
            @Valid @RequestBody SaleDtos.DeclineEstimateRequest request) {
        return saleService.declineEstimate(id, request.getReason());
    }

    @PostMapping("/{id}/convert-from-estimate")
    @Deprecated
    public SaleDtos.SaleResponse convertEstimateToSale(@PathVariable Long id) {
        return saleService.convertEstimateToSale(id);
    }

    @GetMapping(value = "/{id}/estimate.pdf", produces = MediaType.APPLICATION_PDF_VALUE)
    @Deprecated
    public byte[] estimatePdf(@PathVariable Long id) {
        return saleService.estimatePdf(id);
    }
}
