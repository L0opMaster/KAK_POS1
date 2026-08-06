package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.ReportDtos;
import com.kaknnea.pos.service.ReportService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/owner")
public class OwnerReportController {
    private final ReportService reportService;

    public OwnerReportController(ReportService reportService) {
        this.reportService = reportService;
    }

    @GetMapping("/eod")
    @PreAuthorize("hasRole('OWNER')")
    public ReportDtos.EodReportResponse getEodReport(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return reportService.getEodReport(date);
    }

    @PostMapping("/eod/run")
    @PreAuthorize("hasRole('OWNER')")
    public ReportDtos.EodRunResponse runEodReport(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            Authentication authentication) {
        LocalDate eodDate = date != null ? date : LocalDate.now().minusDays(1);
        String processedBy = authentication.getName();
        return reportService.runEodReport(eodDate, processedBy);
    }

    @GetMapping("/aging-summary")
    @PreAuthorize("hasRole('OWNER')")
    public ReportDtos.EodReportResponse getAgingSummary(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return reportService.getEodReport(date);
    }

    @GetMapping("/customer-credit")
    @PreAuthorize("hasRole('OWNER')")
    public ReportDtos.EodReportResponse getCustomerCredit(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return reportService.getEodReport(date);
    }
}