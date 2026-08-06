package com.kaknnea.pos.controller;

import com.kaknnea.pos.dto.CashEventDtos;
import com.kaknnea.pos.dto.ShiftDtos;
import com.kaknnea.pos.service.CashEventService;
import com.kaknnea.pos.service.ShiftService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/shifts")
public class ShiftController {
    private final ShiftService shiftService;
    private final CashEventService cashEventService;

    public ShiftController(ShiftService shiftService, CashEventService cashEventService) {
        this.shiftService = shiftService;
        this.cashEventService = cashEventService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('PERM_SHIFT_MANAGE')")
    public List<ShiftDtos.ShiftResponse> list() {
        return shiftService.list();
    }

    @GetMapping("/current")
    @PreAuthorize("hasAuthority('PERM_POS_SALE')")
    public ShiftDtos.ShiftResponse getCurrentShift() {
        return shiftService.getCurrentShift();
    }

    @GetMapping("/history")
    @PreAuthorize("hasAuthority('PERM_SHIFT_MANAGE')")
    public List<ShiftDtos.ShiftResponse> history() {
        return shiftService.list();
    }

    @PostMapping("/open")
    @PreAuthorize("hasAuthority('PERM_SHIFT_MANAGE') or hasAuthority('PERM_POS_SALE')")
    public ShiftDtos.ShiftResponse open(@Valid @RequestBody ShiftDtos.OpenShiftRequest request) {
        return shiftService.open(request);
    }

    @PostMapping("/{id}/close")
    @PreAuthorize("hasAuthority('PERM_SHIFT_MANAGE')")
    public ShiftDtos.ShiftResponse close(@PathVariable Long id,
            @Valid @RequestBody ShiftDtos.CloseShiftRequest request) {
        return shiftService.close(id, request);
    }

    @GetMapping("/{id}/close-precheck")
    @PreAuthorize("hasAuthority('PERM_POS_SALE') or hasAuthority('PERM_SHIFT_MANAGE')")
    public ShiftDtos.ShiftClosePrecheckResponse closePrecheck(@PathVariable Long id) {
        return shiftService.precheckClose(id);
    }

    @PostMapping("/{id}/approve-variance")
    @PreAuthorize("hasAuthority('PERM_SHIFT_MANAGE') or hasAnyRole('MANAGER', 'OWNER')")
    public ShiftDtos.ShiftResponse approveVariance(@PathVariable Long id,
            @Valid @RequestBody ShiftDtos.ApproveVarianceRequest request) {
        return shiftService.approveVariance(id, request);
    }

    @GetMapping("/{id}/cash-events")
    @PreAuthorize("hasAuthority('PERM_POS_SALE') or hasAuthority('PERM_SHIFT_MANAGE')")
    public List<CashEventDtos.CashEventResponse> listCashEvents(@PathVariable Long id) {
        return cashEventService.listByShift(id);
    }

    @PostMapping("/{id}/cash-events")
    @PreAuthorize("hasAuthority('PERM_POS_SALE') or hasAuthority('PERM_SHIFT_MANAGE')")
    public CashEventDtos.CashEventResponse createCashEvent(
            @PathVariable Long id,
            @Valid @RequestBody CashEventDtos.CashEventRequest request) {
        return cashEventService.create(id, request);
    }
}
