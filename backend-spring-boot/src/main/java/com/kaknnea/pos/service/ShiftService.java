package com.kaknnea.pos.service;

import com.kaknnea.pos.domain.Shift;
import com.kaknnea.pos.domain.Sale;
import com.kaknnea.pos.domain.Store;
import com.kaknnea.pos.domain.User;
import com.kaknnea.pos.dto.ShiftDtos;
import com.kaknnea.pos.exception.ApiException;
import com.kaknnea.pos.repository.CashEventRepository;
import com.kaknnea.pos.repository.SaleRepository;
import com.kaknnea.pos.repository.ShiftRepository;
import com.kaknnea.pos.repository.StoreRepository;
import com.kaknnea.pos.repository.UserRepository;
import com.kaknnea.pos.util.RoleUtil;
import com.kaknnea.pos.util.SecurityUtil;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class ShiftService {
    private static final BigDecimal VARIANCE_THRESHOLD = new BigDecimal("10.00");

    private final ShiftRepository shiftRepository;
    private final UserRepository userRepository;
    private final StoreRepository storeRepository;
    private final CashEventRepository cashEventRepository;
    private final SaleRepository saleRepository;
    private final AuditService auditService;
    private final CashEventService cashEventService;
    private final PasswordEncoder passwordEncoder;

    public ShiftService(ShiftRepository shiftRepository, UserRepository userRepository,
            StoreRepository storeRepository, CashEventRepository cashEventRepository, SaleRepository saleRepository, AuditService auditService,
            CashEventService cashEventService,
            PasswordEncoder passwordEncoder) {
        this.shiftRepository = shiftRepository;
        this.userRepository = userRepository;
        this.storeRepository = storeRepository;
        this.cashEventRepository = cashEventRepository;
        this.saleRepository = saleRepository;
        this.auditService = auditService;
        this.cashEventService = cashEventService;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional(readOnly = true)
    public List<ShiftDtos.ShiftResponse> list() {
        return shiftRepository.findAll().stream().map(this::toResponse).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public ShiftDtos.ShiftResponse getCurrentShift() {
        User actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElseThrow();
        return shiftRepository.findFirstByOpenedByIdAndStatusOrderByOpenedAtDesc(actor.getId(), "OPEN")
                .map(this::toResponse)
                .orElse(null);
    }

    @Transactional
    public ShiftDtos.ShiftResponse open(ShiftDtos.OpenShiftRequest request) {
        User actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElseThrow();
        Store store = resolveStore(request.getStoreId());
        shiftRepository.findFirstByOpenedByIdAndStoreIdAndStatusOrderByOpenedAtDesc(actor.getId(), store.getId(), "OPEN")
                .ifPresent(existing -> {
                    throw new ApiException("An open shift already exists for this cashier and store");
                });
        Shift shift = new Shift();
        shift.setOpenedBy(actor);
        shift.setStore(store);
        shift.setOpeningCash(request.getOpeningCash());
        shift.setStatus("OPEN");
        Shift saved = shiftRepository.save(shift);
        cashEventService.recordInternal(
                saved,
                "OPEN_SHIFT",
                saved.getOpeningCash(),
                "Opening float",
                null,
                actor);
        return toResponse(saved);
    }

    @Transactional
    public ShiftDtos.ShiftResponse close(Long id, ShiftDtos.CloseShiftRequest request) {
        Shift shift = shiftRepository.findById(id).orElseThrow(() -> new ApiException("Shift not found"));
        if (!"OPEN".equals(shift.getStatus())) {
            throw new ApiException("Shift not open");
        }
        ShiftDtos.ShiftClosePrecheckResponse precheck = precheckClose(id);
        User approvedBy = null;
        if (precheck.getInProgressCount() > 0) {
            if (RoleUtil.hasRole("OWNER") || RoleUtil.hasRole("MANAGER")) {
                User actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElseThrow();
                approvedBy = actor;
                if (request.getOverrideReason() == null || request.getOverrideReason().isBlank()) {
                    request.setOverrideReason("Manager override for in-progress tickets");
                }
            } else {
                if (!Boolean.TRUE.equals(request.getForceClose())) {
                    throw new ApiException("Close blocked: resolve in-progress tickets first");
                }
                approvedBy = verifyManagerOverrideCredentials(
                        request.getManagerEmail(),
                        request.getManagerPassword());
                if (request.getOverrideReason() == null || request.getOverrideReason().isBlank()) {
                    throw new ApiException("Override reason is required for force close");
                }
            }
        }
        BigDecimal cashSales = zeroIfNull(cashEventRepository.sumByShiftIdAndTypes(shift.getId(), List.of("SALE_CASH")));
        BigDecimal cashRefunds = zeroIfNull(cashEventRepository.sumByShiftIdAndTypes(shift.getId(), List.of("REFUND_CASH")));
        BigDecimal manualCashEvents = zeroIfNull(cashEventRepository.sumByShiftIdAndTypes(
                shift.getId(),
                List.of("CASH_IN", "CASH_OUT", "PAID_IN", "PAID_OUT")));
        BigDecimal expected = shift.getOpeningCash()
                .add(cashSales)
                .add(cashRefunds)
                .add(manualCashEvents);
        BigDecimal variance = request.getClosingCash().subtract(expected).setScale(2, RoundingMode.HALF_UP);

        shift.setClosingCash(request.getClosingCash());
        shift.setExpectedCash(expected);
        shift.setVariance(variance);

        // Check variance threshold
        if (variance.abs().compareTo(VARIANCE_THRESHOLD) > 0) {
            if (RoleUtil.hasRole("OWNER") || RoleUtil.hasRole("MANAGER")) {
                // Manager/Owner can self-approve
                shift.setStatus("CLOSED");
                shift.setClosedAt(java.time.Instant.now());
            } else {
                // Cashier needs approval
                shift.setStatus("PENDING_APPROVAL");
            }
        } else {
            // Variance acceptable, auto-close
            shift.setStatus("CLOSED");
            shift.setClosedAt(java.time.Instant.now());
        }

        User actor = userRepository.findByEmail(SecurityUtil.currentUsername()).orElseThrow();
        shift.setClosedBy(actor);
        if (approvedBy != null) {
            shift.setApprovedBy(approvedBy);
            shift.setApprovalNote(request.getOverrideReason());
        }

        Shift saved = shiftRepository.save(shift);

        if ("CLOSED".equals(saved.getStatus())) {
            auditService.log(actor, "SHIFT_CLOSE", "Shift", String.valueOf(saved.getId()), null, saved);
            if (approvedBy != null && !approvedBy.getId().equals(actor.getId())) {
                auditService.log(
                        approvedBy,
                        "SHIFT_CLOSE_OVERRIDE",
                        "Shift",
                        String.valueOf(saved.getId()),
                        null,
                        "Override approved by manager. Reason: " + request.getOverrideReason());
            }
            cashEventService.recordInternal(
                    saved,
                    "CLOSE_SHIFT",
                    saved.getClosingCash(),
                    "Shift closed",
                    null,
                    actor);
        } else {
            auditService.log(actor, "SHIFT_CLOSE_PENDING", "Shift", String.valueOf(saved.getId()), null,
                    "Variance: " + variance + " exceeds threshold, pending manager approval");
        }

        return toResponse(saved);
    }

    public ShiftDtos.ShiftClosePrecheckResponse precheckClose(Long shiftId) {
        Shift shift = shiftRepository.findById(shiftId).orElseThrow(() -> new ApiException("Shift not found"));
        ShiftDtos.ShiftClosePrecheckResponse response = new ShiftDtos.ShiftClosePrecheckResponse();
        response.setShiftId(shift.getId());
        List<Sale> heldTickets = saleRepository.findHeldTicketsByShift(shiftId);
        List<Sale> inProgressTickets = saleRepository.findInProgressTicketsByShift(shiftId);
        BigDecimal outstandingCredit = saleRepository.outstandingCreditByShift(shiftId);
        response.setOpenHeldCount(heldTickets.size());
        response.setInProgressCount(inProgressTickets.size());
        response.setOutstandingCreditAmount(outstandingCredit == null ? BigDecimal.ZERO : outstandingCredit);
        response.setHeldTickets(heldTickets.stream().limit(10).map(this::toTicketBlocker).toList());
        response.setInProgressTickets(inProgressTickets.stream().limit(10).map(this::toTicketBlocker).toList());
        List<String> blockers = new ArrayList<>();
        if (!inProgressTickets.isEmpty()) {
            blockers.add("IN_PROGRESS_TICKETS");
        }
        if (response.getOutstandingCreditAmount().compareTo(BigDecimal.ZERO) > 0) {
            blockers.add("OUTSTANDING_CREDIT");
        }
        response.setBlockers(blockers);
        return response;
    }

    private ShiftDtos.TicketBlocker toTicketBlocker(Sale sale) {
        ShiftDtos.TicketBlocker blocker = new ShiftDtos.TicketBlocker();
        blocker.setSaleId(sale.getId());
        blocker.setSaleNumber(sale.getSaleNumber());
        blocker.setStatus(sale.getStatus());
        blocker.setCustomerName(resolveCustomerName(sale));
        blocker.setTotal(zeroIfNull(sale.getGrandTotal()));
        blocker.setPaidAmount(zeroIfNull(sale.getPaidAmount()));
        blocker.setBalanceDue(zeroIfNull(sale.getGrandTotal()).subtract(zeroIfNull(sale.getPaidAmount())));
        blocker.setCreatedAt(sale.getCreatedAt());
        return blocker;
    }

    private String resolveCustomerName(Sale sale) {
        if (sale.getCustomer() == null) {
            return "Walk-in";
        }
        if (sale.getCustomer().getDisplayName() != null && !sale.getCustomer().getDisplayName().isBlank()) {
            return sale.getCustomer().getDisplayName();
        }
        if (sale.getCustomer().getNameEn() != null && !sale.getCustomer().getNameEn().isBlank()) {
            return sale.getCustomer().getNameEn();
        }
        if (sale.getCustomer().getNameKm() != null && !sale.getCustomer().getNameKm().isBlank()) {
            return sale.getCustomer().getNameKm();
        }
        return "Customer #" + sale.getCustomer().getId();
    }

    @Transactional
    public ShiftDtos.ShiftResponse approveVariance(Long shiftId, ShiftDtos.ApproveVarianceRequest request) {
        Shift shift = shiftRepository.findById(shiftId)
                .orElseThrow(() -> new ApiException("Shift not found"));

        if (!"PENDING_APPROVAL".equals(shift.getStatus())) {
            throw new ApiException("Shift not pending approval");
        }

        // Verify manager credentials
        User manager = userRepository.findByEmail(request.getManagerEmail())
                .orElseThrow(() -> new ApiException("Manager not found"));

        boolean isManager = manager.getRoles().stream()
                .anyMatch(r -> "MANAGER".equals(r.getName()) || "OWNER".equals(r.getName()));

        if (!isManager) {
            throw new ApiException("User does not have manager privileges");
        }

        // Verify password
        if (!passwordEncoder.matches(request.getPassword(), manager.getPasswordHash())) {
            throw new ApiException("Invalid credentials");
        }

        // Approve and close
        shift.setStatus("CLOSED");
        shift.setClosedAt(java.time.Instant.now());
        shift.setApprovedBy(manager);
        shift.setApprovalNote(request.getNote());

        Shift saved = shiftRepository.save(shift);

        // Audit log
        auditService.log(manager, "SHIFT_VARIANCE_APPROVED", "Shift",
                String.valueOf(shiftId), null,
                "Variance: " + shift.getVariance() + ", Note: " + request.getNote());

        return toResponse(saved);
    }

    private ShiftDtos.ShiftResponse toResponse(Shift shift) {
        ShiftDtos.ShiftResponse resp = new ShiftDtos.ShiftResponse();
        resp.setId(shift.getId());
        resp.setStatus(shift.getStatus());
        resp.setOpenedAt(shift.getOpenedAt());
        resp.setClosedAt(shift.getClosedAt());
        resp.setOpeningCash(shift.getOpeningCash());
        resp.setClosingCash(shift.getClosingCash());
        resp.setExpectedCash(shift.getExpectedCash());
        resp.setVariance(shift.getVariance());
        resp.setOpenedBy(shift.getOpenedBy() != null ? shift.getOpenedBy().getId() : null);
        resp.setClosedBy(shift.getClosedBy() != null ? shift.getClosedBy().getId() : null);
        resp.setApprovedBy(shift.getApprovedBy() != null ? shift.getApprovedBy().getId() : null);
        resp.setApprovalNote(shift.getApprovalNote());
        resp.setStoreId(shift.getStore() != null ? shift.getStore().getId() : null);
        resp.setStoreName(shift.getStore() != null ? shift.getStore().getName() : null);
        resp.setCashSales(zeroIfNull(cashEventRepository.sumByShiftIdAndTypes(shift.getId(), List.of("SALE_CASH"))));
        resp.setCashRefunds(zeroIfNull(cashEventRepository.sumByShiftIdAndTypes(shift.getId(), List.of("REFUND_CASH"))));
        resp.setManualCashEvents(zeroIfNull(cashEventRepository.sumByShiftIdAndTypes(
                shift.getId(),
                List.of("CASH_IN", "CASH_OUT", "PAID_IN", "PAID_OUT"))));
        if (shift.getId() != null) {
            var view = saleRepository.salesByShift(shift.getId());
            if (view != null) {
                resp.setSalesTotal(view.getTotal());
                resp.setSalesCount(view.getCount());
            }
        }
        return resp;
    }

    private User verifyManagerOverrideCredentials(String managerEmail, String managerPassword) {
        if (managerEmail == null || managerEmail.isBlank()) {
            throw new ApiException("Manager email is required for force close");
        }
        if (managerPassword == null || managerPassword.isBlank()) {
            throw new ApiException("Manager password is required for force close");
        }
        User manager = userRepository.findByEmail(managerEmail)
                .orElseThrow(() -> new ApiException("Manager not found"));
        boolean isManager = manager.getRoles().stream()
                .anyMatch(r -> "MANAGER".equals(r.getName()) || "OWNER".equals(r.getName()));
        if (!isManager) {
            throw new ApiException("User does not have manager privileges");
        }
        if (!passwordEncoder.matches(managerPassword, manager.getPasswordHash())) {
            throw new ApiException("Invalid manager credentials");
        }
        return manager;
    }

    private Store resolveStore(Long storeId) {
        if (storeId != null) {
            return storeRepository.findById(storeId).orElseThrow(() -> new ApiException("Store not found"));
        }
        return storeRepository.findAll().stream().findFirst()
                .orElseThrow(() -> new ApiException("No store configured"));
    }

    private BigDecimal zeroIfNull(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }
}
